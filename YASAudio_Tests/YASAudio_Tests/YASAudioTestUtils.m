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
    YASAudioFormat *format = data.format;
    const YASAudioBitDepthFormat bitDepthFormat = format.bitDepthFormat;
    const UInt32 bufferCount = format.bufferCount;
    const UInt32 stride = format.stride;

    for (UInt32 buffer = 0; buffer < bufferCount; buffer++) {
        YASAudioMutablePointer pointer = [data pointerAtBuffer:buffer];
        for (UInt32 frame = 0; frame < data.frameLength; frame++) {
            for (UInt32 ch = 0; ch < stride; ch++) {
                UInt32 index = frame * stride + ch;
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
                    case YASAudioBitDepthFormatFixed824: {
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

+ (YASAudioMutablePointer)mutablePointerWithData:(YASAudioData *)data channel:(UInt32)channel frame:(UInt32)frame
{
    YASAudioMutableFrameScanner *scanner = [[YASAudioMutableFrameScanner alloc] initWithAudioData:data];
    [scanner setFramePosition:frame];
    [scanner setChannelPosition:channel];

    YASAudioMutablePointer pointer = *scanner.mutablePointer;

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
            YASAudioMutablePointer ptr1 = [YASAudioTestUtils mutablePointerWithData:data1 channel:ch frame:frame];
            YASAudioMutablePointer ptr2 = [YASAudioTestUtils mutablePointerWithData:data2 channel:ch frame:frame];
            if (!YASAudioIsEqualData(ptr1.v, ptr2.v, data1.format.sampleByteCount)) {
                return NO;
            }
        }
    }

    return YES;
}

+ (BOOL)isFilledData:(YASAudioData *)data
{
    __block BOOL isFilled = YES;
    const NSUInteger sampleByteCount = data.format.sampleByteCount;
    NSData *zeroData = [NSMutableData dataWithLength:sampleByteCount];
    const void *zeroBytes = [zeroData bytes];

    YASAudioFrameScanner *scanner = [[YASAudioFrameScanner alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = scanner.pointer;

    while (pointer->v) {
        if (YASAudioIsEqualData(pointer->v, zeroBytes, sampleByteCount)) {
            isFilled = NO;
            YASAudioFrameScannerStop(scanner);
        }
        YASAudioFrameScannerMove(scanner);
    }

    YASRelease(scanner);

    return isFilled;
}

+ (void)audioUnitRenderOnSubThreadWithAudioUnit:(YASAudioUnit *)audioUnit
                                         format:(YASAudioFormat *)format
                                    frameLength:(const UInt32)frameLength
                                          count:(const NSUInteger)count
                                           wait:(const NSTimeInterval)wait
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AudioUnitRenderActionFlags actionFlags = 0;
        YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];

        for (NSInteger i = 0; i < count; i++) {
            YASAudioTime *audioTime = [YASAudioTime timeWithSampleTime:frameLength * i atRate:format.sampleRate];
            AudioTimeStamp timeStamp = audioTime.audioTimeStamp;

            YASAudioUnitRenderParameters parameters = {
                .inRenderType = YASAudioUnitRenderTypeNormal,
                .ioActionFlags = &actionFlags,
                .ioTimeStamp = &timeStamp,
                .inBusNumber = 0,
                .inNumberFrames = frameLength,
                .ioData = data.mutableAudioBufferList,
            };

            [audioUnit audioUnitRender:&parameters];
        }

        YASRelease(data);
    });

    if (wait > 0) {
        [NSThread sleepForTimeInterval:wait];
    }
}

@end
