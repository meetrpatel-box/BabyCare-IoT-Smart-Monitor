/* BabyCare ESP32-S3 — Integrated App with Working Audio
 *
 * WiFi provisioning via BLE (NimBLE)
 * Sensors: MLX90614 temperature, HLK-LD6002 radar
 * Camera: MJPEG stream on port 81 /stream
 * Audio: WebSocket on port 81 /ws (working via esp_codec_dev)
 *   - App -> Device: 16-bit mono PCM -> speaker
 *   - Device -> App: 16-bit mono mic audio streamed back
 * MQTT: vitals, heartbeat, commands
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <netdb.h>
#include <sys/socket.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <errno.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "freertos/semphr.h"
#include "freertos/ringbuf.h"
#include "freertos/idf_additions.h"
#include "esp_heap_caps.h"

#include "esp_log.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_system.h"
#include "esp_netif.h"
#include "nvs_flash.h"
#include "nvs.h"
#include "esp_random.h"

#include "driver/gpio.h"
#include "driver/ledc.h"
#include "driver/uart.h"
#include "driver/i2c_master.h"

#include "mqtt_client.h"
#include "esp_http_server.h"
#include "esp_camera.h"

/* NimBLE */
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "host/ble_hs.h"
#include "host/ble_uuid.h"
#include "host/util/util.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"

/* Working audio stack */
#include "bsp_board.h"
#include "esp_codec_dev.h"
#include "tca9555_driver.h"
#include "cry_gate_feature.h"
#include "camera_stream.h"

static const char *TAG = "babyCare";

/* Config */
#define MQTT_BROKER_URI      "mqtt://broker.hivemq.com:1883"
#define DEVICE_ID            "device001"
#define DEVICE_NAME          "BabyCare-ESP32"
#define MQTT_STATUS_TOPIC    "cradle/" DEVICE_ID "/status"
#define MQTT_CMD_TOPIC       "cradle/" DEVICE_ID "/cmd"
#define MQTT_RESPONSE_TOPIC  "cradle/" DEVICE_ID "/response"
#define MQTT_VITALS_TOPIC    "cradle/" DEVICE_ID "/vitals"
#define MQTT_ALERT_TOPIC     "cradle/" DEVICE_ID "/alert"
#define MQTT_OFFLINE_MSG     "{\"device\":\"" DEVICE_NAME "\",\"deviceId\":\"" DEVICE_ID "\",\"status\":\"offline\"}"

/* Pins */
#define LD6002_UART_TX   GPIO_NUM_3
#define LD6002_UART_RX   GPIO_NUM_4
#define LD6002_UART_PORT UART_NUM_1
#define LD6002_BAUD_RATE 115200
/* MLX90614 is on its own bit-bang I2C (GPIO 8/9).
 * Both hardware I2C ports are taken: NUM_0 by bsp_board codec, NUM_1 by camera SCCB.
 * Software I2C is the only option. */
#define MLX90614_I2C_ADDR 0x5A
#define MLX90614_I2C_SDA  GPIO_NUM_8
#define MLX90614_I2C_SCL  GPIO_NUM_9
#define SW_I2C_DELAY_US   5
#define CAM_XCLK 43
#define CAM_PCLK 44
#define CAM_VSYNC 21
#define CAM_HREF 1
#define CAM_SIOD 11
#define CAM_SIOC 10
#define CAM_D7 48
#define CAM_D6 47
#define CAM_D5 46
#define CAM_D4 45
#define CAM_D3 39
#define CAM_D2 18
#define CAM_D1 17
#define CAM_D0 2
#define CAM_PWDN -1
#define CAM_RESET -1
#define CAM_STREAM_PORT 81
#define NVS_NS       "babyCare"
#define NVS_KEY_SSID "wifi_ssid"
#define NVS_KEY_PASS "wifi_pass"

/* Audio sizes */
#define SAMPLE_RATE         16000
#define AUDIO_MONO_SAMPLES  2048
/* Output to app: 16-bit mono = 512 * 2 = 1024 bytes */
#define AUDIO_CHUNK_BYTES   (AUDIO_MONO_SAMPLES * 2)
/* ES7210 via bsp_board outputs 4-ch 32-bit frames: 512 frames x 4ch x 4bytes = 8192 bytes */
#define CODEC_READ_BYTES    (AUDIO_MONO_SAMPLES * 4 * 4)
/* Speaker 32-bit stereo: 512 frames x 2ch x 4bytes = 4096 bytes */
#define SPEAKER_WRITE_BYTES (AUDIO_MONO_SAMPLES * 2 * 4)

/* BLE UUIDs */
#define PROV_SVC_UUID    0xFFF0
#define PROV_SCAN_UUID   0xFFF4
#define PROV_SSID_UUID   0xFFF1
#define PROV_PASS_UUID   0xFFF2
#define PROV_STATUS_UUID 0xFFF3

/* Forward declarations */
static void ble_start_advertising(void);
static void mqtt_app_start(void);
static void mqtt_start_task(void *pv);
static void prov_complete_task(void *pv);
void mqtt_event_handler(void *handler_args, esp_event_base_t base,
                        int32_t event_id, void *event_data);

/* Globals */
static EventGroupHandle_t wifi_event_group;
#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT      BIT1
static int s_wifi_retry = 0;
#define WIFI_MAX_RETRY 10

static esp_mqtt_client_handle_t mqtt_client = NULL;
static bool mqtt_connected = false;
static httpd_handle_t g_ws_server_handle = NULL;
static int g_ws_client_fd = -1;
volatile bool g_video_stream_active = false;
volatile bool recording_active = false;
static SemaphoreHandle_t recording_mutex = NULL;
static char g_device_ip[24] = {0};
static RingbufHandle_t audio_out_ringbuf = NULL;
static int   g_sim_humidity = 62;
static int   g_sim_spo2     = 98;
static volatile float g_ambient_temp        = 25.0f;
static volatile float g_object_temp         = 36.5f;
static volatile float g_current_heart_rate  = 0.0f;
static volatile float g_current_breath_rate = 0.0f;
static volatile float g_current_distance    = 0.0f;
volatile bool g_audio_playing = false;
static volatile float g_play_freq     = 440.0f;
static char g_prov_ssid[64]   = {0};
static char g_prov_pass[128]  = {0};
static char g_prov_status[32] = "idle";
static char g_scan_json[4096] = "[]";
static uint16_t g_status_handle = 0;
static uint16_t g_ble_conn      = BLE_HS_CONN_HANDLE_NONE;
static bool g_prov_mode         = false;
static EventGroupHandle_t g_prov_event_group;
#define PROV_DO_CONNECT_BIT BIT0
static volatile bool g_prov_in_progress = false;
static esp_codec_dev_handle_t g_play_dev   = NULL;
static esp_codec_dev_handle_t g_record_dev = NULL;

/* NVS helpers */
static bool nv_load_wifi(char *ssid, char *pass)
{
    nvs_handle_t h;
    if (nvs_open(NVS_NS, NVS_READONLY, &h) != ESP_OK) return false;
    size_t sl = 64, pl = 128;
    bool ok = (nvs_get_str(h, NVS_KEY_SSID, ssid, &sl) == ESP_OK)
           && (nvs_get_str(h, NVS_KEY_PASS, pass, &pl) == ESP_OK)
           && (ssid[0] != '\0');
    nvs_close(h);
    return ok;
}

static void nv_save_wifi(const char *ssid, const char *pass)
{
    nvs_handle_t h;
    if (nvs_open(NVS_NS, NVS_READWRITE, &h) != ESP_OK) return;
    nvs_set_str(h, NVS_KEY_SSID, ssid);
    nvs_set_str(h, NVS_KEY_PASS, pass);
    nvs_commit(h);
    nvs_close(h);
}

/* BLE notify */
static void ble_notify_status(const char *status)
{
    strlcpy(g_prov_status, status, sizeof(g_prov_status));
    if (g_ble_conn == BLE_HS_CONN_HANDLE_NONE || g_status_handle == 0) return;
    struct os_mbuf *om = ble_hs_mbuf_from_flat(status, strlen(status));
    if (om) ble_gatts_notify_custom(g_ble_conn, g_status_handle, om);
}

static void prov_complete_task(void *pv)
{
    ble_notify_status("connected");
    vTaskDelay(pdMS_TO_TICKS(500));
    if (g_ble_conn != BLE_HS_CONN_HANDLE_NONE) {
        ble_gap_terminate(g_ble_conn, 0x13);
        vTaskDelay(pdMS_TO_TICKS(2000));
    }
    mqtt_app_start();
    vTaskDelete(NULL);
}

