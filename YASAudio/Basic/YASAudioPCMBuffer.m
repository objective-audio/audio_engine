//
//  YASAudioBuffer.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioPCMBuffer.h"
#import "YASAudioFormat.h"
#import "YASAudioUtility.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"

#if (!TARGET_OS_IPHONE && TARGET_OS_MAC)
#import "YASAudioChannelRoute.h"
#endif

typedef NS_ENUM(NSUInteger, YASAudioPCMBufferFreeType) {
    YASAudioPCMBufferFreeTypeNone,
    YASAudioPCMBufferFreeTypeFull,
    YASAudioPCMBufferFreeTypeWithoutData,
};

@interface YASAudioPCMBuffer ()
@property (nonatomic, strong) YASAudioFormat *format;
@property (nonatomic) UInt32 frameLength;
@property (nonatomic) AudioBufferList *mutableAudioBufferList;
@end

@implementation YASAudioPCMBuffer {
    YASAudioPCMBufferFreeType _freeType;
    AudioBufferList *_audioBufferList;
}

- (instancetype)initWithPCMFormat:(YASAudioFormat *)format
                  audioBufferList:(const AudioBufferList *)audioBufferList
                        needsFree:(BOOL)needsFree
{
    self = [super init];
    if (self) {
        if (!format || !audioBufferList) {
            YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil", __PRETTY_FUNCTION__]));
            YASRelease(self);
            return nil;
        }

        _freeType = needsFree ? YASAudioPCMBufferFreeTypeFull : YASAudioPCMBufferFreeTypeNone;
        _audioBufferList = (AudioBufferList *)audioBufferList;
        self.format = format;

        UInt32 bytesPerFrame = format.streamDescription->mBytesPerFrame;
        UInt32 frameCapacity = audioBufferList->mBuffers[0].mDataByteSize / bytesPerFrame;
        _frameCapacity = frameCapacity;
        _frameLength = frameCapacity;
    }
    return self;
}

#if (!TARGET_OS_IPHONE && TARGET_OS_MAC)

- (instancetype)initWithPCMFormat:(YASAudioFormat *)format
                           buffer:(YASAudioPCMBuffer *)buffer
              outputChannelRoutes:(NSArray *)channelRoutes
{
    return [self _initWithPCMFormat:format buffer:buffer channelRoutes:channelRoutes isOutput:YES];
}

- (instancetype)initWithPCMFormat:(YASAudioFormat *)format
                           buffer:(YASAudioPCMBuffer *)buffer
               inputChannelRoutes:(NSArray *)channelRoutes
{
    return [self _initWithPCMFormat:format buffer:buffer channelRoutes:channelRoutes isOutput:NO];
}

- (instancetype)_initWithPCMFormat:(YASAudioFormat *)format
                            buffer:(YASAudioPCMBuffer *)buffer
                     channelRoutes:(NSArray *)channelRoutes
                          isOutput:(BOOL)isOutput
{
    self = [super init];
    if (self) {
        if (!format || !buffer || !channelRoutes) {
            YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
            YASRelease(self);
            return nil;
        }

        if (format.channelCount != channelRoutes.count || format.isInterleaved) {
            YASRaiseWithReason(([NSString stringWithFormat:@"%s - Invalid format.", __PRETTY_FUNCTION__]));
            YASRelease(self);
            return nil;
        }

        _freeType = YASAudioPCMBufferFreeTypeWithoutData;
        _audioBufferList = YASAudioAllocateAudioBufferListWithoutData(format.bufferCount, format.stride);
        self.format = format;

        const AudioBufferList *audioBufferList = buffer.audioBufferList;
        UInt32 bytesPerFrame = format.streamDescription->mBytesPerFrame;
        UInt32 frameCapacity = 0;

        for (UInt32 i = 0; i < format.channelCount; i++) {
            YASAudioChannelRoute *route = channelRoutes[i];
            UInt32 fromChannel = isOutput ? route.destinationChannel : route.sourceChannel;
            UInt32 toChannel = isOutput ? route.sourceChannel : route.destinationChannel;
            _audioBufferList->mBuffers[toChannel].mData = audioBufferList->mBuffers[fromChannel].mData;
            _audioBufferList->mBuffers[toChannel].mDataByteSize = audioBufferList->mBuffers[fromChannel].mDataByteSize;
            UInt32 frameLength = audioBufferList->mBuffers[0].mDataByteSize / bytesPerFrame;
            if (frameCapacity == 0) {
                frameCapacity = frameLength;
            } else if (frameCapacity != frameLength) {
                YASRaiseWithReason(([NSString stringWithFormat:@"%s - Invalid frame length.", __PRETTY_FUNCTION__]));
            }
        }

        _frameCapacity = frameCapacity;
        _frameLength = frameCapacity;
    }
    return self;
}

