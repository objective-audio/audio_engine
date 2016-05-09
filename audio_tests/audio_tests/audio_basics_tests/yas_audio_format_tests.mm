//
//  YASCppAudioFormatTests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface YASCppAudioFormatTests : XCTestCase

@end

@implementation YASCppAudioFormatTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_empty {
    audio::format format;

    XCTAssertEqual(format.is_empty(), true);
    XCTAssertEqual(format.is_standard(), false);
    XCTAssertEqual(format.pcm_format(), audio::pcm_format::other);
    XCTAssertEqual(format.channel_count(), 0);
    XCTAssertEqual(format.buffer_count(), 0);
    XCTAssertEqual(format.stride(), 0);
    XCTAssertEqual(format.sample_rate(), 0.0);
    XCTAssertEqual(format.is_interleaved(), false);
    XCTAssertEqual(format.sample_byte_count(), 0);
    XCTAssertEqual(format.buffer_frame_byte_count(), 0);
}

- (void)test_create_with_nullptr {
    audio::format format(nullptr);

    XCTAssertEqual(format.is_empty(), true);
    XCTAssertEqual(format.is_standard(), false);
    XCTAssertEqual(format.pcm_format(), audio::pcm_format::other);
    XCTAssertEqual(format.channel_count(), 0);
    XCTAssertEqual(format.buffer_count(), 0);
    XCTAssertEqual(format.stride(), 0);
    XCTAssertEqual(format.sample_rate(), 0.0);
    XCTAssertEqual(format.is_interleaved(), false);
    XCTAssertEqual(format.sample_byte_count(), 0);
    XCTAssertEqual(format.buffer_frame_byte_count(), 0);
}

- (void)test_nullptr_parameter {
    auto lambda = [self](const audio::format &format) {
        audio::format empty_format;
        XCTAssertEqual(empty_format, format);
    };

    lambda(nullptr);
}

- (void)test_create_standard_format {
    const double sampleRate = 44100.0;
    const uint32_t channelCount = 2;
    const uint32_t bufferCount = channelCount;
    const uint32_t stride = 1;
    const BOOL interleaved = NO;
    const audio::pcm_format pcmFormat = audio::pcm_format::float32;
    const uint32_t bitsPerChannel = 32;
    const uint32_t bytesPerFrame = bitsPerChannel / 8;

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

    auto format = audio::format(sampleRate, channelCount);

    XCTAssert(format.is_standard());
    XCTAssert(format.channel_count() == channelCount);
    XCTAssert(format.buffer_count() == bufferCount);
    XCTAssert(format.stride() == stride);
    XCTAssert(format.sample_rate() == sampleRate);
    XCTAssert(format.is_interleaved() == interleaved);
    XCTAssert(format.pcm_format() == pcmFormat);
    XCTAssertTrue(is_equal(format.stream_description(), asbd));
}

- (void)test_create_format_48000kHz_1ch_64bits_interleaved {
    const double sampleRate = 48000.0;
    const uint32_t channelCount = 1;
    const uint32_t bufferCount = 1;
    const uint32_t stride = channelCount;
    const BOOL interleaved = YES;
    const audio::pcm_format pcmFormat = audio::pcm_format::float64;
    const uint32_t bitsPerChannel = 64;
    const uint32_t bytesPerFrame = bitsPerChannel / 8 * channelCount;

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

    auto format = audio::format(sampleRate, channelCount, pcmFormat, interleaved);

    XCTAssert(!format.is_standard());
    XCTAssert(format.channel_count() == channelCount);
    XCTAssert(format.buffer_count() == bufferCount);
    XCTAssert(format.stride() == stride);
    XCTAssert(format.sample_rate() == sampleRate);
    XCTAssert(format.is_interleaved() == interleaved);
    XCTAssert(format.pcm_format() == pcmFormat);
    XCTAssertTrue(is_equal(format.stream_description(), asbd));
}

- (void)test_create_format_32000kHz_4ch_16bits_interleaved {
    const double sampleRate = 32000.0;
    const uint32_t channelCount = 4;
    const uint32_t bufferCount = 1;
    const uint32_t stride = channelCount;
    const BOOL interleaved = YES;
    const audio::pcm_format pcmFormat = audio::pcm_format::int16;
    const uint32_t bitsPerChannel = 16;
    const uint32_t bytesPerFrame = bitsPerChannel / 8 * channelCount;

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

    auto format = audio::format(sampleRate, channelCount, pcmFormat, interleaved);

    XCTAssert(!format.is_standard());
    XCTAssert(format.channel_count() == channelCount);
    XCTAssert(format.buffer_count() == bufferCount);
    XCTAssert(format.stride() == stride);
    XCTAssert(format.sample_rate() == sampleRate);
    XCTAssert(format.is_interleaved() == interleaved);
    XCTAssert(format.pcm_format() == pcmFormat);
    XCTAssertTrue(is_equal(format.stream_description(), asbd));
}

