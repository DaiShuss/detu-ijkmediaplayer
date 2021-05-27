//
//  ijk_ffplay_decoder.c
//  IJKMediaPlayer
//
//  Created by chao on 2017/6/12.
//  Copyright © 2017年 detu. All rights reserved.
//

#include "ijk_ffplay_decoder.h"
#include <stdlib.h>
#include <string.h>
#import <CoreVideo/CVPixelBuffer.h>
#import"IJKFFMoviePlayerController.h"
extern "C" {
#include "ijksdl_vout_overlay_videotoolbox.h"
#include "ijkmeta.h"
}
#import <Foundation/Foundation.h>

#define MAC_DECODER_NAME_SOFT "h264_soft"
#define MAC_DECODER_NAME_VTB "h264_vtb"
#define MAC_MAX_DECODER_NAME_LENGTH 9

@interface DecoderEventReceiver<MovieDecoderDelegate> : NSObject{
    IjkFfplayDecoder* decoder;
}
-(void)setDecoder:(IjkFfplayDecoder*)decoder;
-(void)movieDecoderError:(NSError *)error;
-(void)moviceDecoderPlayItemState:(MovieDecoderPlayItemState)state arg1:(int) arg1 arg2:(int)arg2;
-(void)movieDecoderOnStatisticsUpdated:(NSDictionary*)dic;
-(void)movieDecoderDidDecodeFrameSDL:(SDL_VoutOverlay*)frame;
@end


#define MAC_IJK_VTB_MAX_CACHE_FRAME_SIZE 5

struct IjkFfplayDecoder {
    void* opaque;
    IJKFFMoviePlayerController* controller;
    char codecName[9];
    IjkFfplayDecoderCallBack callBack;
    DecoderEventReceiver* eventReceiver;
    IjkVideoFrame cacheVideoFrames[MAC_IJK_VTB_MAX_CACHE_FRAME_SIZE];
    int index;
};

@implementation DecoderEventReceiver

-(void)setDecoder:(IjkFfplayDecoder*)ijDecoder {
    decoder = ijDecoder;
}

-(void)movieDecoderError:(int)errorCode {
    if(decoder == NULL) {
        return;
    }
    IjkFfplayDecoderCallBack* callBack = &(decoder->callBack);
    if(callBack->func_state_change != 0) {
        (*callBack->func_state_change)(decoder->opaque, IJK_MSG_ERROR, 0, 0);
    }
}

-(void)moviceDecoderPlayItemState:(MovieDecoderPlayItemState)state arg1:(int) arg1 arg2:(int)arg2{
    if(decoder == NULL) {
        return;
    }
    IjkFfplayDecoderCallBack* callBack = &(decoder->callBack);
    if(callBack->func_state_change != 0) {
        switch (state) {
            case MOVICE_STATE_PREPARED:
                (*callBack->func_state_change)(decoder->opaque, IJK_MSG_PREPARED, 0, 0);
                break;
            case MOVICE_STATE_PLAYING:
                //(*callBack->func_state_change)(decoder->opaque, IJK_MSG_PREPARED, 0, 0);
                break;
            case MOVICE_STATE_FINISH:
                (*callBack->func_state_change)(decoder->opaque, IJK_MSG_COMPLETED, 0, 0);
                break;
            case MOVICE_STATE_SEEK_FINISH:
                (*callBack->func_state_change)(decoder->opaque, IJK_MSG_SEEK_COMPLETE, arg1, arg2);
                break;
            case MOVICE_STATE_PLAYBACK_CHANGED:
                (*callBack->func_state_change)(decoder->opaque, IJK_MSG_PLAYBACK_STATE_CHANGED, arg1, arg2);
                break;

            default:
                break;
        }
    }
}

-(void)movieDecoderOnStatisticsUpdated:(NSDictionary*)dic {
    
}