#endif

- (id)copyWithZone:(NSZone *)zone
{
    YASAudioPCMBuffer *buffer =
        [[self.class allocWithZone:zone] initWithPCMFormat:self.format frameCapacity:_frameCapacity];
    YASAudioCopyAudioBufferListDirectly(self.audioBufferList, buffer.mutableAudioBufferList);
    buffer.frameLength = _frameLength;
    return buffer;
}

- (void)dealloc
{
    if (_audioBufferList) {
        switch (_freeType) {
            case YASAudioPCMBufferFreeTypeFull:
                YASAudioRemoveAudioBufferList(_audioBufferList);
                break;
            case YASAudioPCMBufferFreeTypeWithoutData:
                YASAudioRemoveAudioBufferListWithoutData(_audioBufferList);
                break;
            default:
                break;
        }
        _audioBufferList = nil;
    }

    YASRelease(_format);

    _format = nil;

    YASSuperDealloc;
}

- (const AudioBufferList *)audioBufferList
{
    return _audioBufferList;
}

- (AudioBufferList *)mutableAudioBufferList
{
    return _audioBufferList;
}

- (void)setFrameLength:(UInt32)frameLength
{
    if (frameLength > _frameCapacity) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Frame length is over capacity.", __PRETTY_FUNCTION__]));
        return;
    }

    if (_frameLength != frameLength) {
        _frameLength = frameLength;
    }
    UInt32 bytesPerFrame = self.format.streamDescription->mBytesPerFrame;
    UInt32 dataByteSize = frameLength * bytesPerFrame;
    YASAudioSetDataByteSizeToAudioBufferList(self.mutableAudioBufferList, dataByteSize);
}

- (UInt32)bufferCount
{
    return self.audioBufferList->mNumberBuffers;
}

- (UInt32)stride
{
    return self.audioBufferList->mBuffers[0].mNumberChannels;
}

- (const void *)dataAtBufferIndex:(NSUInteger)index
{
    return [self _dataWithBitDepthFormat:self.format.bitDepthFormat atBufferIndex:index];
}

- (Float64)valueAtBufferIndex:(UInt32)bufferIndex channel:(UInt32)channel frame:(UInt32)frame
{
    const YASAudioBitDepthFormat bitDepthFormat = self.format.bitDepthFormat;
    const UInt32 stride = self.stride;
    const UInt32 frameLength = self.frameLength;
    const UInt32 sampleByteCount = self.format.sampleByteCount;

    if (channel >= stride) {
        YASRaiseWithReason(
            ([NSString stringWithFormat:@"%s - Overflow channel(%@).", __PRETTY_FUNCTION__, @(channel)]));
        return 0;
    }

    if (frame >= frameLength) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Overflow frame(%@).", __PRETTY_FUNCTION__, @(frame)]));
        return 0;
    }

    Byte *data = [self _dataWithBitDepthFormat:bitDepthFormat atBufferIndex:bufferIndex];
    void *ptr = &data[(stride * frame + channel) * sampleByteCount];

    switch (bitDepthFormat) {
        case YASAudioBitDepthFormatFloat32:
            return *((Float32 *)ptr);
        case YASAudioBitDepthFormatFloat64:
            return *((Float64 *)ptr);
        case YASAudioBitDepthFormatInt16:
            return (Float64)(*((SInt16 *)ptr)) / INT16_MAX;
        case YASAudioBitDepthFormatInt32:
            return (Float64)(*((SInt32 *)ptr)) / INT32_MAX;
        default:
            break;
    }

    return 0;
}