- (void)test_create_format_with_streadm_description {
    const double sampleRate = 2348739.1;
    const uint32_t channelCount = 6;
    const uint32_t bufferCount = 1;
    const uint32_t stride = channelCount;
    const BOOL interleaved = YES;
    const uint32_t framesPerPacket = 23;
    const uint32_t bitsPerChannel = 16;
    const uint32_t bytesPerFrame = bitsPerChannel / 8;

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

    auto format = audio::format(asbd);

    XCTAssert(!format.is_standard());
    XCTAssert(format.channel_count() == channelCount);
    XCTAssert(format.buffer_count() == bufferCount);
    XCTAssert(format.stride() == stride);
    XCTAssert(format.is_interleaved() == interleaved);
    XCTAssertTrue(is_equal(format.stream_description(), asbd));
}

- (void)test_equal_formats {
    const double sampleRate = 44100;
    const uint32_t channelCount = 2;

    auto audio_format1 = audio::format(sampleRate, channelCount);
    auto audio_format1b = audio_format1;
    auto audio_format2 = audio::format(sampleRate, channelCount);

    XCTAssert(audio_format1 == audio_format1b);
    XCTAssert(audio_format1 == audio_format2);
}

- (void)test_create_format_with_settings {
    const double sampleRate = 44100.0;

    CFDictionaryRef settings = audio::linear_pcm_file_settings(sampleRate, 2, 32, false, true, true);

    auto format = audio::format(settings);

    if (kAudioFormatFlagIsBigEndian != kAudioFormatFlagsNativeEndian) {
        XCTAssertEqual(format.pcm_format(), audio::pcm_format::float32);
        XCTAssertEqual(format.channel_count(), 2);
        XCTAssertEqual(format.buffer_count(), 2);
        XCTAssertEqual(format.stride(), 1);
        XCTAssertEqual(format.sample_rate(), sampleRate);
        XCTAssertEqual(format.is_interleaved(), NO);
        XCTAssertEqual(format.sample_byte_count(), 4);
    } else {
        XCTAssertEqual(format.pcm_format(), audio::pcm_format::other);
    }

    settings = audio::linear_pcm_file_settings(sampleRate, 4, 16, true, false, false);

    format = audio::format(settings);

    if (kAudioFormatFlagIsBigEndian == kAudioFormatFlagsNativeEndian) {
        XCTAssertEqual(format.pcm_format(), audio::pcm_format::int16);
        XCTAssertEqual(format.channel_count(), 4);
        XCTAssertEqual(format.buffer_count(), 1);
        XCTAssertEqual(format.stride(), 4);
        XCTAssertEqual(format.sample_rate(), sampleRate);
        XCTAssertEqual(format.is_interleaved(), YES);
        XCTAssertEqual(format.sample_byte_count(), 2);
    } else {
        XCTAssertEqual(format.pcm_format(), audio::pcm_format::other);
    }
}

- (void)test_is_equal_asbd {
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

    XCTAssertTrue(is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mSampleRate = 2;

    XCTAssertFalse(is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mFormatID = 2;

    XCTAssertFalse(is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mFormatFlags = 2;

    XCTAssertFalse(is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mBytesPerPacket = 2;

    XCTAssertFalse(is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mFramesPerPacket = 2;

    XCTAssertFalse(is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mBytesPerFrame = 2;

    XCTAssertFalse(is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mChannelsPerFrame = 2;

    XCTAssertFalse(is_equal(asbd1, asbd2));

    asbd2 = asbd1;
    asbd2.mBitsPerChannel = 2;

    XCTAssertFalse(is_equal(asbd1, asbd2));
}

- (void)test_pcm_format_to_string {
    XCTAssertTrue(to_string(audio::pcm_format::float32) == "Float32");
    XCTAssertTrue(to_string(audio::pcm_format::float64) == "Float64");
    XCTAssertTrue(to_string(audio::pcm_format::int16) == "Int16");
    XCTAssertTrue(to_string(audio::pcm_format::fixed824) == "Fixed8.24");
    XCTAssertTrue(to_string(audio::pcm_format::other) == "Other");
}

- (void)test_null_format {
    const auto null_format = audio::format::null_format();
    XCTAssertFalse(null_format);
}

- (void)test_is_empty {
    audio::format format{AudioStreamBasicDescription{}};
    XCTAssertTrue(format.is_empty());

    XCTAssertTrue(audio::format::null_format().is_empty());
}

- (void)test_smoke {
    audio::format format{48000.0, 2};
    format.description();
}

@end
