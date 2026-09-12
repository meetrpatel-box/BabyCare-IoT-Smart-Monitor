#include "network_manager.h"
#include <string.h>
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "esp_mac.h"
#include "mdns.h"

static const char *TAG = "network_manager";

#define WIFI_SSID "BMTECHNO"
#define WIFI_PASS "22102001"

static EventGroupHandle_t s_wifi_event_group;
static const int WIFI_CONNECTED_BIT = BIT0;

static char my_ip[16] = {0};

static void event_handler(void* arg, esp_event_base_t event_base,
                                int32_t event_id, void* event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        ESP_LOGI(TAG, "Disconnected. Retrying in 2 seconds...");
        vTaskDelay(pdMS_TO_TICKS(2000));
        esp_wifi_connect();
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        snprintf(my_ip, sizeof(my_ip), IPSTR, IP2STR(&event->ip_info.ip));
        ESP_LOGI(TAG, "Got IP: %s", my_ip);
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    }
}

static void mdns_init_service(void)
{
    ESP_ERROR_CHECK(mdns_init());
    
    uint8_t mac[6];
    esp_read_mac(mac, ESP_MAC_WIFI_STA);
    char hostname[32];
    snprintf(hostname, sizeof(hostname), "intercom-%02x%02x%02x", mac[3], mac[4], mac[5]);
    
    mdns_hostname_set(hostname);
    mdns_instance_name_set("ESP32 Intercom");

    mdns_service_add("ESP32-Intercom", "_intercom", "_tcp", 80, NULL, 0);
    ESP_LOGI(TAG, "mDNS service started: %s.local", hostname);
}

void network_manager_init(void)
{
    s_wifi_event_group = xEventGroupCreate();

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    esp_event_handler_instance_t instance_any_id;
    esp_event_handler_instance_t instance_got_ip;
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT,
                                                        ESP_EVENT_ANY_ID,
                                                        &event_handler,
                                                        NULL,
                                                        &instance_any_id));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT,
                                                        IP_EVENT_STA_GOT_IP,
                                                        &event_handler,
                                                        NULL,
                                                        &instance_got_ip));

    wifi_config_t wifi_config = {};
    strcpy((char*)wifi_config.sta.ssid, WIFI_SSID);
    strcpy((char*)wifi_config.sta.password, WIFI_PASS);
    wifi_config.sta.threshold.authmode = WIFI_AUTH_WPA2_PSK;

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA) );
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config) );
    ESP_ERROR_CHECK(esp_wifi_start() );

    ESP_LOGI(TAG, "wifi_init_sta finished.");
    
    // Wait for connection
    xEventGroupWaitBits(s_wifi_event_group, WIFI_CONNECTED_BIT, pdFALSE, pdFALSE, portMAX_DELAY);
    
    mdns_init_service();
}

bool network_manager_is_connected(void)
{
    EventBits_t bits = xEventGroupGetBits(s_wifi_event_group);
    return (bits & WIFI_CONNECTED_BIT) != 0;
}

bool network_manager_get_peer_ip(char *peer_ip_out, size_t max_len)
{
    mdns_result_t * results = NULL;
    esp_err_t err = mdns_query_ptr("_intercom", "_tcp", 3000, 20, &results);
    
    if (err) {
        ESP_LOGE(TAG, "mDNS Query Failed: %s", esp_err_to_name(err));
        return false;
    }
    if (!results) {
        return false;
    }

    bool found = false;
    mdns_result_t * r = results;
    while (r) {
        if (r->addr) {
            mdns_ip_addr_t * a = r->addr;
            while (a) {
                if (a->addr.type == ESP_IPADDR_TYPE_V4) {
                    char found_ip[16];
                    snprintf(found_ip, sizeof(found_ip), IPSTR, IP2STR(&a->addr.u_addr.ip4));
                    
                    // Don't connect to ourselves
                    if (strcmp(found_ip, my_ip) != 0) {
                        strncpy(peer_ip_out, found_ip, max_len);
                        found = true;
                        break;
                    }
                }
                a = a->next;
            }
        }
        if (found) break;
        r = r->next;
    }
    
    mdns_query_results_free(results);
    return found;
}
