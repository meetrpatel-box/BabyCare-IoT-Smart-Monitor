#include "tmp117.h"
#include "driver/i2c.h"
#include "esp_log.h"


#define I2C_MASTER_NUM      I2C_NUM_0

#define I2C_SDA_GPIO        36
#define I2C_SCL_GPIO        37

#define I2C_FREQ_HZ         100000


#define TMP117_ADDR         0x48
#define TMP117_TEMP_REG     0x00


static const char *TAG = "TMP117";


void tmp117_init(void)
{

    i2c_config_t conf =
    {
        .mode = I2C_MODE_MASTER,

        .sda_io_num = I2C_SDA_GPIO,
        .scl_io_num = I2C_SCL_GPIO,

        .sda_pullup_en = GPIO_PULLUP_ENABLE,
        .scl_pullup_en = GPIO_PULLUP_ENABLE,

        .master.clk_speed = I2C_FREQ_HZ,
    };


    ESP_ERROR_CHECK(
        i2c_param_config(
            I2C_MASTER_NUM,
            &conf
        )
    );


    ESP_ERROR_CHECK(
        i2c_driver_install(
            I2C_MASTER_NUM,
            conf.mode,
            0,
            0,
            0
        )
    );


    ESP_LOGI(TAG,"TMP117 Initialized");


    // I2C SCANNER
    for(int addr = 1; addr < 127; addr++)
    {

        i2c_cmd_handle_t cmd = i2c_cmd_link_create();


        i2c_master_start(cmd);


        i2c_master_write_byte(
            cmd,
            (addr << 1) | I2C_MASTER_WRITE,
            true
        );


        i2c_master_stop(cmd);



        esp_err_t ret =
        i2c_master_cmd_begin(
            I2C_MASTER_NUM,
            cmd,
            pdMS_TO_TICKS(100)
        );


        i2c_cmd_link_delete(cmd);



        if(ret == ESP_OK)
        {
            ESP_LOGI(TAG,
            "FOUND I2C DEVICE AT ADDRESS: 0x%02X",
            addr);
        }

    }


}



float tmp117_read_temperature(void)
{

    uint8_t reg = TMP117_TEMP_REG;

    uint8_t data[2];


    esp_err_t err =
    i2c_master_write_read_device(
        I2C_MASTER_NUM,

        TMP117_ADDR,

        &reg,

        1,

        data,

        2,

        pdMS_TO_TICKS(100)
    );



    if(err != ESP_OK)
    {

        ESP_LOGE(TAG,
        "TMP117 Read Failed: %s",
        esp_err_to_name(err));


        return -999.0;

    }



    int16_t raw =
    (data[0] << 8) | data[1];



    float temperature =
    raw * 0.0078125;



    return temperature;

}