-(void)movieDecoderDidDecodeFrameSDL:(SDL_VoutOverlay*)overlay {
    if (overlay == NULL) {
        return;
    }
    IjkFfplayDecoderCallBack* callBack = &decoder->callBack;
    if(callBack->func_get_frame != 0) {
        IjkVideoFrame videoFrame = {0};
        if(overlay->format == SDL_FCC__VTB) {
            //mac 硬解需要拷贝数据
            CVPixelBufferRef pixel = SDL_VoutOverlayVideoToolBox_GetCVPixelBufferRef(overlay);
            size_t count = CVPixelBufferGetPlaneCount(pixel);
            size_t width = CVPixelBufferGetWidth(pixel);
            size_t height = CVPixelBufferGetHeight(pixel);
            IjkVideoFrame* cacheFrame = &decoder->cacheVideoFrames[decoder->index];
            if(cacheFrame->data[0] == NULL) {
                int alignWidth = (int)CVPixelBufferGetBytesPerRowOfPlane(pixel, 0);
                int alignHeight = (int)CVPixelBufferGetHeightOfPlane(pixel, 0);
                int ySize = alignWidth * alignHeight;
                unsigned char* cacheData = (unsigned char*)calloc(1, ySize * 3 / 2);
                cacheFrame->data[0] = cacheData;
                cacheFrame->data[1] = cacheData + ySize;
            }
            
            videoFrame.w = (int)width;
            videoFrame.h = (int)height;
            videoFrame.format = PIX_FMT_NV12;
            int alignWidth = (int)CVPixelBufferGetBytesPerRowOfPlane(pixel, 0);
            int alignHeight = (int)CVPixelBufferGetHeightOfPlane(pixel, 0);
            videoFrame.planes = 2;
            int copySizes[2] = {0};
            copySizes[0] = alignWidth * alignHeight;
            copySizes[1] = copySizes[0] / 2;
            for(int i = 0; i < count; i++) {
                CVPixelBufferLockBaseAddress(pixel, i);
                void * pb = CVPixelBufferGetBaseAddressOfPlane(pixel, i);
                memcpy(cacheFrame->data[i], pb, copySizes[i]);
                videoFrame.data[i] = cacheFrame->data[i];
                videoFrame.linesize[i] = (int)(int)CVPixelBufferGetBytesPerRowOfPlane(pixel, i);
                CVPixelBufferUnlockBaseAddress(pixel, i);
            }
            decoder->index +=1;
            if(decoder->index == MAC_IJK_VTB_MAX_CACHE_FRAME_SIZE) {
                decoder->index = 0;
            }
            //NSLog(@"the cache frame index:%d", decoder->index);
        } else {
            //软解数据,YUV420P
            videoFrame.w = overlay->w;
            videoFrame.h = overlay->h;
            videoFrame.format = PIX_FMT_YUV420P;
            int planes = 3;
            videoFrame.planes = planes;
            for(int i = 0; i< planes; i++) {
                videoFrame.data[i] = overlay->pixels[i];
                videoFrame.linesize[i] = overlay->pitches[i];
            }
        }
        callBack->func_get_frame(decoder->opaque, &videoFrame);
    }
}

@end

int ijkFfplayDecoder_init(void) {
    return 0;
}

int ijkFfplayDecoder_uninit(void) {
    return 0;
}

IjkFfplayDecoder *ijkFfplayDecoder_create(void) {
    IjkFfplayDecoder* decoder = (IjkFfplayDecoder*)calloc(1, sizeof(IjkFfplayDecoder));
    decoder->eventReceiver = [[DecoderEventReceiver alloc]init];
    [decoder->eventReceiver setDecoder:decoder];
    return decoder;
}

int ijkFfplayDecoder_setLogLevel(IJKLogLevel log_level) {
    return 0;
}

int ijkFfplayDecoder_setLogCallback(void(*callback)(void*, int, const char*, va_list)) {
    return 0;
}

int ijkFfplayDecoder_setDecoderCallBack(IjkFfplayDecoder* decoder, void* opaque, IjkFfplayDecoderCallBack* callback) {
    if(decoder == NULL || callback == NULL) {
        return -1;
    }
    decoder->opaque = opaque;
    memset(&decoder->callBack, 0, sizeof(IjkFfplayDecoderCallBack));
    memcpy(&decoder->callBack, callback, sizeof(IjkFfplayDecoderCallBack));
    return 0;
}

int ijkFfplayDecoder_setDataSource(IjkFfplayDecoder* decoder, const char* file_absolute_path, VideoGLView *glview) {
    if(decoder == NULL || file_absolute_path == NULL || strlen(file_absolute_path) == 0) {
        return -1;
    }
    NSString* path = [[NSString alloc]initWithUTF8String:file_absolute_path];
    bool isVideoToolBox = true;
    if(strcmp(MAC_DECODER_NAME_SOFT, decoder->codecName) == 0) {
        isVideoToolBox = false;
    } else if(strcmp(MAC_DECODER_NAME_VTB, decoder->codecName) == 0) {
        isVideoToolBox = true;
    }
    isVideoToolBox = false;
    IJKFFOptions *options =  [[IJKFFOptions alloc] init];
    if(isVideoToolBox){
        [options setPlayerOptionValue:@"fcc-_es2"          forKey:@"overlay-format"];
        [options setPlayerOptionIntValue:1      forKey:@"videotoolbox"];
        //[options setPlayerOptionIntValue:4096    forKey:@"videotoolbox-max-frame-width"];
    }else{
        //     [options setPlayerOptionValue:@"fcc-rv24"          forKey:@"overlay-format"];
        [options setPlayerOptionIntValue:0      forKey:@"videotoolbox"];
        [options setPlayerOptionValue:@"fcc-i420"          forKey:@"overlay-format"];
        
        
    }
    
    //disable audio
    //[options setPlayerOptionIntValue:1 forKey:@"vn"];
    
    
    //[options setPlayerOptionIntValue:30     forKey:@"max-fps"];
    [options setPlayerOptionValue:0        forKey:@"start-on-prepared"];
    [options setCodecOptionIntValue:0 forKey:@"is_avc"];
    //[options setPlayerOptionIntValue:1      forKey:@"framedrop"];
    
    
    decoder->controller = [[IJKFFMoviePlayerController alloc] initWithContentURLString:path
                                                                           withOptions:options
                                                                        isVideotoolbox:isVideoToolBox
                                                                                glView:glview];
    decoder->controller.delegate = decoder->eventReceiver;
    return 0;
}