- (void)readDataUsingBlock:(YASAudioPCMBufferReadBlock)readDataBlock
{
    if (!readDataBlock) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return;
    }

    const YASAudioBitDepthFormat bitDepthFormat = self.format.bitDepthFormat;
    for (UInt32 i = 0; i < self.bufferCount; i++) {
        readDataBlock([self _dataWithBitDepthFormat:bitDepthFormat atBufferIndex:i], i);
    }
}

- (void *)_dataWithBitDepthFormat:(YASAudioBitDepthFormat)bitDepthFormat atBufferIndex:(NSUInteger)index
{
    if (_format.bitDepthFormat != bitDepthFormat) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Invalid bit depth format.", __PRETTY_FUNCTION__]));
        return nil;
    } else if (index >= self.audioBufferList->mNumberBuffers) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Out of range.", __PRETTY_FUNCTION__]));
        return nil;
    }

    return self.audioBufferList->mBuffers[index].mData;
}

- (void)enumerateReadValuesUsingBlock:(YASAudioPCMBufferReadValueBlock)readValueBlock
{
    if (!readValueBlock) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return;
    }

    const YASAudioBitDepthFormat bitDepthFormat = self.format.bitDepthFormat;
    const UInt32 sampleByteCount = self.format.sampleByteCount;
    const UInt32 frameLength = self.frameLength;
    const UInt32 stride = self.stride;
    const UInt32 bufferCount = self.bufferCount;
    const Byte *datas[bufferCount];

    for (UInt32 i = 0; i < bufferCount; i++) {
        datas[i] = [self _dataWithBitDepthFormat:bitDepthFormat atBufferIndex:i];
    }

    for (UInt32 frame = 0; frame < frameLength; frame++) {
        for (UInt32 ch = 0; ch < stride; ch++) {
            for (UInt32 bufferIndex = 0; bufferIndex < self.bufferCount; bufferIndex++) {
                const void *ptr = &datas[bufferIndex][(stride * frame + ch) * sampleByteCount];
                Float64 value = 0;
                switch (bitDepthFormat) {
                    case YASAudioBitDepthFormatFloat32: {
                        value = *((Float32 *)ptr);
                    } break;
                    case YASAudioBitDepthFormatFloat64: {
                        value = *((Float64 *)ptr);
                    } break;
                    case YASAudioBitDepthFormatInt16: {
                        value = (Float64)(*((SInt16 *)ptr)) / INT16_MAX;
                    } break;
                    case YASAudioBitDepthFormatInt32: {
                        value = (Float64)(*((SInt32 *)ptr)) / INT32_MAX;
                    } break;
                    default:
                        break;
                }
                @autoreleasepool
                {
                    readValueBlock(value, bufferIndex, ch, frame);
                }
            }
        }
    }
}

- (BOOL)copyDataFlexiblyToAudioBufferList:(AudioBufferList *)toAudioBufferList
{
    if (!toAudioBufferList) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is null.", __PRETTY_FUNCTION__]));
        return NO;
    }

    const AudioBufferList *fromAudioBufferList = self.audioBufferList;
    const UInt32 sampleByteCount = self.format.sampleByteCount;

    return YASAudioCopyAudioBufferListFlexibly(fromAudioBufferList, toAudioBufferList, sampleByteCount, NULL);
}

@end

@implementation YASAudioWritablePCMBuffer

- (instancetype)initWithPCMFormat:(YASAudioFormat *)format frameCapacity:(UInt32)frameCapacity
{
    BOOL interleaved = format.isInterleaved;
    UInt32 bufferCount = interleaved ? 1 : format.channelCount;
    UInt32 stride = interleaved ? format.channelCount : 1;
    UInt32 bytesPerFrame = format.streamDescription->mBytesPerFrame;
    AudioBufferList *audioBufferList =
        YASAudioAllocateAudioBufferList(bufferCount, stride, frameCapacity * bytesPerFrame);

    return [self initWithPCMFormat:format audioBufferList:audioBufferList needsFree:YES];
}

- (instancetype)initWithPCMFormat:(YASAudioFormat *)format
           mutableAudioBufferList:(AudioBufferList *)audioBufferList
                        needsFree:(BOOL)needsFree
{
    return [super initWithPCMFormat:format audioBufferList:audioBufferList needsFree:needsFree];
}

