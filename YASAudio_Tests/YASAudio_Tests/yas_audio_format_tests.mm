//
//  YASCppAudioFormatTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_audio_format.h"
#import "YASAudioUtility.h"
#import "YASAudioFile.h"

@interface YASCppAudioFormatTests : XCTestCase

@end

@implementation YASCppAudioFormatTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testCreateStandardAudioFormat
{
    const double sampleRate = 44100.0;
    const UInt32 channelCount = 2;
    const UInt32 bufferCount = channelCount;
    const UInt32 stride = 1;
    const BOOL interleaved = NO;
    const yas::pcm_format pcmFormat = yas::pcm_format::float32;
    const UInt32 bitsPerChannel = 32;
    const UInt32 bytesPerFrame = bitsPerChannel / 8;

    const AudioStreamBasicDescription asbd = {
        .mFormatID = kAudioFormatLinearPCM,
        .mFramesPerPacket = 1,
        .mSampleRate = sampleRate,
        .mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
        .mBitsPerChannel = bitsPerChannel,
        .mChannelsPerFrame = channelCount,
        .mBytesPerFrame = bytesPerFrame,
        .mBytesPerPacket = bytesPerFrame,
    };

    auto format = yas::audio_format::create(sampleRate, channelCount);

    XCTAssert(format->is_standard());
    XCTAssert(format->channel_count() == channelCount);
    XCTAssert(format->buffer_count() == bufferCount);
    XCTAssert(format->stride() == stride);
    XCTAssert(format->sample_rate() == sampleRate);
    XCTAssert(format->is_interleaved() == interleaved);
    XCTAssert(format->pcm_format() == pcmFormat);
    XCTAssert(YASAudioIsEqualASBD(&format->stream_description(), &asbd));
}

- (void)testCreateFormat48000kHz1ch64bitsInterleaved
{
    const double sampleRate = 48000.0;
    const UInt32 channelCount = 1;
    const UInt32 bufferCount = 1;
    const UInt32 stride = channelCount;
    const BOOL interleaved = YES;
    const yas::pcm_format pcmFormat = yas::pcm_format::float64;
    const UInt32 bitsPerChannel = 64;
    const UInt32 bytesPerFrame = bitsPerChannel / 8 * channelCount;

    const AudioStreamBasicDescription asbd = {
        .mFormatID = kAudioFormatLinearPCM,
        .mFramesPerPacket = 1,
        .mSampleRate = sampleRate,
        .mFormatFlags = kAudioFormatFlagsNativeFloatPacked,
        .mBitsPerChannel = bitsPerChannel,
        .mChannelsPerFrame = channelCount,
        .mBytesPerFrame = bytesPerFrame,
        .mBytesPerPacket = bytesPerFrame,
    };

    auto format = yas::audio_format::create(sampleRate, channelCount, pcmFormat, interleaved);

    XCTAssert(!format->is_standard());
    XCTAssert(format->channel_count() == channelCount);
    XCTAssert(format->buffer_count() == bufferCount);
    XCTAssert(format->stride() == stride);
    XCTAssert(format->sample_rate() == sampleRate);
    XCTAssert(format->is_interleaved() == interleaved);
    XCTAssert(format->pcm_format() == pcmFormat);
    XCTAssert(YASAudioIsEqualASBD(&format->stream_description(), &asbd));
}

- (void)testCreateFormat32000kHz4ch16bitsInterleaved
{
    const double sampleRate = 32000.0;
    const UInt32 channelCount = 4;
    const UInt32 bufferCount = 1;
    const UInt32 stride = channelCount;
    const BOOL interleaved = YES;
    const yas::pcm_format pcmFormat = yas::pcm_format::int16;
    const UInt32 bitsPerChannel = 16;
    const UInt32 bytesPerFrame = bitsPerChannel / 8 * channelCount;

    const AudioStreamBasicDescription asbd = {
        .mFormatID = kAudioFormatLinearPCM,
        .mFramesPerPacket = 1,
        .mSampleRate = sampleRate,
        .mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
        .mBitsPerChannel = bitsPerChannel,
        .mChannelsPerFrame = channelCount,
        .mBytesPerFrame = bytesPerFrame,
        .mBytesPerPacket = bytesPerFrame,
    };

    auto format = yas::audio_format::create(sampleRate, channelCount, pcmFormat, interleaved);

    XCTAssert(!format->is_standard());
    XCTAssert(format->channel_count() == channelCount);
    XCTAssert(format->buffer_count() == bufferCount);
    XCTAssert(format->stride() == stride);
    XCTAssert(format->sample_rate() == sampleRate);
    XCTAssert(format->is_interleaved() == interleaved);
    XCTAssert(format->pcm_format() == pcmFormat);
    XCTAssert(YASAudioIsEqualASBD(&format->stream_description(), &asbd));
}

