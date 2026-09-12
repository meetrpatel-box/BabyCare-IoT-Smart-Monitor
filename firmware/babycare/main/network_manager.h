#pragma once

#include <stdbool.h>
#include <stddef.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

// Initialize WiFi, connect to BMTECHNO, and start mDNS
void network_manager_init(void);

// Wait until WiFi is connected and we have an IP
bool network_manager_is_connected(void);

// Query mDNS for _intercom._tcp and return the IP address of the peer.
// Returns true if found and copies the IP string into peer_ip_out.
bool network_manager_get_peer_ip(char *peer_ip_out, size_t max_len);

#ifdef __cplusplus
}
#endif
