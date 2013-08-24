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

#ifndef OpenEmu_ArchiveVGTypes_h
#define OpenEmu_ArchiveVGTypes_h
 
#ifdef ARCHIVE_DEBUG
#define ArchiveDLog NSLog
#else
#define ArchiveDLog(__args__, ...) {} 
#endif

#pragma mark - Output Formats
typedef enum {
	AVGOutputFormatXML,
	AVGOutputFormatJSON,
	AVGOutputFormatYAML,
} AVGOutputFormat;
extern const AVGOutputFormat AVGDefaultOutputFormat;

#pragma mark - API Calls
typedef enum 
{
	AVGConfig,				// no options
    AVGSearch,				// requires search string
    AVGGetSystems,		// no options
    AVGGetDailyFact,	// supply system short name
    
    AVGGetInfoByID,		// requires archive.vg game id							Note: This method is throttled
    AVGGetInfoByCRC,	// requires rom crc										Note: This method is throttled
    AVGGetInfoByMD5,	// requires rom md5										Note: This method is throttled
	
	AVGGetCreditsByID,// requires archive.vg game id							Note: This method is throttled
	AVGGetReleasesByID,// requires archive.vg game id							Note: This method is throttled
	AVGGetTOSECsByID,// requires archive.vg game id							Note: This method is throttled
	AVGGetRatingByID,// requires archive.vg game id
} ArchiveVGOperation;


#pragma mark - Response Dictionary Keys
// Keys that appear in Game Info Dicts
extern NSString * const AVGGameTitleKey;
extern NSString * const AVGGameIDKey;

// Keys that *can* appear in Game Info Dictionaries
extern NSString * const AVGGameDeveloperKey;
extern NSString * const AVGGameSystemNameKey;
extern NSString * const AVGGameDescriptionKey;
extern NSString * const AVGGameGenreKey;
extern NSString * const AVGGameBoxURLStringKey;
extern NSString * const AVGGameBoxSmallURLStringKey;
extern NSString * const AVGGameESRBRatingKey;
extern NSString * const AVGGameCreditsKey;
extern NSString * const AVGGameReleasesKey;
extern NSString * const AVGGameTosecsKey;
extern NSString * const AVGGameRomNameKey;

// Keys that appear in Credits Dictionaries
extern NSString * const AVGCreditsNameKey;
extern NSString * const AVGCreditsPositionKey;

// Keys that appear in Release Dictionaries
extern NSString * const AVGReleaseTitleKey;
extern NSString * const AVGReleaseCompanyKey;
extern NSString * const AVGReleaseSerialKey;
extern NSString * const AVGReleaseDateKey;
extern NSString * const AVGReleaseCountryKey;

// Keys that appear in Tosec Dictionaries
extern NSString * const AVGTosecTitleKey;
extern NSString * const AVGTosecRomNameKey;
extern NSString * const AVGTosecSizeKey;
extern NSString * const AVGTosecCRCKey;
extern NSString * const AVGTosecMD5Key;

// Keys that appear in System Info Dicts
extern NSString * const AVGSystemIDKey;
extern NSString * const AVGSystemNameKey;
extern NSString * const AVGSystemShortKey;

// Keys that appear in Config Dictioanries
extern NSString * const AVGConfigGeneralKey;
extern NSString * const AVGConfigCurrentAPIKey;
extern NSString * const AVGConfigThrottlingKey;
extern NSString * const AVGConfigMaxCallsKey;
extern NSString * const AVGConfigRegenerationKey;

// Keys that appear in Daily Fact Dictionaries
extern NSString * const AVGFactDateKey;
extern NSString * const AVGFactGameIDKey;
extern NSString * const AVGFactContentKey;

#pragma mark - Errors
extern NSString * const OEArchiveVGErrorDomain;

enum {
	AVGNoDataErrorCode = -2,
	AVGInvalidArgumentsErrorCode = -1,
	AVGUnkownOutputFormatErrorCode = -3,
	AVGNotImplementedErrorCode = -4,
	
	// Codes from Archive (see api.archive.vg)
	AVGThrottlingErrorCode = 1,
};
#endif

