// audio_capture.c — see audio_capture.h for the parity/hardware caveats.
//
// *** HARDWARE-UNVERIFIED CODE — READ BEFORE FLASHING ***
// ES7210 register values below are copied verbatim from
// babycare/main/app_main.c's es7210_init_codec() (confirmed working at
// 16kHz on this exact board), NOT from Espressif's official esp-bsp driver
// -- an earlier version of this file mixed register addresses from both
// sources and produced a genuine conflict (both claimed register 0x07, for
// two different purposes), which could not be resolved without the ES7210
// datasheet or hardware access. Reusing babycare's own proven values
// end-to-end avoids that conflict entirely.
//
// Rate-changing theory (unverified): ES7210 runs in I2S slave mode, so its
// actual output sample rate is determined by the MCLK the ESP32-S3 master
// actually drives, not by any codec register alone. ESP-IDF's I2S std
// driver derives MCLK = mclk_multiple x sample_rate_hz (default
// mclk_multiple = 256, unchanged here). babycare's OSR register (0x20 at
// reg 0x03) implements sample_rate = MCLK / (OSR x 8) = MCLK / 256 -- so
// requesting 22050Hz from the ESP32-S3 I2S peripheral (this file's
// I2S_STD_CLK_DEFAULT_CONFIG(CRY_GATE_SR) below) should, under this same
// formula, make the codec output 22050Hz with NO codec register changes at
// all. This is the same theory applied in babycare's own cry_gate_feature.c
// integration (see its file header for the fuller explanation). Before
// trusting classifier output from this module: flash this example, capture
// a WAV via sd_upload, and listen to it -- confirm correct pitch (not sped
// up/slowed down) and no garbling before relying on it.
#include "audio_capture.h"

#include <string.h>
#include <math.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_err.h"
#include "esp_log.h"
#include "driver/i2s_std.h"
#include "driver/i2c_master.h"
#include "driver/gpio.h"

static const char *TAG = "audio_capture";

#define I2S_BCK_PIN   GPIO_NUM_9
#define I2S_WS_PIN    GPIO_NUM_45
#define I2S_MCK_PIN   GPIO_NUM_16
#define I2S_DOUT_PIN  GPIO_NUM_8   /* unused (no playback in this example) */
#define I2S_DIN_PIN   GPIO_NUM_10  /* <- ES7210 ADC <- onboard mics */

#define CODEC_I2C_SDA  GPIO_NUM_17
#define CODEC_I2C_SCL  GPIO_NUM_18
#define CODEC_I2C_PORT I2C_NUM_0
#define CODEC_I2C_FREQ 100000
#define ES7210_I2C_ADDR 0x40

static i2s_chan_handle_t s_i2s_rx_chan = NULL;

static esp_err_t codec_reg_write(i2c_master_dev_handle_t dev, uint8_t reg, uint8_t val) {
    uint8_t buf[2] = {reg, val};
    esp_err_t ret = i2c_master_transmit(dev, buf, 2, pdMS_TO_TICKS(100));
    if (ret != ESP_OK) {
        ESP_LOGW(TAG, "codec_reg_write reg=0x%02X val=0x%02X err=%s", reg, val, esp_err_to_name(ret));
    }
    return ret;
}

// Byte-for-byte identical to babycare/main/app_main.c's es7210_init_codec()
// -- no register value here depends on target sample rate; the rate change
// comes entirely from this file's I2S_STD_CLK_DEFAULT_CONFIG(CRY_GATE_SR)
// in audio_capture_init() below (see file header theory).
static esp_err_t es7210_init_codec(i2c_master_dev_handle_t dev) {
    codec_reg_write(dev, 0x00, 0xFF);  /* Software reset */
    vTaskDelay(pdMS_TO_TICKS(20));
    codec_reg_write(dev, 0x00, 0x32);  /* Normal operation, PDM disable */
    codec_reg_write(dev, 0x01, 0x1F);  /* All internal clocks on */
    codec_reg_write(dev, 0x02, 0xC0);  /* MCLK source = external pin, CLK_DIV=1 */
    codec_reg_write(dev, 0x03, 0x20);  /* OSR=32 (rate set via I2S MCLK, not here) */
    codec_reg_write(dev, 0x06, 0x00);  /* Analog system default */
    codec_reg_write(dev, 0x07, 0x20);  /* MIC bias enable */
    codec_reg_write(dev, 0x08, 0x11);  /* Enable ADC1+ADC2, HPF on */
    codec_reg_write(dev, 0x09, 0x11);  /* Enable ADC3+ADC4, HPF on */
    codec_reg_write(dev, 0x0A, 0x00);
    codec_reg_write(dev, 0x0B, 0x00);
    codec_reg_write(dev, 0x22, 0x00);  /* I2S slave mode */
    codec_reg_write(dev, 0x23, 0x00);  /* I2S format standard, 16-bit */
    codec_reg_write(dev, 0x10, 0x14);  /* MIC1 gain ~30dB */
    codec_reg_write(dev, 0x11, 0x14);  /* MIC2 gain */
    codec_reg_write(dev, 0x12, 0x14);  /* MIC3 gain */
    codec_reg_write(dev, 0x13, 0x14);  /* MIC4 gain */
    codec_reg_write(dev, 0x14, 0x00);  /* Unmute ADC3/4 */
    codec_reg_write(dev, 0x15, 0x00);  /* Unmute ADC1/2 */

    ESP_LOGI(TAG, "ES7210 initialized (rate set via I2S MCLK, target=%dHz) "
                  "-- UNVERIFIED on hardware, see file header", CRY_GATE_SR);
    return ESP_OK;
}

