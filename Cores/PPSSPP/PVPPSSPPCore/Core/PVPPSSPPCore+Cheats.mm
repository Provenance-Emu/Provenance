#import <PVPPSSPP/PVPPSSPP.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

/* PSP Includes */
#include "Common/MemoryUtil.h"
#include "Common/Profiler/Profiler.h"
#include "Common/CPUDetect.h"
#include "Common/Log.h"
#include "Common/LogManager.h"
#include "Common/TimeUtil.h"
#include "Common/File/FileUtil.h"
#include "Common/Serialize/Serializer.h"
#include "Common/ConsoleListener.h"
#include "Common/Input/InputState.h"
#include "Common/Input/KeyCodes.h"
#include "Common/Thread/ThreadUtil.h"
#include "Common/Thread/ThreadManager.h"
#include "Common/File/VFS/VFS.h"
#include "Common/Data/Text/I18n.h"
#include "Common/StringUtils.h""
#include "Common/System/Display.h"
#include "Common/System/NativeApp.h"
#include "Common/System/System.h"
#include "Common/Net/Resolve.h"
#include "Common/UI/Screen.h"
#include "Common/System/NativeApp.h"
#include "Common/File/VFS/VFS.h"
#include "Common/Log.h"
#include "Common/TimeUtil.h"

#include "Core/Config.h"
#include "Core/ConfigValues.h"
#include "Core/Core.h"
#include "Core/CoreParameter.h"
#include "Core/HLE/sceCtrl.h"
#include "Core/HLE/sceUtility.h"
#include "Core/HW/MemoryStick.h"
#include "Core/MemMap.h"
#include "Core/System.h"
#include "Core/CoreTiming.h"
#include "Core/HW/Display.h"
#include "Core/CwCheat.h"
#include "Core/ELF/ParamSFO.h"
#include "Core/SaveState.h"

@implementation PVPPSSPPCore (Cheats)
#pragma mark - Cheats
- (void)resetCheatCodes {
    NSLog(@"Reset Cheat Codes\n");
    // Init Cheat Engine
    CWCheatEngine *cheatEngine = new CWCheatEngine(g_paramSFO.GetDiscID());
    Path file=cheatEngine->CheatFilename();

    // Output cheats to cheat file
    std::ofstream outFile;
    outFile.open(file.c_str());
    outFile << "_S " << g_paramSFO.GetDiscID() << std::endl;
    outFile.close();

    g_Config.bReloadCheats = true;

    // Parse and Run the Cheats
    cheatEngine->ParseCheats();
    if (cheatEngine->HasCheats()) {
       cheatEngine->Run();
    }
}
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType: (NSString *)codeType
		  setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled  error:(NSError**)error {
	// Initialize Cheat Engine
	CWCheatEngine *cheatEngine = new CWCheatEngine(g_paramSFO.GetDiscID());
	cheatEngine->CreateCheatFile();
	Path file=cheatEngine->CheatFilename();

	// Read cheats file
	std::vector<std::string> cheats;
	std::ifstream cheat_content(file.c_str());
	std::stringstream buffer;
	buffer << cheat_content.rdbuf();
	std::string existing_cheats=ReplaceAll(buffer.str(), std::string("\n_C"), std::string("|"));
	SplitString(existing_cheats, '|', cheats);

	// Generate Cheat String
	std::stringstream cheat("");
	cheat << (enabled ? "1 " : "0 ") << index << std::endl;
	std::string code_str([code UTF8String]);
	std::vector<std::string> codes;
	code_str=ReplaceAll(code_str, std::string(" "), std::string("+"));
	SplitString(code_str, '+', codes);
	int part=0;
	for (int i=0; i < codes.size(); i++) {
		if (codes[i].size() <= 2) {
			// _L _M ..etc
			// Assume _L
		} else if (part == 0) {
			cheat << "_L " << codes[i] << " ";
			part++;
		} else {
			cheat << codes[i] << std::endl;
			part=0;
		}
	}

	// Add or Replace the Cheat
	int index = cheatIndex;
	if (index + 1 < cheats.size()) {
		cheats[index + 1]=cheat.str();
	} else {
		cheats.push_back(cheat.str());
	}

	// Output cheats to cheat file
	std::ofstream outFile;
	outFile.open(file.c_str());
	outFile << "_S " << g_paramSFO.GetDiscID() << std::endl;
	for (int i=1; i < cheats.size(); i++) {
		outFile << "_C" << cheats[i] << std::endl;
	}
	outFile.close();

	g_Config.bReloadCheats = true;

	// Parse and Run the Cheats
	cheatEngine->ParseCheats();
	if (cheatEngine->HasCheats()) {
		cheatEngine->Run();
	}
	return true;
}
@end
