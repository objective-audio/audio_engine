//
//  YASAudioData.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioData.h"
#import "YASAudioFormat.h"
#import "YASAudioUtility.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"

#if (!TARGET_OS_IPHONE && TARGET_OS_MAC)
#import "YASAudioChannelRoute.h"
#endif

typedef NS_ENUM(NSUInteger, YASAudioDataFreeType) {
    YASAudioDataFreeTypeNone,
    YASAudioDataFreeTypeFull,
    YASAudioDataFreeTypeWithoutData,
};

@interface YASAudioData ()
@property (nonatomic, strong) YASAudioFormat *format;
@end

@implementation YASAudioData {
    YASAudioDataFreeType _freeType;
    AudioBufferList *_audioBufferList;
}

- (instancetype)initWithFormat:(YASAudioFormat *)format frameCapacity:(UInt32)frameCapacity
{
    BOOL interleaved = format.isInterleaved;
    UInt32 bufferCount = interleaved ? 1 : format.channelCount;
    UInt32 stride = interleaved ? format.channelCount : 1;
    UInt32 bytesPerFrame = format.streamDescription->mBytesPerFrame;
    AudioBufferList *abl = YASAudioAllocateAudioBufferList(bufferCount, stride, frameCapacity * bytesPerFrame);

    return [self initWithFormat:format audioBufferList:abl needsFree:YES];
}

- (instancetype)initWithFormat:(YASAudioFormat *)format audioBufferList:(AudioBufferList *)abl needsFree:(BOOL)needsFree
{
    self = [super init];
    if (self) {
        if (!format || !abl) {
            YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil. format(%@) audioBufferList(%p)",
                                                           __PRETTY_FUNCTION__, format, abl]));
            YASRelease(self);
            return nil;
        }

        _freeType = needsFree ? YASAudioDataFreeTypeFull : YASAudioDataFreeTypeNone;
        _audioBufferList = abl;
        self.format = format;

        UInt32 bytesPerFrame = format.streamDescription->mBytesPerFrame;
        UInt32 frameCapacity = abl->mBuffers[0].mDataByteSize / bytesPerFrame;
        _frameCapacity = frameCapacity;
        _frameLength = frameCapacity;
    }
    return self;
}

#if (!TARGET_OS_IPHONE && TARGET_OS_MAC)

- (instancetype)initWithFormat:(YASAudioFormat *)format
                          data:(YASAudioData *)data
           outputChannelRoutes:(NSArray *)channelRoutes
{
    return [self _initWithFormat:format data:data channelRoutes:channelRoutes isOutput:YES];
}

- (instancetype)initWithFormat:(YASAudioFormat *)format
                          data:(YASAudioData *)data
            inputChannelRoutes:(NSArray *)channelRoutes
{
    return [self _initWithFormat:format data:data channelRoutes:channelRoutes isOutput:NO];
}

