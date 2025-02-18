/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2025 - Joseph Mattiello
 *
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 */

 /**
 * @file apple_wifi.m
 * @brief WiFi driver implementation for iOS and macOS using CoreWLAN and NEHotspotHelper.
 *
 * @note Entitlements Required:
 * - `com.apple.developer.networking.HotspotHelper` (Boolean: true)
 *   This entitlement is required to use the NEHotspotHelper API for managing WiFi networks.
 *
 * @note Info.plist Requirements:
 * - `NSLocalNetworkUsageDescription` (String)
 *   A user-facing description explaining why the app needs access to WiFi networks.
 *   Example: "RetroArch needs access to WiFi networks for network features."
 * - `NEHotspotHelperSupported` (Boolean: true)
 *   Indicates that the app supports the NEHotspotHelper API.
 *
 * @note Permissions:
 * - The app must have the "Hotspot Helper" capability enabled in the Xcode project.
 * - The app must be signed with a provisioning profile that includes the required entitlements.
 *
 * @note Limitations:
 * - On iOS, direct control over WiFi (e.g., enabling/disabling) is not possible due to platform restrictions.
 * - Extended features (e.g., connecting to networks) require the app to have the `NEHotspotHelper` entitlement.
 * - Simulator does not support these features.
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
- (BOOL)hasExtendedPermissions;
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

- (BOOL)hasExtendedPermissions {
    /// Check if the app has the required entitlements for extended WiFi access
#if TARGET_OS_SIMULATOR
    RARCH_LOG("[WiFi] Simulator doesn't support these features\n");
    return NO; /// Simulator doesn't support these features
#else
    if (@available(iOS 14.0, *)) {
        /// Check if NEHotspotHelper class is available
        if ([NEHotspotHelper class]) {
            RARCH_LOG("[WiFi] HotspotHelper API available\n");
            return YES;
        } else {
            RARCH_LOG("[WiFi] HotspotHelper API not available\n");
        }
    } else {
        RARCH_LOG("[WiFi] iOS version too low for extended permissions\n");
    }

    RARCH_LOG("[WiFi] No extended WiFi permissions available\n");
    return NO;
#endif
}

- (NSDictionary *)currentNetwork {
#if TARGET_OS_TV
    RARCH_LOG("[WiFi] TVOS doesn't support these features\n");
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
        } else {
            RARCH_LOG("[WiFi] No active network found\n");
        }
    }
    return nil;
#endif
}

- (NSArray<NSDictionary *> *)availableNetworks {
    RARCH_LOG("[WiFi] Scanning for available networks\n");

    if ([self hasExtendedPermissions]) {
        if (@available(iOS 14.0, *)) {
            RARCH_LOG("[WiFi] Using extended permissions for network scan\n");
            __block NSMutableArray *networks = [NSMutableArray array];

            [NEHotspotHelper registerWithOptions:nil queue:dispatch_get_main_queue() handler:^void(NEHotspotHelperCommand *cmd) {
                if (cmd.commandType == kNEHotspotHelperCommandTypeFilterScanList) {
                    for (NEHotspotNetwork *network in cmd.networkList) {
                        NSMutableDictionary *networkInfo = [NSMutableDictionary dictionary];
                        if (network.SSID) {
                            networkInfo[@"SSID"] = network.SSID;
                        }
                        if (network.BSSID) {
                            networkInfo[@"BSSID"] = network.BSSID;
                        }
                        [networks addObject:networkInfo];
                    }
                }
            }];

            RARCH_LOG("[WiFi] Found %d networks using extended permissions\n", (int)[networks count]);
            return networks;
        }
    }

    RARCH_LOG("[WiFi] Using basic network info\n");
    NSDictionary *currentNetwork = [self currentNetwork];
    if (currentNetwork) {
        NSString *ssid = currentNetwork[@"SSID"];
        RARCH_LOG("[WiFi] Current network SSID: %s\n", [ssid UTF8String]);
    } else {
        RARCH_LOG("[WiFi] No active network found\n");
    }
    return currentNetwork ? @[currentNetwork] : @[];
}

@end
#endif

#if defined(OSX)
/// macOS-specific WiFi manager
@interface RARWiFiManagerMacOS : NSObject
+ (instancetype)shared;
- (NSArray<CWNetwork *> *)availableNetworks;
- (CWInterface *)currentInterface;
@end

@implementation RARWiFiManagerMacOS

+ (instancetype)shared {
    static RARWiFiManagerMacOS *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[RARWiFiManagerMacOS alloc] init];
        RARCH_LOG("[WiFi] RARWiFiManagerMacOS singleton initialized\n");
    });
    return shared;
}

- (CWInterface *)currentInterface {
    CWInterface *interface = [CWWiFiClient sharedWiFiClient].interface;
    if (!interface) {
        RARCH_ERR("[WiFi] Could not get current WiFi interface\n");
    }
    return interface;
}

- (NSArray<CWNetwork *> *)availableNetworks {
    CWInterface *interface = [self currentInterface];
    if (!interface) {
        return nil;
    }

    NSError *error = nil;
    NSArray<CWNetwork *> *networks = [interface scanForNetworksWithName:nil error:&error];
    if (error) {
        RARCH_ERR("[WiFi] Failed to scan networks: %s\n", [[error localizedDescription] UTF8String]);
        return nil;
    }

    RARCH_LOG("[WiFi] Found %lu networks\n", (unsigned long)[networks count]);
    return networks;
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
    RARCH_LOG("[WiFi] Starting WiFi driver\n");
    apple_wifi_t *wifi = (apple_wifi_t*)data;
    if (!wifi) {
        RARCH_ERR("[WiFi] Invalid data pointer\n");
        return false;
    }

    /// Initialize scan list using malloc
    wifi->scan.net_list = (wifi_network_info_t*)malloc(sizeof(wifi_network_info_t));
    if (!wifi->scan.net_list) {
        RARCH_ERR("[WiFi] Failed to allocate scan list\n");
        return false;
    }
    memset(wifi->scan.net_list, 0, sizeof(wifi_network_info_t));

    RARCH_LOG("[WiFi] WiFi driver started\n");
    return true;
}

static void nmcli_stop(void *data)
{
    RARCH_LOG("[WiFi] Stopping WiFi driver\n");
    apple_wifi_t *wifi = (apple_wifi_t*)data;
    if (!wifi) {
        RARCH_ERR("[WiFi] Invalid data pointer\n");
        return;
    }

    /// Free scan list
    if (wifi->scan.net_list) {
        free(wifi->scan.net_list);
        wifi->scan.net_list = NULL;
    }

    RARCH_LOG("[WiFi] WiFi driver stopped\n");
}

static bool nmcli_enable(void* data, bool enabled)
{
#if defined(IOS)
    /// On iOS, we can't programmatically enable/disable WiFi
    RARCH_LOG("[WiFi] Enable request ignored (not supported on iOS): %d\n", enabled);
    return true; // iOS doesn't allow programmatic WiFi control

#elif defined(OSX)
    RARWiFiManagerMacOS *wifiManager = [RARWiFiManagerMacOS shared];
    CWInterface *interface = [wifiManager currentInterface];
    if (!interface) {
        RARCH_ERR("[WiFi] Could not get WiFi interface\n");
        return false;
    }

    NSError *error = nil;
    BOOL success = [interface setPower:enabled error:&error];
    if (error) {
        RARCH_ERR("[WiFi] Failed to %s WiFi: %s\n",
                  enabled ? "enable" : "disable",
                  [[error localizedDescription] UTF8String]);
        return false;
    }

    RARCH_LOG("[WiFi] Successfully %s WiFi\n", enabled ? "enabled" : "disabled");
    return success;
#endif
}

static bool nmcli_connection_info(void *data, wifi_network_info_t *network)
{
    if (!network) {
        RARCH_ERR("[WiFi] Invalid network info pointer\n");
        return false;
    }

#if defined(IOS)
    RARCH_LOG("[WiFi] Getting connection info\n");
    RARWiFiManager *wifiManager = [RARWiFiManager shared];
    NSDictionary *currentNetwork = [wifiManager currentNetwork];

    if (currentNetwork) {
        NSString *ssid = currentNetwork[@"SSID"];
        if (ssid) {
            strlcpy(network->ssid, [ssid UTF8String], sizeof(network->ssid));
            network->connected = true;
            RARCH_LOG("[WiFi] Found active network: %s\n", network->ssid);
            return true;
        }
    }

    RARCH_LOG("[WiFi] No active network found\n");
    memset(network, 0, sizeof(*network));
    return false;
#else
    /// macOS implementation could go here
    return false;
#endif
}

static void nmcli_scan(void *data)
{
    apple_wifi_t *wifi = (apple_wifi_t*)data;
    wifi->scan.scan_time = time(NULL);

    if (wifi->scan.net_list) {
        RARCH_LOG("[WiFi] Freeing previous scan results\n");
        free(wifi->scan.net_list);
    }

#if defined(IOS)
    NSArray *networks = [[RARWiFiManager shared] availableNetworks];
    RARCH_LOG("[WiFi] Found %d networks\n", (int)[networks count]);

    wifi->scan.net_list = (wifi_network_info_t*)malloc(sizeof(wifi_network_info_t) * [networks count]);
    for (NSUInteger i = 0; i < [networks count]; i++) {
        NSDictionary *network = networks[i];
        wifi_network_info_t entry = {0};
        NSString *ssid = network[@"SSID"];
        if (ssid) {
            strlcpy(entry.ssid, [ssid UTF8String], sizeof(entry.ssid));
            entry.connected = true; // On iOS, we can only see the connected network
            wifi->scan.net_list[i] = entry;
        }
    }

#elif defined(OSX)
    RARWiFiManagerMacOS *wifiManager = [RARWiFiManagerMacOS shared];
    NSArray<CWNetwork *> *networks = [wifiManager availableNetworks];
    if (!networks) {
        RARCH_ERR("[WiFi] Failed to scan networks\n");
        return;
    }

    wifi->scan.net_list = (wifi_network_info_t*)malloc(sizeof(wifi_network_info_t) * [networks count]);
    for (NSUInteger i = 0; i < [networks count]; i++) {
        CWNetwork *network = networks[i];
        wifi_network_info_t entry = {0};
        strlcpy(entry.ssid, [network.ssid UTF8String], sizeof(entry.ssid));
        entry.connected = [network.ssid isEqualToString:[wifiManager currentInterface].ssid];
        wifi->scan.net_list[i] = entry;
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
    if (!netinfo) {
        RARCH_ERR("[WiFi]: Invalid network info pointer\n");
        return false;
    }

#if defined(IOS)
    if (@available(iOS 14.0, *)) {
        RARWiFiManager *wifiManager = [RARWiFiManager shared];
        if ([wifiManager hasExtendedPermissions]) {
            RARCH_LOG("[WiFi] Attempting to connect to network: %s\n", netinfo->ssid);

            /// Create a NEHotspotConfiguration object
            NEHotspotConfiguration *config;
            if (netinfo->passphrase[0] != '\0') {
                /// Use passphrase if available
                config = [[NEHotspotConfiguration alloc] initWithSSID:@(netinfo->ssid)
                                                         passphrase:@(netinfo->passphrase)
                                                         isWEP:NO];
            } else {
                /// Connect to open network
                config = [[NEHotspotConfiguration alloc] initWithSSID:@(netinfo->ssid)];
            }

            /// Apply the configuration
            [[NEHotspotConfigurationManager sharedManager] applyConfiguration:config completionHandler:^(NSError * _Nullable error) {
                if (error) {
                    RARCH_ERR("[WiFi] Failed to connect to network: %s\n", [[error localizedDescription] UTF8String]);
                } else {
                    RARCH_LOG("[WiFi] Successfully connected to network: %s\n", netinfo->ssid);
                }
            }];

            return true;
        }
    }
    RARCH_LOG("[WiFi] Connect request ignored (no extended permissions): %s\n", netinfo->ssid);
    return false;

#elif defined(OSX)
    RARWiFiManagerMacOS *wifiManager = [RARWiFiManagerMacOS shared];
    CWInterface *interface = [wifiManager currentInterface];
    if (!interface) {
        RARCH_ERR("[WiFi] Could not get WiFi interface\n");
        return false;
    }

    NSError *error = nil;
    BOOL success = [interface associateToNetworkWithSSID:@(netinfo->ssid)
                                           passphrase:@(netinfo->passphrase)
                                               error:&error];
    if (error) {
        RARCH_ERR("[WiFi] Failed to connect to network: %s\n", [[error localizedDescription] UTF8String]);
        return false;
    }

    RARCH_LOG("[WiFi] Successfully connected to network: %s\n", netinfo->ssid);
    return success;
#endif
}

static bool nmcli_disconnect_ssid(void *data, const wifi_network_info_t *netinfo)
{
    if (!netinfo) {
        RARCH_ERR("[WiFi]: Invalid network info pointer\n");
        return false;
    }

#if defined(IOS)
    if (@available(iOS 14.0, *)) {
        RARWiFiManager *wifiManager = [RARWiFiManager shared];
        if ([wifiManager hasExtendedPermissions]) {
            RARCH_LOG("[WiFi] Attempting to disconnect from network: %s\n", netinfo->ssid);

            /// Remove the configuration
            [[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:@(netinfo->ssid)];
            RARCH_LOG("[WiFi] Successfully disconnected from network: %s\n", netinfo->ssid);
            return true;
        }
    }
    RARCH_LOG("[WiFi] Disconnect request ignored (no extended permissions): %s\n", netinfo->ssid);
    return false;

#elif defined(OSX)
    RARWiFiManagerMacOS *wifiManager = [RARWiFiManagerMacOS shared];
    CWInterface *interface = [wifiManager currentInterface];
    if (!interface) {
        RARCH_ERR("[WiFi] Could not get WiFi interface\n");
        return false;
    }

    NSError *error = nil;
    BOOL success = [interface disassociateWithError:&error];
    if (error) {
        RARCH_ERR("[WiFi] Failed to disconnect: %s\n", [[error localizedDescription] UTF8String]);
        return false;
    }

    RARCH_LOG("[WiFi] Successfully disconnected from network\n");
    return success;
#endif
}

static void nmcli_tether_start_stop(void *data, bool start, char *ssid)
{
#if defined(IOS)
    if (@available(iOS 14.0, *)) {
        RARWiFiManager *wifiManager = [RARWiFiManager shared];
        if ([wifiManager hasExtendedPermissions]) {
            if (start) {
                RARCH_LOG("[WiFi] Starting tethering for SSID: %s\n", ssid);
                /// Create a NEHotspotConfiguration object for tethering
                NEHotspotConfiguration *config = [[NEHotspotConfiguration alloc] initWithSSID:@(ssid)];
                config.joinOnce = YES;

                /// Apply the configuration
                [[NEHotspotConfigurationManager sharedManager] applyConfiguration:config completionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        RARCH_ERR("[WiFi] Failed to start tethering: %s\n", [[error localizedDescription] UTF8String]);
                    } else {
                        RARCH_LOG("[WiFi] Successfully started tethering\n");
                    }
                }];
            } else {
                RARCH_LOG("[WiFi] Stopping tethering\n");
                /// Remove the configuration
                [[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:@(ssid)];
            }
            return;
        }
    }
    RARCH_LOG("[WiFi] Tether request ignored (no extended permissions)\n");
#endif
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
