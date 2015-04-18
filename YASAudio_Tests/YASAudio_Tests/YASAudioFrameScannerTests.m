//
//  YASAudioFrameScannerTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioTestUtils.h"

@interface YASAudioFrameScannerTests : XCTestCase

@end

@implementation YASAudioFrameScannerTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testReadFrameScannerNonInterleaved
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    [YASAudioTestUtils fillTestValuesToData:data];

    YASAudioFrameScanner *scanner = [[YASAudioFrameScanner alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = scanner.pointer;
    const NSUInteger *pointerFrame = scanner.frame;
    const NSUInteger *pointerChannel = scanner.channel;

    for (NSInteger i = 0; i < 2; i++) {
        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*pointerFrame, frame);
            UInt32 channel = 0;
            while (pointer->v) {
                XCTAssertEqual(*pointerChannel, channel);
                XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, 0, channel));
                YASAudioFrameScannerMoveChannel(scanner);
                channel++;
            }
            XCTAssertEqual(channel, channels);
            YASAudioFrameScannerMoveFrame(scanner);
            frame++;
        }
        XCTAssertEqual(frame, frameLength);
        YASAudioFrameScannerReset(scanner);
    }

    YASRelease(scanner);
    YASRelease(data);
}

- (void)testReadFrameScannerInterleavedUseMacro
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 3;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:channels
                                                                interleaved:YES];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.stride, channels);

    [YASAudioTestUtils fillTestValuesToData:data];

    YASAudioFrameScanner *scanner = [[YASAudioFrameScanner alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = scanner.pointer;
    const NSUInteger *pointerFrame = scanner.frame;
    const NSUInteger *pointerChannel = scanner.channel;

    for (NSInteger i = 0; i < 2; i++) {
        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*pointerFrame, frame);
            UInt32 channel = 0;
            while (pointer->v) {
                XCTAssertEqual(*pointerChannel, channel);
                XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, channel, 0));
                YASAudioFrameScannerMoveChannel(scanner);
                channel++;
            }
            XCTAssertEqual(channel, channels);
            YASAudioFrameScannerMoveFrame(scanner);
            frame++;
        }
        XCTAssertEqual(frame, frameLength);
        YASAudioFrameScannerReset(scanner);
    }

    YASRelease(scanner);
    YASRelease(data);
}

- (void)testReadFrameScannerUseMethod
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 3;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:channels
                                                                interleaved:YES];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.stride, channels);

    [YASAudioTestUtils fillTestValuesToData:data];

    YASAudioFrameScanner *scanner = [[YASAudioFrameScanner alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = scanner.pointer;
    const NSUInteger *pointerFrame = scanner.frame;
    const NSUInteger *pointerChannel = scanner.channel;

    for (NSInteger i = 0; i < 2; i++) {
        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*pointerFrame, frame);
            UInt32 channel = 0;
            while (pointer->v) {
                XCTAssertEqual(*pointerChannel, channel);
                XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, channel, 0));
                [scanner moveChannel];
                channel++;
            }
            XCTAssertEqual(channel, channels);
            [scanner moveFrame];
            frame++;
        }
        XCTAssertEqual(frame, frameLength);
        [scanner reset];
    }

    YASRelease(scanner);
    YASRelease(data);
}