static char s_mqtt_client_id[48] = {0};
static const char *s_mqtt_brokers[] = {
    MQTT_BROKER_URI,
    "mqtt://broker.emqx.io:1883",
};
#define NUM_MQTT_BROKERS (sizeof(s_mqtt_brokers) / sizeof(s_mqtt_brokers[0]))
static int s_broker_idx = 0;
static int s_consecutive_mqtt_errors = 0;

static void mqtt_app_start(void)
{
    if (mqtt_client != NULL) {
        ESP_LOGI(TAG, "MQTT client already created, triggering reconnect");
        esp_mqtt_client_reconnect(mqtt_client);
        return;
    }

    uint8_t mac[6] = {0};
    esp_wifi_get_mac(WIFI_IF_STA, mac);
    snprintf(s_mqtt_client_id, sizeof(s_mqtt_client_id), "BabyCare_%s_%02X%02X%02X",
             DEVICE_ID, mac[3], mac[4], mac[5]);

    static const char offline_msg[] = MQTT_OFFLINE_MSG;
    esp_mqtt_client_config_t cfg = {
        .broker.address.uri = s_mqtt_brokers[s_broker_idx],
        .credentials = {
            .client_id = s_mqtt_client_id,
        },
        .session = {
            .last_will = {
                .topic = MQTT_STATUS_TOPIC,
                .msg = offline_msg,
                .msg_len = sizeof(offline_msg) - 1,
                .qos = 0,
                .retain = 0,
            },
            .keepalive = 30, // 30s keepalive ensures NAT tables do not drop the socket
            .disable_clean_session = false,
        },
        .network = {
            .timeout_ms = 15000,
            .reconnect_timeout_ms = 5000,
            .disable_auto_reconnect = false,
        },
        .buffer = {
            .size = 2048,
            .out_size = 2048,
        },
    };

    ESP_LOGI(TAG, "Starting robust MQTT client (ClientId=%s, Broker=%s, Keepalive=30s, Timeout=15s)...",
             s_mqtt_client_id, s_mqtt_brokers[s_broker_idx]);
    mqtt_client = esp_mqtt_client_init(&cfg);
    if (!mqtt_client) {
        ESP_LOGE(TAG, "Failed to initialize MQTT client");
        return;
    }
    esp_mqtt_client_register_event(mqtt_client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_mqtt_client_start(mqtt_client);
}

static void mqtt_start_task(void *pv) { mqtt_app_start(); vTaskDelete(NULL); }

static void wifi_event_handler(void *arg, esp_event_base_t base,
                               int32_t event_id, void *event_data)
{
    if (base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        mqtt_connected = false;
        if (g_prov_in_progress) return;
        if (s_wifi_retry < WIFI_MAX_RETRY) {
            s_wifi_retry++;
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_wifi_connect();
        } else {
            xEventGroupSetBits(wifi_event_group, WIFI_FAIL_BIT);
            if (g_prov_mode) ble_notify_status("failed");
        }
    } else if (base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *ev = event_data;
        snprintf(g_device_ip, sizeof(g_device_ip), IPSTR, IP2STR(&ev->ip_info.ip));
        ESP_LOGI(TAG, "Got IP: %s", g_device_ip);
        s_wifi_retry = 0;
        xEventGroupSetBits(wifi_event_group, WIFI_CONNECTED_BIT);
        if (g_prov_mode) {
            nv_save_wifi(g_prov_ssid, g_prov_pass);
            g_prov_mode = false;
            xTaskCreate(prov_complete_task, "prov_done", 4096, NULL, 5, NULL);
        } else if (mqtt_client == NULL) {
            xTaskCreate(mqtt_start_task, "mqtt_start", 4096, NULL, 5, NULL);
        } else {
            ESP_LOGI(TAG, "IP acquired, triggering MQTT reconnect...");
            esp_mqtt_client_reconnect(mqtt_client);
        }
    }
}

static void wifi_scan_task(void *pv)
{
    esp_wifi_start();
    wifi_scan_config_t sc = {
        .ssid=NULL,.bssid=NULL,.channel=0,.show_hidden=false,
        .scan_type=WIFI_SCAN_TYPE_ACTIVE,
        .scan_time.active={.min=100,.max=200},
    };
    esp_wifi_scan_start(&sc, true);
    uint16_t count = 20;
    wifi_ap_record_t aps[20];
    esp_wifi_scan_get_ap_records(&count, aps);
    esp_wifi_stop();
    if (count > 8) count = 8;
    char *buf = g_scan_json; int rem = (int)sizeof(g_scan_json);
    int n = snprintf(buf, rem, "["); buf += n; rem -= n;
    for (int i = 0; i < (int)count && rem > 20; i++) {
        char ss[21] = {0}; int si = 0;
        for (int ci = 0; aps[i].ssid[ci] && si < 20; ci++) {
            uint8_t c = (uint8_t)aps[i].ssid[ci];
            if (c >= 0x20 && c < 0x7F && c != '"' && c != '\\') ss[si++] = (char)c;
        }
        n = snprintf(buf, rem, "%s{\"s\":\"%s\",\"r\":%d,\"a\":%d}",
                     i>0?",":"", ss, aps[i].rssi, aps[i].authmode);
        buf += n; rem -= n;
    }
    if (rem > 2) { *buf++ = ']'; *buf = '\0'; }
    vTaskDelete(NULL);
}

static void prov_connect_task(void *pv)
{
    for (;;) {
        xEventGroupWaitBits(g_prov_event_group, PROV_DO_CONNECT_BIT, pdTRUE, pdFALSE, portMAX_DELAY);
        g_prov_in_progress = true; s_wifi_retry = 0;
        xEventGroupClearBits(wifi_event_group, WIFI_FAIL_BIT);
        wifi_config_t wifi_cfg = {0};
        strlcpy((char*)wifi_cfg.sta.ssid, g_prov_ssid, sizeof(wifi_cfg.sta.ssid));
        strlcpy((char*)wifi_cfg.sta.password, g_prov_pass, sizeof(wifi_cfg.sta.password));
        esp_wifi_set_config(WIFI_IF_STA, &wifi_cfg);
        esp_wifi_start(); g_prov_in_progress = false; esp_wifi_connect();
        EventBits_t bits = xEventGroupWaitBits(wifi_event_group, WIFI_CONNECTED_BIT|WIFI_FAIL_BIT,
                                               pdFALSE, pdFALSE, portMAX_DELAY);
        if (bits & WIFI_CONNECTED_BIT) break;
        g_prov_in_progress = true; esp_wifi_stop(); vTaskDelay(pdMS_TO_TICKS(100)); g_prov_in_progress = false;
    }
    vTaskDelete(NULL);
}

/* GATT callbacks */
static int gatt_scan_read(uint16_t c, uint16_t a, struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    (void)c;(void)a;(void)arg;
    if (ctxt->op != BLE_GATT_ACCESS_OP_READ_CHR) return BLE_ATT_ERR_UNLIKELY;
    return os_mbuf_append(ctxt->om, g_scan_json, strlen(g_scan_json))==0 ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
}
static int gatt_ssid_write(uint16_t c, uint16_t a, struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    (void)c;(void)a;(void)arg;
    if (ctxt->op != BLE_GATT_ACCESS_OP_WRITE_CHR) return BLE_ATT_ERR_UNLIKELY;
    uint16_t len = OS_MBUF_PKTLEN(ctxt->om);
    if (len >= sizeof(g_prov_ssid)) len = sizeof(g_prov_ssid)-1;
    os_mbuf_copydata(ctxt->om, 0, len, g_prov_ssid); g_prov_ssid[len]='\0';
    return 0;
}
static int gatt_pass_write(uint16_t c, uint16_t a, struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    (void)a;(void)arg;
    if (ctxt->op != BLE_GATT_ACCESS_OP_WRITE_CHR) return BLE_ATT_ERR_UNLIKELY;
    uint16_t len = OS_MBUF_PKTLEN(ctxt->om);
    if (len >= sizeof(g_prov_pass)) len = sizeof(g_prov_pass)-1;
    os_mbuf_copydata(ctxt->om, 0, len, g_prov_pass); g_prov_pass[len]='\0';
    if (g_prov_ssid[0] != '\0') { ble_notify_status("connecting"); xEventGroupSetBits(g_prov_event_group, PROV_DO_CONNECT_BIT); }
    return 0;
}
static int gatt_status_access(uint16_t c, uint16_t a, struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    (void)c;(void)a;(void)arg;
    if (ctxt->op != BLE_GATT_ACCESS_OP_READ_CHR) return BLE_ATT_ERR_UNLIKELY;
    return os_mbuf_append(ctxt->om, g_prov_status, strlen(g_prov_status))==0 ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
}

static const struct ble_gatt_svc_def gatt_svcs[] = {
    { .type = BLE_GATT_SVC_TYPE_PRIMARY, .uuid = BLE_UUID16_DECLARE(PROV_SVC_UUID),
      .characteristics = (struct ble_gatt_chr_def[]) {
          { .uuid=BLE_UUID16_DECLARE(PROV_SCAN_UUID),   .access_cb=gatt_scan_read,    .flags=BLE_GATT_CHR_F_READ },
          { .uuid=BLE_UUID16_DECLARE(PROV_SSID_UUID),   .access_cb=gatt_ssid_write,   .flags=BLE_GATT_CHR_F_WRITE|BLE_GATT_CHR_F_WRITE_NO_RSP },
          { .uuid=BLE_UUID16_DECLARE(PROV_PASS_UUID),   .access_cb=gatt_pass_write,   .flags=BLE_GATT_CHR_F_WRITE|BLE_GATT_CHR_F_WRITE_NO_RSP },
          { .uuid=BLE_UUID16_DECLARE(PROV_STATUS_UUID), .access_cb=gatt_status_access, .flags=BLE_GATT_CHR_F_READ|BLE_GATT_CHR_F_NOTIFY, .val_handle=&g_status_handle },
          { 0 }
      },
    },
    { 0 }
};

static int ble_gap_event(struct ble_gap_event *ev, void *arg)
{
    switch (ev->type) {
        case BLE_GAP_EVENT_CONNECT:
            if (ev->connect.status == 0) g_ble_conn = ev->connect.conn_handle;
            else if (g_prov_mode) ble_start_advertising();
            break;
        case BLE_GAP_EVENT_DISCONNECT: g_ble_conn = BLE_HS_CONN_HANDLE_NONE; if (g_prov_mode) ble_start_advertising(); break;
        case BLE_GAP_EVENT_ADV_COMPLETE: if (g_prov_mode) ble_start_advertising(); break;
        default: break;
    }
    return 0;
}

static void ble_start_advertising(void)
{
    struct ble_gap_adv_params ap = {0};
    ap.conn_mode = BLE_GAP_CONN_MODE_UND; ap.disc_mode = BLE_GAP_DISC_MODE_GEN;
    ble_uuid16_t su = BLE_UUID16_INIT(PROV_SVC_UUID);
    struct ble_hs_adv_fields f = {0};
    f.flags=BLE_HS_ADV_F_DISC_GEN|BLE_HS_ADV_F_BREDR_UNSUP;
    f.uuids16=&su; f.num_uuids16=1; f.uuids16_is_complete=1;
    f.name=(const uint8_t*)ble_svc_gap_device_name(); f.name_len=strlen(ble_svc_gap_device_name()); f.name_is_complete=1;
    ble_gap_adv_set_fields(&f);
    ble_gap_adv_start(BLE_OWN_ADDR_PUBLIC, NULL, BLE_HS_FOREVER, &ap, ble_gap_event, NULL);
}

static void ble_on_sync(void)
{
    uint8_t addr[6]={0}; ble_hs_id_copy_addr(BLE_ADDR_PUBLIC, addr, NULL);
    char dn[24]; snprintf(dn, sizeof(dn), "BabyCare-%02X%02X", addr[1], addr[0]);
    ble_svc_gap_device_name_set(dn);
    ESP_LOGI(TAG, "BLE ready: %s", dn);
    ble_start_advertising();
}

static void ble_host_task(void *p) { nimble_port_run(); nimble_port_freertos_deinit(); }

static void ble_prov_start(void)
{
    g_prov_mode = true;
    ESP_ERROR_CHECK(nimble_port_init());
    ble_hs_cfg.sync_cb=ble_on_sync; ble_hs_cfg.reset_cb=NULL;
    ble_svc_gap_init(); ble_svc_gatt_init();
    ble_gatts_count_cfg(gatt_svcs); ble_gatts_add_svcs(gatt_svcs);
    nimble_port_freertos_init(ble_host_task);
    xTaskCreate(wifi_scan_task,    "wifi_scan", 4096, NULL, 5, NULL);
    xTaskCreate(prov_connect_task, "prov_conn", 4096, NULL, 5, NULL);
}

/* ============================================================
 * Software bit-bang I2C for MLX90614 on GPIO 8 (SDA) / GPIO 9 (SCL)
 * Both HW I2C ports are occupied: NUM_0 = codec, NUM_1 = camera SCCB
 * ============================================================ */
static void sw_i2c_delay(void) { esp_rom_delay_us(SW_I2C_DELAY_US); }

static void sw_i2c_init(void)
{
    gpio_set_direction(MLX90614_I2C_SDA, GPIO_MODE_INPUT_OUTPUT_OD);
    gpio_set_direction(MLX90614_I2C_SCL, GPIO_MODE_INPUT_OUTPUT_OD);
    gpio_set_pull_mode(MLX90614_I2C_SDA, GPIO_PULLUP_ONLY);
    gpio_set_pull_mode(MLX90614_I2C_SCL, GPIO_PULLUP_ONLY);
    gpio_set_level(MLX90614_I2C_SCL, 1);
    gpio_set_level(MLX90614_I2C_SDA, 1);
    ESP_LOGI(TAG, "MLX90614 soft-I2C ready (SDA=%d SCL=%d)", MLX90614_I2C_SDA, MLX90614_I2C_SCL);
}

static void sw_i2c_start(void)
{
    gpio_set_level(MLX90614_I2C_SDA, 1); sw_i2c_delay();
    gpio_set_level(MLX90614_I2C_SCL, 1); sw_i2c_delay();
    gpio_set_level(MLX90614_I2C_SDA, 0); sw_i2c_delay();
    gpio_set_level(MLX90614_I2C_SCL, 0); sw_i2c_delay();
}

static void sw_i2c_stop(void)
{
    gpio_set_level(MLX90614_I2C_SDA, 0); sw_i2c_delay();
    gpio_set_level(MLX90614_I2C_SCL, 1); sw_i2c_delay();
    gpio_set_level(MLX90614_I2C_SDA, 1); sw_i2c_delay();
}

static bool sw_i2c_write_byte(uint8_t byte)
{
    for (int i = 7; i >= 0; i--) {
        gpio_set_level(MLX90614_I2C_SDA, (byte >> i) & 1);
        sw_i2c_delay();
        gpio_set_level(MLX90614_I2C_SCL, 1); sw_i2c_delay();
        gpio_set_level(MLX90614_I2C_SCL, 0); sw_i2c_delay();
    }
    /* Read ACK */
    gpio_set_direction(MLX90614_I2C_SDA, GPIO_MODE_INPUT);
    sw_i2c_delay();
    gpio_set_level(MLX90614_I2C_SCL, 1); sw_i2c_delay();
    bool ack = (gpio_get_level(MLX90614_I2C_SDA) == 0);
    gpio_set_level(MLX90614_I2C_SCL, 0); sw_i2c_delay();
    gpio_set_direction(MLX90614_I2C_SDA, GPIO_MODE_INPUT_OUTPUT_OD);
    return ack;
}

static uint8_t sw_i2c_read_byte(bool send_ack)
{
    uint8_t byte = 0;
    gpio_set_direction(MLX90614_I2C_SDA, GPIO_MODE_INPUT);
    for (int i = 7; i >= 0; i--) {
        sw_i2c_delay();
        gpio_set_level(MLX90614_I2C_SCL, 1); sw_i2c_delay();
        byte |= (uint8_t)(gpio_get_level(MLX90614_I2C_SDA) << i);
        gpio_set_level(MLX90614_I2C_SCL, 0);
    }
    gpio_set_direction(MLX90614_I2C_SDA, GPIO_MODE_INPUT_OUTPUT_OD);
    gpio_set_level(MLX90614_I2C_SDA, send_ack ? 0 : 1);
    sw_i2c_delay();
    gpio_set_level(MLX90614_I2C_SCL, 1); sw_i2c_delay();
    gpio_set_level(MLX90614_I2C_SCL, 0); sw_i2c_delay();
    gpio_set_level(MLX90614_I2C_SDA, 1);
    return byte;
}

/* Read MLX90614 register: 0x06=ambient, 0x07=object */
static float mlx90614_read_temp(uint8_t reg)
{
    sw_i2c_start();
    if (!sw_i2c_write_byte((MLX90614_I2C_ADDR << 1) | 0)) {
        sw_i2c_stop(); return 25.0f;
    }
    sw_i2c_write_byte(reg);
    sw_i2c_start();  /* repeated start */
    if (!sw_i2c_write_byte((MLX90614_I2C_ADDR << 1) | 1)) {
        sw_i2c_stop(); return 25.0f;
    }
    uint8_t d0  = sw_i2c_read_byte(true);
    uint8_t d1  = sw_i2c_read_byte(true);
    uint8_t pec = sw_i2c_read_byte(false);  /* PEC byte — ignored */
    sw_i2c_stop();
    (void)pec;
    float t = (((uint16_t)d1 << 8 | d0) * 0.02f) - 273.15f;
    return (t > -40.0f && t < 125.0f) ? t : 25.0f;  /* sanity check */
}

/* --- Sleep State Machine & Analyzer Variables --- */
#define MAX_BED_DISTANCE    1.0f  // Max presence distance (1.0 meter)
#define SLIDING_WINDOW_SIZE 15    // 15 seconds of history
#define FILTER_ALPHA        0.15f // Smoothing factor for EMA

typedef enum {
    AWAKE_OUT_OF_BED = 0,
    AWAKE_IN_BED,
    LIGHT_SLEEP,
    DEEP_SLEEP
} sleep_state_t;

static volatile sleep_state_t g_sleep_state = AWAKE_OUT_OF_BED;
static const char *g_sleep_state_str = "OUT_OF_BED";
static volatile int g_sleep_count = 0;
static volatile bool g_is_sleeping = false;
static volatile float g_smoothed_heart_rate = 0.0f;

static float calculate_median(const float *array, int size) {
    float temp[SLIDING_WINDOW_SIZE];
    for (int i = 0; i < size; i++) temp[i] = array[i];
    for (int i = 0; i < size - 1; i++) {
        for (int j = i + 1; j < size; j++) {
            if (temp[i] > temp[j]) {
                float t = temp[i]; temp[i] = temp[j]; temp[j] = t;
            }
        }
    }
    if (size % 2 == 0) {
        return (temp[size / 2 - 1] + temp[size / 2]) / 2.0f;
    }
    return temp[size / 2];
}

static float calculate_mean(const float *array, int size) {
    float sum = 0.0f;
    for (int i = 0; i < size; i++) sum += array[i];
    return (size > 0) ? (sum / (float)size) : 0.0f;
}

static float calculate_variance(const float *array, int size) {
    if (size <= 0) return 0.0f;
    float mean = calculate_mean(array, size);
    float varSum = 0.0f;
    for (int i = 0; i < size; i++) {
        varSum += (array[i] - mean) * (array[i] - mean);
    }
    return varSum / (float)size;
}

/* LD6002 radar + Sleep & Heart Rate Analyzer */
static void ld6002_rx_task(void *pv)
{
    uart_config_t uc = { .baud_rate=LD6002_BAUD_RATE, .data_bits=UART_DATA_8_BITS,
        .parity=UART_PARITY_DISABLE, .stop_bits=UART_STOP_BITS_1,
        .flow_ctrl=UART_HW_FLOWCTRL_DISABLE, .source_clk=UART_SCLK_DEFAULT };
    uart_driver_install(LD6002_UART_PORT, 2048, 0, 0, NULL, 0);
    uart_param_config(LD6002_UART_PORT, &uc);
    uart_set_pin(LD6002_UART_PORT, LD6002_UART_TX, LD6002_UART_RX, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE);

    // Sliding window ring buffers
    float hr_buf[SLIDING_WINDOW_SIZE] = {0};
    float br_buf[SLIDING_WINDOW_SIZE] = {0};
    float dist_buf[SLIDING_WINDOW_SIZE] = {0};
    int buf_idx = 0;
    bool buf_full = false;

    float latest_hr = 0.0f;
    float latest_br = 0.0f;
    float latest_dist = 0.0f;

    int64_t last_sample_ms = esp_timer_get_time() / 1000;

    uint8_t fr[256]; int pos=0; bool sync=false; int exl=0;
    while (1) {
        uint8_t b;
        if (uart_read_bytes(LD6002_UART_PORT, &b, 1, pdMS_TO_TICKS(50)) > 0) {
            if (!sync) { if (b==0x01){fr[0]=b;pos=1;sync=true;exl=0;} }
            else {
                if (pos < (int)sizeof(fr)) {
                    fr[pos++]=b;
                    if (pos==7){uint16_t dl=(fr[3]<<8)|fr[4];exl=8+dl+1;if(exl>(int)sizeof(fr)){sync=false;pos=0;}}
                    if (exl>0&&pos>=exl) {
                        uint8_t ck=0; for(int i=0;i<7;i++) ck^=fr[i]; ck=~ck;
                        if (ck==fr[7]) {
                            uint16_t tp=(fr[5]<<8)|fr[6];
                            if (tp == 0x0A15) { // Heart Rate
                                float v; memcpy(&v, &fr[8], 4);
                                if (v >= 40.0f && v <= 150.0f) { // Biological range gating
                                    latest_hr = v;
                                }
                            } else if (tp == 0x0A14) { // Breath Rate
                                float v; memcpy(&v, &fr[8], 4);
                                if (v >= 5.0f && v <= 40.0f) { // Biological range gating
                                    latest_br = v;
                                }
                            } else if (tp == 0x0A16) { // Target Distance (in cm)
                                uint32_t f2; memcpy(&f2, &fr[8], 4);
                                if (f2 == 1) {
                                    float d_cm; memcpy(&d_cm, &fr[12], 4);
                                    latest_dist = d_cm / 100.0f; // Convert to meters
                                }
                            }
                        }
                        sync=false;pos=0;exl=0;
                    }
                } else { sync=false;pos=0;exl=0; }
            }
        }

        // --- 1-Second Periodic Sampling & Sleep Analysis ---
        int64_t now_ms = esp_timer_get_time() / 1000;
        if (now_ms - last_sample_ms >= 1000) {
            last_sample_ms = now_ms;

            hr_buf[buf_idx]   = latest_hr;
            br_buf[buf_idx]   = latest_br;
            dist_buf[buf_idx] = latest_dist;

            buf_idx++;
            if (buf_idx >= SLIDING_WINDOW_SIZE) {
                buf_idx = 0;
                buf_full = true;
            }

            if (buf_full) {
                float median_hr = calculate_median(hr_buf, SLIDING_WINDOW_SIZE);
                float var_hr    = calculate_variance(hr_buf, SLIDING_WINDOW_SIZE);

                float mean_br   = calculate_mean(br_buf, SLIDING_WINDOW_SIZE);
                float var_br    = calculate_variance(br_buf, SLIDING_WINDOW_SIZE);

                float mean_dist = calculate_mean(dist_buf, SLIDING_WINDOW_SIZE);
                float var_dist  = calculate_variance(dist_buf, SLIDING_WINDOW_SIZE);

                // Exponential Moving Average (EMA) on Median Heart Rate
                if (g_smoothed_heart_rate == 0.0f) {
                    g_smoothed_heart_rate = median_hr;
                } else if (median_hr > 0.0f) {
                    g_smoothed_heart_rate = (FILTER_ALPHA * median_hr) + ((1.0f - FILTER_ALPHA) * g_smoothed_heart_rate);
                }

                g_current_heart_rate  = g_smoothed_heart_rate > 0.0f ? g_smoothed_heart_rate : latest_hr;
                g_current_breath_rate = mean_br > 0.0f ? mean_br : latest_br;
                g_current_distance    = mean_dist * 100.0f; // Keep in cm

                // Sleep Classification State Machine
                sleep_state_t next_state = g_sleep_state;
                bool is_present     = (mean_dist > 0.01f && mean_dist <= MAX_BED_DISTANCE);
                bool is_moving      = (var_dist > 0.01f); // >0.1m fluctuation
                bool vitals_stable  = (var_hr < 20.0f && var_br < 8.0f);

                if (!is_present) {
                    next_state = AWAKE_OUT_OF_BED;
                } else {
                    if (is_moving || !vitals_stable) {
                        next_state = AWAKE_IN_BED;
                    } else {
                        if (var_hr < 5.0f && var_br < 2.0f) {
                            next_state = DEEP_SLEEP;
                        } else {
                            next_state = LIGHT_SLEEP;
                        }
                    }
                }

                g_sleep_state = next_state;
                switch (g_sleep_state) {
                    case AWAKE_OUT_OF_BED: g_sleep_state_str = "OUT_OF_BED"; break;
                    case AWAKE_IN_BED:     g_sleep_state_str = "AWAKE"; break;
                    case LIGHT_SLEEP:      g_sleep_state_str = "LIGHT_SLEEP"; break;
                    case DEEP_SLEEP:       g_sleep_state_str = "DEEP_SLEEP"; break;
                }

                // Incremental Sleep Count Logic
                bool sleeping_now = (g_sleep_state == LIGHT_SLEEP || g_sleep_state == DEEP_SLEEP);
                if (sleeping_now && !g_is_sleeping) {
                    g_sleep_count++;
                    g_is_sleeping = true;
                } else if (!sleeping_now && g_is_sleeping) {
                    g_is_sleeping = false;
                }
            } else {
                g_current_heart_rate  = latest_hr;
                g_current_breath_rate = latest_br;
                g_current_distance    = latest_dist * 100.0f;
            }
        }
    }
}

static void mqtt_publish_qos(const char *topic, const char *msg, int qos)
{
    if (!mqtt_connected || !mqtt_client) return;
    int msg_id = esp_mqtt_client_publish(mqtt_client, topic, msg, 0, qos, 0);
    if (msg_id < 0) {
        ESP_LOGD(TAG, "MQTT publish failed for %s", topic);
    }
}

static void mqtt_publish(const char *topic, const char *msg)
{
    mqtt_publish_qos(topic, msg, 1);
}

void app_mqtt_publish_alert(const char *event_type, float intensity)
{
    if (!mqtt_connected || !mqtt_client) {
        ESP_LOGW(TAG, "Cannot publish alert '%s': MQTT not connected", event_type ? event_type : "unknown");
        return;
    }
    char buf[256];
    int64_t now_ms = esp_timer_get_time() / 1000;
    snprintf(buf, sizeof(buf),
             "{\"event\":\"%s\",\"deviceId\":\"" DEVICE_ID "\",\"device\":\"" DEVICE_NAME "\",\"intensity\":%.2f,\"timestamp\":%lld}",
             event_type ? event_type : "cry_detected", (double)intensity, (long long)now_ms);
    mqtt_publish_qos(MQTT_ALERT_TOPIC, buf, 1);
    ESP_LOGI(TAG, "🚨 Cry Alert published to MQTT topic %s: %s", MQTT_ALERT_TOPIC, buf);
}

static void sensor_publish_task(void *pv)
{
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(5000));

        /* Always read and update temperatures */
        float amb = mlx90614_read_temp(0x06);
        float obj = mlx90614_read_temp(0x07);
        g_ambient_temp = amb;
        g_object_temp  = obj;

        g_sim_humidity += (int)(esp_random() % 3) - 1;
        g_sim_humidity  = g_sim_humidity < 45 ? 45 : (g_sim_humidity > 80 ? 80 : g_sim_humidity);
        g_sim_spo2     += (int)(esp_random() % 3) - 1;
        g_sim_spo2      = g_sim_spo2 < 95 ? 95 : (g_sim_spo2 > 100 ? 100 : g_sim_spo2);

        /* Log vitals + sleep analysis to serial monitor */
        ESP_LOGI(TAG, "=== VITALS === Temp:%.1fC (Amb:%.1fC) | Stable HR:%.1fbpm | Resp:%.1f/min | Dist:%.1fcm | Status:%s | SleepCount:%d",
                 g_object_temp, g_ambient_temp,
                 g_current_heart_rate, g_current_breath_rate,
                 g_current_distance, g_sleep_state_str, g_sleep_count);

        /* Publish via MQTT when connected */
        if (!mqtt_connected || !mqtt_client) continue;

        char msg[384];
        snprintf(msg, sizeof(msg),
            "{\"deviceId\":\"" DEVICE_ID "\","
            "\"bodyTemperature\":%.1f,\"heartRate\":%.1f,"
            "\"humidity\":%d,\"respiratoryRate\":%.1f,"
            "\"spo2\":%d,\"ambientTemperature\":%.1f,"
            "\"skinTemperature\":%.1f,\"movement\":%.1f,"
            "\"sleepState\":\"%s\",\"sleepCount\":%d,\"isSleeping\":%s}",
            g_object_temp, g_current_heart_rate, g_sim_humidity,
            g_current_breath_rate, g_sim_spo2,
            g_ambient_temp, g_object_temp, g_current_distance,
            g_sleep_state_str, g_sleep_count, g_is_sleeping ? "true" : "false");
            
        mqtt_publish_qos(MQTT_VITALS_TOPIC, msg, 0);
    }
}

