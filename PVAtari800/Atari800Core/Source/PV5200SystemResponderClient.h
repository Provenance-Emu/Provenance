/*
 Copyright (c) 2012, OpenEmu Team
 
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

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

//@protocol OESystemResponderClient;

typedef NS_ENUM(NSUInteger, PV5200Button) {
	PV5200ButtonUp,
	PV5200ButtonDown,
	PV5200ButtonLeft,
	PV5200ButtonRight,
	PV5200ButtonFire1,
    PV5200ButtonFire2,
    PV5200ButtonStart,
	PV5200ButtonPause,
    PV5200ButtonReset,
    PV5200Button1,
    PV5200Button2,
    PV5200Button3,
    PV5200Button4,
    PV5200Button5,
    PV5200Button6,
    PV5200Button7,
    PV5200Button8,
    PV5200Button9,
    PV5200Button0,
    PV5200ButtonAsterisk,
    PV5200ButtonPound,
	PV5200ButtonCount
};

@protocol PV5200SystemResponderClient <NSObject>

- (oneway void)didPush5200Button:(PV5200Button)button forPlayer:(NSUInteger)player;
- (oneway void)didRelease5200Button:(PV5200Button)button forPlayer:(NSUInteger)player;

@end
