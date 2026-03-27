//
//  PVRetroArchCoreBridge+LightGun.m
//  PVRetroArch
//
//  Thin ObjC category that bridges the Swift LightGunResponder callbacks
//  to the C-level light-gun state variables in PVRetroArchCore+Controls.m.
//

#import "PVRetroArchCoreBridge+LightGun.h"
#import "PVRetroArchCoreCapabilities.h"

@implementation PVRetroArchCoreBridge (LightGun)

- (void)setLightGunX:(int16_t)x y:(int16_t)y offscreen:(BOOL)offscreen {
    pv_lightgun_set_position(x, y, (bool)offscreen);
}

- (void)setLightGunTrigger:(BOOL)down {
    pv_lightgun_set_trigger((bool)down);
}

- (void)setLightGunReload:(BOOL)down {
    pv_lightgun_set_reload((bool)down);
}

- (void)setLightGunAuxA:(BOOL)down {
    pv_lightgun_set_aux_a((bool)down);
}

- (void)setLightGunAuxB:(BOOL)down {
    pv_lightgun_set_aux_b((bool)down);
}

- (void)setLightGunStart:(BOOL)down {
    pv_lightgun_set_start((bool)down);
}

- (void)setLightGunSelect:(BOOL)down {
    pv_lightgun_set_select((bool)down);
}

- (BOOL)coreDeclaresLightGunDevice {
    return pv_core_declares_lightgun_device() ? YES : NO;
}

@end