- (void)testWriteFrameScanner
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    YASAudioMutableFrameScanner *mutableScanner = [[YASAudioMutableFrameScanner alloc] initWithAudioData:data];
    const YASAudioMutablePointer *mutablePointer = mutableScanner.mutablePointer;
    const NSUInteger *mutablePointerFrame = mutableScanner.frame;
    const NSUInteger *mutablePointerChannel = mutableScanner.channel;

    NSUInteger frame = 0;
    while (mutablePointer->v) {
        XCTAssertEqual(*mutablePointerFrame, frame);
        UInt32 channel = 0;
        while (mutablePointer->v) {
            XCTAssertEqual(*mutablePointerChannel, channel);
            *mutablePointer->f32 = (Float32)TestValue((UInt32)*mutablePointerFrame, 0, (UInt32)*mutablePointerChannel);
            YASAudioFrameScannerMoveChannel(mutableScanner);
            channel++;
        }
        YASAudioFrameScannerMoveFrame(mutableScanner);
        frame++;
    }
    XCTAssertEqual(frame, frameLength);
    YASRelease(mutableScanner);

    YASAudioFrameScanner *scanner = [[YASAudioFrameScanner alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = scanner.pointer;
    const NSUInteger *pointerFrame = scanner.frame;
    const NSUInteger *pointerChannel = scanner.channel;

    while (pointer->v) {
        while (pointer->v) {
            XCTAssertEqual(*pointer->f32, (Float32)TestValue((UInt32)*pointerFrame, 0, (UInt32)*pointerChannel));
            YASAudioFrameScannerMoveChannel(scanner);
        }
        YASAudioFrameScannerMoveFrame(scanner);
    }

    YASRelease(scanner);

    YASRelease(data);
}

- (void)testSetFramePosition
{
    const UInt32 frameLength = 16;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:1];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    YASAudioMutablePointer bufferPointer = [data pointerAtBuffer:0];
    for (UInt32 frame = 0; frame < frameLength; frame++) {
        bufferPointer.f32[frame] = TestValue(frame, 0, 0);
    }

    YASAudioFrameScanner *scanner = [[YASAudioFrameScanner alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = scanner.pointer;
    const NSUInteger *pointerFrame = scanner.frame;

    XCTAssertEqual(*pointerFrame, 0);
    XCTAssertEqual(*pointer->f32, TestValue(0, 0, 0));

    [scanner setFramePosition:3];
    XCTAssertEqual(*pointerFrame, 3);
    XCTAssertEqual(*pointer->f32, TestValue(3, 0, 0));

    while (pointer->v) {
        YASAudioFrameScannerMoveChannel(scanner);
    }

    [scanner setFramePosition:5];
    XCTAssertFalse(pointer->v);

    [scanner setChannelPosition:0];
    XCTAssertEqual(*pointer->f32, TestValue(5, 0, 0));

    XCTAssertThrows([scanner setFramePosition:16]);
    XCTAssertThrows([scanner setFramePosition:100]);

    YASRelease(scanner);
    YASRelease(data);
}

- (void)testSetChannelPosition
{
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:channels
                                                                interleaved:YES];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:1];
    YASRelease(format);

    YASAudioMutablePointer bufferPointer = [data pointerAtBuffer:0];
    for (UInt32 ch = 0; ch < channels; ch++) {
        bufferPointer.f32[ch] = TestValue(0, ch, 0);
    }

    YASAudioFrameScanner *scanner = [[YASAudioFrameScanner alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = scanner.pointer;
    const NSUInteger *pointerChannel = scanner.channel;

    XCTAssertEqual(*pointerChannel, 0);
    XCTAssertEqual(*pointer->f32, TestValue(0, 0, 0));

    [scanner setChannelPosition:2];
    XCTAssertEqual(*pointerChannel, 2);
    XCTAssertEqual(*pointer->f32, TestValue(0, 2, 0));

    XCTAssertThrows([scanner setChannelPosition:4]);
    XCTAssertThrows([scanner setChannelPosition:100]);

    YASRelease(scanner);
    YASRelease(data);
}

- (void)testReadFrameScannerEachBitDepthFormat
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    for (NSUInteger bitDepthFormat = YASAudioBitDepthFormatFloat32; bitDepthFormat <= YASAudioBitDepthFormatInt32;
         bitDepthFormat++) {
        YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                     sampleRate:48000
                                                                       channels:channels
                                                                    interleaved:NO];
        YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
        YASRelease(format);

        [YASAudioTestUtils fillTestValuesToData:data];

        YASAudioFrameScanner *scanner = [[YASAudioFrameScanner alloc] initWithAudioData:data];
        const YASAudioPointer *pointer = scanner.pointer;
        const NSUInteger *frame = scanner.frame;
        const NSUInteger *channel = scanner.channel;

        while (pointer->v) {
            while (pointer->v) {
                UInt32 testValue = (Float64)TestValue((UInt32)*frame, 0, (UInt32)*channel);
                switch (bitDepthFormat) {
                    case YASAudioBitDepthFormatFloat32:
                        XCTAssertEqual(*pointer->f32, (Float32)testValue);
                        break;
                    case YASAudioBitDepthFormatFloat64:
                        XCTAssertEqual(*pointer->f64, (Float64)testValue);
                        break;
                    case YASAudioBitDepthFormatInt16:
                        XCTAssertEqual(*pointer->i16, (SInt16)testValue);
                        break;
                    case YASAudioBitDepthFormatInt32:
                        XCTAssertEqual(*pointer->i32, (SInt32)testValue);
                        break;
                    default:
                        XCTAssert(0);
                        break;
                }

                YASAudioFrameScannerMoveChannel(scanner);
            }
            XCTAssertEqual(*channel, channels);
            YASAudioFrameScannerMoveFrame(scanner);
        }

        XCTAssertEqual(*frame, frameLength);

        YASRelease(scanner);
        YASRelease(data);
    }
}

@end
