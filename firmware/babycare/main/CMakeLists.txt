idf_component_register(
    SRCS "app_main.c"
         "camera_stream.c"
         "hardeware_driver/bsp_board.c"
         "tca9555_driver/tca9555_driver.c"
         "audio_manager.cpp"
         "network_manager.cpp"
         "ws_client.cpp"
         "ws_server.cpp"
         "cry_gate_feature.c"
         "trigger.c"
         "edge_model.c"
         "cry_candidate.c"
         "audio_capture_cry.c"
         "mel_spectrogram.c"
         "cry_gate_inference.cc"
         "sd_upload.c"
         "data/cry_gate_model_data.cc"
    PRIV_REQUIRES
        esp_wifi
        nvs_flash
        bt
        mqtt
        esp_driver_i2s
        esp_driver_i2c
        esp_driver_uart
        esp_driver_gpio
        esp_driver_ledc
        mbedtls
        esp_http_server
        espressif__esp32-camera
        fatfs
        sdmmc
        lwip
        esp_ringbuf
        esp-tflite-micro
        esp-dsp
        mdns
        esp_http_client
        esp_websocket_client
    INCLUDE_DIRS "."
                 "hardeware_driver"
                 "tca9555_driver"
                 "data"
)

target_compile_options(${COMPONENT_LIB} PRIVATE "-Wno-error")
