//
//  PVGameLibraryViewController.h
//  Provenance
//
//  Created by James Addyman on 07/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GameController/GameController.h>

extern NSString * const PVGameLibraryHeaderView;
extern NSString * const kRefreshLibraryNotification;

@interface PVGameLibraryViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout,
                                                            UITextFieldDelegate, UINavigationControllerDelegate>

- (NSString *)batterySavesPathForROM:(NSString *)romPath;

@end

#if !TARGET_OS_TV
@interface PVGameLibraryViewController () <UIImagePickerControllerDelegate>

@end
#endif