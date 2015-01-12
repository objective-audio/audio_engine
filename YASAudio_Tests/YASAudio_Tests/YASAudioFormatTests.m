//
//  YASAudioFormatTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioUtility.h"
#import "YASAudioFormat.h"
#import "YASAudioFile.h"
#import "YASMacros.h"

@interface YASAudioFormatTests : XCTestCase

@end

@implementation YASAudioFormatTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testCreateStandardAudioFormat
{
    const double sampleRate = 44100.0;
    const UInt32 channelCount = 2;
    const UInt32 bufferCount = channelCount;
    const UInt32 stride = 1;
    const BOOL interleaved = NO;
    const YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat32;
    const UInt32 bitsPerChannel = 32;
    const UInt32 bytesPerFrame = bitsPerChannel / 8;
    
    AudioStreamBasicDescription asbd = {
        .mFormatID = kAudioFormatLinearPCM,
        .mFramesPerPacket = 1,
        .mSampleRate = sampleRate,
        .mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
        .mBitsPerChannel = bitsPerChannel,
        .mChannelsPerFrame = channelCount,
        .mBytesPerFrame = bytesPerFrame,
        .mBytesPerPacket = bytesPerFrame,
    };
    
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:channelCount];
    
    XCTAssert(format.isStandard);
    XCTAssert(format.channelCount == channelCount);
    XCTAssert(format.bufferCount == bufferCount);
    XCTAssert(format.stride == stride);
    XCTAssert(format.sampleRate == sampleRate);
    XCTAssert(format.isInterleaved == interleaved);
    XCTAssert(format.bitDepthFormat == bitDepthFormat);
    XCTAssert(YASAudioIsEqualASBD(format.streamDescription, &asbd));
    
    YASRelease(format);
}

- (void)testCreateFormat48000kHz1ch64bitsInterleaved
{
    const double sampleRate = 48000.0;
    const UInt32 channelCount = 1;
    const UInt32 bufferCount = 1;
    const UInt32 stride = channelCount;
    const BOOL interleaved = YES;
    const YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat64;
    const UInt32 bitsPerChannel = 64;
    const UInt32 bytesPerFrame = bitsPerChannel / 8 * channelCount;
    
    AudioStreamBasicDescription asbd = {
        .mFormatID = kAudioFormatLinearPCM,
        .mFramesPerPacket = 1,
        .mSampleRate = sampleRate,
        .mFormatFlags = kAudioFormatFlagsNativeFloatPacked,
        .mBitsPerChannel = bitsPerChannel,
        .mChannelsPerFrame = channelCount,
        .mBytesPerFrame = bytesPerFrame,
        .mBytesPerPacket = bytesPerFrame,
    };
    
    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat sampleRate:sampleRate channels:channelCount interleaved:interleaved];
    
    XCTAssert(!format.isStandard);
    XCTAssert(format.channelCount == channelCount);
    XCTAssert(format.bufferCount == bufferCount);
    XCTAssert(format.stride == stride);
    XCTAssert(format.sampleRate == sampleRate);
    XCTAssert(format.isInterleaved == interleaved);
    XCTAssert(format.bitDepthFormat == bitDepthFormat);
    XCTAssert(YASAudioIsEqualASBD(format.streamDescription, &asbd));
    
    YASRelease(format);
}

- (void)testCreateFormat32000kHz4ch16bitsInterleaved
{
    const double sampleRate = 32000.0;
    const UInt32 channelCount = 4;
    const UInt32 bufferCount = 1;
    const UInt32 stride = channelCount;
    const BOOL interleaved = YES;
    const YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatInt16;
    const UInt32 bitsPerChannel = 16;
    const UInt32 bytesPerFrame = bitsPerChannel / 8 * channelCount;
    
    AudioStreamBasicDescription asbd = {
        .mFormatID = kAudioFormatLinearPCM,
        .mFramesPerPacket = 1,
        .mSampleRate = sampleRate,
        .mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
        .mBitsPerChannel = bitsPerChannel,
        .mChannelsPerFrame = channelCount,
        .mBytesPerFrame = bytesPerFrame,
        .mBytesPerPacket = bytesPerFrame,
    };
    
    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat sampleRate:sampleRate channels:channelCount interleaved:interleaved];
    
    XCTAssert(!format.isStandard);
    XCTAssert(format.channelCount == channelCount);
    XCTAssert(format.bufferCount == bufferCount);
    XCTAssert(format.stride == stride);
    XCTAssert(format.sampleRate == sampleRate);
    XCTAssert(format.isInterleaved == interleaved);
    XCTAssert(format.bitDepthFormat == bitDepthFormat);
    XCTAssert(YASAudioIsEqualASBD(format.streamDescription, &asbd));
    
    YASRelease(format);
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
    
    YASAudioFormat *format = [[YASAudioFormat alloc] initWithStreamDescription:&asbd];
    
    XCTAssert(!format.isStandard);
    XCTAssert(format.channelCount == channelCount);
    XCTAssert(format.bufferCount == bufferCount);
    XCTAssert(format.stride == stride);
    XCTAssert(format.isInterleaved == interleaved);
    XCTAssert(YASAudioIsEqualASBD(format.streamDescription, &asbd));
    
    YASRelease(format);
}

