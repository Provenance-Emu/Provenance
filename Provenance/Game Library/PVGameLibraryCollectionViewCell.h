//
//  PVGameLibraryCollectionViewCell.h
//  Provenance
//
//  Created by James Addyman on 07/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PVGameLibraryCollectionViewCell : UICollectionViewCell

@property (nonatomic, readonly) UIImageView *imageView;
@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, readonly) UILabel *missingLabel;

- (void)setText:(NSString *)text;

@end