static void audio_play_task(void *pv)
{
    if (!g_play_dev) { vTaskDelete(NULL); return; }
    
    #define CHUNK_SAMPLES 512
    int32_t *out_buf = (int32_t *)calloc(1, CHUNK_SAMPLES * 2 * sizeof(int32_t));
    TickType_t last_audio_tick = 0;
    
    while (1) {
        size_t size = 0;
        int16_t *data = (int16_t *)xRingbufferReceive(audio_out_ringbuf, &size, pdMS_TO_TICKS(10));

        if (data && size > 0) {
            g_audio_playing = true;
            last_audio_tick = xTaskGetTickCount();
            size_t ns_total = size / 2;
            size_t ns_processed = 0;

            while (ns_processed < ns_total) {
                size_t ns = ns_total - ns_processed;
                if (ns > CHUNK_SAMPLES) ns = CHUNK_SAMPLES;
                
                for (size_t i = 0; i < ns; i++) {
                    int32_t val = (int32_t)data[ns_processed + i];
                    // 3.0x digital software gain boost with int16 clamping for loud, clear speech
                    val = val * 3;
                    if (val > 32767) val = 32767;
                    if (val < -32768) val = -32768;
                    int32_t s = val << 16;
                    out_buf[2 * i] = s; out_buf[2 * i + 1] = s;
                }
                esp_codec_dev_write(g_play_dev, out_buf, ns * 2 * sizeof(int32_t));
                ns_processed += ns;
            }
            vRingbufferReturnItem(audio_out_ringbuf, data);
        } else {
            if (g_audio_playing && (xTaskGetTickCount() - last_audio_tick > pdMS_TO_TICKS(250))) {
                g_audio_playing = false; // Idle for > 250ms after speech ends
            }

            if (g_audio_playing) {
                /* Feed silence to keep I2S clock and DMA alive, preventing underflow pops during active streams */
                memset(out_buf, 0, CHUNK_SAMPLES * 2 * sizeof(int32_t));
                esp_codec_dev_write(g_play_dev, out_buf, CHUNK_SAMPLES * 2 * sizeof(int32_t));
                vTaskDelay(pdMS_TO_TICKS(5)); // Yield CPU to other Core 1 tasks
            } else {
                vTaskDelay(pdMS_TO_TICKS(10));
            }
        }
    }
    
    free(out_buf);
    vTaskDelete(NULL);
}

