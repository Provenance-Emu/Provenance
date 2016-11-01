//
//  PVGameLibraryCollectionViewCell.h
//  Provenance
//
//  Created by James Addyman on 07/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PVGame;

@interface PVGameLibraryCollectionViewCell : UICollectionViewCell

- (void)setupWithGame:(PVGame *)game;

+ (CGSize)cellSizeForImageSize:(CGSize)imageSize;

@end
