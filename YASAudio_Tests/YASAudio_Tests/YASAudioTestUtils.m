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
@end