static void releaseCacheFrames(IjkFfplayDecoder* decoder) {
    IjkVideoFrame* frame = NULL;
    for(int i = 0; i < MAC_IJK_VTB_MAX_CACHE_FRAME_SIZE; i++) {
        frame = &decoder->cacheVideoFrames[i];
        if(frame->data[0] != NULL) {
            free(frame->data[0]);
        }
    }
    memset(decoder->cacheVideoFrames, 0, sizeof(decoder->cacheVideoFrames));
}

int ijkFfplayDecoder_prepare(IjkFfplayDecoder* decoder) {
    if(decoder == NULL) {
        return -1;
    }
    releaseCacheFrames(decoder);
    [decoder->controller prepareToPlay];
    return 0;
}

int ijkFfplayDecoder_start(IjkFfplayDecoder* decoder) {
    if(decoder == NULL) {
        return -1;
    }
    [decoder->controller play];
    return 0;
}

int ijkFfplayDecoder_pause(IjkFfplayDecoder* decoder) {
    if(decoder == NULL) {
        return -1;
    }
    [decoder->controller pause];
    return 0;
}

int ijkFfplayDecoder_stop(IjkFfplayDecoder* decoder) {
    if(decoder == NULL) {
        return -1;
    }
    [decoder->controller stop];
    return 0;
}

int ijkFfplayDecoder_seekTo(IjkFfplayDecoder* decoder, long msec) {
    if(decoder == NULL) {
        return -1;
    }
    [decoder->controller setCurrentPlaybackTime:msec];
    return 0;
}

bool ijkFfplayDecoder_isPlaying(IjkFfplayDecoder* decoder) {
    if(decoder == NULL) {
        return -1;
    }
    return [decoder->controller isPlaying];
}

long ijkFfplayDecoder_getCurrentPosition(IjkFfplayDecoder* decoder) {
    if(decoder == NULL) {
        return -1;
    }
    return decoder->controller.currentPlaybackTime;
}

long ijkFfplayDecoder_getDuration(IjkFfplayDecoder* decoder) {
    if(decoder == NULL) {
        return -1;
    }
    return decoder->controller.duration;
}

int ijkFfplayDecoder_release(IjkFfplayDecoder* decoder) {
    if(decoder == NULL) {
        return -1;
    }
    [decoder->controller shutdown];
    releaseCacheFrames(decoder);
    NSLog(@"ijk release cache frames!");
    return 0;
}

int ijkFfplayDecoder_setVolume(IjkFfplayDecoder* decoder, float volume) {
    if(decoder == NULL) {
        return -1;
    }
    [decoder->controller setVolume:volume];
    return 0;
}

float ijkFfplayDecoder_getVolume(IjkFfplayDecoder* decoder) {
    if(decoder == NULL) {
        return -1;
    }
    return [decoder->controller getVolume];
}

int ijkFfplayDecoder_setOptionLongValue(IjkFfplayDecoder* decoder, int opt_category, const char* key, long value) {
    if(decoder == NULL) {
        return -1;
    }
//    [decoder->controller setOptionValue:value forKey:[NSString stringWithUTF8String:key] ofCategory:<#(IJKFFOptionCategory)#>];
    return 0;
}

int ijkFfplayDecoder_setOptionStringValue(IjkFfplayDecoder* decoder, int opt_category, const char* key, const char* value) {
    if(decoder == NULL) {
        return -1;
    }
    return 0;
}

int ijkFfplayDecoder_getVideoCodecInfo(IjkFfplayDecoder* decoder, char **codec_info) {
    if(decoder == NULL) {
        return -1;
    }
    return 0;
}

int ijkFfplayDecoder_getAudioCodecInfo(IjkFfplayDecoder* decoder, char **codec_info) {
    if(decoder == NULL) {
        return -1;
    }
    return 0;
}

long ijkFfplayDecoder_getPropertyLong(IjkFfplayDecoder* decoder, int optionId, long default_value) {
    if(decoder == NULL) {
        return -1;
    }
    return 0l;
}