- (void)testCreateAudioFormatWithStreamDescription
{
    const double sampleRate = 2348739.1;
    const UInt32 channelCount = 6;
    const UInt32 bufferCount = 1;
    const UInt32 stride = channelCount;
    const BOOL interleaved = YES;
    const UInt32 framesPerPacket = 23;
    const UInt32 bitsPerChannel = 16;
    const UInt32 bytesPerFrame = bitsPerChannel / 8;

    AudioStreamBasicDescription asbd = {
        .mFormatID = kAudioFormatAppleLossless,
        .mFramesPerPacket = framesPerPacket,
        .mSampleRate = sampleRate,
        .mFormatFlags = kAudioFormatFlagsNativeFloatPacked,
        .mBitsPerChannel = bitsPerChannel,
        .mChannelsPerFrame = channelCount,
        .mBytesPerFrame = bytesPerFrame,
        .mBytesPerPacket = bytesPerFrame * framesPerPacket,
    };

    auto format = yas::audio_format::create(asbd);

    XCTAssert(!format->is_standard());
    XCTAssert(format->channel_count() == channelCount);
    XCTAssert(format->buffer_count() == bufferCount);
    XCTAssert(format->stride() == stride);
    XCTAssert(format->is_interleaved() == interleaved);
    XCTAssert(YASAudioIsEqualASBD(&format->stream_description(), &asbd));
}

- (void)testEqualAudioFormats
{
    const double sampleRate = 44100;
    const UInt32 channelCount = 2;

    auto audio_format1 = yas::audio_format::create(sampleRate, channelCount);
    auto audio_format1b = audio_format1;
    auto audio_format2 = yas::audio_format::create(sampleRate, channelCount);

    XCTAssert(*audio_format1 == *audio_format1b);
    XCTAssert(*audio_format1 == *audio_format2);
}

- (void)testCreateAudioFormatWithSettings
{
    const double sampleRate = 44100.0;

    CFDictionaryRef settings = (__bridge CFDictionaryRef)[NSDictionary yas_linearPCMSettingsWithSampleRate:sampleRate
                                                                                          numberOfChannels:2
                                                                                                  bitDepth:32
                                                                                               isBigEndian:NO
                                                                                                   isFloat:YES
                                                                                          isNonInterleaved:YES];

    auto format = yas::audio_format::create(settings);

    if (kAudioFormatFlagIsBigEndian != kAudioFormatFlagsNativeEndian) {
        XCTAssertEqual(format->pcm_format(), yas::pcm_format::float32);
        XCTAssertEqual(format->channel_count(), 2);
        XCTAssertEqual(format->buffer_count(), 2);
        XCTAssertEqual(format->stride(), 1);
        XCTAssertEqual(format->sample_rate(), sampleRate);
        XCTAssertEqual(format->is_interleaved(), NO);
        XCTAssertEqual(format->sample_byte_count(), 4);
    } else {
        XCTAssertEqual(format->pcm_format(), yas::pcm_format::other);
    }

    settings = (__bridge CFDictionaryRef)[NSDictionary yas_linearPCMSettingsWithSampleRate:sampleRate
                                                                          numberOfChannels:4
                                                                                  bitDepth:16
                                                                               isBigEndian:YES
                                                                                   isFloat:NO
                                                                          isNonInterleaved:NO];

    format = yas::audio_format::create(settings);

    if (kAudioFormatFlagIsBigEndian == kAudioFormatFlagsNativeEndian) {
        XCTAssertEqual(format->pcm_format(), yas::pcm_format::int16);
        XCTAssertEqual(format->channel_count(), 4);
        XCTAssertEqual(format->buffer_count(), 1);
        XCTAssertEqual(format->stride(), 4);
        XCTAssertEqual(format->sample_rate(), sampleRate);
        XCTAssertEqual(format->is_interleaved(), YES);
        XCTAssertEqual(format->sample_byte_count(), 2);
    } else {
        XCTAssertEqual(format->pcm_format(), yas::pcm_format::other);
    }
}

@end
