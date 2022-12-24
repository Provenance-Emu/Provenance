//
//  EAGLView.h
//  Provenance
//
//  Created by Joseph Mattiello on 12/18/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#ifndef EAGLView_h
#define EAGLView_h

#define GLES_SILENCE_DEPRECATION

#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>

@interface EAGLView : UIView

@end
#endif
#endif /* EAGLView_h */
