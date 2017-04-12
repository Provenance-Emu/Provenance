/*
 Copyright (c) 2013, OpenEmu Team


 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "mednafen.h"
#include "settings-driver.h"
#include "state-driver.h"
#include "mednafen-driver.h"
#include "MemoryStream.h"

#import "MednafenGameCore.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#import <PVSupport/OERingBuffer.h>

#define GET_CURRENT_OR_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

typedef struct OEIntPoint {
    int x;
    int y;
} OEIntPoint;

typedef struct OEIntSize {
    int width;
    int height;
} OEIntSize;

typedef struct OEIntRect {
    OEIntPoint origin;
    OEIntSize size;
} OEIntRect;

static inline OEIntSize OEIntSizeMake(int width, int height)
{
    return (OEIntSize){ width, height };
}
static inline BOOL OEIntSizeEqualToSize(OEIntSize size1, OEIntSize size2)
{
    return size1.width == size2.width && size1.height == size2.height;
}
static inline BOOL OEIntSizeIsEmpty(OEIntSize size)
{
    return size.width == 0 || size.height == 0;
}

static inline OEIntRect OEIntRectMake(int x, int y, int width, int height)
{
    return (OEIntRect){ (OEIntPoint){ x, y }, (OEIntSize){ width, height } };
}

static MDFNGI *game;
static MDFN_Surface *surf;

namespace MDFN_IEN_VB
{
    extern void VIP_SetParallaxDisable(bool disabled);
    extern void VIP_SetAnaglyphColors(uint32 lcolor, uint32 rcolor);
    int mednafenCurrentDisplayMode = 1;
}

typedef enum MednaSystem {lynx, neogeo, pce, pcfx, psx, vb, wswan };

@interface MednafenGameCore ()
{
    uint32_t *inputBuffer[8];
    MednaSystem systemType;
    int videoWidth, videoHeight;
    int videoOffsetX, videoOffsetY;
    int multiTapPlayerCount;
    NSString *romName;
    double sampleRate;
    double masterClock;

    NSString *mednafenCoreModule;
    NSTimeInterval mednafenCoreTiming;
    OEIntSize mednafenCoreAspect;
    NSUInteger maxDiscs;
}

@end

static __weak MednafenGameCore *_current;

@implementation MednafenGameCore

-(uint32_t*) getInputBuffer:(int)bufferId
{
    return inputBuffer[bufferId];
}

static void mednafen_init(MednafenGameCore* current)
{
    //passing by parameter
    //GET_CURRENT_OR_RETURN();

    NSString* batterySavesDirectory = current.batterySavesPath;
    NSString* biosPath = current.BIOSPath;
    
    std::vector<MDFNGI*> ext;
    MDFNI_InitializeModules(ext);

    std::vector<MDFNSetting> settings;

    //passing by parameter
    //NSString *batterySavesDirectory = [self batterySavesPath];
    //NSString *biosPath = current.biosDirectoryPath;

    MDFNI_Initialize([biosPath UTF8String], settings);

    // Set bios/system file and memcard save paths
    MDFNI_SetSetting("pce.cdbios", [[[biosPath stringByAppendingPathComponent:@"syscard3"] stringByAppendingPathExtension:@"pce"] UTF8String]); // PCE CD BIOS
    MDFNI_SetSetting("pcfx.bios", [[[biosPath stringByAppendingPathComponent:@"pcfx"] stringByAppendingPathExtension:@"rom"] UTF8String]); // PCFX BIOS
    MDFNI_SetSetting("psx.bios_jp", [[[biosPath stringByAppendingPathComponent:@"scph5500"] stringByAppendingPathExtension:@"bin"] UTF8String]); // JP SCPH-5500 BIOS
    MDFNI_SetSetting("psx.bios_na", [[[biosPath stringByAppendingPathComponent:@"scph5501"] stringByAppendingPathExtension:@"bin"] UTF8String]); // NA SCPH-5501 BIOS
    MDFNI_SetSetting("psx.bios_eu", [[[biosPath stringByAppendingPathComponent:@"scph5502"] stringByAppendingPathExtension:@"bin"] UTF8String]); // EU SCPH-5502 BIOS
    MDFNI_SetSetting("filesys.path_sav", [batterySavesDirectory UTF8String]); // Memcards

    // VB defaults. dox http://mednafen.sourceforge.net/documentation/09x/vb.html
    MDFNI_SetSetting("vb.disable_parallax", "1");       // Disable parallax for BG and OBJ rendering
    MDFNI_SetSetting("vb.anaglyph.preset", "disabled"); // Disable anaglyph preset
    MDFNI_SetSetting("vb.anaglyph.lcolor", "0xFF0000"); // Anaglyph l color
    MDFNI_SetSetting("vb.anaglyph.rcolor", "0x000000"); // Anaglyph r color
    //MDFNI_SetSetting("vb.allow_draw_skip", "1");      // Allow draw skipping
    //MDFNI_SetSetting("vb.instant_display_hack", "1"); // Display latency reduction hack

    MDFNI_SetSetting("pce.slstart", "0"); // PCE: First rendered scanline
    MDFNI_SetSetting("pce.slend", "239"); // PCE: Last rendered scanline

    MDFNI_SetSetting("psx.h_overscan", "0"); // Remove PSX overscan

    // PlayStation Multitap supported games (incomplete list)
    NSDictionary *multiTapGames =
    @{
      @"SLES-02339" : @3, // Arcade Party Pak (Europe, Australia)
      @"SLUS-00952" : @3, // Arcade Party Pak (USA)
      @"SLES-02537" : @3, // Bishi Bashi Special (Europe)
      @"SLPM-86123" : @3, // Bishi Bashi Special (Japan)
      @"SLPM-86539" : @3, // Bishi Bashi Special 3: Step Champ (Japan)
      @"SLPS-01701" : @3, // Capcom Generation - Dai 4 Shuu Kokou no Eiyuu (Japan)
      @"SLPS-01567" : @3, // Captain Commando (Japan)
      @"SLUS-00682" : @3, // Jeopardy! (USA)
      @"SLUS-01173" : @3, // Jeopardy! 2nd Edition (USA)
      @"SLES-03752" : @3, // Quiz Show (Italy) (Disc 1)
      @"SLES-13752" : @3, // Quiz Show (Italy) (Disc 2)
      @"SLES-02849" : @3, // Rampage - Through Time (Europe) (En,Fr,De)
      @"SLUS-01065" : @3, // Rampage - Through Time (USA)
      @"SLES-02021" : @3, // Rampage 2 - Universal Tour (Europe)
      @"SLUS-00742" : @3, // Rampage 2 - Universal Tour (USA)
      @"SLUS-01174" : @3, // Wheel of Fortune - 2nd Edition (USA)
      @"SLES-03499" : @3, // You Don't Know Jack (Germany)
      @"SLUS-00716" : @3, // You Don't Know Jack (USA) (Disc 1)
      @"SLUS-00762" : @3, // You Don't Know Jack (USA) (Disc 2)
      @"SLUS-01194" : @3, // You Don't Know Jack - Mock 2 (USA)
      @"SLES-00015" : @4, // Actua Golf (Europe) (En,Fr,De)
      @"SLPS-00298" : @4, // Actua Golf (Japan)
      @"SLUS-00198" : @4, // VR Golf '97 (USA) (En,Fr)
      @"SLES-00044" : @4, // Actua Golf 2 (Europe)
      @"SLUS-00636" : @4, // FOX Sports Golf '99 (USA)
      @"SLES-01042" : @4, // Actua Golf 3 (Europe)
      @"SLES-00188" : @4, // Actua Ice Hockey (Europe) (En,Fr,De,Sv,Fi)
      @"SLPM-86078" : @4, // Actua Ice Hockey (Japan)
      @"SLES-01226" : @4, // Actua Ice Hockey 2 (Europe)
      @"SLES-00021" : @4, // Actua Soccer 2 (Europe) (En,Fr)
      @"SLES-01029" : @4, // Actua Soccer 2 (Germany) (En,De)
      @"SLES-01028" : @4, // Actua Soccer 2 (Italy)
      @"SLES-00265" : @4, // Actua Tennis (Europe)
      @"SLES-01396" : @4, // Actua Tennis (Europe) (Fr,De)
      @"SLES-00189" : @4, // Adidas Power Soccer (Europe) (En,Fr,De,Es,It)
      @"SCUS-94502" : @4, // Adidas Power Soccer (USA)
      @"SLES-00857" : @4, // Adidas Power Soccer 2 (Europe) (En,Fr,De,Es,It,Nl)
      @"SLES-00270" : @4, // Adidas Power Soccer International '97 (Europe) (En,Fr,De,Es,It,Nl)
      @"SLES-01239" : @4, // Adidas Power Soccer 98 (Europe) (En,Fr,De,Es,It,Nl)
      @"SLUS-00547" : @4, // Adidas Power Soccer 98 (USA)
      @"SLES-03963" : @4, // All Star Tennis (Europe)
      @"SLPS-02228" : @4, // Simple 1500 Series Vol. 26 - The Tennis (Japan)
      @"SLUS-01348" : @4, // Tennis (USA)
      @"SLES-01433" : @4, // All Star Tennis '99 (Europe) (En,Fr,De,Es,It)
      @"SLES-02764" : @4, // All Star Tennis 2000 (Europe) (En,De,Es,It)
      @"SLES-02765" : @4, // All Star Tennis 2000 (France)
      @"SCES-00263" : @4, // Namco Tennis Smash Court (Europe)
      @"SLPS-00450" : @4, // Smash Court (Japan)
      @"SCES-01833" : @4, // Anna Kournikova's Smash Court Tennis (Europe)
      @"SLPS-01693" : @4, // Smash Court 2 (Japan)
      @"SLPS-03001" : @4, // Smash Court 3 (Japan)
      @"SLES-03579" : @4, // Junior Sports Football (Europe)
      @"SLES-03581" : @4, // Junior Sports Fussball (Germany)
      @"SLUS-01094" : @4, // Backyard Soccer (USA)
      @"SLES-03210" : @4, // Hunter, The (Europe)
      @"SLPM-86400" : @4, // SuperLite 1500 Series - Battle Sugoroku the Hunter - A.R.0062 (Japan)
      @"SLUS-01335" : @4, // Battle Hunter (USA)
      @"SLES-00476" : @4, // Blast Chamber (Europe) (En,Fr,De,Es,It)
      @"SLPS-00622" : @4, // Kyuu Bakukku (Japan)
      @"SLUS-00219" : @4, // Blast Chamber (USA)
      @"SLES-00845" : @4, // Blaze & Blade - Eternal Quest (Europe)
      @"SLES-01274" : @4, // Blaze & Blade - Eternal Quest (Germany)
      @"SLPS-01209" : @4, // Blaze & Blade - Eternal Quest (Japan)
      @"SLPS-01576" : @4, // Blaze & Blade Busters (Japan)
      @"SCES-01443" : @4, // Blood Lines (Europe) (En,Fr,De,Es,It)
      @"SLPS-03002" : @4, // Bomberman Land (Japan) (v1.0) / (v1.1) / (v1.2)
      @"SLES-00258" : @4, // Break Point (Europe) (En,Fr)
      @"SLES-02854" : @4, // Break Out (Europe) (En,Fr,De,It)
      @"SLUS-01170" : @4, // Break Out (USA)
      @"SLES-00759" : @4, // Brian Lara Cricket (Europe)
      @"SLES-01486" : @4, // Caesars Palace II (Europe)
      @"SLES-02476" : @4, // Caesars Palace 2000 - Millennium Gold Edition (Europe)
      @"SLUS-01089" : @4, // Caesars Palace 2000 - Millennium Gold Edition (USA)
      @"SLES-03206" : @4, // Card Shark (Europe)
      @"SLPS-02225" : @4, // Trump Shiyouyo! (Japan) (v1.0)
      @"SLPS-02612" : @4, // Trump Shiyouyo! (Japan) (v1.1)
      @"SLES-02825" : @4, // Catan - Die erste Insel (Germany)
      @"SLUS-00886" : @4, // Chessmaster II (USA)
      @"SLES-00753" : @4, // Circuit Breakers (Europe) (En,Fr,De,Es,It)
      @"SLUS-00697" : @4, // Circuit Breakers (USA)
      @"SLUS-00196" : @4, // College Slam (USA)
      @"SCES-02834" : @4, // Crash Bash (Europe) (En,Fr,De,Es,It)
      @"SCPS-10140" : @4, // Crash Bandicoot Carnival (Japan)
      @"SCUS-94570" : @4, // Crash Bash (USA)
      @"SCES-02105" : @4, // CTR - Crash Team Racing (Europe) (En,Fr,De,Es,It,Nl) (EDC) / (No EDC)
      @"SCPS-10118" : @4, // Crash Bandicoot Racing (Japan)
      @"SCUS-94426" : @4, // CTR - Crash Team Racing (USA)
      @"SLES-02371" : @4, // CyberTiger (Australia)
      @"SLES-02370" : @4, // CyberTiger (Europe) (En,Fr,De,Es,Sv)
      @"SLUS-01004" : @4, // CyberTiger (USA)
      @"SLES-03488" : @4, // David Beckham Soccer (Europe)
      @"SLES-03682" : @4, // David Beckham Soccer (Europe) (Fr,De,Es,It)
      @"SLUS-01455" : @4, // David Beckham Soccer (USA)
      @"SLES-00096" : @4, // Davis Cup Complete Tennis (Europe)
      @"SCES-03705" : @4, // Disney's Party Time with Winnie the Pooh (Europe)
      @"SCES-03744" : @4, // Disney's Winnie l'Ourson - C'est la récré! (France)
      @"SCES-03745" : @4, // Disney's Party mit Winnie Puuh (Germany)
      @"SCES-03749" : @4, // Disney Pooh e Tigro! E Qui la Festa (Italy)
      @"SLPS-03460" : @4, // Pooh-San no Minna de Mori no Daikyosou! (Japan)
      @"SCES-03746" : @4, // Disney's Spelen met Winnie de Poeh en zijn Vriendjes! (Netherlands)
      @"SCES-03748" : @4, // Disney Ven a la Fiesta! con Winnie the Pooh (Spain)
      @"SLUS-01437" : @4, // Disney's Pooh's Party Game - In Search of the Treasure (USA)
      @"SLPS-00155" : @4, // DX Jinsei Game (Japan)
      @"SLPS-00918" : @4, // DX Jinsei Game II (Japan) (v1.0) / (v1.1)
      @"SLPS-02469" : @4, // DX Jinsei Game III (Japan)
      @"SLPM-86963" : @4, // DX Jinsei Game IV (Japan)
      @"SLPM-87187" : @4, // DX Jinsei Game V (Japan)
      @"SLES-02823" : @4, // ECW Anarchy Rulz (Europe)
      @"SLES-03069" : @4, // ECW Anarchy Rulz (Germany)
      @"SLUS-01169" : @4, // ECW Anarchy Rulz (USA)
      @"SLES-02535" : @4, // ECW Hardcore Revolution (Europe) (v1.0) / (v1.1)
      @"SLES-02536" : @4, // ECW Hardcore Revolution (Germany) (v1.0) / (v1.1)
      @"SLUS-01045" : @4, // ECW Hardcore Revolution (USA)
      @"SLUS-01186" : @4, // ESPN MLS Gamenight (USA)
      @"SLES-03082" : @4, // European Super League (Europe) (En,Fr,De,Es,It,Pt)
      @"SLES-02142" : @4, // F.A. Premier League Stars, The (Europe)
      @"SLES-02143" : @4, // Bundesliga Stars 2000 (Germany)
      @"SLES-02702" : @4, // Primera Division Stars (Spain)
      @"SLES-03063" : @4, // F.A. Premier League Stars 2001, The (Europe)
      @"SLES-03064" : @4, // LNF Stars 2001 (France)
      @"SLES-03065" : @4, // Bundesliga Stars 2001 (Germany)
      @"SLES-00548" : @4, // Fantastic Four (Europe) (En,Fr,De,Es,It)
      @"SLPS-01034" : @4, // Fantastic Four (Japan)
      @"SLUS-00395" : @4, // Fantastic Four (USA)
      @"SLPS-02065" : @4, // Fire Pro Wrestling G (Japan) (v1.0)
      @"SLPS-02817" : @4, // Fire Pro Wrestling G (Japan) (v1.1)
      @"SLES-00704" : @4, // Frogger (Europe) (En,Fr,De,Es,It)
      @"SLPS-01399" : @4, // Frogger (Japan)
      @"SLUS-00506" : @4, // Frogger (USA)
      @"SLES-02853" : @4, // Frogger 2 - Swampy's Revenge (Europe) (En,Fr,De,It)
      @"SLUS-01172" : @4, // Frogger 2 - Swampy's Revenge (USA)
      @"SLES-01241" : @4, // Gekido - Urban Fighters (Europe) (En,Fr,De,Es,It)
      @"SLUS-00970" : @4, // Gekido - Urban Fighters (USA)
      @"SLPM-86761" : @4, // Simple 1500 Series Vol. 60 - The Table Hockey (Japan)
      @"SLPS-03362" : @4, // Simple Character 2000 Series Vol. 05 - High School Kimengumi - The Table Hockey (Japan)
      @"SLES-01041" : @4, // Hogs of War (Europe)
      @"SLUS-01195" : @4, // Hogs of War (USA)
      @"SCES-00983" : @4, // Everybody's Golf (Europe) (En,Fr,De,Es,It)
      @"SCPS-10042" : @4, // Minna no Golf (Japan)
      @"SCUS-94188" : @4, // Hot Shots Golf (USA)
      @"SCES-02146" : @4, // Everybody's Golf 2 (Europe)
      @"SCPS-10093" : @4, // Minna no Golf 2 (Japan) (v1.0)
      @"SCUS-94476" : @4, // Hot Shots Golf 2 (USA)
      @"SLES-03595" : @4, // Hot Wheels - Extreme Racing (Europe)
      @"SLUS-01293" : @4, // Hot Wheels - Extreme Racing (USA)
      @"SLPM-86651" : @4, // Hunter X Hunter - Maboroshi no Greed Island (Japan)
      @"SLES-00309" : @4, // Hyper Tennis - Final Match (Europe)
      @"SLES-00309" : @4, // Hyper Final Match Tennis (Japan)
      @"SLES-02550" : @4, // International Superstar Soccer (Europe) (En,De)
      @"SLES-03149" : @4, // International Superstar Soccer (Europe) (Fr,Es,It)
      @"SLPM-86317" : @4, // Jikkyou J. League 1999 - Perfect Striker (Japan)
      @"SLES-00511" : @4, // International Superstar Soccer Deluxe (Europe)
      @"SLPM-86538" : @4, // J. League Jikkyou Winning Eleven 2000 (Japan)
      @"SLPM-86668" : @4, // J. League Jikkyou Winning Eleven 2000 2nd (Japan)
      @"SLPM-86835" : @4, // J. League Jikkyou Winning Eleven 2001 (Japan)
      @"SLES-00333" : @4, // International Track & Field (Europe)
      @"SLPM-86002" : @4, // Hyper Olympic in Atlanta (Japan)
      @"SLUS-00238" : @4, // International Track & Field (USA)
      @"SLES-02448" : @4, // International Track & Field 2 (Europe)
      @"SLPM-86482" : @4, // Ganbare! Nippon! Olympic 2000 (Japan)
      @"SLUS-00987" : @4, // International Track & Field 2000 (USA)
      @"SLES-02424" : @4, // ISS Pro Evolution (Europe) (Es,It)
      @"SLES-02095" : @4, // ISS Pro Evolution (Europe) (En,Fr,De) (EDC) / (No EDC)
      @"SLPM-86291" : @4, // World Soccer Jikkyou Winning Eleven 4 (Japan) (v1.0) / (v1.1)
      @"SLUS-01014" : @4, // ISS Pro Evolution (USA)
      @"SLES-03321" : @4, // ISS Pro Evolution 2 (Europe) (En,Fr,De)
      @"SLPM-86600" : @4, // World Soccer Jikkyou Winning Eleven 2000 - U-23 Medal e no Chousen (Japan)
      @"SLPS-00832" : @4, // Iwatobi Penguin Rocky x Hopper (Japan)
      @"SLPS-01283" : @4, // Iwatobi Penguin Rocky x Hopper 2 - Tantei Monogatari (Japan)
      @"SLES-02572" : @4, // TOCA World Touring Cars (Europe) (En,Fr,De)
      @"SLES-02573" : @4, // TOCA World Touring Cars (Europe) (Es,It)
      @"SLPS-02852" : @4, // WTC World Touring Car Championship (Japan)
      @"SLUS-01139" : @4, // Jarrett & Labonte Stock Car Racing (USA)
      @"SLES-03328" : @4, // Jetracer (Europe) (En,Fr,De)
      @"SLES-00377" : @4, // Jonah Lomu Rugby (Europe) (En,De,Es,It)
      @"SLES-00611" : @4, // Jonah Lomu Rugby (France)
      @"SLPS-01268" : @4, // Great Rugby Jikkyou '98 - World Cup e no Michi (Japan)
      @"SLES-01061" : @4, // Kick Off World (Europe) (En,Fr)
      @"SLES-01327" : @4, // Kick Off World (Europe) (Es,Nl)
      @"SLES-01062" : @4, // Kick Off World (Germany)
      @"SLES-01328" : @4, // Kick Off World (Greece)
      @"SLES-01063" : @4, // Kick Off World Manager (Italy)
      @"SCES-03922" : @4, // Klonoa - Beach Volleyball (Europe) (En,Fr,De,Es,It)
      @"SLPS-03433" : @4, // Klonoa Beach Volley - Saikyou Team Ketteisen! (Japan)
      @"SLUS-01125" : @4, // Kurt Warner's Arena Football Unleashed (USA)
      @"SLPS-00686" : @4, // Love Game's - Wai Wai Tennis (Japan)
      @"SLES-02272" : @4, // Yeh Yeh Tennis (Europe) (En,Fr,De)
      @"SLPS-02983" : @4, // Love Game's - Wai Wai Tennis 2 (Japan)
      @"SLPM-86899" : @4, // Love Game's -  Wai Wai Tennis Plus (Japan)
      @"SLES-01594" : @4, // Michael Owen's World League Soccer 99 (Europe) (En,Fr,It)
      @"SLES-02499" : @4, // Midnight in Vegas (Europe) (En,Fr,De) (v1.0) / (v1.1)
      @"SLUS-00836" : @4, // Vegas Games 2000 (USA)
      @"SLES-03246" : @4, // Monster Racer (Europe) (En,Fr,De,Es,It,Pt)
      @"SLES-03813" : @4, // Monte Carlo Games Compendium (Europe) (Disc 1)
      @"SLES-13813" : @4, // Monte Carlo Games Compendium (Europe) (Disc 2)
      @"SLES-00945" : @4, // Monopoly (Europe) (En,Fr,De,Es,Nl) (v1.0) / (v1.1)
      @"SLPS-00741" : @4, // Monopoly (Japan)
      @"SLES-00310" : @4, // Motor Mash (Europe) (En,Fr,De)
      @"SCES-03085" : @4, // Ms. Pac-Man Maze Madness (Europe) (En,Fr,De,Es,It)
      @"SLPS-03000" : @4, // Ms. Pac-Man Maze Madness (Japan)
      @"SLUS-01018" : @4, // Ms. Pac-Man Maze Madness (USA) (v1.0) / (v1.1)
      @"SLES-02224" : @4, // Music 2000 (Europe) (En,Fr,De,Es,It)
      @"SLUS-01006" : @4, // MTV Music Generator (USA)
      @"SLES-00999" : @4, // Nagano Winter Olympics '98 (Europe)
      @"SLPM-86056" : @4, // Hyper Olympic in Nagano (Japan)
      @"SLUS-00591" : @4, // Nagano Winter Olympics '98 (USA)
      @"SLUS-00329" : @4, // NBA Hangtime (USA)
      @"SLES-00529" : @4, // NBA Jam Extreme (Europe)
      @"SLPS-00699" : @4, // NBA Jam Extreme (Japan)
      @"SLUS-00388" : @4, // NBA Jam Extreme (USA)
      @"SLES-00068" : @4, // NBA Jam - Tournament Edition (Europe)
      @"SLPS-00199" : @4, // NBA Jam - Tournament Edition (Japan)
      @"SLUS-00002" : @4, // NBA Jam - Tournament Edition (USA)
      @"SLES-02336" : @4, // NBA Showtime - NBA on NBC (Europe)
      @"SLUS-00948" : @4, // NBA Showtime - NBA on NBC (USA)
      @"SLES-02689" : @4, // Need for Speed - Porsche 2000 (Europe) (En,De,Sv)
      @"SLES-02700" : @4, // Need for Speed - Porsche 2000 (Europe) (Fr,Es,It)
      @"SLUS-01104" : @4, // Need for Speed - Porsche Unleashed (USA)
      @"SLES-01907" : @4, // V-Rally - Championship Edition 2 (Europe) (En,Fr,De)
      @"SLPS-02516" : @4, // V-Rally - Championship Edition 2 (Japan)
      @"SLUS-01003" : @4, // Need for Speed - V-Rally 2 (USA)
      @"SLES-02335" : @4, // NFL Blitz 2000 (Europe)
      @"SLUS-00861" : @4, // NFL Blitz 2000 (USA)
      @"SLUS-01146" : @4, // NFL Blitz 2001 (USA)
      @"SLUS-00327" : @4, // NHL Open Ice - 2 on 2 Challenge (USA)
      @"SLES-00113" : @4, // Olympic Soccer (Europe) (En,Fr,De,Es,It)
      @"SLPS-00523" : @4, // Olympic Soccer (Japan)
      @"SLUS-00156" : @4, // Olympic Soccer (USA)
      @"SLPS-03056" : @4, // Oshigoto-shiki Jinsei Game - Mezase Shokugyou King (Japan)
      @"SLPS-00899" : @4, // Panzer Bandit (Japan)
      @"SLPM-86016" : @4, // Paro Wars (Japan)
      @"SLUS-01130" : @4, // Peter Jacobsen's Golden Tee Golf (USA)
      @"SLES-00201" : @4, // Pitball (Europe) (En,Fr,De,Es,It)
      @"SLPS-00607" : @4, // Pitball (Japan)
      @"SLUS-00146" : @4, // Pitball (USA)
      @"SLUS-01033" : @4, // Polaris SnoCross (USA)
      @"SLES-02020" : @4, // Pong (Europe) (En,Fr,De,Es,It,Nl)
      @"SLUS-00889" : @4, // Pong - The Next Level (USA)
      @"SLES-02808" : @4, // Beach Volleyball (Europe) (En,Fr,De,Es,It)
      @"SLUS-01196" : @4, // Power Spike - Pro Beach Volleyball (USA)
      @"SLES-00785" : @4, // Poy Poy (Europe)
      @"SLPM-86034" : @4, // Poitters' Point (Japan)
      @"SLUS-00486" : @4, // Poy Poy (USA)
      @"SLES-01536" : @4, // Poy Poy 2 (Europe)
      @"SLPM-86061" : @4, // Poitters' Point 2 - Sodom no Inbou
      @"SLES-01544" : @4, // Premier Manager Ninety Nine (Europe)
      @"SLES-01864" : @4, // Premier Manager Novanta Nove (Italy)
      @"SLES-02292" : @4, // Premier Manager 2000 (Europe)
      @"SLES-02293" : @4, // Canal+ Premier Manager (Europe) (Fr,Es,It)
      @"SLES-02563" : @4, // Anstoss - Premier Manager (Germany)
      @"SLES-00738" : @4, // Premier Manager 98 (Europe)
      @"SLES-01284" : @4, // Premier Manager 98 (Italy)
      @"SLES-03795" : @4, // Pro Evolution Soccer (Europe) (En,Fr,De)
      @"SLES-03796" : @4, // Pro Evolution Soccer (Europe) (Es,It)
      @"SLES-03946" : @4, // Pro Evolution Soccer 2 (Europe) (En,Fr,De)
      @"SLES-03957" : @4, // Pro Evolution Soccer 2 (Europe) (Es,It)
      @"SLPM-87056" : @4, // World Soccer Winning Eleven 2002 (Japan)
      @"SLPM-86868" : @4, // Simple 1500 Series Vol. 69 - The Putter Golf (Japan)
      @"SLUS-01371" : @4, // Putter Golf (USA)
      @"SLPS-03114" : @4, // Puyo Puyo Box (Japan)
      @"SLUS-00757" : @4, // Quake II (USA)
      @"SLPS-02909" : @4, // Simple 1500 Series Vol. 34 - The Quiz Bangumi (Japan)
      @"SLPS-03384" : @4, // Nice Price Series Vol. 06 - Quiz de Battle (Japan)
      @"SLES-03511" : @4, // Rageball (Europe)
      @"SLUS-01461" : @4, // Rageball (USA)
      @"SLPM-86272" : @4, // Rakugaki Showtime
      @"SCES-00408" : @4, // Rally Cross (Europe)
      @"SIPS-60022" : @4, // Rally Cross (Japan)
      @"SCUS-94308" : @4, // Rally Cross (USA)
      @"SLES-01103" : @4, // Rat Attack (Europe) (En,Fr,De,Es,It,Nl)
      @"SLUS-00656" : @4, // Rat Attack! (USA)
      @"SLES-00707" : @4, // Risk (Europe) (En,Fr,De,Es)
      @"SLUS-00616" : @4, // Risk - The Game of Global Domination (USA)
      @"SLES-02552" : @4, // Road Rash - Jailbreak (Europe) (En,Fr,De)
      @"SLUS-01053" : @4, // Road Rash - Jailbreak (USA)
      @"SCES-01630" : @4, // Running Wild (Europe)
      @"SCUS-94272" : @4, // Running Wild (USA)
      @"SLES-00217" : @4, // Sampras Extreme Tennis (Europe) (En,Fr,De,Es,It)
      @"SLPS-00594" : @4, // Sampras Extreme Tennis (Japan)
      @"SLES-01286" : @4, // S.C.A.R.S. (Europe) (En,Fr,De,Es,It)
      @"SLUS-00692" : @4, // S.C.A.R.S. (USA)
      @"SLES-03642" : @4, // Scrabble (Europe) (En,De,Es)
      @"SLUS-00903" : @4, // Scrabble (USA)
      @"SLPS-02912" : @4, // SD Gundam - G Generation-F (Japan) (Disc 1)
      @"SLPS-02913" : @4, // SD Gundam - G Generation-F (Japan) (Disc 2)
      @"SLPS-02914" : @4, // SD Gundam - G Generation-F (Japan) (Disc 3)
      @"SLPS-02915" : @4, // SD Gundam - G Generation-F (Japan) (Premium Disc)
      @"SLPS-03195" : @4, // SD Gundam - G Generation-F.I.F (Japan)
      @"SLPS-00785" : @4, // SD Gundam - GCentury (Japan) (v1.0) / (v1.1)
      @"SLPS-01560" : @4, // SD Gundam - GGeneration (Japan) (v1.0) / (v1.1)
      @"SLPS-01561" : @4, // SD Gundam - GGeneration (Premium Disc) (Japan)
      @"SLPS-02200" : @4, // SD Gundam - GGeneration-0 (Japan) (Disc 1) (v1.0)
      @"SLPS-02201" : @4, // SD Gundam - GGeneration-0 (Japan) (Disc 2) (v1.0)
      @"SLES-03776" : @4, // Sky Sports Football Quiz (Europe)
      @"SLES-03856" : @4, // Sky Sports Football Quiz - Season 02 (Europe)
      @"SLES-00076" : @4, // Slam 'n Jam '96 featuring Magic & Kareem (Europe)
      @"SLPS-00426" : @4, // Magic Johnson to Kareem Abdul-Jabbar no Slam 'n Jam '96 (Japan)
      @"SLUS-00022" : @4, // Slam 'n Jam '96 featuring Magic & Kareem (USA)
      @"SLES-02194" : @4, // Sled Storm (Europe) (En,Fr,De,Es)
      @"SLUS-00955" : @4, // Sled Storm (USA)
      @"SLES-01972" : @4, // South Park - Chef's Luv Shack (Europe)
      @"SLUS-00997" : @4, // South Park - Chef's Luv Shack (USA)
      @"SCES-01763" : @4, // Speed Freaks (Europe)
      @"SCUS-94563" : @4, // Speed Punks (USA)
      @"SLES-00023" : @4, // Striker 96 (Europe) (v1.0)
      @"SLPS-00127" : @4, // Striker - World Cup Premiere Stage (Japan)
      @"SLUS-00210" : @4, // Striker 96 (USA)
      @"SLES-01733" : @4, // UEFA Striker (Europe) (En,Fr,De,Es,It,Nl)
      @"SLUS-01078" : @4, // Striker Pro 2000 (USA)
      @"SLPS-01264" : @4, // Suchie-Pai Adventure - Doki Doki Nightmare (Japan) (Disc 1)
      @"SLPS-01265" : @4, // Suchie-Pai Adventure - Doki Doki Nightmare (Japan) (Disc 2)
      @"SLES-00213" : @4, // Syndicate Wars (Europe) (En,Fr,Es,It,Sv)
      @"SLES-00212" : @4, // Syndicate Wars (Germany)
      @"SLUS-00262" : @4, // Syndicate Wars (USA)
      @"SLPS-03050" : @4, // Tales of Eternia (Japan) (Disc 1)
      @"SLPS-03051" : @4, // Tales of Eternia (Japan) (Disc 2)
      @"SLPS-03052" : @4, // Tales of Eternia (Japan) (Disc 3)
      @"SLUS-01355" : @4, // Tales of Destiny II (USA) (Disc 1)
      @"SLUS-01367" : @4, // Tales of Destiny II (USA) (Disc 2)
      @"SLUS-01368" : @4, // Tales of Destiny II (USA) (Disc 3)
      @"SCES-01923" : @4, // Team Buddies (Europe) (En,Fr,De)
      @"SLUS-00869" : @4, // Team Buddies (USA)
      @"SLPS-00321" : @4, // Tetris X (Japan)
      @"SLES-01675" : @4, // Tiger Woods 99 USA Tour Golf (Australia)
      @"SLES-01674" : @4, // Tiger Woods 99 PGA Tour Golf (Europe) (En,Fr,De,Es,Sv)
      @"SLPS-02012" : @4, // Tiger Woods 99 PGA Tour Golf (Japan)
      @"SLUS-00785" : @4, // Tiger Woods 99 PGA Tour Golf (USA) (v1.0) / (v1.1)
      @"SLES-03148" : @4, // Tiger Woods PGA Tour Golf (Europe)
      @"SLUS-01273" : @4, // Tiger Woods PGA Tour Golf (USA)
      @"SLES-02595" : @4, // Tiger Woods USA Tour 2000 (Australia)
      @"SLES-02551" : @4, // Tiger Woods PGA Tour 2000 (Europe) (En,Fr,De,Es,Sv)
      @"SLUS-01054" : @4, // Tiger Woods PGA Tour 2000 (USA)
      @"SLPS-01113" : @4, // Toshinden Card Quest (Japan)
      @"SLES-00256" : @4, // Trash It (Europe) (En,Fr,De,Es,It)
      @"SCUS-94249" : @4, // Twisted Metal III (USA) (v1.0) / (v1.1)
      @"SCUS-94560" : @4, // Twisted Metal 4 (USA)
      @"SLES-02806" : @4, // UEFA Challenge (Europe) (En,Fr,De,Nl)
      @"SLES-02807" : @4, // UEFA Challenge (Europe) (Fr,Es,It,Pt)
      @"SLES-01622" : @4, // UEFA Champions League - Season 1998-99 (Europe)
      @"SLES-01745" : @4, // UEFA Champions League - Saison 1998-99 (Germany)
      @"SLES-01746" : @4, // UEFA Champions League - Stagione 1998-99 (Italy)
      @"SLES-02918" : @4, // Vegas Casino (Europe)
      @"SLPS-00467" : @4, // Super Casino Special (Japan)
      @"SLES-00761" : @4, // Viva Football (Europe) (En,Fr,De,Es,It,Pt)
      @"SLES-01341" : @4, // Absolute Football (France) (En,Fr,De,Es,It,Pt)
      @"SLUS-00953" : @4, // Viva Soccer (USA) (En,Fr,De,Es,It,Pt)
      @"SLES-02193" : @4, // WCW Mayhem (Europe)
      @"SLUS-00963" : @4, // WCW Mayhem (USA)
      @"SLES-03806" : @4, // Westlife - Fan-O-Mania (Europe)
      @"SLES-03779" : @4, // Westlife - Fan-O-Mania (Europe) (Fr,De)
      @"SLES-00717" : @4, // World League Soccer '98 (Europe) (En,Es,It)
      @"SLES-01166" : @4, // World League Soccer '98 (France)
      @"SLES-01167" : @4, // World League Soccer '98 (Germany)
      @"SLPS-01389" : @4, // World League Soccer (Japan)
      @"SLES-02170" : @4, // Wu-Tang - Taste the Pain (Europe)
      @"SLES-02171" : @4, // Wu-Tang - Shaolin Style (France)
      @"SLES-02172" : @4, // Wu-Tang - Shaolin Style (Germany)
      @"SLUS-00929" : @4, // Wu-Tang - Shaolin Style (USA)
      @"SLES-01980" : @4, // WWF Attitude (Europe)
      @"SLES-02255" : @4, // WWF Attitude (Germany)
      @"SLUS-00831" : @4, // WWF Attitude (USA)
      @"SLES-00286" : @4, // WWF In Your House (Europe)
      @"SLPS-00695" : @4, // WWF In Your House (Japan)
      @"SLUS-00246" : @4, // WWF In Your House (USA) (v1.0) / (v1.1)
      @"SLES-02619" : @4, // WWF SmackDown! (Europe)
      @"SLPS-02885" : @4, // Exciting Pro Wres (Japan)
      @"SLUS-00927" : @4, // WWF SmackDown! (USA)
      @"SLES-03251" : @4, // WWF SmackDown! 2 - Know Your Role (Europe)
      @"SLPS-03122" : @4, // Exciting Pro Wres 2 (Japan)
      @"SLUS-01234" : @4, // WWF SmackDown! 2 - Know Your Role (USA)
      @"SLES-00804" : @4, // WWF War Zone (Europe)
      @"SLUS-00495" : @4, // WWF War Zone (USA) (v1.0) / (v1.1)
      @"SLES-01893" : @5, // Bomberman (Europe)
      @"SLPS-01717" : @5, // Bomberman (Japan)
      @"SLUS-01189" : @5, // Bomberman - Party Edition (USA)
      @"SCES-01078" : @5, // Bomberman World (Europe) (En,Fr,De,Es,It)
      @"SLPS-01155" : @5, // Bomberman World (Japan)
      @"SLUS-00680" : @5, // Bomberman World (USA)
      @"SCES-01312" : @5, // Devil Dice (Europe) (En,Fr,De,Es,It)
      @"SCPS-10051" : @5, // XI [sai] (Japan) (En,Ja)
      @"SLUS-00672" : @5, // Devil Dice (USA)
      @"SLPS-02943" : @5, // DX Monopoly (Japan)
      @"SLES-00865" : @5, // Overboard! (Europe)
      @"SLUS-00558" : @5, // Shipwreckers! (USA)
      @"SLES-01376" : @6, // Brunswick Circuit Pro Bowling (Europe)
      @"SLUS-00571" : @6, // Brunswick Circuit Pro Bowling (USA)
      @"SLUS-00769" : @6, // Game of Life, The (USA)
      @"SLES-03362" : @6, // NBA Hoopz (Europe) (En,Fr,De)
      @"SLUS-01331" : @6, // NBA Hoopz (USA)
      @"SLES-00284" : @6, // Space Jam (Europe)
      @"SLPS-00697" : @6, // Space Jam (Japan)
      @"SLUS-00243" : @6, // Space Jam (USA)
      @"SLES-00534" : @6, // Ten Pin Alley (Europe)
      @"SLUS-00377" : @6, // Ten Pin Alley (USA)
      @"SLPS-01243" : @6, // Tenant Wars (Japan)
      @"SLPM-86240" : @6, // SuperLite 1500 Series - Tenant Wars Alpha - SuperLite 1500 Version (Japan)
      @"SLUS-01333" : @6, // Board Game - Top Shop (USA)
      @"SLES-03830" : @8, // 2002 FIFA World Cup Korea Japan (Europe) (En,Sv)
      @"SLES-03831" : @8, // Coupe du Monde FIFA 2002 (France)
      @"SLES-03832" : @8, // 2002 FIFA World Cup Korea Japan (Germany)
      @"SLES-03833" : @8, // 2002 FIFA World Cup Korea Japan (Italy)
      @"SLES-03834" : @8, // 2002 FIFA World Cup Korea Japan (Spain)
      @"SLUS-01449" : @8, // 2002 FIFA World Cup (USA) (En,Es)
      @"SLES-01210" : @8, // Actua Soccer 3 (Europe)
      @"SLES-01644" : @8, // Actua Soccer 3 (France)
      @"SLES-01645" : @8, // Actua Soccer 3 (Germany)
      @"SLES-01646" : @8, // Actua Soccer 3 (Italy)
      @"SLPM-86044" : @8, // Break Point (Japan)
      @"SCUS-94156" : @8, // Cardinal Syn (USA)
      @"SLES-02948" : @8, // Chris Kamara's Street Soccer (Europe)
      @"SLES-00080" : @8, // Supersonic Racers (Europe) (En,Fr,De,Es,It)
      @"SLPS-01025" : @8, // Dare Devil Derby 3D (Japan)
      @"SLUS-00300" : @8, // Dare Devil Derby 3D (USA)
      @"SLES-00116" : @8, // FIFA Soccer 96 (Europe) (En,Fr,De,Es,It,Sv)
      @"SLUS-00038" : @8, // FIFA Soccer 96 (USA)
      @"SLES-00504" : @8, // FIFA 97 (Europe) (En,Fr,De,Es,It,Sv)
      @"SLES-00505" : @8, // FIFA 97 (France) (En,Fr,De,Es,It,Sv)
      @"SLES-00506" : @8, // FIFA 97 (Germany) (En,Fr,De,Es,It,Sv)
      @"SLPS-00878" : @8, // FIFA Soccer 97 (Japan)
      @"SLUS-00269" : @8, // FIFA Soccer 97 (USA)
      @"SLES-00914" : @8, // FIFA - Road to World Cup 98 (Europe) (En,Fr,De,Es,Nl,Sv)
      @"SLES-00915" : @8, // FIFA - En Route pour la Coupe du Monde 98 (France) (En,Fr,De,Es,Nl,Sv)
      @"SLES-00916" : @8, // FIFA - Die WM-Qualifikation 98 (Germany) (En,Fr,De,Es,Nl,Sv)
      @"SLES-00917" : @8, // FIFA - Road to World Cup 98 (Italy)
      @"SLPS-01383" : @8, // FIFA - Road to World Cup 98 (Japan)
      @"SLES-00918" : @8, // FIFA - Rumbo al Mundial 98 (Spain) (En,Fr,De,Es,Nl,Sv)
      @"SLUS-00520" : @8, // FIFA - Road to World Cup 98 (USA) (En,Fr,De,Es,Nl,Sv)
      @"SLES-01584" : @8, // FIFA 99 (Europe) (En,Fr,De,Es,Nl,Sv)
      @"SLES-01585" : @8, // FIFA 99 (France) (En,Fr,De,Es,Nl,Sv)
      @"SLES-01586" : @8, // FIFA 99 (Germany) (En,Fr,De,Es,Nl,Sv)
      @"SLES-01587" : @8, // FIFA 99 (Italy)
      @"SLPS-02309" : @8, // FIFA 99 - Europe League Soccer (Japan)
      @"SLES-01588" : @8, // FIFA 99 (Spain) (En,Fr,De,Es,Nl,Sv)
      @"SLUS-00782" : @8, // FIFA 99 (USA)
      @"SLES-02315" : @8, // FIFA 2000 (Europe) (En,De,Es,Nl,Sv) (v1.0) / (v1.1)
      @"SLES-02316" : @8, // FIFA 2000 (France)
      @"SLES-02317" : @8, // FIFA 2000 (Germany) (En,De,Es,Nl,Sv)
      @"SLES-02320" : @8, // FIFA 2000 (Greece)
      @"SLES-02319" : @8, // FIFA 2000 (Italy)
      @"SLPS-02675" : @8, // FIFA 2000 - Europe League Soccer (Japan)
      @"SLES-02318" : @8, // FIFA 2000 (Spain) (En,De,Es,Nl,Sv)
      @"SLUS-00994" : @8, // FIFA 2000 - Major League Soccer (USA) (En,De,Es,Nl,Sv)
      @"SLES-03140" : @8, // FIFA 2001 (Europe) (En,De,Es,Nl,Sv)
      @"SLES-03141" : @8, // FIFA 2001 (France)
      @"SLES-03142" : @8, // FIFA 2001 (Germany) (En,De,Es,Nl,Sv)
      @"SLES-03143" : @8, // FIFA 2001 (Greece)
      @"SLES-03145" : @8, // FIFA 2001 (Italy)
      @"SLES-03146" : @8, // FIFA 2001 (Spain) (En,De,Es,Nl,Sv)
      @"SLUS-01262" : @8, // FIFA 2001 (USA)
      @"SLES-03666" : @8, // FIFA Football 2002 (Europe) (En,De,Es,Nl,Sv)
      @"SLES-03668" : @8, // FIFA Football 2002 (France)
      @"SLES-03669" : @8, // FIFA Football 2002 (Germany) (En,De,Es,Nl,Sv)
      @"SLES-03671" : @8, // FIFA Football 2002 (Italy)
      @"SLES-03672" : @8, // FIFA Football 2002 (Spain) (En,De,Es,Nl,Sv)
      @"SLUS-01408" : @8, // FIFA Soccer 2002 (USA) (En,Es)
      @"SLES-03977" : @8, // FIFA Football 2003 (Europe) (En,Nl,Sv)
      @"SLES-03978" : @8, // FIFA Football 2003 (France)
      @"SLES-03979" : @8, // FIFA Football 2003 (Germany)
      @"SLES-03980" : @8, // FIFA Football 2003 (Italy)
      @"SLES-03981" : @8, // FIFA Football 2003 (Spain)
      @"SLUS-01504" : @8, // FIFA Soccer 2003 (USA)
      @"SLES-04115" : @8, // FIFA Football 2004 (Europe) (En,Nl,Sv)
      @"SLES-04116" : @8, // FIFA Football 2004 (France)
      @"SLES-04117" : @8, // FIFA Football 2004 (Germany)
      @"SLES-04119" : @8, // FIFA Football 2004 (Italy)
      @"SLES-04118" : @8, // FIFA Football 2004 (Spain)
      @"SLUS-01578" : @8, // FIFA Soccer 2004 (USA) (En,Es)
      @"SLES-04165" : @8, // FIFA Football 2005 (Europe) (En,Nl)
      @"SLES-04166" : @8, // FIFA Football 2005 (France)
      @"SLES-04168" : @8, // FIFA Football 2005 (Germany)
      @"SLES-04167" : @8, // FIFA Football 2005 (Italy)
      @"SLES-04169" : @8, // FIFA Football 2005 (Spain)
      @"SLUS-01585" : @8, // FIFA Soccer 2005 (USA) (En,Es)
      @"SLUS-01129" : @8, // FoxKids.com - Micro Maniacs Racing (USA)
      @"SLES-03084" : @8, // Inspector Gadget - Gadget's Crazy Maze (Europe) (En,Fr,De,Es,It,Nl)
      @"SLUS-01267" : @8, // Inspector Gadget - Gadget's Crazy Maze (USA) (En,Fr,De,Es,It,Nl)
      @"SLUS-00500" : @8, // Jimmy Johnson's VR Football '98 (USA)
      @"SLES-00436" : @8, // Madden NFL 97 (Europe)
      @"SLUS-00018" : @8, // Madden NFL 97 (USA)
      @"SLES-00904" : @8, // Madden NFL 98 (Europe)
      @"SLUS-00516" : @8, // Madden NFL 98 (USA) / (Alt)
      @"SLES-01427" : @8, // Madden NFL 99 (Europe)
      @"SLUS-00729" : @8, // Madden NFL 99 (USA)
      @"SLES-02192" : @8, // Madden NFL 2000 (Europe)
      @"SLUS-00961" : @8, // Madden NFL 2000 (USA)
      @"SLES-03067" : @8, // Madden NFL 2001 (Europe)
      @"SLUS-01241" : @8, // Madden NFL 2001 (USA)
      @"SLUS-01402" : @8, // Madden NFL 2002 (USA)
      @"SLUS-01482" : @8, // Madden NFL 2003 (USA)
      @"SLUS-01570" : @8, // Madden NFL 2004 (USA)
      @"SLUS-01584" : @8, // Madden NFL 2005 (USA)
      @"SLUS-00526" : @8, // March Madness '98 (USA)
      @"SLUS-00559" : @8, // Micro Machines V3 (USA)
      @"SLUS-00507" : @8, // Monopoly (USA)
      @"SLUS-01178" : @8, // Monster Rancher Battle Card - Episode II (USA)
      @"SLES-02299" : @8, // NBA Basketball 2000 (Europe) (En,Fr,De,Es,It)
      @"SLUS-00926" : @8, // NBA Basketball 2000 (USA)
      @"SLES-01003" : @8, // NBA Fastbreak '98 (Europe)
      @"SLUS-00492" : @8, // NBA Fastbreak '98 (USA)
      @"SLES-00171" : @8, // NBA in the Zone (Europe)
      @"SLPS-00188" : @8, // NBA Power Dunkers (Japan)
      @"SLUS-00048" : @8, // NBA in the Zone (USA)
      @"SLES-00560" : @8, // NBA in the Zone 2 (Europe)
      @"SLPM-86011" : @8, // NBA Power Dunkers 2 (Japan)
      @"SLUS-00294" : @8, // NBA in the Zone 2 (USA)
      @"SLES-00882" : @8, // NBA Pro 98 (Europe)
      @"SLPM-86060" : @8, // NBA Power Dunkers 3 (Japan)
      @"SLUS-00445" : @8, // NBA in the Zone '98 (USA) (v1.0) / (v1.1)
      @"SLES-01970" : @8, // NBA Pro 99 (Europe)
      @"SLPM-86176" : @8, // NBA Power Dunkers 4 (Japan)
      @"SLUS-00791" : @8, // NBA in the Zone '99 (USA)
      @"SLES-02513" : @8, // NBA in the Zone 2000 (Europe)
      @"SLPM-86397" : @8, // NBA Power Dunkers 5 (Japan)
      @"SLUS-01028" : @8, // NBA in the Zone 2000 (USA)
      @"SLES-00225" : @8, // NBA Live 96 (Europe)
      @"SLPS-00389" : @8, // NBA Live 96 (Japan)
      @"SLUS-00060" : @8, // NBA Live 96 (USA)
      @"SLES-00517" : @8, // NBA Live 97 (Europe) (En,Fr,De)
      @"SLPS-00736" : @8, // NBA Live 97 (Japan)
      @"SLUS-00267" : @8, // NBA Live 97 (USA)
      @"SLES-00906" : @8, // NBA Live 98 (Europe) (En,Es,It)
      @"SLES-00952" : @8, // NBA Live 98 (Germany)
      @"SLPS-01296" : @8, // NBA Live 98 (Japan)
      @"SLUS-00523" : @8, // NBA Live 98 (USA)
      @"SLES-01446" : @8, // NBA Live 99 (Europe)
      @"SLES-01455" : @8, // NBA Live 99 (Germany)
      @"SLES-01456" : @8, // NBA Live 99 (Italy)
      @"SLPS-02033" : @8, // NBA Live 99 (Japan)
      @"SLES-01457" : @8, // NBA Live 99 (Spain)
      @"SLUS-00736" : @8, // NBA Live 99 (USA)
      @"SLES-02358" : @8, // NBA Live 2000 (Europe)
      @"SLES-02360" : @8, // NBA Live 2000 (Germany)
      @"SLES-02361" : @8, // NBA Live 2000 (Italy)
      @"SLPS-02603" : @8, // NBA Live 2000 (Japan)
      @"SLES-02362" : @8, // NBA Live 2000 (Spain)
      @"SLUS-00998" : @8, // NBA Live 2000 (USA)
      @"SLES-03128" : @8, // NBA Live 2001 (Europe)
      @"SLES-03129" : @8, // NBA Live 2001 (France)
      @"SLES-03130" : @8, // NBA Live 2001 (Germany)
      @"SLES-03131" : @8, // NBA Live 2001 (Italy)
      @"SLES-03132" : @8, // NBA Live 2001 (Spain)
      @"SLUS-01271" : @8, // NBA Live 2001 (USA)
      @"SLES-03718" : @8, // NBA Live 2002 (Europe)
      @"SLES-03719" : @8, // NBA Live 2002 (France)
      @"SLES-03720" : @8, // NBA Live 2002 (Germany)
      @"SLES-03721" : @8, // NBA Live 2002 (Italy)
      @"SLES-03722" : @8, // NBA Live 2002 (Spain)
      @"SLUS-01416" : @8, // NBA Live 2002 (USA)
      @"SLES-03982" : @8, // NBA Live 2003 (Europe)
      @"SLES-03969" : @8, // NBA Live 2003 (France)
      @"SLES-03968" : @8, // NBA Live 2003 (Germany)
      @"SLES-03970" : @8, // NBA Live 2003 (Italy)
      @"SLES-03971" : @8, // NBA Live 2003 (Spain)
      @"SLUS-01483" : @8, // NBA Live 2003 (USA)
      @"SCES-00067" : @8, // Total NBA '96 (Europe)
      @"SIPS-60008" : @8, // Total NBA '96 (Japan)
      @"SCUS-94500" : @8, // NBA Shoot Out (USA)
      @"SCES-00623" : @8, // Total NBA '97 (Europe)
      @"SIPS-60015" : @8, // Total NBA '97 (Japan)
      @"SCUS-94552" : @8, // NBA Shoot Out '97 (USA)
      @"SCES-01079" : @8, // Total NBA 98 (Europe)
      @"SCUS-94171" : @8, // NBA ShootOut 98 (USA)
      @"SCUS-94561" : @8, // NBA ShootOut 2000 (USA)
      @"SCUS-94581" : @8, // NBA ShootOut 2001 (USA)
      @"SCUS-94641" : @8, // NBA ShootOut 2002 (USA)
      @"SCUS-94673" : @8, // NBA ShootOut 2003 (USA)
      @"SCUS-94691" : @8, // NBA ShootOut 2004 (USA)
      @"SLUS-00142" : @8, // NCAA Basketball Final Four 97 (USA)
      @"SCUS-94264" : @8, // NCAA Final Four 99 (USA)
      @"SCUS-94562" : @8, // NCAA Final Four 2000 (USA)
      @"SCUS-94579" : @8, // NCAA Final Four 2001 (USA)
      @"SLUS-00514" : @8, // NCAA Football 98 (USA)
      @"SLUS-00688" : @8, // NCAA Football 99 (USA)
      @"SLUS-00932" : @8, // NCAA Football 2000 (USA) (v1.0) / (v1.1)
      @"SLUS-01219" : @8, // NCAA Football 2001 (USA)
      @"SCUS-94509" : @8, // NCAA Football GameBreaker (USA)
      @"SCUS-94172" : @8, // NCAA GameBreaker 98 (USA)
      @"SCUS-94246" : @8, // NCAA GameBreaker 99 (USA)
      @"SCUS-94557" : @8, // NCAA GameBreaker 2000 (USA)
      @"SCUS-94573" : @8, // NCAA GameBreaker 2001 (USA)
      @"SLUS-00805" : @8, // NCAA March Madness 99 (USA)
      @"SLUS-01023" : @8, // NCAA March Madness 2000 (USA)
      @"SLUS-01320" : @8, // NCAA March Madness 2001 (USA)
      @"SCES-00219" : @8, // NFL GameDay (Europe)
      @"SCUS-94505" : @8, // NFL GameDay (USA)
      @"SCUS-94510" : @8, // NFL GameDay 97 (USA)
      @"SCUS-94173" : @8, // NFL GameDay 98 (USA)
      @"SCUS-94234" : @8, // NFL GameDay 99 (USA) (v1.0) / (v1.1)
      @"SCUS-94556" : @8, // NFL GameDay 2000 (USA)
      @"SCUS-94575" : @8, // NFL GameDay 2001 (USA)
      @"SCUS-94639" : @8, // NFL GameDay 2002 (USA)
      @"SCUS-94665" : @8, // NFL GameDay 2003 (USA)
      @"SCUS-94690" : @8, // NFL GameDay 2004 (USA)
      @"SCUS-94695" : @8, // NFL GameDay 2005 (USA)
      @"SLES-00449" : @8, // NFL Quarterback Club 97 (Europe)
      @"SLUS-00011" : @8, // NFL Quarterback Club 97 (USA)
      @"SCUS-94420" : @8, // NFL Xtreme 2 (USA)
      @"SLES-00492" : @8, // NHL 97 (Europe)
      @"SLES-00533" : @8, // NHL 97 (Germany)
      @"SLPS-00861" : @8, // NHL 97 (Japan)
      @"SLUS-00030" : @8, // NHL 97 (USA)
      @"SLES-00907" : @8, // NHL 98 (Europe) (En,Sv,Fi)
      @"SLES-00512" : @8, // NHL 98 (Germany)
      @"SLUS-00519" : @8, // NHL 98 (USA)
      @"SLES-01445" : @8, // NHL 99 (Europe) (En,Fr,Sv,Fi)
      @"SLES-01458" : @8, // NHL 99 (Germany)
      @"SLUS-00735" : @8, // NHL 99 (USA)
      @"SLES-02225" : @8, // NHL 2000 (Europe) (En,Sv,Fi)
      @"SLES-02227" : @8, // NHL 2000 (Germany)
      @"SLUS-00965" : @8, // NHL 2000 (USA)
      @"SLES-03139" : @8, // NHL 2001 (Europe) (En,Sv,Fi)
      @"SLES-03154" : @8, // NHL 2001 (Germany)
      @"SLUS-01264" : @8, // NHL 2001 (USA)
      @"SLES-02514" : @8, // NHL Blades of Steel 2000 (Europe)
      @"SLPM-86193" : @8, // NHL Blades of Steel 2000 (Japan)
      @"SLUS-00825" : @8, // NHL Blades of Steel 2000 (USA)
      @"SLES-00624" : @8, // NHL Breakaway 98 (Europe)
      @"SLUS-00391" : @8, // NHL Breakaway 98 (USA)
      @"SLES-02298" : @8, // NHL Championship 2000 (Europe) (En,Fr,De,Sv)
      @"SLUS-00925" : @8, // NHL Championship 2000 (USA)
      @"SCES-00392" : @8, // NHL Face Off '97 (Europe)
      @"SIPS-60018" : @8, // NHL PowerRink '97 (Japan)
      @"SCUS-94550" : @8, // NHL Face Off '97 (USA)
      @"SCES-01022" : @8, // NHL FaceOff 98 (Europe)
      @"SCUS-94174" : @8, // NHL FaceOff 98 (USA)
      @"SCES-01736" : @8, // NHL FaceOff 99 (Europe)
      @"SCUS-94235" : @8, // NHL FaceOff 99 (USA)
      @"SCES-02451" : @8, // NHL FaceOff 2000 (Europe)
      @"SCUS-94558" : @8, // NHL FaceOff 2000 (USA)
      @"SCUS-94577" : @8, // NHL FaceOff 2001 (USA)
      @"SLES-00418" : @8, // NHL Powerplay 98 (Europe) (En,Fr,De)
      @"SLUS-00528" : @8, // NHL Powerplay 98 (USA) (En,Fr,De)
      @"SLES-00110" : @8, // Olympic Games (Europe) (En,Fr,De,Es,It)
      @"SLPS-00465" : @8, // Atlanta Olympics '96
      @"SLUS-00148" : @8, // Olympic Summer Games (USA)
      @"SLES-01559" : @8, // Pro 18 - World Tour Golf (Europe) (En,Fr,De,Es,It,Sv)
      @"SLUS-00817" : @8, // Pro 18 - World Tour Golf (USA)
      @"SLES-00472" : @8, // Riot (Europe)
      @"SCUS-94551" : @8, // Professional Underground League of Pain (USA)
      @"SLES-01203" : @8, // Puma Street Soccer (Europe) (En,Fr,De,It)
      @"SLES-01436" : @8, // Rival Schools - United by Fate (Europe) (Disc 1) (Evolution Disc)
      @"SLES-11436" : @8, // Rival Schools - United by Fate (Europe) (Disc 2) (Arcade Disc)
      @"SLPS-01240" : @8, // Shiritsu Justice Gakuen - Legion of Heroes (Japan) (Disc 1) (Evolution Disc)
      @"SLPS-01241" : @8, // Shiritsu Justice Gakuen - Legion of Heroes (Japan) (Disc 2) (Arcade Disc)
      @"SLPS-02120" : @8, // Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan)
      @"SLES-01658" : @8, // Shaolin (Europe)
      @"SLPS-02168" : @8, // Lord of Fist (Japan)
      @"SLES-00296" : @8, // Street Racer (Europe)
      @"SLPS-00610" : @8, // Street Racer Extra (Japan)
      @"SLUS-00099" : @8, // Street Racer (USA)
      @"SLES-02857" : @8, // Sydney 2000 (Europe)
      @"SLES-02858" : @8, // Sydney 2000 (France)
      @"SLES-02859" : @8, // Sydney 2000 (Germany)
      @"SLPM-86626" : @8, // Sydney 2000 (Japan)
      @"SLES-02861" : @8, // Sydney 2000 (Spain)
      @"SLUS-01177" : @8, // Sydney 2000 (USA)
      @"SCES-01700" : @8, // This Is Football (Europe)
      @"SCES-01882" : @8, // This Is Football (Europe) (Fr,Nl)
      @"SCES-01701" : @8, // Monde des Bleus, Le - Le jeu officiel de l'equipe de France (France)
      @"SCES-01702" : @8, // Fussball Live (Germany)
      @"SCES-01703" : @8, // This Is Football (Italy)
      @"SCES-01704" : @8, // Esto es Futbol (Spain)
      @"SCES-03070" : @8, // This Is Football 2 (Europe)
      @"SCES-03073" : @8, // Monde des Bleus 2, Le (France)
      @"SCES-03074" : @8, // Fussball Live 2 (Germany)
      @"SCES-03075" : @8, // This Is Football 2 (Italy)
      @"SCES-03072" : @8, // This Is Football 2 (Netherlands)
      @"SCES-03076" : @8, // Esto es Futbol 2 (Spain)
      @"SLPS-00682" : @8, // Triple Play 97 (Japan)
      @"SLUS-00237" : @8, // Triple Play 97 (USA)
      @"SLPS-00887" : @8, // Triple Play 98 (Japan)
      @"SLUS-00465" : @8, // Triple Play 98 (USA)
      @"SLUS-00618" : @8, // Triple Play 99 (USA) (En,Es)
      @"SLES-02577" : @8, // UEFA Champions League - Season 1999-2000 (Europe)
      @"SLES-02578" : @8, // UEFA Champions League - Season 1999-2000 (France)
      @"SLES-02579" : @8, // UEFA Champions League - Season 1999-2000 (Germany)
      @"SLES-02580" : @8, // UEFA Champions League - Season 1999-2000 (Italy)
      @"SLES-03262" : @8, // UEFA Champions League - Season 2000-2001 (Europe)
      @"SLES-03281" : @8, // UEFA Champions League - Season 2000-2001 (Germany)
      @"SLES-02704" : @8, // UEFA Euro 2000 (Europe)
      @"SLES-02705" : @8, // UEFA Euro 2000 (France)
      @"SLES-02706" : @8, // UEFA Euro 2000 (Germany)
      @"SLES-02707" : @8, // UEFA Euro 2000 (Italy)
      @"SLES-01265" : @8, // World Cup 98 (Europe) (En,Fr,De,Es,Nl,Sv,Da)
      @"SLES-01266" : @8, // Coupe du Monde 98 (France)
      @"SLES-01267" : @8, // Frankreich 98 - Die Fussball-WM (Germany) (En,Fr,De,Es,Nl,Sv,Da)
      @"SLES-01268" : @8, // World Cup 98 - Coppa del Mondo (Italy)
      @"SLPS-01719" : @8, // FIFA World Cup 98 - France 98 Soushuuhen (Japan)
      @"SLUS-00644" : @8, // World Cup 98 (USA)
      };

    // 5-player games requiring Multitap on port 2 instead of port 1
    NSArray *multiTap5PlayerPort2 =
    @[
      @"SLES-01893", // Bomberman (Europe)
      @"SLPS-01717", // Bomberman (Japan)
      @"SLUS-01189", // Bomberman - Party Edition (USA)
      ];

#pragma message "forget about multitap for now :)"
    // Set multitap configuration if detected
//    if (multiTapGames[[current ROMSerial]])
//    {
//        current->multiTapPlayerCount = [[multiTapGames objectForKey:[current ROMSerial]] intValue];
//
//        if([multiTap5PlayerPort2 containsObject:[current ROMSerial]])
//            MDFNI_SetSetting("psx.input.pport2.multitap", "1"); // Enable multitap on PSX port 2
//        else
//        {
//            MDFNI_SetSetting("psx.input.pport1.multitap", "1"); // Enable multitap on PSX port 1
//            if(current->multiTapPlayerCount > 5)
//                MDFNI_SetSetting("psx.input.pport2.multitap", "1"); // Enable multitap on PSX port 2
//        }
//    }
}

- (id)init {
    if((self = [super init]))
    {
        _current = self;

        multiTapPlayerCount = 2;

        for(unsigned i = 0; i < 8; i++) {
            inputBuffer[i] = (uint32_t *) calloc(9, sizeof(uint32_t));
        }
    }

    return self;
}

- (void)dealloc {
    for(unsigned i = 0; i < 8; i++) {
        free(inputBuffer[i]);
    }

    delete surf;
    
    if (_current == self) {
        _current = nil;
    }
}

# pragma mark - Execution

static void emulation_run() {
    GET_CURRENT_OR_RETURN();
    
    static int16_t sound_buf[0x10000];
    int32 rects[game->fb_height];
    rects[0] = ~0;

    EmulateSpecStruct spec = {0};
    spec.surface = surf;
    spec.SoundRate = current->sampleRate;
    spec.SoundBuf = sound_buf;
    spec.LineWidths = rects;
    spec.SoundBufMaxSize = sizeof(sound_buf) / 2;
    spec.SoundVolume = 1.0;
    spec.soundmultiplier = 1.0;

    MDFNI_Emulate(&spec);

    current->mednafenCoreTiming = current->masterClock / spec.MasterCycles;
    
    // Fix for game stutter. mednafenCoreTiming flutters on init before settling and we only read it
    // after the first frame wot set the current->gameInterval in the super class. This work around
    // resets the value after a few frames. -Joe M
    static int fixCount = 0;
    if(fixCount < 10) {
        current->gameInterval = 1.0 / current->mednafenCoreTiming;
        NSLog(@"%f", current->mednafenCoreTiming);
        fixCount++;
    }

    if(current->systemType == psx)
    {
        current->videoWidth = rects[spec.DisplayRect.y];
        current->videoOffsetX = spec.DisplayRect.x;
    }
    else if(game->multires)
    {
        current->videoWidth = rects[spec.DisplayRect.y];
        current->videoOffsetX = spec.DisplayRect.x;
    }
    else
    {
        current->videoWidth = spec.DisplayRect.w;
        current->videoOffsetX = spec.DisplayRect.x;
    }

    current->videoHeight = spec.DisplayRect.h;
    current->videoOffsetY = spec.DisplayRect.y;

    update_audio_batch(spec.SoundBuf, spec.SoundBufSize);
}

- (BOOL)loadFileAtPath:(NSString *)path
{
    [[NSFileManager defaultManager] createDirectoryAtPath:[self batterySavesPath] withIntermediateDirectories:YES attributes:nil error:NULL];

    if([[self systemIdentifier] isEqualToString:@"com.provenance.lynx"])
    {
        systemType = lynx;
        
        mednafenCoreModule = @"lynx";
        mednafenCoreAspect = OEIntSizeMake(80, 51);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.ngp"] || [[self systemIdentifier] isEqualToString:@"com.provenance.ngpc"])
    {
        systemType = neogeo;
        
        mednafenCoreModule = @"ngp";
        mednafenCoreAspect = OEIntSizeMake(20, 19);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 44100;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.pce"] || [[self systemIdentifier] isEqualToString:@"com.provenance.pcecd"] || [[self systemIdentifier] isEqualToString:@"com.provenance.sgfx"])
    {
        systemType = pce;
        
        mednafenCoreModule = @"pce";
        mednafenCoreAspect = OEIntSizeMake(256 * (8.0/7.0), 240);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.pcfx"])
    {
        systemType = pcfx;
        
        mednafenCoreModule = @"pcfx";
        mednafenCoreAspect = OEIntSizeMake(4, 3);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.psx"])
    {
        systemType = psx;
        
        mednafenCoreModule = @"psx";
        // Note: OpenEMU sets this to 4, 3.
        mednafenCoreAspect = OEIntSizeMake(3, 2);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 44100;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.vb"])
    {
        systemType = vb;
        
        mednafenCoreModule = @"vb";
        mednafenCoreAspect = OEIntSizeMake(12, 7);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.ws"] || [[self systemIdentifier] isEqualToString:@"com.provenance.wsc"])
    {
        systemType = wswan;
        
        mednafenCoreModule = @"wswan";
        mednafenCoreAspect = OEIntSizeMake(14, 9);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else
    {
        NSLog(@"MednafenGameCore loadFileAtPath: Incorrect systemIdentifier");
        assert(false);
    }

    assert(_current);
    mednafen_init(_current);

    game = MDFNI_LoadGame([mednafenCoreModule UTF8String], [path UTF8String]);

    if(!game) {
        return NO;
    }
    
    // BGRA pixel format
    MDFN_PixelFormat pix_fmt(MDFN_COLORSPACE_RGB, 16, 8, 0, 24);
    surf = new MDFN_Surface(NULL, game->fb_width, game->fb_height, game->fb_width, pix_fmt);

    masterClock = game->MasterClock >> 32;

    if (systemType == pce)
    {
        game->SetInput(0, "gamepad", (uint8_t *)inputBuffer[0]);
        game->SetInput(1, "gamepad", (uint8_t *)inputBuffer[1]);
        game->SetInput(2, "gamepad", (uint8_t *)inputBuffer[2]);
        game->SetInput(3, "gamepad", (uint8_t *)inputBuffer[3]);
        game->SetInput(4, "gamepad", (uint8_t *)inputBuffer[4]);
    }
    else if (systemType == pcfx)
    {
        game->SetInput(0, "gamepad", (uint8_t *)inputBuffer[0]);
        game->SetInput(1, "gamepad", (uint8_t *)inputBuffer[1]);
    }
    else if (systemType == psx)
    {
        for(unsigned i = 0; i < multiTapPlayerCount; i++) {
            game->SetInput(i, "dualshock", (uint8_t *)inputBuffer[i]);
        }
    }
    else
    {
        game->SetInput(0, "gamepad", (uint8_t *)inputBuffer[0]);
    }

    MDFNI_SetMedia(0, 2, 0, 0); // Disc selection API

    // Parse number of discs in m3u
    if([[[path pathExtension] lowercaseString] isEqualToString:@"m3u"])
    {
        NSString *m3uString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@".cue|.ccd" options:NSRegularExpressionCaseInsensitive error:nil];
        NSUInteger numberOfMatches = [regex numberOfMatchesInString:m3uString options:0 range:NSMakeRange(0, [m3uString length])];

        NSLog(@"Loaded m3u containing %lu cue sheets or ccd",numberOfMatches);

        maxDiscs = numberOfMatches;
    }

    emulation_run();

    return YES;
}

- (void)pollControllers {
    unsigned maxValue = 0;
    const int*map;
    switch (systemType) {
        case psx:
            maxValue = PVPSXButtonCount;
            map = PSXMap;
            break;
        case neogeo:
            maxValue = OENGPButtonCount;
            map = NeoMap;
            break;
        case lynx:
            maxValue = OELynxButtonCount;
            map = LynxMap;
            break;
        case pce:
            maxValue = OEPCEButtonCount;
            map = PCEMap;
            break;
        case pcfx:
            maxValue = OEPCFXButtonCount;
            map = PCFXMap;
            break;
        case vb:
            maxValue = OEVBButtonCount;
            map = VBMap;
            break;
        case wswan:
            maxValue = OEWSButtonCount;
            map = WSMap;
            break;
            return;
    }

    for (NSInteger playerIndex = 0; playerIndex < 2; playerIndex++) {
        GCController *controller = nil;
        
        if (self.controller1 && playerIndex == 0) {
            controller = self.controller1;
        }
        else if (self.controller2 && playerIndex == 1)
        {
            controller = self.controller2;
        }
        
        if (controller) {
            for (unsigned i=0; i<maxValue; i++) {
                
                if (systemType != psx || i < OEPSXLeftAnalogUp) {
                    uint32_t value = (uint32_t)[self controllerValueForButtonID:i forPlayer:playerIndex];
                    
                    if(value > 0) {
                        inputBuffer[playerIndex][0] |= 1 << map[i];
                    } else {
                        inputBuffer[playerIndex][0] &= ~(1 << map[i]);
                    }
                } else {
                    float analogValue = [self PSXAnalogControllerValueForButtonID:i forController:controller];
                    [self didMovePSXJoystickDirection:(PVPSXButton)i
                                            withValue:analogValue
                                            forPlayer:playerIndex];
                }
            }
        }
    }
}

- (void)executeFrame
{
    // Should we be using controller callbacks instead?
    if (self.controller1 || self.controller2) {
        [self pollControllers];
    }
    
    emulation_run();
}

- (void)resetEmulation
{
    MDFNI_Reset();
}

- (void)stopEmulation
{
    MDFNI_CloseGame();
    MDFNI_Kill();
    [super stopEmulation];
}

- (NSTimeInterval)frameInterval
{
    return mednafenCoreTiming ?: 60;
}

# pragma mark - Video

- (CGRect)screenRect
{
    return CGRectMake(videoOffsetX, videoOffsetY, videoWidth, videoHeight);
}

- (CGSize)bufferSize
{
    
    return CGSizeMake(game->fb_width, game->fb_height);
}

- (CGSize)aspectSize
{
    return CGSizeMake(mednafenCoreAspect.width,mednafenCoreAspect.height);
}

- (const void *)videoBuffer
{
    return surf->pixels;
}

- (GLenum)pixelFormat
{
    return GL_BGRA;
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat
{
    return GL_RGBA;
}

- (BOOL)wideScreen {
    switch (systemType) {
        case psx:
            return YES;
        case neogeo:
        case lynx:
        case pce:
        case pcfx:
        case vb:
        case wswan:
            return NO;
    }
}

# pragma mark - Audio

static size_t update_audio_batch(const int16_t *data, size_t frames)
{
    GET_CURRENT_OR_RETURN(frames);

    [[current ringBufferAtIndex:0] write:data maxLength:frames * [current channelCount] * 2];
    return frames;
}

- (double)audioSampleRate
{
    return sampleRate ? sampleRate : 48000;
}

- (NSUInteger)channelCount
{
    return game->soundchan;
}

# pragma mark - Save States

- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
    return MDFNI_SaveState(fileName.fileSystemRepresentation, "", NULL, NULL, NULL);
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
    return MDFNI_LoadState(fileName.fileSystemRepresentation, "");
}

- (NSData *)serializeStateWithError:(NSError **)outError
{
    MemoryStream stream(65536, false);
    MDFNSS_SaveSM(&stream, true);
    size_t length = stream.map_size();
    void *bytes = stream.map();

    if(length) {
        return [NSData dataWithBytes:bytes length:length];
    }
    
    if(outError) {
        assert(false);
#pragma message "fix error log"
//        *outError = [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotSaveStateError  userInfo:@{
//            NSLocalizedDescriptionKey : @"Save state data could not be written",
//            NSLocalizedRecoverySuggestionErrorKey : @"The emulator could not write the state data."
//        }];
    }

    return nil;
}

- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError {
    NSError *error;
    const void *bytes = [state bytes];
    size_t length = [state length];

    MemoryStream stream(length, -1);
    memcpy(stream.map(), bytes, length);
    MDFNSS_LoadSM(&stream, true);
    size_t serialSize = stream.map_size();

    if(serialSize != length)
    {
        #pragma message "fix error log"
//        error = [NSError errorWithDomain:OEGameCoreErrorDomain
//                                    code:OEGameCoreStateHasWrongSizeError
//                                userInfo:@{
//                                           NSLocalizedDescriptionKey : @"Save state has wrong file size.",
//                                           NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"The size of the save state does not have the right size, %lu expected, got: %ld.", serialSize, [state length]],
//                                        }];
    }

    if(error) {
        if(outError) {
            *outError = error;
        }
        return false;
    } else {
        return true;
    }
}

# pragma mark - Input

// Map OE button order to Mednafen button order
const int LynxMap[] = { 6, 7, 4, 5, 0, 1, 3, 2 };
const int PCEMap[]  = { 4, 6, 7, 5, 0, 1, 8, 9, 10, 11, 3, 2, 12 };
const int PCFXMap[] = { 8, 10, 11, 9, 0, 1, 2, 3, 4, 5, 7, 6 };
const int PSXMap[]  = { 4, 6, 7, 5, 12, 13, 14, 15, 10, 8, 1, 11, 9, 2, 3, 0, 16, 24, 23, 22, 21, 20, 19, 18, 17 };
const int VBMap[]   = { 9, 8, 7, 6, 4, 13, 12, 5, 3, 2, 0, 1, 10, 11 };
const int WSMap[]   = { 0, 2, 3, 1, 4, 6, 7, 5, 9, 10, 8, 11 };
const int NeoMap[]  = { 0, 1, 2, 3, 4, 5, 6};

#pragma mark Atari Lynx
- (oneway void)didPushLynxButton:(OELynxButton)button forPlayer:(NSUInteger)player {
    inputBuffer[player][0] |= 1 << LynxMap[button];
}

- (oneway void)didReleaseLynxButton:(OELynxButton)button forPlayer:(NSUInteger)player {
    inputBuffer[player][0] &= ~(1 << LynxMap[button]);
}

- (NSInteger)LynxControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad]) {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OELynxButtonUp:
                return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
            case OELynxButtonDown:
                return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
            case OELynxButtonLeft:
                return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
            case OELynxButtonRight:
                return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
            case OELynxButtonB:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case OELynxButtonA:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case OELynxButtonOption1:
                return [[pad leftShoulder] isPressed]?:[[pad leftTrigger] isPressed];
            case OELynxButtonOption2:
                return [[pad rightShoulder] isPressed]?:[[pad rightTrigger] isPressed];
            default:
                break;
        }
    } else if ([controller gamepad]) {
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OELynxButtonUp:
                return [[dpad up] isPressed];
            case OELynxButtonDown:
                return [[dpad down] isPressed];
            case OELynxButtonLeft:
                return [[dpad left] isPressed];
            case OELynxButtonRight:
                return [[dpad right] isPressed];
            case OELynxButtonB:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case OELynxButtonA:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case OELynxButtonOption1:
                return [[pad leftShoulder] isPressed];
            case OELynxButtonOption2:
                return [[pad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad]) {
        GCMicroGamepad *pad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OELynxButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case OELynxButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case OELynxButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case OELynxButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case OELynxButtonA:
                return [[pad buttonA] isPressed];
                break;
            case OELynxButtonB:
                return [[pad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}

#pragma mark Neo Geo
- (oneway void)didPushNGPButton:(OENGPButton)button forPlayer:(NSUInteger)player
{
    inputBuffer[player][0] |= 1 << NeoMap[button];
}

- (oneway void)didReleaseNGPButton:(OENGPButton)button forPlayer:(NSUInteger)player
{
    inputBuffer[player][0] &= ~(1 << NeoMap[button]);
}

#pragma mark PC-*
- (oneway void)didPushPCEButton:(OEPCEButton)button forPlayer:(NSUInteger)player
{
    if (button != OEPCEButtonMode) { // Check for six button mode toggle
        inputBuffer[player][0] |= 1 << PCEMap[button];
    } else {
        inputBuffer[player][0] ^= 1 << PCEMap[button];
    }
}

- (oneway void)didReleasePCEButton:(OEPCEButton)button forPlayer:(NSUInteger)player
{
    if (button != OEPCEButtonMode)
        inputBuffer[player][0] &= ~(1 << PCEMap[button]);
}

- (oneway void)didPushPCECDButton:(OEPCECDButton)button forPlayer:(NSUInteger)player
{
    if (button != OEPCECDButtonMode) { // Check for six button mode toggle
        inputBuffer[player][0] |= 1 << PCEMap[button];
    } else {
        inputBuffer[player][0] ^= 1 << PCEMap[button];
    }
}

- (oneway void)didReleasePCECDButton:(OEPCECDButton)button forPlayer:(NSUInteger)player;
{
    if (button != OEPCECDButtonMode) {
        inputBuffer[player][0] &= ~(1 << PCEMap[button]);
    }
}

- (oneway void)didPushPCFXButton:(OEPCFXButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] |= 1 << PCFXMap[button];
}

- (oneway void)didReleasePCFXButton:(OEPCFXButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] &= ~(1 << PCFXMap[button]);
}

#pragma mark PSX
- (oneway void)didPushPSXButton:(PVPSXButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] |= 1 << PSXMap[button];
}

- (oneway void)didReleasePSXButton:(PVPSXButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] &= ~(1 << PSXMap[button]);
}

- (oneway void)didMovePSXJoystickDirection:(PVPSXButton)button withValue:(CGFloat)value forPlayer:(NSUInteger)player
{
    int analogNumber = PSXMap[button] - 17;
    uint8_t *buf = (uint8_t *)inputBuffer[player];
    *(uint16*)& buf[3 + analogNumber * 2] = 32767 * value;
}

#pragma mark Virtual Boy
- (oneway void)didPushVBButton:(OEVBButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] |= 1 << VBMap[button];
}

- (oneway void)didReleaseVBButton:(OEVBButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] &= ~(1 << VBMap[button]);
}

#pragma mark WonderSwan
- (oneway void)didPushWSButton:(OEWSButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] |= 1 << WSMap[button];
}

- (oneway void)didReleaseWSButton:(OEWSButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] &= ~(1 << WSMap[button]);
}

- (NSInteger)controllerValueForButtonID:(unsigned)buttonID forPlayer:(NSInteger)player {
    GCController *controller = nil;
    
    if (player == 0) {
        controller = self.controller1;
    } else {
        controller = self.controller2;
    }
    
    switch (systemType) {
        case neogeo:
            return [self NeoGeoValueForButtonID:buttonID forController:controller];
            break;

        case lynx:
            return [self LynxControllerValueForButtonID:buttonID forController:controller];
            break;

        case pce:
        case pcfx:
            return [self PCEValueForButtonID:buttonID forController:controller];
            break;

        case psx:
            return [self PSXcontrollerValueForButtonID:buttonID forController:controller];
            break;

        case vb:
            return [self VirtualBoyControllerValueForButtonID:buttonID forController:controller];
            break;

        case wswan:
            return [self WonderSwanControllerValueForButtonID:buttonID forController:controller];
            break;
            
        default:
            break;
    }

    return 0;
}

- (NSInteger)NeoGeoValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad]) {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OENGPButtonUp:
                return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
            case OENGPButtonDown:
                return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
            case OENGPButtonLeft:
                return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
            case OENGPButtonRight:
                return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
            case OENGPButtonB:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case OENGPButtonA:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case OENGPButtonOption:
                return [[pad leftShoulder] isPressed]?:[[pad leftTrigger] isPressed] ?: [[pad rightShoulder] isPressed]?:[[pad rightTrigger] isPressed];
            default:
                break;
        }
    } else if ([controller gamepad]) {
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OENGPButtonUp:
                return [[dpad up] isPressed];
            case OENGPButtonDown:
                return [[dpad down] isPressed];
            case OENGPButtonLeft:
                return [[dpad left] isPressed];
            case OENGPButtonRight:
                return [[dpad right] isPressed];
            case OENGPButtonB:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case OENGPButtonA:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case OENGPButtonOption:
                return [[pad leftShoulder] isPressed] ?: [[pad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *pad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OENGPButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case OENGPButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case OENGPButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case OENGPButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case OENGPButtonA:
                return [[pad buttonA] isPressed];
                break;
            case OENGPButtonB:
                return [[pad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}

- (NSInteger)PCEValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *gamePad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamePad dpad];
        switch (buttonID) {
            case OEPCEButtonUp:
                return [[dpad up] isPressed]?:[[[gamePad leftThumbstick] up] isPressed];
            case OEPCEButtonDown:
                return [[dpad down] isPressed]?:[[[gamePad leftThumbstick] down] isPressed];
            case OEPCEButtonLeft:
                return [[dpad left] isPressed]?:[[[gamePad leftThumbstick] left] isPressed];
            case OEPCEButtonRight:
                return [[dpad right] isPressed]?:[[[gamePad leftThumbstick] right] isPressed];
            case OEPCEButton3:
                return [[gamePad buttonX] isPressed];
            case OEPCEButton2:
                return [[gamePad buttonA] isPressed];
            case OEPCEButton1:
                return [[gamePad buttonB] isPressed];
            case OEPCEButton4:
                return [[gamePad leftShoulder] isPressed];
            case OEPCEButton5:
                return [[gamePad buttonY] isPressed];
            case OEPCEButton6:
                return [[gamePad rightShoulder] isPressed];
            case OEPCEButtonMode:
                return [[gamePad leftTrigger] isPressed];
            case OEPCEButtonRun:
                return [[gamePad leftTrigger] isPressed];
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *gamePad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamePad dpad];
        switch (buttonID) {
            case OEPCEButtonUp:
                return [[dpad up] isPressed];
            case OEPCEButtonDown:
                return [[dpad down] isPressed];
            case OEPCEButtonLeft:
                return [[dpad left] isPressed];
            case OEPCEButtonRight:
                return [[dpad right] isPressed];
            case OEPCEButton3:
                return [[gamePad buttonX] isPressed];
            case OEPCEButton2:
                return [[gamePad buttonA] isPressed];
            case OEPCEButton1:
                return [[gamePad buttonB] isPressed];
            case OEPCEButton4:
                return [[gamePad leftShoulder] isPressed];
            case OEPCEButton5:
                return [[gamePad buttonY] isPressed];
            case OEPCEButton6:
                return [[gamePad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamePad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamePad dpad];
        switch (buttonID) {
            case OEPCEButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case OEPCEButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case OEPCEButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case OEPCEButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case OEPCEButton2:
                return [[gamePad buttonA] isPressed];
                break;
            case OEPCEButton1:
                return [[gamePad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    
    return 0;
}

- (float)PSXAnalogControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        switch (buttonID) {
            case OEPSXLeftAnalogUp:
                return [pad leftThumbstick].up.value;
            case OEPSXLeftAnalogDown:
                return [pad leftThumbstick].down.value;
            case OEPSXLeftAnalogLeft:
                return [pad leftThumbstick].left.value;
            case OEPSXLeftAnalogRight:
                return [pad leftThumbstick].right.value;
            case OEPSXRightAnalogUp:
                return [pad rightThumbstick].up.value;
            case OEPSXRightAnalogDown:
                return [pad rightThumbstick].down.value;
            case OEPSXRightAnalogLeft:
                return [pad rightThumbstick].left.value;
            case OEPSXRightAnalogRight:
                return [pad rightThumbstick].right.value;
            default:
                break;
        }
    }
    return 0;
}

- (NSInteger)PSXcontrollerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVPSXButtonUp:
                return [[dpad up] isPressed];
            case PVPSXButtonDown:
                return [[dpad down] isPressed];
            case PVPSXButtonLeft:
                return [[dpad left] isPressed];
            case PVPSXButtonRight:
                return [[dpad right] isPressed];
            case OEPSXLeftAnalogUp:
                return [pad leftThumbstick].up.value;
            case OEPSXLeftAnalogDown:
                return [pad leftThumbstick].down.value;
            case OEPSXLeftAnalogLeft:
                return [pad leftThumbstick].left.value;
            case OEPSXLeftAnalogRight:
                return [pad leftThumbstick].right.value;
            case PVPSXButtonSquare:
                return [[pad buttonX] isPressed];
            case PVPSXButtonCross:
                return [[pad buttonA] isPressed];
            case PVPSXButtonCircle:
                return [[pad buttonB] isPressed];
            case PVPSXButtonL1:
                return [[pad leftShoulder] isPressed];
            case PVPSXButtonTriangle:
                return [[pad buttonY] isPressed];
            case PVPSXButtonR1:
                return [[pad rightShoulder] isPressed];
            case PVPSXButtonStart:
                return [[pad rightTrigger] isPressed];
            case PVPSXButtonSelect:
                return [[pad leftTrigger] isPressed];
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVPSXButtonUp:
                return [[dpad up] isPressed];
            case PVPSXButtonDown:
                return [[dpad down] isPressed];
            case PVPSXButtonLeft:
                return [[dpad left] isPressed];
            case PVPSXButtonRight:
                return [[dpad right] isPressed];
            case PVPSXButtonSquare:
                return [[pad buttonX] isPressed];
            case PVPSXButtonCross:
                return [[pad buttonA] isPressed];
            case PVPSXButtonCircle:
                return [[pad buttonB] isPressed];
            case PVPSXButtonL1:
                return [[pad leftShoulder] isPressed];
            case PVPSXButtonTriangle:
                return [[pad buttonY] isPressed];
            case PVPSXButtonR1:
                return [[pad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *pad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVPSXButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVPSXButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVPSXButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVPSXButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVPSXButtonCross:
                return [[pad buttonA] isPressed];
                break;
            case PVPSXButtonCircle:
                return [[pad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}

- (NSInteger)VirtualBoyControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OEVBButtonLeftUp:
                return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
            case OEVBButtonLeftDown:
                return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
            case OEVBButtonLeftLeft:
                return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
            case OEVBButtonLeftRight:
                return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
            case OEVBButtonRightUp:
                return [[[pad rightThumbstick] up] isPressed];
            case OEVBButtonRightDown:
                return [[[pad rightThumbstick] down] isPressed];
            case OEVBButtonRightLeft:
                return [[[pad rightThumbstick] left] isPressed];
            case OEVBButtonRightRight:
                return [[[pad rightThumbstick] right] isPressed];
            case OEVBButtonB:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case OEVBButtonA:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case OEVBButtonL:
                return [[pad leftShoulder] isPressed];
            case OEVBButtonR:
                return [[pad rightShoulder] isPressed];
            case OEVBButtonStart:
                return [[pad leftTrigger] isPressed];
            case OEVBButtonSelect:
                return [[pad rightTrigger] isPressed];
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OEVBButtonLeftUp:
                return [[dpad up] isPressed];
            case OEVBButtonLeftDown:
                return [[dpad down] isPressed];
            case OEVBButtonLeftLeft:
                return [[dpad left] isPressed];
            case OEVBButtonLeftRight:
                return [[dpad right] isPressed];
            case OEVBButtonB:
                return [[pad buttonB] isPressed];
            case OEVBButtonA:
                return [[pad buttonA] isPressed];
            case OEVBButtonL:
                return [[pad leftShoulder] isPressed];
            case OEVBButtonR:
                return [[pad rightShoulder] isPressed];
            case OEVBButtonStart:
                return [[pad buttonX] isPressed];
            case OEVBButtonSelect:
                return [[pad buttonY] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *pad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OEVBButtonLeftUp:
                return [[dpad up] value] > 0.5;
                break;
            case OEVBButtonLeftDown:
                return [[dpad down] value] > 0.5;
                break;
            case OEVBButtonLeftLeft:
                return [[dpad left] value] > 0.5;
                break;
            case OEVBButtonLeftRight:
                return [[dpad right] value] > 0.5;
                break;
            case OEVBButtonA:
                return [[pad buttonA] isPressed];
                break;
            case OEVBButtonB:
                return [[pad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}

- (NSInteger)WonderSwanControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
                /* WonderSwan has a Top (Y) D-Pad and a lower (X) D-Pad. MFi controllers
                 may have the Joy Stick and Left D-Pad in either Top/Bottom configuration.
                 Another Option is to map to Left/Right Joystick and Make left D-Pad same as
                 left JoyStick, but if the games require using Left/Right hand at same time it
                 may be difficult to his the right d-pad and action buttons at the same time.
                 -joe M */
            case OEWSButtonX1:
                return [[[pad leftThumbstick] up] isPressed];
            case OEWSButtonX3:
                return [[[pad leftThumbstick] down] isPressed];
            case OEWSButtonX4:
                return [[[pad leftThumbstick] left] isPressed];
            case OEWSButtonX2:
                return [[[pad leftThumbstick] right] isPressed];
            case OEWSButtonY1:
                return [[dpad up] isPressed];
            case OEWSButtonY3:
                return [[dpad down] isPressed];
            case OEWSButtonY4:
                return [[dpad left] isPressed];
            case OEWSButtonY2:
                return [[dpad right] isPressed];
            case OEWSButtonA:
                return [[pad buttonX] isPressed];
            case OEWSButtonB:
                return [[pad buttonA] isPressed];
            case OEWSButtonStart:
                return [[pad buttonB] isPressed];
            case OEWSButtonSound:
                return [[pad leftShoulder] isPressed];
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OEWSButtonX1:
                return [[dpad up] isPressed];
            case OEWSButtonX3:
                return [[dpad down] isPressed];
            case OEWSButtonX4:
                return [[dpad left] isPressed];
            case OEWSButtonX2:
                return [[dpad right] isPressed];
            case OEWSButtonA:
                return [[pad buttonX] isPressed];
            case OEWSButtonB:
                return [[pad buttonA] isPressed];
            case OEWSButtonStart:
                return [[pad buttonB] isPressed];
            case OEWSButtonSound:
                return [[pad leftShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *pad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OEWSButtonX1:
                return [[dpad up] value] > 0.5;
                break;
            case OEWSButtonX3:
                return [[dpad down] value] > 0.5;
                break;
            case OEWSButtonX4:
                return [[dpad left] value] > 0.5;
                break;
            case OEWSButtonX2:
                return [[dpad right] value] > 0.5;
                break;
            case OEWSButtonA:
                return [[pad buttonA] isPressed];
                break;
            case OEWSButtonB:
                return [[pad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}

- (void)changeDisplayMode
{
    if (systemType == vb)
    {
        switch (MDFN_IEN_VB::mednafenCurrentDisplayMode)
        {
            case 0: // (2D) red/black
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x000000);
                MDFN_IEN_VB::VIP_SetParallaxDisable(true);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 1: // (2D) white/black
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFFFFFF, 0x000000);
                MDFN_IEN_VB::VIP_SetParallaxDisable(true);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 2: // (2D) purple/black
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF00FF, 0x000000);
                MDFN_IEN_VB::VIP_SetParallaxDisable(true);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 3: // (3D) red/blue
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x0000FF);
                MDFN_IEN_VB::VIP_SetParallaxDisable(false);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 4: // (3D) red/cyan
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x00B7EB);
                MDFN_IEN_VB::VIP_SetParallaxDisable(false);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 5: // (3D) red/electric cyan
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x00FFFF);
                MDFN_IEN_VB::VIP_SetParallaxDisable(false);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 6: // (3D) red/green
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x00FF00);
                MDFN_IEN_VB::VIP_SetParallaxDisable(false);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 7: // (3D) green/red
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0x00FF00, 0xFF0000);
                MDFN_IEN_VB::VIP_SetParallaxDisable(false);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 8: // (3D) yellow/blue
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFFFF00, 0x0000FF);
                MDFN_IEN_VB::VIP_SetParallaxDisable(false);
                MDFN_IEN_VB::mednafenCurrentDisplayMode = 0;
                break;

            default:
                return;
                break;
        }
    }
}

- (void)setDisc:(NSUInteger)discNumber {
    uint32_t index = discNumber - 1; // 0-based index
    MDFNI_SetMedia(0, 0, 0, 0); // open drive/eject disc

    // Open/eject needs a bit of delay, so wait 1 second until inserting new disc
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        MDFNI_SetMedia(0, 2, index, 0); // close drive/insert disc (2 = close)
    });
}

- (NSUInteger)discCount {
    return maxDiscs ? maxDiscs : 1;
}

@end