static struct sockaddr_storage g_udp_client_addr;
static socklen_t g_udp_client_addr_len = 0;
static bool g_udp_client_connected = false;
static int g_udp_sock = -1;

static void audio_recording_task(void *pv)
{
    // Recording & mic distribution is unified in cloud_mic_stream_task to eliminate I2S DMA contention
    vTaskDelete(NULL);
}

void speak_enqueue_raw(const uint8_t *pcm, size_t len)
{
    if (audio_out_ringbuf && pcm && len > 0) {
        xRingbufferSend(audio_out_ringbuf, pcm, len, pdMS_TO_TICKS(50));
    }
}

static void cloud_mic_stream_task(void *pv) {
    #define CLOUD_MIC_SAMPLES     1024
    #define CLOUD_MIC_READ_BYTES  (CLOUD_MIC_SAMPLES * 4 * sizeof(int16_t)) // 8192 bytes (4-ch raw)
    #define CLOUD_MIC_CHUNK_BYTES (CLOUD_MIC_SAMPLES * sizeof(int16_t))     // 2048 bytes (mono PCM)

    uint8_t *rb = heap_caps_malloc(CLOUD_MIC_READ_BYTES, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
    int16_t *mb = heap_caps_malloc(CLOUD_MIC_CHUNK_BYTES, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
    if (!rb) rb = malloc(CLOUD_MIC_READ_BYTES);
    if (!mb) mb = malloc(CLOUD_MIC_CHUNK_BYTES);
    if (!rb || !mb) {
        if (rb) free(rb);
        if (mb) free(mb);
        ESP_LOGE(TAG, "OOM allocating cloud mic buffers");
        vTaskDelete(NULL);
        return;
    }

    ESP_LOGI(TAG, "Unified mic stream task started (1024 samples/chunk, 64ms, 16kHz raw clear speech)");

    static uint32_t s_udp_packets_sent = 0;

    while (1) {
        bool ws_active = camera_stream_is_ws_connected();
        bool udp_active = (g_udp_client_connected && g_udp_sock >= 0);

        if (!ws_active && !udp_active) {
            vTaskDelay(pdMS_TO_TICKS(50));
            continue;
        }
        if (!g_record_dev) {
            vTaskDelay(pdMS_TO_TICKS(100));
            continue;
        }

        if (esp_codec_dev_read(g_record_dev, rb, CLOUD_MIC_READ_BYTES) == ESP_CODEC_DEV_OK) {
            int16_t *rp = (int16_t *)rb;
            // Channel 1 is physical microphone - full duplex continuous streaming without any attenuation
            for (int i = 0; i < CLOUD_MIC_SAMPLES; i++) {
                mb[i] = rp[4 * i + 1];
            }
            if (ws_active) {
                camera_stream_send_audio((const uint8_t *)mb, CLOUD_MIC_CHUNK_BYTES);
            }
            if (udp_active) {
                int sent = sendto(g_udp_sock, mb, CLOUD_MIC_CHUNK_BYTES, 0, (struct sockaddr *)&g_udp_client_addr, g_udp_client_addr_len);
                if (sent > 0) {
                    s_udp_packets_sent++;
                    if (s_udp_packets_sent % 100 == 0) {
                        ESP_LOGI(TAG, "Sent %u local UDP mic chunks to phone", (unsigned)s_udp_packets_sent);
                    }
                } else {
                    ESP_LOGW(TAG, "Local UDP sendto failed (err=%d)", errno);
                }
            }
        } else {
            vTaskDelay(pdMS_TO_TICKS(10));
        }
    }
    free(rb); free(mb);
    vTaskDelete(NULL);
}

static void audio_udp_server_task(void *pv) {
    int sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
    if (sock < 0) {
        ESP_LOGE(TAG, "Unable to create socket");
        vTaskDelete(NULL);
        return;
    }

    struct sockaddr_in server_addr;
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(8282);
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);

    if (bind(sock, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        ESP_LOGE(TAG, "Socket bind failed");
        close(sock);
        vTaskDelete(NULL);
        return;
    }

    g_udp_sock = sock;
    ESP_LOGI(TAG, "UDP Audio Server listening on port 8282");
    uint8_t *rx_buf = malloc(4096);
    static uint32_t s_udp_rx_count = 0;

    while (1) {
        struct sockaddr_storage source_addr;
        socklen_t socklen = sizeof(source_addr);
        int len = recvfrom(sock, rx_buf, 4096, 0, (struct sockaddr *)&source_addr, &socklen);
        if (len > 0) {
            if (len < 64 && rx_buf[0] == '{') {
                rx_buf[len] = '\0';
                if (strstr((char *)rx_buf, "\"cmd\":\"start_recording\"")) {
                    g_udp_client_addr = source_addr;
                    g_udp_client_addr_len = socklen;
                    g_udp_client_connected = true;
                    recording_active = true;
                    ESP_LOGI(TAG, "Local LAN UDP 2-Way Call Started!");
                } else if (strstr((char *)rx_buf, "\"cmd\":\"stop_recording\"")) {
                    recording_active = false;
                    g_udp_client_connected = false;
                    ESP_LOGI(TAG, "Local LAN UDP 2-Way Call Stopped!");
                }
            } else {
                g_udp_client_addr = source_addr;
                g_udp_client_addr_len = socklen;
                g_udp_client_connected = true;
                
                s_udp_rx_count++;
                if (s_udp_rx_count % 30 == 0) {
                    ESP_LOGI(TAG, "Voice -> Speaker: received %d bytes (pkt=%u)", len, (unsigned)s_udp_rx_count);
                }
                
                if (g_play_dev && audio_out_ringbuf) {
                    if (xRingbufferSend(audio_out_ringbuf, rx_buf, len, pdMS_TO_TICKS(100)) != pdTRUE) {
                        ESP_LOGW(TAG, "Audio ringbuffer full, dropping UDP chunk!");
                    }
                }
            }
        }
    }
}


/* --- Motor Control (74HC595 Shift Register) --- */
#define MOTOR_DATA_PIN  GPIO_NUM_7
#define MOTOR_LATCH_PIN GPIO_NUM_6
#define MOTOR_CLOCK_PIN GPIO_NUM_5

static uint8_t shiftRegisterState = 0x00;
static const uint8_t stepSequence[8] = {0x01, 0x03, 0x02, 0x06, 0x04, 0x0C, 0x08, 0x09};
static int motor_pan_index = 0;
static int motor_tilt_index = 0;

static void shiftOut(gpio_num_t dataPin, gpio_num_t clockPin, uint8_t val) {
    for (int i = 0; i < 8; i++)  {
        gpio_set_level(dataPin, !!(val & (1 << (7 - i))));
        gpio_set_level(clockPin, 1);
        esp_rom_delay_us(2);
        gpio_set_level(clockPin, 0);
        esp_rom_delay_us(2);
    }
}

static void updateShiftRegister(void) {
    gpio_set_level(MOTOR_LATCH_PIN, 0);
    shiftOut(MOTOR_DATA_PIN, MOTOR_CLOCK_PIN, shiftRegisterState);
    gpio_set_level(MOTOR_LATCH_PIN, 1);
}

static void motor_init(void) {
    gpio_reset_pin(MOTOR_DATA_PIN);
    gpio_reset_pin(MOTOR_LATCH_PIN);
    gpio_reset_pin(MOTOR_CLOCK_PIN);
    gpio_set_direction(MOTOR_DATA_PIN, GPIO_MODE_OUTPUT);
    gpio_set_direction(MOTOR_LATCH_PIN, GPIO_MODE_OUTPUT);
    gpio_set_direction(MOTOR_CLOCK_PIN, GPIO_MODE_OUTPUT);
    shiftRegisterState = 0x00;
    updateShiftRegister();
}

static void motor_pan(int dir) {
    ESP_LOGI(TAG, "Panning camera %s", dir > 0 ? "right" : "left");
    for (int i = 0; i < 64; i++) { // Step 64 times (~5.6 degrees per click)
        motor_pan_index = (motor_pan_index + dir + 8) % 8;
        shiftRegisterState &= 0xF0; // Clear lower 4 bits (Motor 1 = Pan)
        shiftRegisterState |= (stepSequence[motor_pan_index] & 0x0F);
        updateShiftRegister();
        esp_rom_delay_us(5000); // 5ms per step (slower)
        if (i % 10 == 0) vTaskDelay(1); // Yield every 50ms to feed watchdog
    }
    // Turn off motor coils to prevent overheating
    shiftRegisterState &= 0xF0;
    updateShiftRegister();
}

static void motor_tilt(int dir) {
    ESP_LOGI(TAG, "Tilting camera %s", dir > 0 ? "up" : "down");
    for (int i = 0; i < 64; i++) { // Step 64 times (~5.6 degrees per click)
        motor_tilt_index = (motor_tilt_index + dir + 8) % 8;
        shiftRegisterState &= 0x0F; // Clear upper 4 bits (Motor 2 = Tilt)
        shiftRegisterState |= ((stepSequence[motor_tilt_index] << 4) & 0xF0);
        updateShiftRegister();
        esp_rom_delay_us(5000); // 5ms per step (slower)
        if (i % 10 == 0) vTaskDelay(1); // Yield every 50ms to feed watchdog
    }
    // Turn off motor coils
    shiftRegisterState &= 0x0F;
    updateShiftRegister();
}

static void handle_command(const char *data, int data_len)
{
    char buf[256]; int cl=data_len<(int)(sizeof(buf)-1)?data_len:(int)(sizeof(buf)-1);
    memcpy(buf,data,cl); buf[cl]='\0';
    if(strstr(buf,"\"ping\"")){mqtt_publish(MQTT_RESPONSE_TOPIC,"{\"cmd\":\"ping\",\"status\":\"pong\",\"device\":\"" DEVICE_NAME "\",\"deviceId\":\"" DEVICE_ID "\"}");}
    else if(strstr(buf,"\"start_recording\"")){
        if(recording_active){mqtt_publish(MQTT_RESPONSE_TOPIC,"{\"cmd\":\"start_recording\",\"status\":\"busy\"}");return;}
        if(xSemaphoreTake(recording_mutex,0)==pdTRUE){recording_active=true;xTaskCreatePinnedToCore(audio_recording_task,"audio_rec",4096,NULL,10,NULL,1);}
    } else if(strstr(buf,"\"stop_recording\"")){recording_active=false;mqtt_publish(MQTT_RESPONSE_TOPIC,"{\"cmd\":\"stop_recording\",\"status\":\"stopped\"}");}
    else if (strstr(buf, "\"start_cry_monitor\"")) {
        if (cry_gate_start_monitor()) {
            mqtt_publish(MQTT_RESPONSE_TOPIC, "{\"cmd\":\"start_cry_monitor\",\"status\":\"started\"}");
        } else {
            mqtt_publish(MQTT_RESPONSE_TOPIC, "{\"cmd\":\"start_cry_monitor\",\"status\":\"busy\"}");
        }
    } else if (strstr(buf, "\"stop_cry_monitor\"")) {
        cry_gate_stop_monitor();
        mqtt_publish(MQTT_RESPONSE_TOPIC, "{\"cmd\":\"stop_cry_monitor\",\"status\":\"stopped\"}");
    }
    else if(strstr(buf,"\"play_audio\"")){
        float freq=440.0f; const char *tk=strstr(buf,"\"track\":\"");
        if(tk){tk+=9;
            if(strncmp(tk,"white_noise",11)==0)freq=0.0f;
            else if(strncmp(tk,"lullaby_1",9)==0)freq=261.63f;
            else if(strncmp(tk,"lullaby_2",9)==0)freq=293.66f;
            else if(strncmp(tk,"heartbeat",9)==0)freq=80.0f;
            else if(strncmp(tk,"ocean_waves",11)==0)freq=110.0f;
            else if(strncmp(tk,"shushing",8)==0)freq=600.0f;
        }
        g_audio_playing=false;vTaskDelay(pdMS_TO_TICKS(60));
        g_play_freq=freq;g_audio_playing=true;
        xTaskCreatePinnedToCore(audio_play_task,"audio_play",4096,NULL,10,NULL,1);
        mqtt_publish(MQTT_RESPONSE_TOPIC,"{\"cmd\":\"play_audio\",\"status\":\"playing\"}");
    } else if(strstr(buf,"\"stop_audio\"")){g_audio_playing=false;mqtt_publish(MQTT_RESPONSE_TOPIC,"{\"cmd\":\"stop_audio\",\"status\":\"stopped\"}");}
    else if(strstr(buf,"\"reboot\"")){mqtt_publish(MQTT_RESPONSE_TOPIC,"{\"cmd\":\"reboot\",\"status\":\"rebooting\"}");vTaskDelay(pdMS_TO_TICKS(500));esp_restart();}
    else if(strstr(buf,"\"cmd\":\"motor\"")){
        if(strstr(buf,"\"direction\":\"up\"")) motor_tilt(-1);
        else if(strstr(buf,"\"direction\":\"down\"")) motor_tilt(1);
        else if(strstr(buf,"\"direction\":\"left\"")) motor_pan(1);
        else if(strstr(buf,"\"direction\":\"right\"")) motor_pan(-1);
        mqtt_publish(MQTT_RESPONSE_TOPIC,"{\"cmd\":\"motor\",\"status\":\"ok\"}");
    }
    else if(strstr(buf,"\"disconnect\"")){
        mqtt_publish(MQTT_RESPONSE_TOPIC,"{\"cmd\":\"disconnect\",\"status\":\"clearing_credentials\"}");
        vTaskDelay(pdMS_TO_TICKS(500));
        nvs_handle_t dh; if(nvs_open(NVS_NS,NVS_READWRITE,&dh)==ESP_OK){nvs_erase_key(dh,NVS_KEY_SSID);nvs_erase_key(dh,NVS_KEY_PASS);nvs_commit(dh);nvs_close(dh);}
        vTaskDelay(pdMS_TO_TICKS(200));esp_restart();
    }
}

void mqtt_event_handler(void *handler_args, esp_event_base_t base,
                        int32_t event_id, void *event_data)
{
    esp_mqtt_event_handle_t ev = (esp_mqtt_event_handle_t)event_data;
    switch ((esp_mqtt_event_id_t)event_id) {
        case MQTT_EVENT_CONNECTED:
            mqtt_connected = true;
            s_consecutive_mqtt_errors = 0;
            ESP_LOGI(TAG, "MQTT connected to broker: %s!", s_mqtt_brokers[s_broker_idx]);
            esp_mqtt_client_subscribe(mqtt_client, MQTT_CMD_TOPIC, 1);
            char sm[256];
            snprintf(sm, sizeof(sm),
                     "{\"device\":\"" DEVICE_NAME "\",\"deviceId\":\"" DEVICE_ID "\",\"status\":\"online\",\"ip\":\"%s\"}",
                     g_device_ip);
            esp_mqtt_client_publish(mqtt_client, MQTT_STATUS_TOPIC, sm, 0, 0, 1);
            break;
        case MQTT_EVENT_DISCONNECTED:
            mqtt_connected = false;
            ESP_LOGW(TAG, "MQTT disconnected from broker");
            break;
        case MQTT_EVENT_SUBSCRIBED:
            ESP_LOGI(TAG, "MQTT subscribed to command topic: %s (msg_id=%d)", MQTT_CMD_TOPIC, ev->msg_id);
            break;
        case MQTT_EVENT_ERROR:
            s_consecutive_mqtt_errors++;
            ESP_LOGW(TAG, "MQTT event error: type=%d (fail_count=%d)",
                     ev->error_handle ? ev->error_handle->error_type : -1, s_consecutive_mqtt_errors);
            if (ev->error_handle && ev->error_handle->error_type == MQTT_ERROR_TYPE_TCP_TRANSPORT) {
                ESP_LOGW(TAG, "MQTT transport sock_errno=%d", ev->error_handle->esp_transport_sock_errno);
            }
            if (s_consecutive_mqtt_errors >= 3 && mqtt_client != NULL) {
                s_consecutive_mqtt_errors = 0;
                s_broker_idx = (s_broker_idx + 1) % NUM_MQTT_BROKERS;
                ESP_LOGW(TAG, "Failing over to alternative broker [%d/%d]: %s",
                         s_broker_idx + 1, (int)NUM_MQTT_BROKERS, s_mqtt_brokers[s_broker_idx]);
                esp_mqtt_client_set_uri(mqtt_client, s_mqtt_brokers[s_broker_idx]);
                esp_mqtt_client_reconnect(mqtt_client);
            }
            break;
        case MQTT_EVENT_DATA:
            if (ev->topic && strncmp(ev->topic, MQTT_CMD_TOPIC, ev->topic_len) == 0) {
                handle_command(ev->data, ev->data_len);
            }
            break;
        default:
            break;
    }
}

static void heartbeat_task(void *pv)
{
    int disconnected_seconds = 0;
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(10000));
        if (!mqtt_connected) {
            disconnected_seconds += 10;
            // Active watchdog: if disconnected for >=30s while WiFi is up, force a reconnect
            if (disconnected_seconds >= 30 && mqtt_client != NULL) {
                ESP_LOGI(TAG, "MQTT disconnected for %ds, requesting clean reconnect...", disconnected_seconds);
                esp_mqtt_client_reconnect(mqtt_client);
                disconnected_seconds = 0;
            }
            continue;
        }
        disconnected_seconds = 0;
        char hb[256];
        snprintf(hb, sizeof(hb),
                 "{\"device\":\"" DEVICE_NAME "\",\"deviceId\":\"" DEVICE_ID "\",\"status\":\"online\",\"ip\":\"%s\"}",
                 g_device_ip);
        mqtt_publish_qos(MQTT_STATUS_TOPIC, hb, 0);
        ESP_LOGI(TAG, "Heap check: DRAM free=%u (largest=%u), PSRAM free=%u",
                 (unsigned)heap_caps_get_free_size(MALLOC_CAP_INTERNAL),
                 (unsigned)heap_caps_get_largest_free_block(MALLOC_CAP_INTERNAL | MALLOC_CAP_DMA),
                 (unsigned)heap_caps_get_free_size(MALLOC_CAP_SPIRAM));
    }
}

