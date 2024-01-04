#import <PVRetroArch/PVRetroArch.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import "PVRetroArchCore.h"
#import "PVRetroArchCore+Archive.h"

NSString* AppleII_EXTENSIONS  = @"dsk|do|bin|nib|fdi|td0|imd|cqm|d77|d88|1dd|image|dc|po|2mg|2img|img|chd|hdv|2mg";

@interface PVRetroArchCore (Archive)
@end

@implementation PVRetroArchCore (Archive)
- (NSMutableArray *)getAppleIIFiles:(NSString *)path extract:(bool)extract {
    NSError *error = nil;
    NSMutableArray<NSDictionary *> *files = [NSMutableArray arrayWithArray:@[]];
    NSDirectoryEnumerator *contents = [[NSFileManager defaultManager]
                                       enumeratorAtPath:path];
    for (NSString *obj in contents) {
        // Rename to Lowercase
        NSString *file=[path stringByAppendingString:[NSString stringWithFormat:@"/%@",obj]];
        NSString *fileLC=[path stringByAppendingString:[NSString stringWithFormat:@"/%@",obj.lowercaseString]];
        NSData *decode = [fileLC dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
        fileLC = [[NSString alloc] initWithData:decode encoding:NSUTF8StringEncoding];
        if (![file isEqualToString:fileLC]) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:fileLC]) {
                [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
            } else {
                [[NSFileManager defaultManager] moveItemAtPath:file toPath:fileLC error:nil];
            }
        }
        file=fileLC;
        NSLog(@"Archive: File %@\n", file);
        NSDictionary* attribs = [[NSFileManager defaultManager] attributesOfItemAtPath:file error:nil];
        BOOL isDirectory = attribs.fileType == NSFileTypeDirectory;
        if (!isDirectory) {
            if (extract && [self extractArchive:file toDestination:path overwrite:false]) {
                // Extract Archive
                [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
            } else if ([AppleII_EXTENSIONS localizedCaseInsensitiveContainsString:file.pathExtension]) {
                // Return AppleII ROMs
                NSDate* modDate = [attribs objectForKey:NSFileCreationDate];
                [files addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                  file, @"path",
                                  modDate, @"lastModDate",
                                  nil]];
            }
        }
    }
    return files;
}
- (NSString *)checkROM_AppleII:(NSString*)romFile {
    NSString *runFile = [NSString stringWithFormat:@"%@/run.cmd", [self getExtractedRomDirectory]];
    NSString *unzipPath = [self getExtractedRomDirectory];
    bool extract=true;
    if (![[NSFileManager defaultManager] fileExistsAtPath:runFile]) {
        if (![self isArchive:romPath]) {
            [[NSFileManager defaultManager] copyItemAtPath:romPath toPath:[unzipPath stringByAppendingFormat:@"/%@", [romPath lastPathComponent]] error:nil];
            extract=false;
        } else {
            NSError *error;
            NSLog(@"Archive: Extract Path: %@", unzipPath);
            if (!unzipPath) {
                return romFile;
            }
            NSString *password = @"";
            BOOL success = [self extractArchive:romPath toDestination:unzipPath overwrite:false];
            if (!success) {
                NSLog(@"Archive: Could not be Extracted");
                return romFile;
            }
        }
    } else {
        extract = false;
    }
    // Get Extracted Files
    NSMutableArray<NSDictionary *> *files = [self getAppleIIFiles:unzipPath extract:extract];
    // Refresh with Extracted archive in the the archive
    files = [self getAppleIIFiles:unzipPath extract:extract];
    // Sort Extracted ROMs
    NSArray* sortedFiles = [files sortedArrayUsingComparator: ^(id path1, id path2) {
        NSComparisonResult comp = [[path2 objectForKey:@"path"] compare:
                                   [path1 objectForKey:@"path"]];
        if (comp == NSOrderedDescending) {
            comp = NSOrderedAscending;
        } else if(comp == NSOrderedAscending){
            comp = NSOrderedDescending;
        }
        return comp;
    }];
    // Create run.cmd
    NSString* content = @"apple2e";
    switch (self.machineType) {
        case 210:
            content=@"apple2";
            break;
        case 211:
            content=@"apple2p";
            break;
        case 212:
            content=@"apple2e";
            break;
        case 213:
            content=@"apple2ee";
            break;
        case 220:
            content=@"apple2c";
            break;
        case 221:
            content=@"apple2gs";
            break;
        case 222:
            content=@"apple3";
            break;
    }
    // Find / Append system disk first
    int disk=1;
    bool isHDI=false;
    NSString *options=@"";
    for (NSDictionary *obj in sortedFiles) {
        NSString *file=[obj objectForKey:@"path"];
        file = [file stringByReplacingOccurrencesOfString:unzipPath
                                               withString:@"."];
        NSString *fullpath = [file stringByReplacingOccurrencesOfString:@"./"
                                                             withString:[self.batterySavesPath stringByAppendingString:@"/"]];
        NSLog(@"Archive: %@ Extension %@\n", file, file.pathExtension);
         if ([file.pathExtension containsString:@"hd"] && disk < 3) {
             disk = 3;
         }
        options = [options stringByAppendingString:[NSString stringWithFormat:@"floppydisk%d \"%@\"\n", disk, fullpath]];
        disk+=1;
    }
    [self writeApple2Ini:options];
    NSLog(@"Archive: Writing %@ to %@", content, runFile);
    NSError *error;
    [content writeToFile:runFile
              atomically:NO
                encoding:NSUTF8StringEncoding
                   error:&error];
    [self syncResources:self.BIOSPath
                     to:self.batterySavesPath];
    if (error) {
        NSLog(@"Archive: run.cmd write error %@",error);
        if (sortedFiles.count)
            return [sortedFiles[0] objectForKey:@"path"];
        else
            return romFile;
    }
    if (sortedFiles.count)
        return runFile;
    else
        return romFile;
}
- (void) writeApple2Ini:(NSString *)options {
    NSString *hp1=[self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system"];
    NSString *hp2=self.batterySavesPath;
    NSString *hp3=[self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system/mame"];
    NSString *rom1=[self.batterySavesPath stringByAppendingPathComponent:@"../../com.provenance.appleii"];
    NSString *rom2=[self.batterySavesPath stringByAppendingPathComponent:@"../../com.provenance.mame"];
    NSString *ini=[self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system/mame/ini"];
    NSString *content = [NSString stringWithFormat:
                         @"# CORE CONFIGURATION OPTIONS\n"
                         @"readconfig                1\n"
                         @"writeconfig               1\n"
                         @"# CORE SEARCH PATH OPTIONS\n"
                         @"homepath                  %s/../../RetroArch/system/mame\n"
                         @"rompath                   ./;%s;%s;%s;%s;%s\n"
                         @"hashpath                  %s/../../RetroArch/system/mame/hash\n"
                         @"samplepath                %s/../../RetroArch/system/mame/samples\n"
                         @"artpath                   %s/../../RetroArch/system/mame/artwork\n"
                         @"ctrlrpath                 %s/../../RetroArch/system/mame/ctrlr\n"
                         @"inipath                   ./;%s\n"
                         @"fontpath                  %s/../../RetroArch/system/mame/\n"
                         @"cheatpath                 %s/../../RetroArch/system/mame/cheat\n"
                         @"crosshairpath             %s/../../RetroArch/system/mame/crosshair\n"
                         @"pluginspath               %s/../../RetroArch/system/mame/plugins\n"
                         @"languagepath              %s/../../RetroArch/system/mame/language\n"
                         @"swpath                    ./;%s;%s;%s;%s;%s\n"
                         @"# CORE OUTPUT DIRECTORY OPTIONS\n"
                         @"cfg_directory             %s/../../RetroArch/states/mame/cfg\n"
                         @"nvram_directory           %s/../../RetroArch/states/mame/nvram\n"
                         @"input_directory           %s/../../RetroArch/states/mame/inp\n"
                         @"state_directory           %s/../../RetroArch/states/mame/sta\n"
                         @"snapshot_directory        %s/../../RetroArch/screenshots/mame\n"
                         @"diff_directory            %s/../../RetroArch/system/mame/diff\n"
                         @"comment_directory         %s/../../RetroArch/system/mame/comments\n"
                         @"share_directory           %s/../../RetroArch/system/mame/share\n"
                         @"# CORE STATE/PLAYBACK OPTIONS\n"
                         @"state\n"
                         @"autosave                  0\n"
                         @"rewind                    0\n"
                         @"rewind_capacity           100\n"
                         @"playback\n"
                         @"record\n"
                         @"exit_after_playback       0\n"
                         @"mngwrite\n"
                         @"aviwrite\n"
                         @"wavwrite\n"
                         @"snapname                  %%g/%%i\n"
                         @"snapsize                  auto\n"
                         @"snapview                  auto\n"
                         @"snapbilinear              1\n"
                         @"statename                 %%g\n"
                         @"burnin                    0\n"
                         @"# CORE PERFORMANCE OPTIONS\n"
                         @"autoframeskip             0\n"
                         @"frameskip                 0\n"
                         @"seconds_to_run            0\n"
                         @"throttle                  0\n"
                         @"sleep                     1\n"
                         @"speed                     1.0\n"
                         @"refreshspeed              0\n"
                         @"lowlatency                0\n"
                         @"# CORE RENDER OPTIONS\n"
                         @"keepaspect                1\n"
                         @"unevenstretch             1\n"
                         @"unevenstretchx            0\n"
                         @"unevenstretchy            0\n"
                         @"autostretchxy             0\n"
                         @"intoverscan               0\n"
                         @"intscalex                 0\n"
                         @"intscaley                 0\n"
                         @"# CORE ROTATION OPTIONS\n"
                         @"rotate                    0\n"
                         @"ror                       0\n"
                         @"rol                       0\n"
                         @"autoror                   0\n"
                         @"autorol                   0\n"
                         @"flipx                     0\n"
                         @"flipy                     0\n"
                         @"# CORE ARTWORK OPTIONS\n"
                         @"artwork_crop              0\n"
                         @"fallback_artwork\n"
                         @"override_artwork\n"
                         @"# CORE SCREEN OPTIONS\n"
                         @"brightness                1.0\n"
                         @"contrast                  1.0\n"
                         @"gamma                     1.0\n"
                         @"pause_brightness          0.65\n"
                         @"effect                    none\n"
                         @"# CORE SOUND OPTIONS\n"
                         @"samplerate                48000\n"
                         @"samples                   1\n"
                         @"volume                    1\n"
                         @"compressor                1\n"
                         @"speaker_report            0\n"
                         @"# CORE INPUT OPTIONS\n"
                         @"coin_lockout              1\n"
                         @"ctrlr\n"
                         @"mouse                     1\n"
                         @"joystick                  1\n"
                         @"lightgun                  1\n"
                         @"multikeyboard             1\n"
                         @"multimouse                1\n"
                         @"steadykey                 0\n"
                         @"ui_active                 1\n"
                         @"offscreen_reload          0\n"
                         @"joystick_map              auto\n"
                         @"joystick_deadzone         0.15\n"
                         @"joystick_saturation       0.85\n"
                         @"joystick_threshold        0.30\n"
                         @"natural                   0\n"
                         @"joystick_contradictory    0\n"
                         @"coin_impulse              0\n"
                         @"# CORE INPUT AUTOMATIC ENABLE OPTIONS\n"
                         @"paddle_device             keyboard\n"
                         @"adstick_device            keyboard\n"
                         @"pedal_device              keyboard\n"
                         @"dial_device               keyboard\n"
                         @"trackball_device          keyboard\n"
                         @"lightgun_device           keyboard\n"
                         @"positional_device         keyboard\n"
                         @"mouse_device              mouse\n"
                         @"# CORE DEBUGGING OPTIONS\n"
                         @"verbose                   0\n"
                         @"log                       0\n"
                         @"oslog                     0\n"
                         @"debug                     0\n"
                         @"update_in_pause           1\n"
                         @"debugscript\n"
                         @"debuglog                  0\n"
                         @"# CORE COMM OPTIONS\n"
                         @"comm_localhost            0.0.0.0\n"
                         @"comm_localport            15112\n"
                         @"comm_remotehost           127.0.0.1\n"
                         @"comm_remoteport           15112\n"
                         @"comm_framesync            0\n"
                         @"# CORE MISC OPTIONS\n"
                         @"drc                       1\n"
                         @"drc_use_c                 0\n"
                         @"drc_log_uml               0\n"
                         @"drc_log_native            0\n"
                         @"bios\n"
                         @"cheat                     1\n"
                         @"skip_gameinfo             1\n"
                         @"uifont                    default\n"
                         @"ui                        cabinet\n"
                         @"ramsize\n"
                         @"confirm_quit              0\n"
                         @"ui_mouse                  1\n"
                         @"language\n"
                         @"nvram_save                1\n"
                         @"# SCRIPTING OPTIONS\n"
                         @"autoboot_command\n"
                         @"autoboot_delay            0\n"
                         @"autoboot_script\n"
                         @"console                   0\n"
                         @"plugins                   1\n"
                         @"# plugin\n"
                         @"# noplugin\n"
                         @"# HTTP SERVER OPTIONS\n"
                         @"http                      0\n"
                         @"http_port                 8080\n"
                         @"http_root                 web\n"
                         @"# OSD INPUT MAPPING OPTIONS\n"
                         @"uimodekey                 DEL\n"
                         @"controller_map            none\n"
                         @"background_input          0\n"
                         @"# OSD FONT OPTIONS\n"
                         @"uifontprovider            auto\n"
                         @"# OSD OUTPUT OPTIONS\n"
                         @"output                    auto\n"
                         @"# OSD INPUT OPTIONS\n"
                         @"keyboardprovider          auto\n"
                         @"mouseprovider             auto\n"
                         @"lightgunprovider          auto\n"
                         @"joystickprovider          auto\n"
                         @"# OSD DEBUGGING OPTIONS\n"
                         @"debugger                  auto\n"
                         @"debugger_port             23946\n"
                         @"debugger_font             auto\n"
                         @"debugger_font_size        0\n"
                         @"watchdog                  0\n"
                         @"# OSD PERFORMANCE OPTIONS\n"
                         @"numprocessors             auto\n"
                         @"bench                     0\n"
                         @"# OSD VIDEO OPTIONS\n"
                         @"video                     auto\n"
                         @"numscreens                1\n"
                         @"window                    0\n"
                         @"maximize                  1\n"
                         @"waitvsync                 0\n"
                         @"syncrefresh               0\n"
                         @"monitorprovider           auto\n"
                         @"# OSD PER-WINDOW VIDEO OPTIONS\n"
                         @"screen                    auto\n"
                         @"aspect                    auto\n"
                         @"resolution                auto\n"
                         @"view                      auto\n"
                         @"screen0                   auto\n"
                         @"aspect0                   auto\n"
                         @"resolution0               auto\n"
                         @"view0                     auto\n"
                         @"screen1                   auto\n"
                         @"aspect1                   auto\n"
                         @"resolution1               auto\n"
                         @"view1                     auto\n"
                         @"screen2                   auto\n"
                         @"aspect2                   auto\n"
                         @"resolution2               auto\n"
                         @"view2                     auto\n"
                         @"screen3                   auto\n"
                         @"aspect3                   auto\n"
                         @"resolution3               auto\n"
                         @"view3                     auto\n"
                         @"# OSD FULL SCREEN OPTIONS\n"
                         @"switchres                 0\n"
                         @"# OSD ACCELERATED VIDEO OPTIONS\n"
                         @"filter                    1\n"
                         @"prescale                  1\n"
                         @"# OSD SOUND OPTIONS\n"
                         @"sound                     auto\n"
                         @"audio_latency             2\n"
                         @"# CoreAudio-SPECIFIC OPTIONS\n"
                         @"audio_output              auto\n"
                         @"audio_effect0             none\n"
                         @"audio_effect1             none\n"
                         @"audio_effect2             none\n"
                         @"audio_effect3             none\n"
                         @"audio_effect4             none\n"
                         @"audio_effect5             none\n"
                         @"audio_effect6             none\n"
                         @"audio_effect7             none\n"
                         @"audio_effect8             none\n"
                         @"audio_effect9             none\n"
                         @"# OSD MIDI OPTIONS\n"
                         @"midiprovider              auto\n"
                         @"# OSD EMULATED NETWORKING OPTIONS\n"
                         @"networkprovider           auto\n"
                         @"# BGFX POST-PROCESSING OPTIONS\n"
                         @"bgfx_path                 bgfx\n"
                         @"bgfx_backend              auto\n"
                         @"bgfx_debug                0\n"
                         @"bgfx_screen_chains\n"
                         @"bgfx_shadow_mask          slot-mask.png\n"
                         @"bgfx_lut                  lut-default.png\n"
                         @"bgfx_avi_name             auto\n"
                         @"# SDL VIDEO OPTIONS\n"
                         @"centerh                   1\n"
                         @"centerv                   1\n"
                         @"scalemode                 none\n"
                         @"# SDL JOYSTICK MAPPING\n"
                         @"joy_idx1                  auto\n"
                         @"joy_idx2                  auto\n"
                         @"joy_idx3                  auto\n"
                         @"joy_idx4                  auto\n"
                         @"joy_idx5                  auto\n"
                         @"joy_idx6                  auto\n"
                         @"joy_idx7                  auto\n"
                         @"joy_idx8                  auto\n"
                         @"sixaxis                   0\n"
                         @"# SDL MOUSE MAPPING\n"
                         @"mouse_index1              auto\n"
                         @"mouse_index2              auto\n"
                         @"mouse_index3              auto\n"
                         @"mouse_index4              auto\n"
                         @"mouse_index5              auto\n"
                         @"mouse_index6              auto\n"
                         @"mouse_index7              auto\n"
                         @"mouse_index8              auto\n"
                         @"# SDL KEYBOARD MAPPING\n"
                         @"keyb_idx1                 auto\n"
                         @"keyb_idx2                 auto\n"
                         @"keyb_idx3                 auto\n"
                         @"keyb_idx4                 auto\n"
                         @"keyb_idx5                 auto\n"
                         @"keyb_idx6                 auto\n"
                         @"keyb_idx7                 auto\n"
                         @"keyb_idx8                 auto\n"
                         @"# FRONTEND COMMAND OPTIONS\n"
                         @"dtd                       1\n"
                         @"# SLOT DEVICES\n"
                         @"gameio                    joy\n"
                         @"%s\n",
                         self.batterySavesPath.UTF8String,
                         hp1.UTF8String,
                         hp2.UTF8String,
                         hp3.UTF8String,
                         rom1.UTF8String,
                         rom2.UTF8String,
                         self.batterySavesPath.UTF8String,
                         self.batterySavesPath.UTF8String,
                         self.batterySavesPath.UTF8String,
                         self.batterySavesPath.UTF8String,
                         ini.UTF8String,
                         self.batterySavesPath.UTF8String,
                         self.batterySavesPath.UTF8String,
                         self.batterySavesPath.UTF8String,
                         self.batterySavesPath.UTF8String,
                         self.batterySavesPath.UTF8String,
                         hp1.UTF8String,
                         hp2.UTF8String,
                         hp3.UTF8String,
                         rom1.UTF8String,
                         rom2.UTF8String,
                         self.batterySavesPath.UTF8String,
                         self.batterySavesPath.UTF8String,
                         self.batterySavesPath.UTF8String,
                         self.batterySavesPath.UTF8String,
                         self.batterySavesPath.UTF8String,
                         self.batterySavesPath.UTF8String,
                         self.batterySavesPath.UTF8String,
                         self.batterySavesPath.UTF8String,
                         options.UTF8String];
    [[NSFileManager defaultManager] createDirectoryAtPath:[self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system/mame/cheat/"]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:[self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system/mame/ini/"]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    NSString *fileName = [self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system/mame/ini/apple2ee.ini"];
    NSLog(@"Archive: Writing %s to %s (%s)", content.UTF8String, fileName.UTF8String, options.UTF8String);
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
    fileName = [self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system/mame/ini/apple2e.ini"];
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
    fileName = [self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system/mame/ini/apple2p.ini"];
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
    fileName = [self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system/mame/ini/apple2c.ini"];
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
    fileName = [self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system/mame/ini/apple2gs.ini"];
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
    fileName = [self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system/mame/ini/apple2.ini"];
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
    fileName = [self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system/mame/ini/apple3.ini"];
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
    fileName = [self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system/mame/ini/mame.ini"];
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
    [self writeUIini];
    [self writePluginIni];
}

-(void) writeUIini {
    NSString *content = [NSString stringWithFormat:
                         @"# UI SEARCH PATH OPTIONS\n"
                         @"historypath               history;dats;.\n"
                         @"categorypath              folders\n"
                         @"cabinets_directory        cabinets;cabdevs\n"
                         @"cpanels_directory         cpanel\n"
                         @"pcbs_directory            pcb\n"
                         @"flyers_directory          flyers\n"
                         @"titles_directory          titles\n"
                         @"ends_directory            ends\n"
                         @"marquees_directory        marquees\n"
                         @"artwork_preview_directory \"artwork preview;artpreview\"\n"
                         @"bosses_directory          bosses\n"
                         @"logos_directory           logo\n"
                         @"scores_directory          scores\n"
                         @"versus_directory          versus\n"
                         @"gameover_directory        gameover\n"
                         @"howto_directory           howto\n"
                         @"select_directory          select\n"
                         @"icons_directory           icons\n"
                         @"covers_directory          covers\n"
                         @"ui_path                   ui\n"
                         @"# UI MISC OPTIONS\n"
                         @"system_names\n"
                         @"skip_warnings             0\n"
                         @"unthrottle_mute           0\n"
                         @"# UI OPTIONS\n"
                         @"infos_text_size           0.75\n"
                         @"font_rows                 30\n"
                         @"ui_border_color           ffffffff\n"
                         @"ui_bg_color               ef101030\n"
                         @"ui_clone_color            ff808080\n"
                         @"ui_dipsw_color            ffffff00\n"
                         @"ui_gfxviewer_color        ef101030\n"
                         @"ui_mousedown_bg_color     b0606000\n"
                         @"ui_mousedown_color        ffffff80\n"
                         @"ui_mouseover_bg_color     70404000\n"
                         @"ui_mouseover_color        ffffff80\n"
                         @"ui_selected_bg_color      ef808000\n"
                         @"ui_selected_color         ffffff00\n"
                         @"ui_slider_color           ffffffff\n"
                         @"ui_subitem_color          ffffffff\n"
                         @"ui_text_bg_color          ef000000\n"
                         @"ui_text_color             ffffffff\n"
                         @"ui_unavail_color          ff404040\n"
                         @"# SYSTEM/SOFTWARE SELECTION MENU OPTIONS\n"
                         @"hide_main_panel           0\n"
                         @"use_background            1\n"
                         @"skip_biosmenu             0\n"
                         @"skip_partsmenu            0\n"
                         @"remember_last             1\n"
                         @"last_used_machine         apple2e\n"
                         @"last_used_filter          Available\n"
                         @"system_right_panel        image\n"
                         @"software_right_panel      image\n"
                         @"system_right_image        cpanel\n"
                         @"software_right_image      snap\n"
                         @"enlarge_snaps             1\n"
                         @"forced4x3                 1\n"
                         @"info_audit_enabled        0\n"
                         @"hide_romless              1\n"];
    NSString *fileName = [self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system/mame/ini/ui.ini"];
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];

}

-(void) writePluginIni {
    NSString *content = [NSString stringWithFormat:
                             @"autofire                  0\n"
                             @"cheat                     1\n"
                             @"cheatfind                 1\n"
                             @"commonui                  1\n"
                             @"console                   1\n"
                             @"data                      1\n"
                             @"gdbstub                   1\n"
                             @"hiscore                   0\n"
                             @"inputmacro                1\n"
                             @"json                      1\n"
                             @"layout                    1\n"
                             @"portname                  1\n"
                             @"timecode                  1\n"
                             @"timer                     1\n"
                             @"xml                       1\n"
                         ];
    NSString *fileName = [self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system/mame/ini/plugin.ini"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
        [content writeToFile:fileName
                  atomically:NO
                    encoding:NSStringEncodingConversionAllowLossy
                       error:nil];
    }
}
@end