int audio_capture_init(void) {
    i2c_master_bus_handle_t bus;
    i2c_master_bus_config_t bus_cfg = {
        .i2c_port = CODEC_I2C_PORT,
        .sda_io_num = CODEC_I2C_SDA,
        .scl_io_num = CODEC_I2C_SCL,
        .clk_source = I2C_CLK_SRC_DEFAULT,
        .glitch_ignore_cnt = 7,
        .flags.enable_internal_pullup = true,
    };
    if (i2c_new_master_bus(&bus_cfg, &bus) != ESP_OK) {
        ESP_LOGE(TAG, "I2C bus init failed");
        return -1;
    }

    i2c_master_dev_handle_t es7210_dev;
    i2c_device_config_t es7210_cfg = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address = ES7210_I2C_ADDR,
        .scl_speed_hz = CODEC_I2C_FREQ,
    };
    if (i2c_master_bus_add_device(bus, &es7210_cfg, &es7210_dev) != ESP_OK) {
        ESP_LOGE(TAG, "ES7210 not found on I2C (addr=0x%02X)", ES7210_I2C_ADDR);
        i2c_del_master_bus(bus);
        return -1;
    }
    es7210_init_codec(es7210_dev);
    i2c_master_bus_rm_device(es7210_dev);
    i2c_del_master_bus(bus);

    i2s_chan_config_t chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(I2S_NUM_0, I2S_ROLE_MASTER);
    chan_cfg.auto_clear = true;
    i2s_chan_handle_t tx_unused = NULL;
    esp_err_t ret = i2s_new_channel(&chan_cfg, &tx_unused, &s_i2s_rx_chan);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "i2s_new_channel: %s", esp_err_to_name(ret));
        return -1;
    }

    i2s_std_config_t std_cfg = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(CRY_GATE_SR),
        .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO),
        .gpio_cfg = {
            .mclk = I2S_MCK_PIN,
            .bclk = I2S_BCK_PIN,
            .ws = I2S_WS_PIN,
            .dout = I2S_DOUT_PIN,
            .din = I2S_DIN_PIN,
            .invert_flags = {.mclk_inv = false, .bclk_inv = false, .ws_inv = false},
        },
    };

    ret = i2s_channel_init_std_mode(s_i2s_rx_chan, &std_cfg);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "i2s RX init: %s", esp_err_to_name(ret));
        return -1;
    }
    ret = i2s_channel_enable(s_i2s_rx_chan);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "i2s RX enable: %s", esp_err_to_name(ret));
        return -1;
    }

    ESP_LOGI(TAG, "I2S RX ready at %dHz: BCK=%d WS=%d MCK=%d DIN=%d",
             CRY_GATE_SR, I2S_BCK_PIN, I2S_WS_PIN, I2S_MCK_PIN, I2S_DIN_PIN);
    return 0;
}

int audio_capture_record_10s(float *out_buf) {
    if (s_i2s_rx_chan == NULL) {
        ESP_LOGE(TAG, "audio_capture_init() was not called");
        return -1;
    }

    const int chunk_samples = 4096;
    int16_t *raw = (int16_t *)malloc(chunk_samples * sizeof(int16_t));
    if (raw == NULL) {
        ESP_LOGE(TAG, "OOM allocating capture chunk buffer");
        return -1;
    }

    int samples_captured = 0;
    while (samples_captured < CRY_GATE_N_SAMPLES) {
        int want = CRY_GATE_N_SAMPLES - samples_captured;
        if (want > chunk_samples) want = chunk_samples;

        size_t bytes_read = 0;
        esp_err_t ret = i2s_channel_read(s_i2s_rx_chan, raw, want * sizeof(int16_t),
                                          &bytes_read, pdMS_TO_TICKS(2000));
        if (ret != ESP_OK || bytes_read == 0) {
            ESP_LOGE(TAG, "i2s_channel_read failed: %s", esp_err_to_name(ret));
            free(raw);
            return -1;
        }

        int n = (int)(bytes_read / sizeof(int16_t));
        for (int i = 0; i < n; i++) {
            out_buf[samples_captured + i] = (float)raw[i] / 32768.0f;
        }
        samples_captured += n;
    }
    free(raw);

    // Peak-normalize to [-1, 1], matching export/preprocess.py's
    // preprocess_audio() exactly.
    float peak = 0.0f;
    for (int i = 0; i < CRY_GATE_N_SAMPLES; i++) {
        float a = fabsf(out_buf[i]);
        if (a > peak) peak = a;
    }
    if (peak > 0.0f) {
        for (int i = 0; i < CRY_GATE_N_SAMPLES; i++) {
            out_buf[i] /= peak;
        }
    }
    return 0;
}
