//
//  DarwinFileSystemServices.mm
//  PPSSPP
//
//  Created by Serena on 20/01/2023.
//

#include "ppsspp_config.h"
#include "Core/Config.h"
#include "DarwinFileSystemServices.h"
#include <dispatch/dispatch.h>
#include <CoreServices/CoreServices.h>

#if !__has_feature(objc_arc)
#error Must be built with ARC, please revise the flags for DarwinFileSystemServices.mm to include -fobjc-arc.
#endif

#if __has_include(<UIKit/UIKit.h>)
#include <UIKit/UIKit.h>

#if!TARGET_OS_TV

@interface DocumentPickerDelegate : NSObject <UIDocumentPickerDelegate>
@property DarwinDirectoryPanelCallback callback;
@end

@implementation DocumentPickerDelegate
-(instancetype)initWithCallback: (DarwinDirectoryPanelCallback)callback {
    if (self = [super init]) {
        self.callback = callback;
    }
    
    return self;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count >= 1)
		self.callback(true, Path(urls[0].path.UTF8String));
    else
        self.callback(false, Path());
}

@end
#endif
#elif __has_include(<AppKit/AppKit.h>)
#include <AppKit/AppKit.h>
#endif // __has_include(<UIKit/UIKit.h>)

void DarwinFileSystemServices::presentDirectoryPanel(DarwinDirectoryPanelCallback callback,
													 bool allowFiles,
													 bool allowDirectories) {
    dispatch_async(dispatch_get_main_queue(), ^{
#if PPSSPP_PLATFORM(MAC)
        NSOpenPanel *panel = [[NSOpenPanel alloc] init];
        panel.allowsMultipleSelection = NO;
        panel.canChooseFiles = allowFiles;
        panel.canChooseDirectories = allowDirectories;
        NSModalResponse modalResponse = [panel runModal];
        if (modalResponse == NSModalResponseOK && panel.URLs.firstObject) {
            callback(true, Path(panel.URLs.firstObject.path.UTF8String));
        } else if (modalResponse == NSModalResponseCancel) {
            callback(false, Path());
        }
#elif PPSSPP_PLATFORM(IOS) && !TARGET_OS_TV
		UIViewController *rootViewController = UIApplication.sharedApplication
			.keyWindow
			.rootViewController;
		
		// get current window view controller
		if (!rootViewController)
			return;
		
		NSMutableArray<NSString *> *types = [NSMutableArray array];
		UIDocumentPickerMode pickerMode = UIDocumentPickerModeOpen;
		
		UIDocumentPickerViewController *pickerVC = [[UIDocumentPickerViewController alloc] initWithDocumentTypes: types inMode: pickerMode];
		// What if you wanted to go to heaven, but then God showed you the next few lines?
		// serious note: have to do this, because __pickerDelegate has to stay retained as a class property
		__pickerDelegate = (void *)CFBridgingRetain([[DocumentPickerDelegate alloc] initWithCallback:callback]);
		pickerVC.delegate = (__bridge DocumentPickerDelegate *)__pickerDelegate;
		[rootViewController presentViewController:pickerVC animated:true completion:nil];
#endif
    });
}

Path DarwinFileSystemServices::appropriateMemoryStickDirectoryToUse() {
    NSString *userPreferred = [[NSUserDefaults standardUserDefaults] stringForKey:@(PreferredMemoryStickUserDefaultsKey)];
    if (userPreferred)
        return Path(userPreferred.UTF8String);
    
    return __defaultMemoryStickPath();
}

Path DarwinFileSystemServices::__defaultMemoryStickPath() {
#if PPSSPP_PLATFORM(IOS)
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
                               objectAtIndex:0];
    return Path(documentsPath.UTF8String);
#elif PPSSPP_PLATFORM(MAC)
    return g_Config.defaultCurrentDirectory / ".config/ppsspp";
#endif
}

void DarwinFileSystemServices::setUserPreferredMemoryStickDirectory(Path path) {
    [[NSUserDefaults standardUserDefaults] setObject:@(path.c_str())
                                              forKey:@(PreferredMemoryStickUserDefaultsKey)];
    g_Config.memStickDirectory = path;
}

void RestartMacApp() {
#if PPSSPP_PLATFORM(MAC)
    NSURL *bundleURL = NSBundle.mainBundle.bundleURL;
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/open"];
    task.arguments = @[@"-n", bundleURL.path];
    [task launch];
    exit(0);
#endif
}