- (instancetype)_initWithFormat:(YASAudioFormat *)format
                           data:(YASAudioData *)data
                  channelRoutes:(NSArray *)channelRoutes
                       isOutput:(BOOL)isOutput
{
    self = [super init];
    if (self) {
        if (!format || !data || !channelRoutes) {
            YASRaiseWithReason(
                ([NSString stringWithFormat:@"%s - Argument is nil. format(%@) data(%@) channelRoutes(%@)",
                                            __PRETTY_FUNCTION__, format, data, channelRoutes]));
            YASRelease(self);
            return nil;
        }

        if (format.channelCount != channelRoutes.count || format.isInterleaved) {
            YASRaiseWithReason(([NSString
                stringWithFormat:
                    @"%s - Invalid format. format.channelCount(%@) channelRoute.count(%@) isInterleaved(%@)",
                    __PRETTY_FUNCTION__, @(format.channelCount), @(channelRoutes.count), @(format.isInterleaved)]));
            YASRelease(self);
            return nil;
        }

        _freeType = YASAudioDataFreeTypeWithoutData;
        _audioBufferList = YASAudioAllocateAudioBufferListWithoutData(format.bufferCount, format.stride);
        self.format = format;

        const AudioBufferList *abl = data.audioBufferList;
        UInt32 bytesPerFrame = format.streamDescription->mBytesPerFrame;
        UInt32 frameCapacity = 0;

        for (UInt32 i = 0; i < format.channelCount; i++) {
            YASAudioChannelRoute *route = channelRoutes[i];
            UInt32 fromChannel = isOutput ? route.destinationChannel : route.sourceChannel;
            UInt32 toChannel = isOutput ? route.sourceChannel : route.destinationChannel;
            _audioBufferList->mBuffers[toChannel].mData = abl->mBuffers[fromChannel].mData;
            _audioBufferList->mBuffers[toChannel].mDataByteSize = abl->mBuffers[fromChannel].mDataByteSize;
            UInt32 frameLength = abl->mBuffers[0].mDataByteSize / bytesPerFrame;
            if (frameCapacity == 0) {
                frameCapacity = frameLength;
            } else if (frameCapacity != frameLength) {
                YASRaiseWithReason(
                    ([NSString stringWithFormat:@"%s - Invalid frame length. frameCapacity(%@) frameLength(%@)",
                                                __PRETTY_FUNCTION__, @(frameCapacity), @(frameLength)]));
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
    YASAudioData *data = [[self.class allocWithZone:zone] initWithFormat:self.format frameCapacity:_frameCapacity];
    YASAudioCopyAudioBufferListDirectly(self.audioBufferList, data.mutableAudioBufferList);
    data.frameLength = _frameLength;
    return data;
}

- (void)dealloc
{
    if (_audioBufferList) {
        switch (_freeType) {
            case YASAudioDataFreeTypeFull:
                YASAudioRemoveAudioBufferList(_audioBufferList);
                break;
            case YASAudioDataFreeTypeWithoutData:
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
        YASRaiseWithReason(
            ([NSString stringWithFormat:@"%s - Frame length is over capacity. frameLength(%@) frameCapacity(%@)",
                                        __PRETTY_FUNCTION__, @(frameLength), @(_frameCapacity)]));
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

- (YASAudioMutablePointer)pointerAtBuffer:(NSUInteger)buffer
{
    YASAudioMutablePointer pointer = {NULL};

    if (buffer >= self.audioBufferList->mNumberBuffers) {
        YASRaiseWithReason(
            ([NSString stringWithFormat:@"%s - Out of range. buffer(%@) abl.mNumberBuffers(%@)", __PRETTY_FUNCTION__,
                                        @(buffer), @(self.audioBufferList->mNumberBuffers)]));
    } else {
        pointer.v = self.audioBufferList->mBuffers[buffer].mData;
    }

    return pointer;
}

- (YASAudioMutablePointer)pointerAtChannel:(NSUInteger)channel
{
    YASAudioMutablePointer pointer = {NULL};

    const UInt32 stride = self.format.stride;

    if (stride > 1) {
        if (channel < self.audioBufferList->mBuffers[0].mNumberChannels) {
            pointer.v = self.audioBufferList->mBuffers[0].mData;
            if (channel > 0) {
                pointer.u8 += channel * self.format.sampleByteCount;
            }
        } else {
            YASRaiseWithReason(
                ([NSString stringWithFormat:@"%s - Out of range. channel(%@) mNumberChannels(%@)", __PRETTY_FUNCTION__,
                                            @(channel), @(self.audioBufferList->mBuffers[0].mNumberChannels)]));
        }
    } else {
        if (channel < self.audioBufferList->mNumberBuffers) {
            pointer.v = self.audioBufferList->mBuffers[channel].mData;
        } else {
            YASRaiseWithReason(
                ([NSString stringWithFormat:@"%s - Out of range. channel(%@) mNumberChannels(%@)", __PRETTY_FUNCTION__,
                                            @(channel), @(self.audioBufferList->mBuffers[0].mNumberChannels)]));
        }
    }

    return pointer;
}

- (void)clear
{
    self.frameLength = self.frameCapacity;
    YASAudioClearAudioBufferList(_audioBufferList);
}

- (void)clearWithStartFrame:(UInt32)frame length:(UInt32)length
{
    if ((frame + length) > self.frameLength) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Out of range. frame(%@) length(%@) frameLength(%@)",
                                                       __PRETTY_FUNCTION__, @(frame), @(length), @(self.frameLength)]));
        return;
    }

    UInt32 bytesPerFrame = self.format.streamDescription->mBytesPerFrame;

    for (UInt32 i = 0; i < self.bufferCount; i++) {
        Byte *data = self.audioBufferList->mBuffers[i].mData;
        memset(&data[frame * bytesPerFrame], 0, length * bytesPerFrame);
    }
}

- (BOOL)copyFromData:(YASAudioData *)fromData
{
    return [self copyFromData:fromData fromStartFrame:0 toStartFrame:0 length:fromData.frameLength];
}

- (BOOL)copyFromData:(YASAudioData *)fromData
      fromStartFrame:(UInt32)fromFrame
        toStartFrame:(UInt32)toFrame
              length:(UInt32)length
{
    if (!fromData) {
        YASRaiseWithReason(
            ([NSString stringWithFormat:@"%s - Argument is nil. fromData(%@)", __PRETTY_FUNCTION__, fromData]));
        return NO;
    }

    if (![fromData.format isEqualToAudioFormat:self.format]) {
        YASLog(@"%s - Format is not equal.", __PRETTY_FUNCTION__);
        return NO;
    }

    if (((toFrame + length) > self.frameLength) || ((fromFrame + length) > fromData.frameLength)) {
        YASLog(@"%s - Out of range (toFrame = %@ / fromFrame = %@ / length = %@ / toFrameLength = %@ / fromFrameLength "
               @"= %@).",
               __PRETTY_FUNCTION__, @(toFrame), @(fromFrame), @(length), @(self.frameLength), @(fromData.frameLength));
        return NO;
    }

    const UInt32 bytesPerFrame = self.format.streamDescription->mBytesPerFrame;

    for (UInt32 i = 0; i < self.bufferCount; i++) {
        Byte *toDataPointer = self.audioBufferList->mBuffers[i].mData;
        Byte *fromDataPointer = fromData.audioBufferList->mBuffers[i].mData;
        memcpy(&toDataPointer[toFrame * bytesPerFrame], &fromDataPointer[fromFrame * bytesPerFrame],
               length * bytesPerFrame);
    }

    return YES;
}

- (BOOL)copyFlexiblyFromData:(YASAudioData *)data
{
    if (!data) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil. data(%@)", __PRETTY_FUNCTION__, data]));
        return NO;
    }

    if (self.format.bitDepthFormat != data.format.bitDepthFormat) {
        YASLog(@"%s - Invalid bit depth format.", __PRETTY_FUNCTION__);
        return NO;
    }

    const AudioBufferList *abl = data.audioBufferList;

    return [self copyFlexiblyFromAudioBufferList:abl];
}

- (BOOL)copyFlexiblyFromAudioBufferList:(const AudioBufferList *)fromAbl
{
    if (!fromAbl) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil. fromAbl(%p)", __PRETTY_FUNCTION__, fromAbl]));
        return NO;
    }

    self.frameLength = 0;
    [self _resetDataByteSize];

    AudioBufferList *toAbl = self.mutableAudioBufferList;
    const UInt32 sampleByteCount = self.format.sampleByteCount;
    UInt32 frameLength = 0;

    BOOL result = YASAudioCopyAudioBufferListFlexibly(fromAbl, toAbl, sampleByteCount, &frameLength);

    if (result) {
        self.frameLength = frameLength;
    }

    return result;
}

- (BOOL)copyFlexiblyToAudioBufferList:(AudioBufferList *)toAbl
{
    if (!toAbl) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil. toAbl(%p)", __PRETTY_FUNCTION__, toAbl]));
        return NO;
    }

    const AudioBufferList *fromAbl = self.audioBufferList;
    const UInt32 sampleByteCount = self.format.sampleByteCount;

    return YASAudioCopyAudioBufferListFlexibly(fromAbl, toAbl, sampleByteCount, NULL);
}

#pragma mark Private

- (void)_resetDataByteSize
{
    const AudioStreamBasicDescription *asbd = self.format.streamDescription;
    UInt32 dataByteSize = (UInt32)(self.frameCapacity * asbd->mBytesPerFrame);
    AudioBufferList *abl = self.mutableAudioBufferList;
    for (NSInteger i = 0; i < abl->mNumberBuffers; i++) {
        abl->mBuffers[i].mDataByteSize = dataByteSize;
    }
}

@end
