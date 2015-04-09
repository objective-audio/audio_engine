//
//  YASAudioFrameScanner.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioFrameScanner.h"
#import "YASAudioPCMBuffer.h"
#import "YASAudioFormat.h"
#import "YASMacros.h"

@implementation YASAudioFrameScanner {
    YASAudioPointer _pointer;
    YASAudioPointer *_pointers;
    YASAudioPointer *_topPointers;
    BOOL _atFrameEnd;
    BOOL _atChannelEnd;
    NSUInteger _pointerStride;
    NSUInteger _frameLength;
    NSUInteger _frame;
    NSUInteger _channel;
}

- (instancetype)initWithPCMBuffer:(YASAudioPCMBuffer *)pcmBuffer
{
    self = [super init];
    if (self) {
        NSUInteger bufferCount = pcmBuffer.bufferCount;
        NSUInteger stride = pcmBuffer.stride;
        NSUInteger sampleByteCount = pcmBuffer.format.sampleByteCount;

        _frame = _channel = 0;
        _atFrameEnd = _atChannelEnd = NO;
        _frameLength = pcmBuffer.frameLength;
        _channelCount = bufferCount * stride;
        _pointerStride = stride * sampleByteCount;
        _pointers = calloc(_channelCount, sizeof(YASAudioPointer *));
        _topPointers = calloc(_channelCount, sizeof(YASAudioPointer *));

        NSUInteger channel = 0;
        for (NSInteger buf = 0; buf < bufferCount; buf++) {
            YASAudioPointer pointer = [pcmBuffer dataAtBufferIndex:buf];
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

- (YASAudioPointer *)pointer
{
    return &_pointer;
}

- (const NSUInteger *)frame
{
    return &_frame;
}

- (const NSUInteger *)channel
{
    return &_channel;
}

- (const BOOL *)isAtFrameEnd
{
    return &_atFrameEnd;
}

- (const BOOL *)isAtChannelEnd
{
    return &_atChannelEnd;
}

- (void)moveFrame
{
    if (++_frame >= _frameLength) {
        memset(_pointers, 0, _channelCount * sizeof(YASAudioPointer *));
        _pointer.v = NULL;
        _atFrameEnd = YES;
    } else {
        NSUInteger pointerIndex = _channelCount;
        while (pointerIndex--) {
            _pointers[pointerIndex].u8 += _pointerStride;
        }

        if (_atChannelEnd) {
            _channel = 0;
            _pointer.v = _pointers->v;
            _atChannelEnd = NO;
        } else {
            _pointer.v = _pointers[_channel].v;
        }
    }
}

- (void)moveChannel
{
    if (++_channel >= _channelCount) {
        _atChannelEnd = YES;
        _pointer.v = NULL;
    } else {
        _pointer.v = _pointers[_channel].v;
    }
}

- (void)reset
{
    _frame = 0;
    _atFrameEnd = _atChannelEnd = NO;

    NSUInteger channel = _channelCount;
    while (channel--) {
        _pointers[channel].v = _topPointers[channel].v;
    }

    _channel = 0;
    _pointer.v = _pointers->v;
}

@end
