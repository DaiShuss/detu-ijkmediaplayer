/*
 * ijksdl_vout_ios_gles2.c
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

#import "ijksdl_vout_ios_gles2.h"

#include <assert.h>
#include "ijksdl/ijksdl_vout.h"
#include "ijksdl/ijksdl_vout_internal.h"
#include "ijksdl/ffmpeg/ijksdl_vout_overlay_ffmpeg.h"
#include "ijksdl_vout_overlay_videotoolbox.h"

#include "ijk_frame.h"


typedef struct SDL_VoutSurface_Opaque {
    SDL_Vout *vout;
} SDL_VoutSurface_Opaque;

struct SDL_Vout_Opaque {
    VideoGLView *gl_view;
};

static SDL_VoutOverlay *vout_create_overlay_l(int width, int height, int frame_format, SDL_Vout *vout)
{
    switch (frame_format) {
        case IJK_AV_PIX_FMT__VIDEO_TOOLBOX:
            return SDL_VoutVideoToolBox_CreateOverlay(width, height, vout);
        default:
            return SDL_VoutFFmpeg_CreateOverlay(width, height, frame_format, vout);
    }
}

static SDL_VoutOverlay *vout_create_overlay(int width, int height, int frame_format, SDL_Vout *vout)
{
    SDL_LockMutex(vout->mutex);
    SDL_VoutOverlay *overlay = vout_create_overlay_l(width, height, frame_format, vout);
    SDL_UnlockMutex(vout->mutex);
    return overlay;
}

static void vout_free_l(SDL_Vout *vout)
{
    if (!vout)
        return;
    
    SDL_Vout_Opaque *opaque = vout->opaque;
    if (opaque) {
        if (opaque->gl_view) {
            // TODO: post to MainThread?
            [opaque->gl_view release];
            opaque->gl_view = nil;
        }
    }
    
    SDL_Vout_FreeInternal(vout);
}

static void bbb(SDL_Vout *vout, IjkVideoFrame *overlay) {
    VideoGLView *openGLView = vout->opaque->gl_view;
    RcFrame frame = {0};
    frame.data[0] = overlay->data[0];
    frame.data[1] = overlay->data[1];
    frame.data[2] = overlay->data[2];
    frame.linesize[0] = overlay->linesize[0];
    frame.linesize[1] = overlay->linesize[1];
    frame.linesize[2] = overlay->linesize[2];
    frame.width = overlay->w;
    frame.height = overlay->h;
    switch(overlay->format) {
        case PIX_FMT_YUV420P:
            frame.format = FMT_YUV420P;
            frame.planes = 3;
            break;
        case PIX_FMT_NV12:
            frame.format = FMT_NV12;
            frame.planes = 2;
            break;
        default:
            break;
    }
    [openGLView setImage:&frame];
}

void aaa(SDL_Vout *vout, SDL_VoutOverlay* overlay) {
    if (overlay == NULL) {
        return;
    }
    IjkVideoFrame videoFrame = {0};
    
    //软解数据,YUV420P
    videoFrame.w = overlay->w;
    videoFrame.h = overlay->h;
    videoFrame.format = PIX_FMT_YUV420P;
    int planes = 3;
    videoFrame.planes = planes;
    for(int i = 0; i< planes; i++) {
        videoFrame.data[i] = overlay->pixels[i];
        videoFrame.linesize[i] = overlay->pitches[i];
        bbb(vout, &videoFrame);
    }
}

static int vout_display_overlay_l(SDL_Vout *vout, SDL_VoutOverlay *overlay)
{
    SDL_Vout_Opaque *opaque = vout->opaque;
    VideoGLView *gl_view = opaque->gl_view;
    
    if (!gl_view) {
        return -1;
    }
    
    if (!overlay) {
        ALOGE("vout_display_overlay_l: NULL overlay\n");
        return -1;
    }
    
    if (overlay->w <= 0 || overlay->h <= 0) {
        ALOGE("vout_display_overlay_l: invalid overlay dimensions(%d, %d)\n", overlay->w, overlay->h);
        return -1;
    }
    
    if (overlay == NULL) {
        return 0;
    }
    
    aaa(vout, overlay);
    
    return 0;
}

static int vout_display_overlay(SDL_Vout *vout, SDL_VoutOverlay *overlay)
{
    @autoreleasepool {
        SDL_LockMutex(vout->mutex);
        int retval = vout_display_overlay_l(vout, overlay);
        SDL_UnlockMutex(vout->mutex);
        return retval;
    }
}

SDL_Vout *SDL_VoutIos_CreateForGLES2()
{
    SDL_Vout *vout = SDL_Vout_CreateInternal(sizeof(SDL_Vout_Opaque));
    if (!vout)
        return NULL;
    
    SDL_Vout_Opaque *opaque = vout->opaque;
    opaque->gl_view = nil;
    vout->create_overlay = vout_create_overlay;
    vout->free_l = vout_free_l;
    vout->display_overlay = vout_display_overlay;
    
    return vout;
}

static void SDL_VoutIos_SetGLView_l(SDL_Vout *vout, VideoGLView *view)
{
    SDL_Vout_Opaque *opaque = vout->opaque;
    
    if (opaque->gl_view == view)
        return;
    
    if (opaque->gl_view) {
        [opaque->gl_view release];
        opaque->gl_view = nil;
    }
    
    if (view)
        opaque->gl_view = [view retain];
}

void SDL_VoutIos_SetGLView(SDL_Vout *vout, VideoGLView *view)
{
    SDL_LockMutex(vout->mutex);
    SDL_VoutIos_SetGLView_l(vout, view);
    SDL_UnlockMutex(vout->mutex);
}
