/*
 * IJKFFMoviePlayerController.h
 *
 * Copyright (c) 2013 Zhang Rui <bbcallen@gmail.com>
 *
 * This file is part of ijkPlayer.
 *
 * ijkPlayer is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * ijkPlayer is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with ijkPlayer; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#import "IJKMediaPlayback.h"
#import "IJKFFMonitor.h"
#import "IJKFFOptions.h"
#import "ijksdl.h"
#import "ARMGLView.h"

typedef void (^DisplayFrameBlock)(SDL_VoutOverlay* overlay);

typedef enum {
    MOVICE_STATE_PREPARED,
    MOVICE_STATE_PLAYING,
    MOVICE_STATE_STOP,
    MOVICE_STATE_PAUSE,
    MOVICE_STATE_FINISH,
    MOVICE_STATE_SEEK_FINISH,
    MOVICE_STATE_BUFFER_EMPTY,
    MOVICE_STATE_START_SEEK,
    MOVICE_STATE_FAILED,
    MOVICE_STATE_READYTOPALY,
    MOVICE_STATE_PLAYBACK_CHANGED,
    MOVICE_STATE_UNKNOWN
    
}MovieDecoderPlayItemState;

@protocol MovieDecoderDelegate <NSObject>

@required
-(void)movieDecoderError:(int)errorCode;
-(void)moviceDecoderPlayItemState:(MovieDecoderPlayItemState)state arg1:(int) arg1 arg2:(int)arg2;
-(void)movieDecoderDidDecodeFrameSDL:(SDL_VoutOverlay*)frame;
@optional
-(void)movieDecoderOnStatisticsUpdated:(NSDictionary*)dic;

@end



typedef enum MAC_IJKLogLevel {
    MAC_IJK_LOG_UNKNOWN = 0,
    MAC_IJK_LOG_DEFAULT = 1,

    MAC_IJK_LOG_VERBOSE = 2,
    MAC_IJK_LOG_DEBUG   = 3,
    MAC_IJK_LOG_INFO    = 4,
    MAC_IJK_LOG_WARN    = 5,
    MAC_IJK_LOG_ERROR   = 6,
    MAC_IJK_LOG_FATAL   = 7,
    MAC_IJK_LOG_SILENT  = 8,
} MAC_IJKLogLevel;

@interface IJKFFMoviePlayerController : NSObject <IJKMediaPlayback>


- (id)initWithContentURL:(NSURL *)aUrl
             withOptions:(IJKFFOptions *)options
                  glView:(ARMGLView *)glView;

- (id)initWithContentURLString:(NSString *)aUrlString
                   withOptions:(IJKFFOptions *)options
                        glView:(ARMGLView *)glView;

@property(nonatomic,assign) Boolean isVideotoolbox;
- (id)initWithContentURLString:(NSString *)aUrlString
                   withOptions:(IJKFFOptions *)options
                isVideotoolbox:(Boolean)isVideotoolbox
                        glView:(ARMGLView *)glView;

- (void)prepareToPlay;
- (void)play;
- (void)pause;
- (void)stop;
- (BOOL)isPlaying;
- (void)setPauseInBackground:(BOOL)pause;
- (BOOL)isVideoToolboxOpen;

-(void)setVolume:(float)volume;
-(float)getVolume;

+ (void)setLogReport:(BOOL)preferLogReport;
+ (void)setLogLevel:(MAC_IJKLogLevel)logLevel;
+ (BOOL)checkIfFFmpegVersionMatch:(BOOL)showAlert;
+ (BOOL)checkIfPlayerVersionMatch:(BOOL)showAlert
                            major:(unsigned int)major
                            minor:(unsigned int)minor
                            micro:(unsigned int)micro;

@property(nonatomic, readonly) CGFloat fpsInMeta;
@property(nonatomic, readonly) CGFloat fpsAtOutput;
@property(nonatomic) BOOL shouldShowHudView;
@property (nonatomic,weak) id<MovieDecoderDelegate> delegate;

- (void)setOptionValue:(NSString *)value
                forKey:(NSString *)key
            ofCategory:(IJKFFOptionCategory)category;

- (void)setOptionIntValue:(int64_t)value
                   forKey:(NSString *)key
               ofCategory:(IJKFFOptionCategory)category;



- (void)setFormatOptionValue:       (NSString *)value forKey:(NSString *)key;
- (void)setCodecOptionValue:        (NSString *)value forKey:(NSString *)key;
- (void)setSwsOptionValue:          (NSString *)value forKey:(NSString *)key;
- (void)setPlayerOptionValue:       (NSString *)value forKey:(NSString *)key;

- (void)setFormatOptionIntValue:    (int64_t)value forKey:(NSString *)key;
- (void)setCodecOptionIntValue:     (int64_t)value forKey:(NSString *)key;
- (void)setSwsOptionIntValue:       (int64_t)value forKey:(NSString *)key;
- (void)setPlayerOptionIntValue:    (int64_t)value forKey:(NSString *)key;

- (NSDictionary *)getMediaMeta;

@property (nonatomic, retain) id<IJKMediaUrlOpenDelegate> segmentOpenDelegate;
@property (nonatomic, retain) id<IJKMediaUrlOpenDelegate> tcpOpenDelegate;
@property (nonatomic, retain) id<IJKMediaUrlOpenDelegate> httpOpenDelegate;
@property (nonatomic, retain) id<IJKMediaUrlOpenDelegate> liveOpenDelegate;

@property (nonatomic, retain) id<IJKMediaNativeInvokeDelegate> nativeInvokeDelegate;

- (void)didShutdown;

#pragma mark KVO properties
@property (nonatomic, readonly) IJKFFMonitor *monitor;

@end

#define IJK_FF_IO_TYPE_READ (1)
void IJKFFIOStatDebugCallback(const char *url, int type, int bytes);
void IJKFFIOStatRegister(void (*cb)(const char *url, int type, int bytes));

void IJKFFIOStatCompleteDebugCallback(const char *url,
                                      int64_t read_bytes, int64_t total_size,
                                      int64_t elpased_time, int64_t total_duration);
void IJKFFIOStatCompleteRegister(void (*cb)(const char *url,
                                            int64_t read_bytes, int64_t total_size,
                                            int64_t elpased_time, int64_t total_duration));


