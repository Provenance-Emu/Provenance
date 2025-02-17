/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2024 - Joseph Mattiello
 *
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 */

#include <time.h>
#include <compat/strl.h>
#include <file/file_path.h>
#include <array/rbuf.h>
#include <string/stdstring.h>
#include <retro_miscellaneous.h>
#include <string.h>

#include <libretro.h>

#include "../../network/wifi_driver.h"
#include "../../retroarch.h"
#include "../../configuration.h"
#include "../../verbosity.h"

#if defined(OSX)
#import <CoreWLAN/CoreWLAN.h>
#elif defined(IOS)
#import <NetworkExtension/NetworkExtension.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#endif

typedef struct
{
   wifi_network_scan_t scan;
} apple_wifi_t;

#if defined(IOS)
@interface RARWiFiManager : NSObject
+ (instancetype)shared;
- (NSDictionary *)currentNetwork;
- (NSArray<NSDictionary *> *)availableNetworks;
@end

@implementation RARWiFiManager

+ (instancetype)shared {
    static RARWiFiManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[RARWiFiManager alloc] init];
        RARCH_LOG("[WiFi] RARWiFiManager singleton initialized\n");
    });
    return shared;
}

- (NSDictionary *)currentNetwork {
#if TARGET_OS_TV
    return nil;
#else
    RARCH_LOG("[WiFi] Querying current network info\n");
    NSArray *interfaces = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
    for (NSString *interface in interfaces) {
        RARCH_LOG("[WiFi] Checking interface: %s\n", [interface UTF8String]);
        NSDictionary *networkInfo = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)interface);
        if (networkInfo) {
            RARCH_LOG("[WiFi] Found active network on interface: %s\n", [interface UTF8String]);
            return networkInfo;
        }
    }
    RARCH_LOG("[WiFi] No active network found\n");
    return nil;
#endif
}

- (NSArray<NSDictionary *> *)availableNetworks {
    RARCH_LOG("[WiFi] Scanning for available networks (iOS limited)\n");
    // Note: iOS requires special entitlements to scan networks
    // This will only return the currently connected network
    NSDictionary *currentNetwork = [self currentNetwork];
    if (currentNetwork) {
        NSString *ssid = currentNetwork[@"SSID"];
        RARCH_LOG("[WiFi] Current network SSID: %s\n", [ssid UTF8String]);
    }
    return currentNetwork ? @[currentNetwork] : @[];
}

@end
#endif

static void *nmcli_init(void)
{
    RARCH_LOG("[WiFi] Initializing Apple WiFi driver\n");
    apple_wifi_t *wifi = (apple_wifi_t*)calloc(1, sizeof(apple_wifi_t));
    return wifi;
}

static void nmcli_free(void *data)
{
    RARCH_LOG("[WiFi] Freeing Apple WiFi driver\n");
    apple_wifi_t *wifi = (apple_wifi_t*)data;
    if (wifi)
    {
        if (wifi->scan.net_list)
            RBUF_FREE(wifi->scan.net_list);
        free(wifi);
    }
}

static bool nmcli_start(void *data)
{
    RARCH_LOG("[WiFi] Starting Apple WiFi driver\n");
    return true;
}

static void nmcli_stop(void *data)
{
    RARCH_LOG("[WiFi] Stopping Apple WiFi driver\n");
}

static bool nmcli_enable(void* data, bool enabled)
{
    RARCH_LOG("[WiFi] Enable request ignored (not supported on iOS): %d\n", enabled);
    return true; // iOS doesn't allow programmatic WiFi control
}

static bool nmcli_connection_info(void *data, wifi_network_info_t *netinfo)
{
    if (!netinfo)
        return false;

#if defined(IOS)
    RARCH_LOG("[WiFi] Querying connection info\n");
    NSDictionary *currentNetwork = [[RARWiFiManager shared] currentNetwork];
    if (currentNetwork) {
        NSString *ssid = currentNetwork[@"SSID"];
        if (ssid) {
            strlcpy(netinfo->ssid, [ssid UTF8String], sizeof(netinfo->ssid));
            netinfo->connected = true;
            RARCH_LOG("[WiFi] Connected to network: %s\n", netinfo->ssid);
            return true;
        }
    }
    RARCH_LOG("[WiFi] No active connection found\n");
#endif

    return false;
}

static void nmcli_scan(void *data)
{
    RARCH_LOG("[WiFi] Starting network scan\n");
    apple_wifi_t *wifi = (apple_wifi_t*)data;
    wifi->scan.scan_time = time(NULL);

    if (wifi->scan.net_list)
    {
        RARCH_LOG("[WiFi] Freeing previous scan results\n");
        RBUF_FREE(wifi->scan.net_list);
    }

#if defined(IOS)
    NSArray *networks = [[RARWiFiManager shared] availableNetworks];
    RARCH_LOG("[WiFi] Found %d networks\n", (int)[networks count]);

    for (NSDictionary *network in networks) {
        wifi_network_info_t entry;
        memset(&entry, 0, sizeof(entry));

        NSString *ssid = network[@"SSID"];
        if (ssid) {
            strlcpy(entry.ssid, [ssid UTF8String], sizeof(entry.ssid));
            entry.connected = true; // On iOS, we can only see the connected network
            RARCH_LOG("[WiFi] Adding network to list: %s\n", entry.ssid);
            RBUF_PUSH(wifi->scan.net_list, entry);
        }
    }
#endif
}

static wifi_network_scan_t* nmcli_get_ssids(void *data)
{
    RARCH_LOG("[WiFi] Retrieving scan results\n");
    apple_wifi_t *wifi = (apple_wifi_t*)data;
    return &wifi->scan;
}

static bool nmcli_ssid_is_online(void *data, unsigned idx)
{
    apple_wifi_t *wifi = (apple_wifi_t*)data;
    if (!wifi->scan.net_list || idx >= RBUF_LEN(wifi->scan.net_list))
    {
        RARCH_LOG("[WiFi] Invalid network index: %u\n", idx);
        return false;
    }
    RARCH_LOG("[WiFi] Checking online status for network %u: %s\n",
              idx, wifi->scan.net_list[idx].ssid);
    return wifi->scan.net_list[idx].connected;
}

static bool nmcli_connect_ssid(void *data, const wifi_network_info_t *netinfo)
{
    RARCH_LOG("[WiFi] Connect request ignored (not supported on iOS): %s\n",
              netinfo ? netinfo->ssid : "null");
    return false; // iOS doesn't allow programmatic WiFi connections
}

static bool nmcli_disconnect_ssid(void *data, const wifi_network_info_t *netinfo)
{
    RARCH_LOG("[WiFi] Disconnect request ignored (not supported on iOS): %s\n",
              netinfo ? netinfo->ssid : "null");
    return false; // iOS doesn't allow programmatic WiFi disconnections
}

static void nmcli_tether_start_stop(void *a, bool b, char *c)
{
    RARCH_LOG("[WiFi] Tether request ignored (not supported on iOS)\n");
}

wifi_driver_t wifi_nmcli = {
   nmcli_init,
   nmcli_free,
   nmcli_start,
   nmcli_stop,
   nmcli_enable,
   nmcli_connection_info,
   nmcli_scan,
   nmcli_get_ssids,
   nmcli_ssid_is_online,
   nmcli_connect_ssid,
   nmcli_disconnect_ssid,
   nmcli_tether_start_stop,
   "apple_wifi",
};
