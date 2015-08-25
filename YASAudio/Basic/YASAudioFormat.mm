//
//  YASAudioFormat.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioFormat.h"
#import "YASMacros.h"
#import "NSString+YASAudio.h"
#import "yas_audio_format.h"

@implementation YASAudioFormat {
    yas::audio_format_sptr _format;
}

- (instancetype)initWithStreamDescription:(const AudioStreamBasicDescription *)asbd
{
    self = [super init];
    if (self) {
        _format = yas::audio_format::create(*asbd);
    }
    return self;
}

- (instancetype)initStandardFormatWithSampleRate:(double)sampleRate channels:(UInt32)channels
{
    return [self initWithPCMFormat:YASAudioPCMFormatFloat32 sampleRate:sampleRate channels:channels interleaved:NO];
}

- (instancetype)initWithPCMFormat:(YASAudioPCMFormat)pcmFormat
                       sampleRate:(Float64)sampleRate
                         channels:(UInt32)channels
                      interleaved:(BOOL)interleaved
{
    self = [super init];
    if (self) {
        _format =
            yas::audio_format::create(sampleRate, channels, static_cast<yas::pcm_format>(pcmFormat), (bool)interleaved);
    }
    return self;
}

- (instancetype)initWithSettings:(NSDictionary *)settings
{
    self = [super init];
    if (self) {
        _format = yas::audio_format::create((__bridge CFDictionaryRef)settings);
    }
    return self;
}

- (BOOL)isStandard
{
    return _format->is_standard();
}

- (YASAudioPCMFormat)pcmFormat
{
    return static_cast<YASAudioPCMFormat>(_format->pcm_format());
}

- (UInt32)channelCount
{
    return _format->channel_count();
}

- (UInt32)bufferCount
{
    return _format->buffer_count();
}

- (UInt32)stride
{
    return _format->stride();
}

- (double)sampleRate
{
    return _format->sample_rate();
}

- (BOOL)isInterleaved
{
    return _format->is_interleaved();
}

- (const AudioStreamBasicDescription *)streamDescription
{
    return &_format->stream_description();
}

- (UInt32)sampleByteCount
{
    return _format->sample_byte_count();
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    } else if (![other isKindOfClass:self.class]) {
        return NO;
    } else {
        return [self isEqualToAudioFormat:other];
    }
}

- (BOOL)isEqualToAudioFormat:(YASAudioFormat *)otherFormat
{
    if (self == otherFormat) {
        return YES;
    } else {
        return yas::is_equal(*self.streamDescription, *otherFormat.streamDescription);
    }
}

- (NSUInteger)hash
{
    const AudioStreamBasicDescription *asbd = self.streamDescription;
    NSUInteger hash = asbd->mFormatID + asbd->mFormatFlags + asbd->mChannelsPerFrame + asbd->mBitsPerChannel;
    return hash;
}

- (NSString *)description
{
    NSMutableString *result = [NSMutableString stringWithFormat:@"<%@: %p>\n", self.class, self];
    [result appendString:[NSString stringWithUTF8String:_format->description().c_str()]];
    return result;
}

@end