- (void *)writableDataAtBufferIndex:(NSUInteger)index
{
    return [self _dataWithBitDepthFormat:self.format.bitDepthFormat atBufferIndex:index];
}

- (void)clearData
{
    self.frameLength = self.frameCapacity;
    YASAudioClearAudioBufferList(self.mutableAudioBufferList);
}

- (void)clearDataWithStartFrame:(UInt32)frame length:(UInt32)length
{
    if ((frame + length) > self.frameLength) {
        YASRaiseWithReason(
            ([NSString stringWithFormat:@"%s - Out of range (frame = %@ / length = %@ / frameLength = %@).",
                                        __PRETTY_FUNCTION__, @(frame), @(length), @(self.frameLength)]));
        return;
    }

    UInt32 bytesPerFrame = self.format.streamDescription->mBytesPerFrame;

    for (UInt32 i = 0; i < self.bufferCount; i++) {
        Byte *data = self.audioBufferList->mBuffers[i].mData;
        memset(&data[frame * bytesPerFrame], 0, length * bytesPerFrame);
    }
}

- (BOOL)copyDataFromBuffer:(YASAudioPCMBuffer *)fromBuffer
{
    return [self copyDataFromBuffer:fromBuffer fromStartFrame:0 toStartFrame:0 length:fromBuffer.frameLength];
}

- (BOOL)copyDataFromBuffer:(YASAudioPCMBuffer *)fromBuffer
            fromStartFrame:(UInt32)fromFrame
              toStartFrame:(UInt32)toFrame
                    length:(UInt32)length
{
    if (!fromBuffer) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is null.", __PRETTY_FUNCTION__]));
        return NO;
    }

    if (![fromBuffer.format isEqualToAudioFormat:self.format]) {
        YASLog(@"%s - Format is not equal.", __PRETTY_FUNCTION__);
        return NO;
    }

    if (((toFrame + length) > self.frameLength) || ((fromFrame + length) > fromBuffer.frameLength)) {
        YASLog(@"%s - Out of range (toFrame = %@ / fromFrame = %@ / length = %@ / toFrameLength = %@ / fromFrameLength "
               @"= %@).",
               __PRETTY_FUNCTION__, @(toFrame), @(fromFrame), @(length), @(self.frameLength),
               @(fromBuffer.frameLength));
        return NO;
    }

    const UInt32 bytesPerFrame = self.format.streamDescription->mBytesPerFrame;

    for (UInt32 i = 0; i < self.bufferCount; i++) {
        Byte *toData = self.audioBufferList->mBuffers[i].mData;
        Byte *fromData = fromBuffer.audioBufferList->mBuffers[i].mData;
        memcpy(&toData[toFrame * bytesPerFrame], &fromData[fromFrame * bytesPerFrame], length * bytesPerFrame);
    }

    return YES;
}

- (BOOL)copyDataFlexiblyFromBuffer:(YASAudioPCMBuffer *)buffer
{
    if (!buffer) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is null.", __PRETTY_FUNCTION__]));
        return NO;
    }

    if (self.format.bitDepthFormat != buffer.format.bitDepthFormat) {
        YASLog(@"%s - Invalid bit depth format.", __PRETTY_FUNCTION__);
        return NO;
    }

    const AudioBufferList *audioBufferList = buffer.audioBufferList;

    return [self copyDataFlexiblyFromAudioBufferList:audioBufferList];
}

- (BOOL)copyDataFlexiblyFromAudioBufferList:(const AudioBufferList *)fromAudioBufferList
{
    if (!fromAudioBufferList) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is null.", __PRETTY_FUNCTION__]));
        return NO;
    }

    self.frameLength = 0;
    [self _resetDataByteSize];

    AudioBufferList *toAudioBufferList = self.mutableAudioBufferList;
    const UInt32 sampleByteCount = self.format.sampleByteCount;
    UInt32 frameLength = 0;

    BOOL result =
        YASAudioCopyAudioBufferListFlexibly(fromAudioBufferList, toAudioBufferList, sampleByteCount, &frameLength);

    if (result) {
        self.frameLength = frameLength;
    }

    return result;
}