static esp_err_t camera_init(void)
{
    camera_config_t cfg={
        .pin_pwdn=CAM_PWDN,.pin_reset=CAM_RESET,.pin_xclk=CAM_XCLK,
        .pin_sccb_sda=CAM_SIOD,.pin_sccb_scl=CAM_SIOC,
        .pin_d7=CAM_D7,.pin_d6=CAM_D6,.pin_d5=CAM_D5,.pin_d4=CAM_D4,
        .pin_d3=CAM_D3,.pin_d2=CAM_D2,.pin_d1=CAM_D1,.pin_d0=CAM_D0,
        .pin_vsync=CAM_VSYNC,.pin_href=CAM_HREF,.pin_pclk=CAM_PCLK,
        .xclk_freq_hz=10000000,.ledc_timer=LEDC_TIMER_0,.ledc_channel=LEDC_CHANNEL_0,
        .pixel_format=PIXFORMAT_JPEG,.frame_size=FRAMESIZE_SVGA,
        .jpeg_quality=20,.fb_count=3,.grab_mode=CAMERA_GRAB_WHEN_EMPTY,.fb_location=CAMERA_FB_IN_PSRAM,
    };
    esp_err_t err=esp_camera_init(&cfg);
    if(err!=ESP_OK){ESP_LOGE(TAG,"Camera init failed");return err;}
    sensor_t *s=esp_camera_sensor_get();
    if(s){s->set_vflip(s,0);s->set_brightness(s,1);s->set_contrast(s,1);}
    ESP_LOGI(TAG,"Camera ready");
    return ESP_OK;
}

