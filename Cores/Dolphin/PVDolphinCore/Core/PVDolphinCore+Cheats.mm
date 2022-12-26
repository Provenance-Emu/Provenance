#import <PVDolphin/PVDolphin.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

@implementation PVDolphinCore (Cheats)

#pragma mark - Cheats

# pragma mark - Cheats
- (void)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType setCheatIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled
{
	gcode.codes.clear();
	gcode.enabled = enabled;
	arcode.ops.clear();
	arcode.enabled = enabled;

	Gecko::GeckoCode::Code gcodecode;
	uint32_t cmd_addr, cmd_value;

	std::vector<std::string> arcode_encrypted_lines;

	//Get the code sent and sanitize it.
	NSString* nscode = [NSString stringWithUTF8String:[code UTF8String]];

	//Remove whitespace
	nscode = [nscode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	// Remove any spaces and dashes
	nscode = [nscode stringByReplacingOccurrencesOfString:@" " withString:@""];
	nscode = [nscode stringByReplacingOccurrencesOfString:@"-" withString:@""];

	//Check if it is a valid Gecko or ActionReplay code
	NSString *singleCode;
	NSArray *multipleCodes = [nscode componentsSeparatedByString:@"+"];

	for (singleCode in multipleCodes)
	{
		if ([singleCode length] == 16) // Gecko code
		{
			NSString *address = [singleCode substringWithRange:NSMakeRange(0, 8)];
			NSString *value = [singleCode substringWithRange:NSMakeRange(8, 8)];

			bool success_addr = TryParse(std::string("0x") + [address UTF8String], &cmd_addr);
			bool success_val = TryParse(std::string("0x") + [value UTF8String], &cmd_value);

			if (!success_addr || !success_val)
				return;

			gcodecode.address = cmd_addr;
			gcodecode.data = cmd_value;
			gcode.codes.push_back(gcodecode);
		}
		else if ([singleCode length] == 13) // Encrypted AR code
		{
			// Add the code to list encrypted lines
			arcode_encrypted_lines.emplace_back([singleCode UTF8String]);
		}
		else
		{
			// Not a good code
			return;
		}
	}

	if (arcode_encrypted_lines.size())
	{
		DecryptARCode(arcode_encrypted_lines,  &arcode.ops);
	}

	bool exists = false;

	//Check to make sure the Gecko codes are not already in the list
	//  cycle through the codes in our Gecko vector
	for (Gecko::GeckoCode& gcompare : gcodes)
	{
		//If the code being modified is the same size as one in the vector, check each value
		if (gcompare.codes.size() == gcode.codes.size())
		{
			for(int i = 0; i < gcode.codes.size() ;i++)
			{
				if (gcompare.codes[i].address == gcode.codes[i].address && gcompare.codes[i].data == gcode.codes[i].data)
				{
					exists = true;
				}
				else
				{
					exists = false;
					// If it's not the same, no need to look through all the codes
					break;
				}
			}
		}
		if(exists)
		{
			gcompare.enabled = enabled;
			// If it exists, enable it, and we don't need to look at the rest of the codes
			break;
		}
	}

	if(!exists)
		gcodes.push_back(gcode);

	Gecko::SetActiveCodes(gcodes);


	//Check to make sure the ARcode is not already in the list
	//  cycle through the codes in our AR vector
	for (ActionReplay::ARCode& acompare : arcodes)
	{
		if (acompare.ops.size() == arcode.ops.size())
		{
			for(int i = 0; i < arcode.ops.size() ;i++)
			{
				if (acompare.ops[i].cmd_addr == arcode.ops[i].cmd_addr && acompare.ops[i].value == arcode.ops[i].value)
				{
					exists = true;
				}
				else
				{
					exists = false;
					// If it's not the same, no need to look through all the codes
					break;
				}
			}
		}
		if(exists)
		{
			acompare.enabled = enabled;
			// If it exists, enable it, and we don't need to look at the rest of the codes
			break;
		}
	}

	if(!exists)
		arcodes.push_back(arcode);

	ActionReplay::RunAllActive();
	//dol_host->SetCheat([code UTF8String], [type UTF8String], enabled);
}


- (BOOL)supportsCheatCode { return YES; }