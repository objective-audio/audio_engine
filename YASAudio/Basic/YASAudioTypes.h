//
//  YASAudioTypes.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import <AudioUnit/AUComponent.h>

#ifndef __YASAudio_YASAudioTypes_h
#define __YASAudio_YASAudioTypes_h

@class YASAudioWritablePCMBuffer, YASAudioTime;

typedef NS_ENUM(NSUInteger, YASAudioBitDepthFormat) {
    YASAudioBitDepthFormatOther = 0,
    YASAudioBitDepthFormatFloat32 = 1,
    YASAudioBitDepthFormatFloat64 = 2,
    YASAudioBitDepthFormatInt16 = 3,
    YASAudioBitDepthFormatInt32 = 4
};

typedef NS_ENUM(NSUInteger, YASAudioUnitRenderType) {
    YASAudioUnitRenderTypeNormal,
    YASAudioUnitRenderTypeInput,
    YASAudioUnitRenderTypeNotify,
    YASAudioUnitRenderTypeUnknown,
};

typedef struct YASAudioUnitRenderParameters {
    YASAudioUnitRenderType inRenderType;
    AudioUnitRenderActionFlags *ioActionFlags;
    const AudioTimeStamp *ioTimeStamp;
    UInt32 inBusNumber;
    UInt32 inNumberFrames;
    AudioBufferList *ioData;
} YASAudioUnitRenderParameters;

typedef void (^YASAudioUnitCallbackBlock)(YASAudioUnitRenderParameters *renderParameters);
typedef void (^YASAudioDeviceIOCallbackBlock)(YASAudioWritablePCMBuffer *outBuffer, YASAudioTime *when);
typedef void (^YASAudioNodeRenderBlock)(YASAudioWritablePCMBuffer *buffer, NSNumber *bus, YASAudioTime *when,
                                        id nodeCore);
typedef void (^YASAudioOfflineRenderCallbackBlock)(YASAudioWritablePCMBuffer *buffer, YASAudioTime *when, BOOL *stop);
typedef void (^YASAudioOfflineRenderCompletionBlock)(BOOL cancelled);

#endif