#define STREAM_BOUNDARY "\r\n--frame\r\n"

static esp_err_t stream_handler(httpd_req_t *req)
{
    g_video_stream_active = true;
    ESP_LOGI(TAG, "Local MJPEG Video stream connected");
    httpd_resp_set_type(req, "multipart/x-mixed-replace;boundary=frame");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
    httpd_resp_set_hdr(req, "Cache-Control", "no-cache, no-store, must-revalidate");
    httpd_resp_set_hdr(req, "Pragma", "no-cache");

    char part_buf[128];
    esp_err_t r = ESP_OK;
    int null_count = 0;

    while (true) {
        camera_fb_t *fb = esp_camera_fb_get(); 
        if (!fb) {
            null_count++;
            if (null_count > 40) { // Over 2 seconds of consecutive NULL frames
                ESP_LOGW(TAG, "Camera fb_get timeout, ending stream");
                r = ESP_FAIL;
                break;
            }
            vTaskDelay(pdMS_TO_TICKS(50));
            continue;
        }
        null_count = 0;

        int hlen = snprintf(part_buf, sizeof(part_buf),
            STREAM_BOUNDARY "Content-Type: image/jpeg\r\nContent-Length: %zu\r\n\r\n", fb->len);

        r = httpd_resp_send_chunk(req, part_buf, hlen);
        if (r == ESP_OK) {
            r = httpd_resp_send_chunk(req, (const char *)fb->buf, fb->len);
        }
        esp_camera_fb_return(fb);

        if (r != ESP_OK) {
            ESP_LOGI(TAG, "Local client disconnected from stream");
            break;
        }

        vTaskDelay(pdMS_TO_TICKS(40)); // ~20-25 fps optimal rate
    }

    g_video_stream_active = false;
    return r;
}

