//
//  format_tests.m
//

#import "../test_utils.h"

using namespace yas;

@interface format_tests : XCTestCase

@end

@implementation format_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_empty {
    audio::format format{AudioStreamBasicDescription{0}};

    XCTAssertEqual(format.is_empty(), true);
}

- (void)test_create_standard_format {
    double const sampleRate = 44100.0;
    uint32_t const channelCount = 2;
    uint32_t const bufferCount = channelCount;
    uint32_t const stride = 1;
    bool const interleaved = NO;
    audio::pcm_format const pcmFormat = audio::pcm_format::float32;
    uint32_t const bitsPerChannel = 32;
    uint32_t const bytesPerFrame = bitsPerChannel / 8;
    AudioFormatFlags const nativeFloatPackedFlag = kAudioFormatFlagsNativeFloatPacked;
    AudioFormatFlags const nonInterleavedFlag = kAudioFormatFlagIsNonInterleaved;

    AudioStreamBasicDescription const asbd = {
        .mFormatID = kAudioFormatLinearPCM,
        .mFramesPerPacket = 1,
        .mSampleRate = sampleRate,
        .mFormatFlags = nativeFloatPackedFlag | nonInterleavedFlag,
        .mBitsPerChannel = bitsPerChannel,
        .mChannelsPerFrame = channelCount,
        .mBytesPerFrame = bytesPerFrame,
        .mBytesPerPacket = bytesPerFrame,
    };

    auto format = audio::format({.sample_rate = sampleRate, .channel_count = channelCount});

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
    double const sampleRate = 48000.0;
    uint32_t const channelCount = 1;
    uint32_t const bufferCount = 1;
    uint32_t const stride = channelCount;
    bool const interleaved = YES;
    audio::pcm_format const pcmFormat = audio::pcm_format::float64;
    uint32_t const bitsPerChannel = 64;
    uint32_t const bytesPerFrame = bitsPerChannel / 8 * channelCount;

    AudioStreamBasicDescription const asbd = {
        .mFormatID = kAudioFormatLinearPCM,
        .mFramesPerPacket = 1,
        .mSampleRate = sampleRate,
        .mFormatFlags = kAudioFormatFlagsNativeFloatPacked,
        .mBitsPerChannel = bitsPerChannel,
        .mChannelsPerFrame = channelCount,
        .mBytesPerFrame = bytesPerFrame,
        .mBytesPerPacket = bytesPerFrame,
    };

    auto format = audio::format({.sample_rate = sampleRate,
                                 .channel_count = channelCount,
                                 .pcm_format = pcmFormat,
                                 .interleaved = interleaved});

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
    double const sampleRate = 32000.0;
    uint32_t const channelCount = 4;
    uint32_t const bufferCount = 1;
    uint32_t const stride = channelCount;
    bool const interleaved = YES;
    audio::pcm_format const pcmFormat = audio::pcm_format::int16;
    uint32_t const bitsPerChannel = 16;
    uint32_t const bytesPerFrame = bitsPerChannel / 8 * channelCount;
    AudioFormatFlags const signedIntegerFlag = kAudioFormatFlagIsSignedInteger;
    AudioFormatFlags const nativeEndianFlag = kAudioFormatFlagsNativeEndian;
    AudioFormatFlags const packedFlag = kAudioFormatFlagIsPacked;

    AudioStreamBasicDescription const asbd = {
        .mFormatID = kAudioFormatLinearPCM,
        .mFramesPerPacket = 1,
        .mSampleRate = sampleRate,
        .mFormatFlags = signedIntegerFlag | nativeEndianFlag | packedFlag,
        .mBitsPerChannel = bitsPerChannel,
        .mChannelsPerFrame = channelCount,
        .mBytesPerFrame = bytesPerFrame,
        .mBytesPerPacket = bytesPerFrame,
    };

    auto format = audio::format({.sample_rate = sampleRate,
                                 .channel_count = channelCount,
                                 .pcm_format = pcmFormat,
                                 .interleaved = interleaved});

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
    double const sampleRate = 2348739.1;
    uint32_t const channelCount = 6;
    uint32_t const bufferCount = 1;
    uint32_t const stride = channelCount;
    bool const interleaved = YES;
    uint32_t const framesPerPacket = 23;
    uint32_t const bitsPerChannel = 16;
    uint32_t const bytesPerFrame = bitsPerChannel / 8;

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
    double const sampleRate = 44100;
    uint32_t const channelCount = 2;

    auto audio_format1 = audio::format({.sample_rate = sampleRate, .channel_count = channelCount});
    auto audio_format1b = audio_format1;
    auto audio_format2 = audio::format({.sample_rate = sampleRate, .channel_count = channelCount});

    XCTAssert(audio_format1 == audio_format1b);
    XCTAssert(audio_format1 == audio_format2);
}

- (void)test_create_format_with_settings {
    double const sampleRate = 44100.0;

    CFDictionaryRef settings = audio::linear_pcm_file_settings(sampleRate, 2, 32, false, true, true);

    auto format = audio::format(settings);

    AudioFormatFlags const bigEndianFlag = kAudioFormatFlagIsBigEndian;
    AudioFormatFlags const nativeEndignFlag = kAudioFormatFlagsNativeEndian;

    if (bigEndianFlag != nativeEndignFlag) {
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

    if (bigEndianFlag == nativeEndignFlag) {
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

- (void)test_is_empty {
    audio::format format{AudioStreamBasicDescription{0}};
    XCTAssertTrue(format.is_empty());
}

- (void)test_smoke {
    audio::format format{{.sample_rate = 48000.0, .channel_count = 2}};
    auto description = format.description();
    NSLog(@"%@", (__bridge NSString *)description);
}

@end
