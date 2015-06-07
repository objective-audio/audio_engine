//
//  YASAudioEnumerator.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioEnumerator.h"
#import "YASAudioData.h"
#import "YASAudioFormat.h"
#import "NSException+YASAudio.h"
#import "YASMacros.h"

@implementation YASAudioEnumerator

- (instancetype)initWithAudioData:(YASAudioData *)data atChannel:(const NSUInteger)channel
{
    YASAudioPointer pointer = [data pointerAtChannel:channel];
    YASAudioFormat *format = data.format;
    NSUInteger stride = format.stride * format.sampleByteCount;
    return [self initWithPointer:pointer stride:stride length:data.frameLength];
}

- (instancetype)initWithPointer:(const YASAudioPointer)pointer
                         stride:(const NSUInteger)stride
                         length:(const NSUInteger)length
{
    self = [super init];
    if (self) {
        if (!pointer.v || stride == 0 || length == 0) {
            YASRaiseWithReason(
                ([NSString stringWithFormat:@"%s - Invalid argument. pointer.v(%p) stride(%@) length(%@)",
                                            __PRETTY_FUNCTION__, pointer.v, @(stride), @(length)]));
            YASRelease(self);
            return nil;
        }
        _pointer = _topPointer = pointer;
        _stride = stride;
        _length = length;
        _index = 0;
    }
    return self;
}

- (const YASAudioPointer *)pointer
{
    return (YASAudioPointer *)&_pointer;
}

- (const NSUInteger *)index
{
    return &_index;
}

- (void)move
{
    YASAudioEnumeratorMove(self);
}

- (void)stop
{
    YASAudioEnumeratorStop(self);
}

- (void)setPosition:(const NSUInteger)index
{
    if (index >= _length) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Out of range. position(%@) length(%@)",
                                                       __PRETTY_FUNCTION__, @(index), @(_length)]));
        return;
    }
    _index = index;
    _pointer.v = _topPointer.u8 + (_stride * index);
}

- (void)reset
{
    YASAudioEnumeratorReset(self);
}

@end

@implementation YASAudioFrameEnumerator

- (instancetype)initWithAudioData:(YASAudioData *)data
{
    self = [super init];
    if (self) {
        YASAudioFormat *format = data.format;
        NSUInteger bufferCount = format.bufferCount;
        NSUInteger stride = format.stride;
        NSUInteger sampleByteCount = data.format.sampleByteCount;

        _frame = _channel = 0;
        _frameLength = data.frameLength;
        _channelCount = bufferCount * stride;
        _frameStride = stride * sampleByteCount;
        _pointersSize = _channelCount * sizeof(YASAudioPointer *);
        _pointers = calloc(_pointersSize, 1);
        _topPointers = calloc(_pointersSize, 1);

        NSUInteger channel = 0;
        for (NSInteger buffer = 0; buffer < bufferCount; buffer++) {
            YASAudioPointer pointer = [data pointerAtBuffer:buffer];
            for (NSInteger ch = 0; ch < stride; ch++) {
                _pointers[channel].v = _topPointers[channel].v = pointer.v;
                pointer.u8 += sampleByteCount;
                channel++;
            }
        }

        _pointer.v = _pointers->v;
    }
    return self;
}

- (void)dealloc
{
    free(_pointers);
    free(_topPointers);

    YASSuperDealloc;
}

- (const YASAudioPointer *)pointer
{
    return (YASAudioPointer *)&_pointer;
}

- (const NSUInteger *)frame
{
    return &_frame;
}

- (const NSUInteger *)channel
{
    return &_channel;
}

- (void)move
{
    YASAudioFrameEnumeratorMove(self);
}

- (void)moveFrame
{
    YASAudioFrameEnumeratorMoveFrame(self);
}

- (void)moveChannel
{
    YASAudioFrameEnumeratorMoveChannel(self);
}

- (void)stop
{
    YASAudioFrameEnumeratorStop(self);
}

- (void)setFramePosition:(const NSUInteger)frame
{
    if (frame >= _frameLength) {
        YASRaiseWithReason(
            ([NSString stringWithFormat:@"%s - Out of range. frame(%@)", __PRETTY_FUNCTION__, @(frame)]));
        return;
    }

    _frame = frame;

    NSUInteger stride = _frameStride * frame;
    NSUInteger index = _channelCount;
    while (index--) {
        _pointers[index].v = _topPointers[index].u8 + stride;
    }

    if (_pointer.v) {
        _pointer.v = _pointers[_channel].v;
    }
}

- (void)setChannelPosition:(const NSUInteger)channel
{
    if (channel >= _channelCount) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Out of range. channel(%@) count(%@)", __PRETTY_FUNCTION__,
                                                       @(channel), @(_channelCount)]));
        return;
    }

    _channel = channel;
    _pointer.v = _pointers[_channel].v;
}

- (void)reset
{
    YASAudioFrameEnumeratorReset(self);
}

@end
