//
//  YASAudioTestUtils.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioTestUtils.h"

UInt32 TestValue(UInt32 frame, UInt32 channel, UInt32 buffer)
{
    return frame + 1024 * (channel + 1) + 512 * (buffer + 1);
}

@implementation YASAudioTestUtils

+ (void)fillTestValuesToData:(YASAudioData *)data
{
    YASAudioBitDepthFormat bitDepthFormat = data.format.bitDepthFormat;

    for (UInt32 buffer = 0; buffer < data.bufferCount; buffer++) {
        YASAudioPointer pointer = [data pointerAtBuffer:buffer];
        for (UInt32 frame = 0; frame < data.frameLength; frame++) {
            for (UInt32 ch = 0; ch < data.stride; ch++) {
                UInt32 index = frame * data.stride + ch;
                UInt32 value = TestValue(frame, ch, buffer);
                switch (bitDepthFormat) {
                    case YASAudioBitDepthFormatFloat32: {
                        pointer.f32[index] = value;
                    } break;
                    case YASAudioBitDepthFormatFloat64: {
                        pointer.f64[index] = value;
                    } break;
                    case YASAudioBitDepthFormatInt16: {
                        pointer.i16[index] = value;
                    } break;
                    case YASAudioBitDepthFormatInt32: {
                        pointer.i32[index] = value;
                    } break;
                    default:
                        break;
                }
            }
        }
    }
}

+ (BOOL)isClearedDataWithBuffer:(YASAudioData *)data
{
    const AudioBufferList *abl = data.audioBufferList;

    for (UInt32 buffer = 0; buffer < abl->mNumberBuffers; buffer++) {
        Byte *ptr = abl->mBuffers[buffer].mData;
        for (UInt32 frame = 0; frame < abl->mBuffers[buffer].mDataByteSize; frame++) {
            if (ptr[frame] != 0) {
                return NO;
            }
        }
    }

    return YES;
}

+ (YASAudioPointer)dataPointerWithData:(YASAudioData *)data channel:(UInt32)channel frame:(UInt32)frame
{
    YASAudioFrameScanner *scanner = [[YASAudioFrameScanner alloc] initWithAudioData:data];
    [scanner setFramePosition:frame];
    [scanner setChannelPosition:channel];

    YASAudioPointer pointer = {scanner.pointer->v};

    YASRelease(scanner);

    return pointer;
}

+ (BOOL)compareDataFlexiblyWithData:(YASAudioData *)data1 otherData:(YASAudioData *)data2
{
    if (data1.format.channelCount != data2.format.channelCount) {
        return NO;
    }

    if (data1.frameLength != data2.frameLength) {
        return NO;
    }

    if (data1.format.sampleByteCount != data2.format.sampleByteCount) {
        return NO;
    }

    if (data1.format.bitDepthFormat != data2.format.bitDepthFormat) {
        return NO;
    }

    for (UInt32 ch = 0; ch < data1.format.channelCount; ch++) {
        for (UInt32 frame = 0; frame < data1.frameLength; frame++) {
            YASAudioPointer ptr1 = [YASAudioTestUtils dataPointerWithData:data1 channel:ch frame:frame];
            YASAudioPointer ptr2 = [YASAudioTestUtils dataPointerWithData:data2 channel:ch frame:frame];
            if (!YASAudioIsEqualData(ptr1.v, ptr2.v, data1.format.sampleByteCount)) {
                return NO;
            }
        }
    }

    return YES;
}

@end
