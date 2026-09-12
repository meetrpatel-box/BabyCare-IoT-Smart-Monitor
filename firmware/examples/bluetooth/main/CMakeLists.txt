set(srcs 
    "main.c"
    "gatt_svr.c"
    "tmp117.c"
)

idf_component_register(
    SRCS
        ${srcs}
    INCLUDE_DIRS
        "."
    REQUIRES
        driver
        bt
        nvs_flash
)