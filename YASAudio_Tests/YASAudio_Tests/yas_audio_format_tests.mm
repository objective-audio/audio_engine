//
//  YASCppAudioFormatTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_audio_format.h"
#import "yas_audio_file_utils.h"

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
    const Float64 sampleRate = 44100.0;
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
    XCTAssertTrue(yas::is_equal(format->stream_description(), asbd));
}

- (void)testCreateFormat48000kHz1ch64bitsInterleaved
{
    const Float64 sampleRate = 48000.0;
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
    XCTAssertTrue(yas::is_equal(format->stream_description(), asbd));
}

- (void)testCreateFormat32000kHz4ch16bitsInterleaved
{
    const Float64 sampleRate = 32000.0;
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
    XCTAssertTrue(yas::is_equal(format->stream_description(), asbd));
}

- (void)testCreateAudioFormatWithStreamDescription
{
    const Float64 sampleRate = 2348739.1;
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
    XCTAssertTrue(yas::is_equal(format->stream_description(), asbd));
}

- (void)testEqualAudioFormats
{
    const Float64 sampleRate = 44100;
    const UInt32 channelCount = 2;

    auto audio_format1 = yas::audio_format::create(sampleRate, channelCount);
    auto audio_format1b = audio_format1;
    auto audio_format2 = yas::audio_format::create(sampleRate, channelCount);

    XCTAssert(*audio_format1 == *audio_format1b);
    XCTAssert(*audio_format1 == *audio_format2);
}

- (void)testCreateAudioFormatWithSettings
{
    const Float64 sampleRate = 44100.0;

    CFDictionaryRef settings = yas::linear_pcm_file_settings(sampleRate, 2, 32, false, true, true);

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

    settings = yas::linear_pcm_file_settings(sampleRate, 4, 16, true, false, false);

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

- (void)testIsEqualASBD
{
    AudioStreamBasicDescription asbd1 = {
        .mSampleRate = 1,
        .mFormatID = 1,
        .mFormatFlags = 1,
        .mBytesPerPacket = 1,
        .mFramesPerPacket = 1,
        .mBytesPerFrame = 1,
        .mChannelsPerFrame = 1,
        .mBitsPerChannel = 1,
    };

    AudioStreamBasicDescription asbd2 = asbd1;

    XCTAssertTrue(yas::is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mSampleRate = 2;

    XCTAssertFalse(yas::is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mFormatID = 2;

    XCTAssertFalse(yas::is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mFormatFlags = 2;

    XCTAssertFalse(yas::is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mBytesPerPacket = 2;

    XCTAssertFalse(yas::is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mFramesPerPacket = 2;

    XCTAssertFalse(yas::is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mBytesPerFrame = 2;

    XCTAssertFalse(yas::is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mChannelsPerFrame = 2;

    XCTAssertFalse(yas::is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mBitsPerChannel = 2;

    XCTAssertFalse(yas::is_equal(asbd1, asbd2));
}

@end