- (void)setValue:(Float64)value atBufferIndex:(UInt32)bufferIndex channel:(UInt32)channel frame:(UInt32)frame
{
    const YASAudioBitDepthFormat bitDepthFormat = self.format.bitDepthFormat;
    const UInt32 stride = self.stride;
    const UInt32 frameLength = self.frameLength;
    const UInt32 sampleByteCount = self.format.sampleByteCount;

    if (channel >= stride) {
        YASRaiseWithReason(
            ([NSString stringWithFormat:@"%s - Overflow channel(%@).", __PRETTY_FUNCTION__, @(channel)]));
        return;
    }

    if (frame >= frameLength) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Overflow frame(%@).", __PRETTY_FUNCTION__, @(frame)]));
        return;
    }

    Byte *data = [self _dataWithBitDepthFormat:bitDepthFormat atBufferIndex:bufferIndex];
    const void *ptr = &data[(stride * frame + channel) * sampleByteCount];

    switch (bitDepthFormat) {
        case YASAudioBitDepthFormatFloat32: {
            *((Float32 *)ptr) = value;
        } break;
        case YASAudioBitDepthFormatFloat64: {
            *((Float64 *)ptr) = value;
        } break;
        case YASAudioBitDepthFormatInt16: {
            *((SInt16 *)ptr) = value * INT16_MAX;
        } break;
        case YASAudioBitDepthFormatInt32: {
            *((SInt32 *)ptr) = value * INT32_MAX;
        } break;
        default:
            break;
    }
}

- (void)writeDataUsingBlock:(YASAudioPCMBufferWriteBlock)writeDataBlock
{
    if (!writeDataBlock) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
    }

    const YASAudioBitDepthFormat bitDepthFormat = self.format.bitDepthFormat;
    for (UInt32 i = 0; i < self.bufferCount; i++) {
        writeDataBlock([self _dataWithBitDepthFormat:bitDepthFormat atBufferIndex:i], i);
    }
}

- (void)enumerateWriteValuesUsingBlock:(YASAudioPCMBufferWriteValueBlock)writeValueBlock
{
    if (!writeValueBlock) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return;
    }

    const YASAudioBitDepthFormat bitDepthFormat = self.format.bitDepthFormat;
    const UInt32 sampleByteCount = self.format.sampleByteCount;
    const UInt32 frameLength = self.frameLength;
    const UInt32 stride = self.stride;
    const UInt32 bufferCount = self.bufferCount;
    Byte *datas[bufferCount];

    for (UInt32 i = 0; i < bufferCount; i++) {
        datas[i] = [self _dataWithBitDepthFormat:bitDepthFormat atBufferIndex:i];
    }

    for (UInt32 frame = 0; frame < frameLength; frame++) {
        for (UInt32 ch = 0; ch < stride; ch++) {
            for (UInt32 bufferIndex = 0; bufferIndex < self.bufferCount; bufferIndex++) {
                @autoreleasepool
                {
                    Float64 value = writeValueBlock(bufferIndex, ch, frame);
                    void *ptr = &datas[bufferIndex][(stride * frame + ch) * sampleByteCount];
                    switch (bitDepthFormat) {
                        case YASAudioBitDepthFormatFloat32: {
                            *((Float32 *)ptr) = value;
                        } break;
                        case YASAudioBitDepthFormatFloat64: {
                            *((Float64 *)ptr) = value;
                        } break;
                        case YASAudioBitDepthFormatInt16: {
                            *((SInt16 *)ptr) = value * INT16_MAX;
                        } break;
                        case YASAudioBitDepthFormatInt32: {
                            *((SInt32 *)ptr) = value * INT32_MAX;
                        } break;
                        default:
                            break;
                    }
                }
            }
        }
    }
}

#pragma mark Private

- (void)_resetDataByteSize
{
    const AudioStreamBasicDescription *asbd = self.format.streamDescription;
    UInt32 dataByteSize = (UInt32)(self.frameCapacity * asbd->mBytesPerFrame);
    AudioBufferList *audioBufferList = self.mutableAudioBufferList;
    for (NSInteger i = 0; i < audioBufferList->mNumberBuffers; i++) {
        audioBufferList->mBuffers[i].mDataByteSize = dataByteSize;
    }
}

@end