static void start_camera_server(void)
{
    // --- Server 1: Camera Stream (Port 81) ---
    httpd_config_t cfg_cam = HTTPD_DEFAULT_CONFIG();
    cfg_cam.server_port = CAM_STREAM_PORT; 
    cfg_cam.ctrl_port = CAM_STREAM_PORT + 1000;
    cfg_cam.stack_size = 8192; 
    cfg_cam.max_uri_handlers = 4;
    cfg_cam.lru_purge_enable = true; // Auto close stale dead sockets!
    cfg_cam.send_wait_timeout = 3;   // 3 seconds send timeout
    cfg_cam.recv_wait_timeout = 3;
    httpd_handle_t srv_cam = NULL;
    if (httpd_start(&srv_cam, &cfg_cam) != ESP_OK) {
        ESP_LOGE(TAG, "Camera server start failed");
        return;
    }
    httpd_uri_t su = {.uri = "/stream", .method = HTTP_GET, .handler = stream_handler};
    httpd_register_uri_handler(srv_cam, &su);
    
    ESP_LOGI(TAG, "Camera: http://%s:%d/stream", g_device_ip, CAM_STREAM_PORT);
}

void app_main(void)
{
    esp_err_t ret=nvs_flash_init();
    if(ret==ESP_ERR_NVS_NO_FREE_PAGES||ret==ESP_ERR_NVS_NEW_VERSION_FOUND){
        ESP_ERROR_CHECK(nvs_flash_erase()); ESP_ERROR_CHECK(nvs_flash_init());
    }

    /* Step 1: Board + codec init */
    ESP_LOGI(TAG,"Initializing board...");
    ESP_ERROR_CHECK(esp_board_init(SAMPLE_RATE,1,16));
    
    // Initialize the TCA9555 IO Expander and power ON the audio amplifier
    tca9555_driver_init();
    Set_EXIO(IO_EXPANDER_PIN_NUM_8, 1);     // Power up the audio amplifier
    Set_EXIO(IO_EXPANDER_PIN_NUM_6, 1);     // Use Tx/Rx for Camera
    Set_EXIO(IO_EXPANDER_PIN_NUM_5, 0);     // Enable Camera
    
    g_play_dev   = esp_ret_play_dev();
    g_record_dev = esp_ret_record_dev();
    if(g_play_dev)   esp_codec_dev_set_out_vol(g_play_dev, 85.0);
    if(g_record_dev) esp_codec_dev_set_in_channel_gain(g_record_dev, ESP_CODEC_DEV_MAKE_CHANNEL_MASK(1), 24.0);

    ESP_LOGI(TAG,"Board ready. Play dev=%p, Record dev=%p", g_play_dev, g_record_dev);

    /* Initialize camera hardware early while internal DMA RAM is unfragmented */
    static bool s_camera_ready = false;
    s_camera_ready = (camera_init() == ESP_OK);
    
    /* Create RingBuffer for speaker output (8192 bytes = ~256ms low-latency jitter buffer) */
    audio_out_ringbuf = xRingbufferCreateWithCaps(8192, RINGBUF_TYPE_BYTEBUF, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
    if (!audio_out_ringbuf) {
        audio_out_ringbuf = xRingbufferCreate(8192, RINGBUF_TYPE_BYTEBUF);
    }
    if (!audio_out_ringbuf) { ESP_LOGE(TAG, "Failed to create audio ringbuffer"); return; }
    
    if (g_play_dev && audio_out_ringbuf) {
        g_audio_playing = false;
#if CONFIG_SPIRAM_ALLOW_STACK_EXTERNAL_MEMORY
        if (xTaskCreatePinnedToCoreWithCaps(audio_play_task, "audio_play", 8192, NULL, 6, NULL, 1, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT) != pdPASS)
#endif
        {
            xTaskCreatePinnedToCore(audio_play_task, "audio_play", 4096, NULL, 6, NULL, 1);
        }
    }

    /* Step 2: WiFi + events */
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    wifi_event_group   = xEventGroupCreate();
    g_prov_event_group = xEventGroupCreate();
    recording_mutex    = xSemaphoreCreateBinary();
    xSemaphoreGive(recording_mutex);
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT,ESP_EVENT_ANY_ID,wifi_event_handler,NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT,IP_EVENT_STA_GOT_IP,wifi_event_handler,NULL));
    esp_netif_create_default_wifi_sta();
    wifi_init_config_t wc=WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&wc));
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));

    char sv[64]={0}, sp[128]={0};
    strlcpy(sv, "BMTECHNO", sizeof(sv));
    strlcpy(sp, "22102001", sizeof(sp));
    nv_save_wifi(sv, sp);
    ESP_LOGI(TAG, "Connecting to WiFi: '%s'", sv);
    wifi_config_t wfg={0};
    strlcpy((char*)wfg.sta.ssid, sv, sizeof(wfg.sta.ssid));
    strlcpy((char*)wfg.sta.password, sp, sizeof(wfg.sta.password));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wfg));
    ESP_ERROR_CHECK(esp_wifi_start());

    EventBits_t bits;
    for(;;){
        bits=xEventGroupWaitBits(wifi_event_group,WIFI_CONNECTED_BIT|WIFI_FAIL_BIT,pdFALSE,pdFALSE,portMAX_DELAY);
        if(bits&WIFI_CONNECTED_BIT) break;
        xEventGroupClearBits(wifi_event_group,WIFI_FAIL_BIT);
        if(!g_prov_mode){s_wifi_retry=0;vTaskDelay(pdMS_TO_TICKS(5000));esp_wifi_connect();}
    }

    /* Step 3: Camera */
    if(s_camera_ready) {
        start_camera_server();
        camera_stream_start();
#if CONFIG_SPIRAM_ALLOW_STACK_EXTERNAL_MEMORY
        if (xTaskCreatePinnedToCoreWithCaps(cloud_mic_stream_task, "cloud_mic", 8192, NULL, 6, NULL, 1,
                                            MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT) != pdPASS)
#endif
        {
            xTaskCreatePinnedToCore(cloud_mic_stream_task, "cloud_mic", 4096, NULL, 6, NULL, 1);
        }
    } else {
        ESP_LOGW(TAG,"Camera unavailable");
    }

    /* Step 4: Sensors + Tasks + Motors */
    motor_init();
    sw_i2c_init();   /* MLX90614 soft bit-bang I2C on GPIO 8/9 */
    xTaskCreate(ld6002_rx_task,      "ld6002_rx",  4096,NULL,5,NULL);
    xTaskCreate(sensor_publish_task, "sensor_pub", 4096,NULL,4,NULL);
    xTaskCreate(heartbeat_task,      "heartbeat",  4096,NULL,3,NULL);
#if CONFIG_SPIRAM_ALLOW_STACK_EXTERNAL_MEMORY
    if (xTaskCreatePinnedToCoreWithCaps(audio_udp_server_task, "audio_udp", 8192, NULL, 6, NULL, 1, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT) != pdPASS)
#endif
    {
        xTaskCreatePinnedToCore(audio_udp_server_task, "audio_udp", 4096, NULL, 6, NULL, 1);
    }

    /* Step 5: Auto-start continuous Infant Cry Detection ML Pipeline */
    ESP_LOGI(TAG, "Auto-starting Infant Cry Detection Monitor...");
    cry_gate_start_monitor();

    ESP_LOGI(TAG,"BabyCare ready. DeviceId=" DEVICE_ID " IP=%s",g_device_ip);
    while(1) vTaskDelay(pdMS_TO_TICKS(1000));
}
