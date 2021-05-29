 /*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The OpenGLRenderer class creates and draws objects.
  Most of the code is OS independent.
 */
#include "glUtil.h"
#include "ijksdl_vout.h"
#import <Foundation/Foundation.h>

typedef enum RcColorFormat {
    FMT_RGBA,
    FMT_YUV420P,
    FMT_NV12,
    FMT_VTB
}RcColorFormat;

@interface OpenGLRenderer : NSObject 

@property (nonatomic) GLuint defaultFBOName;

- (instancetype) initWithDefaultFBO: (GLuint) defaultFBOName;
- (void) resizeWithWidth:(GLuint)width AndHeight:(GLuint)height;
- (void) render;
- (void) dealloc;

- (void)display:(SDL_VoutOverlay *)realoverlay;

@end
