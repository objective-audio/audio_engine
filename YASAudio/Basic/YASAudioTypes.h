//
//  YASAudioTypes.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <AudioUnit/AUComponent.h>

typedef enum {
    YASAudioPCMFormatOther = 0,
    YASAudioPCMFormatFloat32 = 1,
    YASAudioPCMFormatFloat64 = 2,
    YASAudioPCMFormatInt16 = 3,
    YASAudioPCMFormatFixed824 = 4
} YASAudioPCMFormat;

typedef enum {
    YASAudioUnitRenderTypeNormal,
    YASAudioUnitRenderTypeInput,
    YASAudioUnitRenderTypeNotify,
    YASAudioUnitRenderTypeUnknown,
} YASAudioUnitRenderType;

typedef union {
    void *v;
    struct {
        UInt8 graph;
        UInt16 unit;
    };
} YASAudioRenderID;

typedef struct {
    YASAudioUnitRenderType inRenderType;
    AudioUnitRenderActionFlags *ioActionFlags;
    const AudioTimeStamp *ioTimeStamp;
    UInt32 inBusNumber;
    UInt32 inNumberFrames;
    AudioBufferList *ioData;
    YASAudioRenderID renderID;
} YASAudioUnitRenderParameters;

typedef union {
    void *v;
    Float32 *f32;
    Float64 *f64;
    SInt16 *i16;
    SInt32 *i32;
    SInt8 *i8;
    UInt8 *u8;
} YASAudioPointer;