- (void)testEqualAudioFormats
{
    const double sampleRate = 44100;
    const UInt32 channelCount = 2;
    
    YASAudioFormat *audioFormat1 = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:channelCount];
    YASAudioFormat *audioFormat1b = YASRetain(audioFormat1);
    YASAudioFormat *audioFormat2 = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:channelCount];
    NSString *audioFormat3 = @"audioFormat3";
    
    XCTAssert([audioFormat1 isEqual:audioFormat1b]);
    XCTAssert([audioFormat1 isEqual:audioFormat2]);
    XCTAssertFalse([audioFormat1 isEqual:audioFormat3]);
    
    YASRelease(audioFormat1);
    YASRelease(audioFormat1b);
    YASRelease(audioFormat2);
}

- (void)testCreateAudioFormatWithSettings
{
    const double sampleRate = 44100.0;
    
    NSDictionary *settings = nil;
    YASAudioFormat *format = nil;
    
    settings = [NSDictionary yas_linearPCMSettingsWithSampleRate:sampleRate numberOfChannels:2 bitDepth:32 isBigEndian:NO isFloat:YES isNonInterleaved:YES];
    
    format = [[YASAudioFormat alloc] initWithSettings:settings];
    
    if (kAudioFormatFlagIsBigEndian != kAudioFormatFlagsNativeEndian) {
        XCTAssertEqual(format.bitDepthFormat, YASAudioBitDepthFormatFloat32);
        XCTAssertEqual(format.channelCount, 2);
        XCTAssertEqual(format.bufferCount, 2);
        XCTAssertEqual(format.stride, 1);
        XCTAssertEqual(format.sampleRate, sampleRate);
        XCTAssertEqual(format.isInterleaved, NO);
        XCTAssertEqual(format.sampleByteCount, 4);
    } else {
        XCTAssertEqual(format.bitDepthFormat, YASAudioBitDepthFormatOther);
    }
    
    YASRelease(format);
    format = nil;
    
    settings = [NSDictionary yas_linearPCMSettingsWithSampleRate:sampleRate numberOfChannels:4 bitDepth:16 isBigEndian:YES isFloat:NO isNonInterleaved:NO];
    
    format = [[YASAudioFormat alloc] initWithSettings:settings];
    
    if (kAudioFormatFlagIsBigEndian == kAudioFormatFlagsNativeEndian) {
        XCTAssertEqual(format.bitDepthFormat, YASAudioBitDepthFormatInt16);
        XCTAssertEqual(format.channelCount, 4);
        XCTAssertEqual(format.bufferCount, 1);
        XCTAssertEqual(format.stride, 4);
        XCTAssertEqual(format.sampleRate, sampleRate);
        XCTAssertEqual(format.isInterleaved, YES);
        XCTAssertEqual(format.sampleByteCount, 2);
    } else {
        XCTAssertEqual(format.bitDepthFormat, YASAudioBitDepthFormatOther);
    }
    
    YASRelease(format);
    format = nil;
}

- (void)testIsEqualHash
{
    YASAudioFormat *format1 = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32 sampleRate:48000 channels:2 interleaved:YES];
    YASAudioFormat *format2 = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32 sampleRate:48000 channels:2 interleaved:YES];
    YASAudioFormat *format3 = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatInt16 sampleRate:48000 channels:4 interleaved:NO];
    
    XCTAssertEqual(format1.hash, format2.hash);
    XCTAssertNotEqual(format1.hash, format3.hash);
    
    YASRelease(format1);
    YASRelease(format2);
    YASRelease(format3);
}

- (void)testDescription
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    NSString *description = format.description;
    
    XCTAssertNotEqual([description rangeOfString:@"bitDepthFormat"].location, NSNotFound);
    XCTAssertNotEqual([description rangeOfString:@"sampleRate"].location, NSNotFound);
    XCTAssertNotEqual([description rangeOfString:@"bitsPerChannel"].location, NSNotFound);
    XCTAssertNotEqual([description rangeOfString:@"bytesPerFrame"].location, NSNotFound);
    XCTAssertNotEqual([description rangeOfString:@"bytesPerPacket"].location, NSNotFound);
    XCTAssertNotEqual([description rangeOfString:@"channelsPerFrame"].location, NSNotFound);
    XCTAssertNotEqual([description rangeOfString:@"formatFlags"].location, NSNotFound);
    XCTAssertNotEqual([description rangeOfString:@"formatID"].location, NSNotFound);
    XCTAssertNotEqual([description rangeOfString:@"framesPerPacket"].location, NSNotFound);
    
    YASRelease(format);
}

@end
