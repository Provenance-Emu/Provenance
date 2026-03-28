/*
 Copyright (c) 2026, Provenance EMU Team

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the names of its contributors
       may be used to endorse or promote products derived from this software
       without specific prior written permission.

 THIS SOFTWARE IS PROVIDED ''AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHORS
 BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
 OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

//  PVSNESEmulatorCore+LightGun.mm
//  PVSNES
//
//  Implements LightGunResponder bridge helpers for snes9x:
//    - Super Scope   (port 2, most light-gun SNES titles)
//    - Konami Justifier (port 2, Lethal Enforcers)
//
//  Coordinate system
//  -----------------
//  Provenance delivers normalised aim coordinates in [0,1]×[0,1] screen space.
//  snes9x expects pixel coordinates:
//    x ∈ [0, 255]   (SNES horizontal resolution 256 px)
//    y ∈ [0, 223]   (SNES vertical resolution  224 px)
//
//  Button-ID ranges
//  ----------------
//  The mouse bridge uses 0x9000–0x9002.  We use non-overlapping ranges:
//    Super Scope : 0x9100–0x9105
//    Justifier   : 0x9200–0x9203

#import "PVSNESEmulatorCore.h"

#include "SNESCore/controls.h"

// ── snes9x screen dimensions ─────────────────────────────────────────────────
static const double kSNESScreenWidth  = 256.0;
static const double kSNESScreenHeight = 224.0;

// ── Button/pointer mapping IDs ────────────────────────────────────────────────
// Super Scope
static const uint32_t kScopePtrID       = 0x9100;
static const uint32_t kScopeFireID      = 0x9101;
static const uint32_t kScopeCursorID    = 0x9102;
static const uint32_t kScopeTurboID     = 0x9103;
static const uint32_t kScopePauseID     = 0x9104;
static const uint32_t kScopeOffscreenID = 0x9105;

// Justifier (gun 1, port 2)
static const uint32_t kJustPtrID        = 0x9200;
static const uint32_t kJustTriggerID    = 0x9201;
static const uint32_t kJustStartID      = 0x9202;
static const uint32_t kJustOffscreenID  = 0x9203;

// ── File-scope session state ──────────────────────────────────────────────────
// ObjC categories cannot add instance variables, so we use a file-scope struct.
// Only one emulator session runs at a time, so this is safe.

typedef NS_ENUM(NSUInteger, SNESLightGunType) {
    SNESLightGunTypeNone       = 0,
    SNESLightGunTypeSuperScope = 1,
    SNESLightGunTypeJustifier  = 2,
};

static SNESLightGunType sLightGunType    = SNESLightGunTypeNone;
static BOOL             sOffscreenActive = NO;   // tracks whether AimOffscreen is currently held

// ── Helper: normalised [0,1] → SNES pixel coordinates ────────────────────────
static inline int16_t normToSNESX(CGFloat nx) {
    int v = (int)(nx * (kSNESScreenWidth  - 1.0) + 0.5);
    return (int16_t)(v < 0 ? 0 : (v > 255 ? 255 : v));
}

static inline int16_t normToSNESY(CGFloat ny) {
    int v = (int)(ny * (kSNESScreenHeight - 1.0) + 0.5);
    return (int16_t)(v < 0 ? 0 : (v > 223 ? 223 : v));
}

// ── Category implementation ───────────────────────────────────────────────────

@implementation PVSNESEmulatorCoreBridge (LightGun)

#pragma mark - Setup / teardown

- (BOOL)isSNESLightGunGame {
    return sLightGunType != SNESLightGunTypeNone;
}

- (void)setupSuperScopeMappings {
    sLightGunType    = SNESLightGunTypeSuperScope;
    sOffscreenActive = NO;

    // Pointer — aims the Super Scope crosshair
    s9xcommand_t ptr = S9xGetCommandT("Pointer Superscope");
    if (ptr.type == S9xPointer) {
        S9xMapPointer(kScopePtrID, ptr, false);
    }

    // Fire (primary trigger)
    s9xcommand_t fire = S9xGetCommandT("Superscope Fire");
    if (fire.type == S9xButtonSuperscope) {
        S9xMapButton(kScopeFireID, fire, false);
    }

    // Cursor button (secondary / AuxA)
    s9xcommand_t cursor = S9xGetCommandT("Superscope Cursor");
    if (cursor.type == S9xButtonSuperscope) {
        S9xMapButton(kScopeCursorID, cursor, false);
    }

    // ToggleTurbo button (AuxB)
    s9xcommand_t turbo = S9xGetCommandT("Superscope ToggleTurbo");
    if (turbo.type == S9xButtonSuperscope) {
        S9xMapButton(kScopeTurboID, turbo, false);
    }

    // Pause button (Start)
    s9xcommand_t pause = S9xGetCommandT("Superscope Pause");
    if (pause.type == S9xButtonSuperscope) {
        S9xMapButton(kScopePauseID, pause, false);
    }

    // AimOffscreen — when held, snes9x ignores the pointer and signals a miss
    s9xcommand_t offscreen = S9xGetCommandT("Superscope AimOffscreen");
    if (offscreen.type == S9xButtonSuperscope) {
        S9xMapButton(kScopeOffscreenID, offscreen, false);
    }

    // Start the pointer at screen centre so the first frame isn't aimed at (0,0).
    S9xReportPointer(kScopePtrID,
                     (int16_t)(kSNESScreenWidth  / 2),
                     (int16_t)(kSNESScreenHeight / 2));
}

- (void)setupJustifierMappings {
    sLightGunType    = SNESLightGunTypeJustifier;
    sOffscreenActive = NO;

    // Pointer — aims Justifier gun #1
    s9xcommand_t ptr = S9xGetCommandT("Pointer Justifier1");
    if (ptr.type == S9xPointer) {
        S9xMapPointer(kJustPtrID, ptr, false);
    }

    // Trigger
    s9xcommand_t trigger = S9xGetCommandT("Justifier1 Trigger");
    if (trigger.type == S9xButtonJustifier) {
        S9xMapButton(kJustTriggerID, trigger, false);
    }

    // Start
    s9xcommand_t start = S9xGetCommandT("Justifier1 Start");
    if (start.type == S9xButtonJustifier) {
        S9xMapButton(kJustStartID, start, false);
    }

    // AimOffscreen
    s9xcommand_t offscreen = S9xGetCommandT("Justifier1 AimOffscreen");
    if (offscreen.type == S9xButtonJustifier) {
        S9xMapButton(kJustOffscreenID, offscreen, false);
    }

    // Start the pointer at screen centre.
    S9xReportPointer(kJustPtrID,
                     (int16_t)(kSNESScreenWidth  / 2),
                     (int16_t)(kSNESScreenHeight / 2));
}

- (void)resetSNESLightGunState {
    // Release all held light-gun inputs and clear session state.
    if (sOffscreenActive) {
        switch (sLightGunType) {
            case SNESLightGunTypeSuperScope:
                S9xReportButton(kScopeOffscreenID, false);
                S9xReportButton(kScopeFireID,      false);
                break;
            case SNESLightGunTypeJustifier:
                S9xReportButton(kJustOffscreenID,  false);
                S9xReportButton(kJustTriggerID,    false);
                break;
            default:
                break;
        }
        sOffscreenActive = NO;
    }
    sLightGunType = SNESLightGunTypeNone;
}

#pragma mark - Aim

- (void)snesLightGunMovedToPoint:(CGPoint)normalizedPoint isOffscreen:(BOOL)isOffscreen {
    switch (sLightGunType) {
        case SNESLightGunTypeSuperScope: {
            // Keep AimOffscreen in sync with the isOffscreen flag.
            if (isOffscreen != sOffscreenActive) {
                S9xReportButton(kScopeOffscreenID, isOffscreen);
                sOffscreenActive = isOffscreen;
            }
            if (!isOffscreen) {
                S9xReportPointer(kScopePtrID,
                                 normToSNESX(normalizedPoint.x),
                                 normToSNESY(normalizedPoint.y));
            }
            break;
        }
        case SNESLightGunTypeJustifier: {
            if (isOffscreen != sOffscreenActive) {
                S9xReportButton(kJustOffscreenID, isOffscreen);
                sOffscreenActive = isOffscreen;
            }
            if (!isOffscreen) {
                S9xReportPointer(kJustPtrID,
                                 normToSNESX(normalizedPoint.x),
                                 normToSNESY(normalizedPoint.y));
            }
            break;
        }
        default:
            break;
    }
}

#pragma mark - Trigger

- (void)snesLightGunTriggerDown {
    switch (sLightGunType) {
        case SNESLightGunTypeSuperScope: S9xReportButton(kScopeFireID,    true);  break;
        case SNESLightGunTypeJustifier:  S9xReportButton(kJustTriggerID,  true);  break;
        default: break;
    }
}

- (void)snesLightGunTriggerUp {
    switch (sLightGunType) {
        case SNESLightGunTypeSuperScope: S9xReportButton(kScopeFireID,    false); break;
        case SNESLightGunTypeJustifier:  S9xReportButton(kJustTriggerID,  false); break;
        default: break;
    }
}

#pragma mark - Auxiliary buttons

/// AuxA maps to Super Scope "Pause" (per LightGunResponder protocol comment).
/// No-op for Justifier.
- (void)snesLightGunAuxADown {
    if (sLightGunType == SNESLightGunTypeSuperScope) {
        S9xReportButton(kScopePauseID, true);
    }
}

- (void)snesLightGunAuxAUp {
    if (sLightGunType == SNESLightGunTypeSuperScope) {
        S9xReportButton(kScopePauseID, false);
    }
}

/// AuxB maps to Super Scope "ToggleTurbo" (fire-toggle, per LightGunResponder comment).
/// No-op for Justifier.
- (void)snesLightGunAuxBDown {
    if (sLightGunType == SNESLightGunTypeSuperScope) {
        S9xReportButton(kScopeTurboID, true);
    }
}

- (void)snesLightGunAuxBUp {
    if (sLightGunType == SNESLightGunTypeSuperScope) {
        S9xReportButton(kScopeTurboID, false);
    }
}

/// Start maps to Super Scope "Cursor" (the prominent secondary button) and
/// Justifier "Start".
- (void)snesLightGunStartDown {
    switch (sLightGunType) {
        case SNESLightGunTypeSuperScope: S9xReportButton(kScopeCursorID, true); break;
        case SNESLightGunTypeJustifier:  S9xReportButton(kJustStartID,   true); break;
        default: break;
    }
}

- (void)snesLightGunStartUp {
    switch (sLightGunType) {
        case SNESLightGunTypeSuperScope: S9xReportButton(kScopeCursorID, false); break;
        case SNESLightGunTypeJustifier:  S9xReportButton(kJustStartID,   false); break;
        default: break;
    }
}

#pragma mark - Reload gesture (aim offscreen + fire simultaneously)

/// Signal a "reload" — set AimOffscreen and press trigger together.
/// This is the standard way SNES light guns detect a shot fired off-screen,
/// which many games use to reload an empty magazine.
- (void)snesLightGunReloadDown {
    switch (sLightGunType) {
        case SNESLightGunTypeSuperScope:
            S9xReportButton(kScopeOffscreenID, true);
            S9xReportButton(kScopeFireID,      true);
            sOffscreenActive = YES;
            break;
        case SNESLightGunTypeJustifier:
            S9xReportButton(kJustOffscreenID,  true);
            S9xReportButton(kJustTriggerID,    true);
            sOffscreenActive = YES;
            break;
        default:
            break;
    }
}

- (void)snesLightGunReloadUp {
    switch (sLightGunType) {
        case SNESLightGunTypeSuperScope:
            S9xReportButton(kScopeFireID,      false);
            S9xReportButton(kScopeOffscreenID, false);
            sOffscreenActive = NO;
            break;
        case SNESLightGunTypeJustifier:
            S9xReportButton(kJustTriggerID,    false);
            S9xReportButton(kJustOffscreenID,  false);
            sOffscreenActive = NO;
            break;
        default:
            break;
    }
}

@end