float ijkFfplayDecoder_getPropertyFloat(IjkFfplayDecoder* decoder, int optionId, float default_value) {
    if(decoder == NULL) {
        return -1;
    }
    return 0.0;
}

int ijkFfplayDecoder_getMediaMeta(IjkFfplayDecoder* decoder, IjkMetadata* metadata) {
    if(decoder == NULL) {
        return -1;
    }
    NSDictionary * mediaDicts = [decoder->controller getMediaMeta];
    if(mediaDicts != nil) {
        metadata->duration_ms = decoder->controller.duration;
        
        const char* comment = [[mediaDicts objectForKey:@"comment"]UTF8String];
        if(comment != NULL) {
            memcpy(metadata->comment, comment, strlen(comment));
        }
        
        const char* original_format = [[mediaDicts objectForKey:@"original_format"]UTF8String];
        if(original_format != NULL) {
            memcpy(metadata->original_format, original_format, strlen(original_format));
        }
        
        const char* lens_param = [[mediaDicts objectForKey:@"lens_param"]UTF8String];
        if(lens_param != NULL) {
            memcpy(metadata->lens_param, lens_param, strlen(lens_param));
        }
        
        const char* device_sn = [[mediaDicts objectForKey:@"device_sn"]UTF8String];
        if(device_sn != NULL) {
            memcpy(metadata->device_sn, device_sn, strlen(device_sn));
        }
        
        const char* cdn_ip = [[mediaDicts objectForKey:@"cdn_ip"]UTF8String];
        if(cdn_ip != NULL) {
            memcpy(metadata->cdn_ip, cdn_ip, strlen(cdn_ip));
        }
    }
    
    NSDictionary * videoDicts = decoder->controller.monitor.videoMeta;
    if(videoDicts != nil) {
        metadata->video_bitrate = [[videoDicts objectForKey:@IJKM_KEY_BITRATE] intValue];
        metadata->width = [[videoDicts objectForKey:@IJKM_KEY_WIDTH] intValue];
        metadata->height = [[videoDicts objectForKey:@IJKM_KEY_HEIGHT]intValue];
        
        const char* videoCodecName = [[videoDicts objectForKey:@IJKM_KEY_CODEC_NAME] UTF8String];
        if(videoCodecName != NULL) {
            memcpy(metadata->video_code_name, videoCodecName, strlen(videoCodecName));
        }
        
        const char* videoCodecLongName = [[videoDicts objectForKey:@IJKM_KEY_CODEC_LONG_NAME] UTF8String];
        if(videoCodecLongName != NULL) {
            memcpy(metadata->video_code_long_name, videoCodecLongName, strlen(videoCodecLongName));
        }
        metadata->video_fps_den = [[videoDicts objectForKey:@IJKM_KEY_FPS_DEN]intValue];
        metadata->video_fps_num = [[videoDicts objectForKey:@IJKM_KEY_FPS_NUM]intValue];
        metadata->video_tbr_den = [[videoDicts objectForKey:@IJKM_KEY_TBR_DEN]intValue];
        metadata->video_tbr_num = [[videoDicts objectForKey:@IJKM_KEY_TBR_NUM]intValue];
    }
    
    NSDictionary * audioDicts = decoder->controller.monitor.audioMeta;
    if(audioDicts != nil) {
        metadata->audio_bitrate = [[audioDicts objectForKey:@IJKM_KEY_BITRATE] intValue];
        
        const char* audioCodecName = [[audioDicts objectForKey:@IJKM_KEY_CODEC_NAME] UTF8String];
        if(audioCodecName != NULL) {
            memcpy(metadata->audio_code_name, audioCodecName, strlen(audioCodecName));
        }
        
        const char* audioCodecLongName = [[audioDicts objectForKey:@IJKM_KEY_CODEC_LONG_NAME] UTF8String];
        if(audioCodecLongName != NULL){
            memcpy(metadata->audio_code_long_name, audioCodecLongName, strlen(audioCodecLongName));
        }
        
        metadata->audio_samples_per_sec = [[audioDicts objectForKey:@IJKM_KEY_SAMPLE_RATE]intValue];
        metadata->audio_channel_layout = [[audioDicts objectForKey:@IJKM_KEY_CHANNEL_LAYOUT]intValue];
    }
    
    return 0;
}

//decoder_name: h264_vtb
int ijkFfplayDecoder_setHwDecoderName(IjkFfplayDecoder* decoder, const char* decoder_name) {
    if(decoder == NULL) {
        return -1;
    }
    if(decoder_name == NULL) {
        decoder_name = MAC_DECODER_NAME_SOFT;
    }
    int length = strlen(decoder_name);
    if(length > MAC_MAX_DECODER_NAME_LENGTH) {
        return -1;
    }
    memset(decoder->codecName, 0, sizeof(decoder->codecName));
    strcpy(decoder->codecName, decoder_name);
    return 0;
}
