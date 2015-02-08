//
//  YASAudioBuffer.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioPCMBuffer.h"
#import "YASAudioFormat.h"
#import "YASAudioUtility.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"

typedef NS_ENUM(NSUInteger, YASAudioPCMBufferFreeType) {
    YASAudioPCMBufferFreeTypeNone,
    YASAudioPCMBufferFreeTypeFull,
    YASAudioPCMBufferFreeTypeWithoutData,
};

@interface YASAudioPCMBuffer ()
@property (nonatomic, strong) YASAudioFormat *format;
@end

@implementation YASAudioPCMBuffer {
    YASAudioPCMBufferFreeType _freeType;
    AudioBufferList *_audioBufferList;
}

- (instancetype)initWithPCMFormat:(YASAudioFormat *)format frameCapacity:(UInt32)frameCapacity
{
    BOOL interleaved = format.isInterleaved;
    UInt32 bufferCount = interleaved ? 1 : format.channelCount;
    UInt32 stride = interleaved ? format.channelCount : 1;
    UInt32 bytesPerFrame = format.streamDescription->mBytesPerFrame;
    AudioBufferList *audioBufferList = YASAudioAllocateAudioBufferList(bufferCount, stride, frameCapacity * bytesPerFrame);
    
    return [self initWithPCMFormat:format audioBufferList:audioBufferList needsFree:YES];
}

- (instancetype)initWithPCMFormat:(YASAudioFormat *)format audioBufferList:(AudioBufferList *)audioBufferList needsFree:(BOOL)needsFree
{
    self = [super init];
    if (self) {
        if (!format || !audioBufferList) {
            YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil", __PRETTY_FUNCTION__]));
            YASRelease(self);
            return nil;
        }
        
        _freeType = needsFree ? YASAudioPCMBufferFreeTypeFull : YASAudioPCMBufferFreeTypeNone;
        _audioBufferList = audioBufferList;
        self.format = format;
        
        UInt32 bytesPerFrame = format.streamDescription->mBytesPerFrame;
        UInt32 frameCapacity = audioBufferList->mBuffers[0].mDataByteSize / bytesPerFrame;
        _frameCapacity = frameCapacity;
        _frameLength = frameCapacity;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    YASAudioPCMBuffer *buffer = [[self.class allocWithZone:zone] initWithPCMFormat:self.format frameCapacity:_frameCapacity];
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

- (Float32 *)float32DataAtBufferIndex:(NSUInteger)index
{
    return [self _dataWithBitDepthFormat:YASAudioBitDepthFormatFloat32 atBufferIndex:index];
}

- (Float64 *)float64DataAtBufferIndex:(NSUInteger)index
{
    return [self _dataWithBitDepthFormat:YASAudioBitDepthFormatFloat64 atBufferIndex:index];
}

- (SInt16 *)int16DataAtBufferIndex:(NSUInteger)index
{
    return [self _dataWithBitDepthFormat:YASAudioBitDepthFormatInt16 atBufferIndex:index];
}

- (SInt32 *)int32DataAtBufferIndex:(NSUInteger)index
{
    return [self _dataWithBitDepthFormat:YASAudioBitDepthFormatInt32 atBufferIndex:index];
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

- (void)clearData
{
    self.frameLength = self.frameCapacity;
    YASAudioClearAudioBufferList(_audioBufferList);
}

- (void)clearDataWithStartFrame:(UInt32)frame length:(UInt32)length
{
    if ((frame + length) > self.frameLength) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Out of range (frame = %@ / length = %@ / frameLength = %@).", __PRETTY_FUNCTION__, @(frame), @(length), @(self.frameLength)]));
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

- (BOOL)copyDataFromBuffer:(YASAudioPCMBuffer *)fromBuffer fromStartFrame:(UInt32)fromFrame toStartFrame:(UInt32)toFrame length:(UInt32)length
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
        YASLog(@"%s - Out of range (toFrame = %@ / fromFrame = %@ / length = %@ / toFrameLength = %@ / fromFrameLength = %@).", __PRETTY_FUNCTION__, @(toFrame), @(fromFrame), @(length), @(self.frameLength), @(fromBuffer.frameLength));
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
    
    BOOL result = YASAudioCopyAudioBufferListFlexibly(fromAudioBufferList, toAudioBufferList, sampleByteCount, &frameLength);
    
    if (result) {
        self.frameLength = frameLength;
    }
    
    return result;
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
