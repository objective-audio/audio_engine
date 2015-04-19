//
//  YASAudioFrameScannerTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioTestUtils.h"

@interface YASAudioScannerTests : XCTestCase

@end

@implementation YASAudioScannerTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testReadScannerNonInterleavedUseMacro
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    [YASAudioTestUtils fillTestValuesToData:data];

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        YASAudioScanner *scanner = [[YASAudioScanner alloc] initWithAudioData:data atChannel:buffer];
        const YASAudioPointer *pointer = scanner.pointer;
        const NSUInteger *index = scanner.index;

        for (NSInteger i = 0; i < 2; i++) {
            UInt32 frame = 0;
            while (pointer->v) {
                XCTAssertEqual(*index, frame);
                XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, 0, buffer));
                YASAudioScannerMove(scanner);
                frame++;
            }
            XCTAssertEqual(frame, frameLength);
            YASAudioScannerReset(scanner);
        }

        YASRelease(scanner);
    }

    YASRelease(data);
}

- (void)testReadScannerNonInterleavedUseMethod
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    [YASAudioTestUtils fillTestValuesToData:data];

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        YASAudioScanner *scanner = [[YASAudioScanner alloc] initWithAudioData:data atChannel:buffer];
        const YASAudioPointer *pointer = scanner.pointer;
        const NSUInteger *index = scanner.index;

        for (NSInteger i = 0; i < 2; i++) {
            UInt32 frame = 0;
            while (pointer->v) {
                XCTAssertEqual(*index, frame);
                XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, 0, buffer));
                [scanner move];
                frame++;
            }
            XCTAssertEqual(frame, frameLength);
            [scanner reset];
        }

        YASRelease(scanner);
    }

    YASRelease(data);
}

- (void)testReadScannerInterleaved
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:channels
                                                                interleaved:YES];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.stride, channels);

    [YASAudioTestUtils fillTestValuesToData:data];

    for (UInt32 ch = 0; ch < channels; ch++) {
        YASAudioScanner *scanner = [[YASAudioScanner alloc] initWithAudioData:data atChannel:ch];
        const YASAudioPointer *pointer = scanner.pointer;
        const NSUInteger *index = scanner.index;

        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(frame, *index);
            XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, ch, 0));
            YASAudioScannerMove(scanner);
            frame++;
        }

        YASRelease(scanner);
    }

    YASRelease(data);
}

- (void)testWriteScanner
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        YASAudioMutableScanner *mutableScanner =
            [[YASAudioMutableScanner alloc] initWithAudioData:data atChannel:buffer];
        const YASAudioMutablePointer *mutablePointer = mutableScanner.mutablePointer;
        const NSUInteger *index = mutableScanner.index;

        UInt32 frame = 0;
        while (mutablePointer->v) {
            XCTAssertEqual(*index, frame);
            *mutablePointer->f32 = (Float32)TestValue(frame, 0, buffer);
            YASAudioScannerMove(mutableScanner);
            frame++;
        }

        XCTAssertEqual(frame, frameLength);

        YASRelease(mutableScanner);
    }

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        YASAudioScanner *scanner = [[YASAudioScanner alloc] initWithAudioData:data atChannel:buffer];
        const YASAudioPointer *pointer = scanner.pointer;
        const NSUInteger *index = scanner.index;

        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*index, frame);
            XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, 0, buffer));
            YASAudioScannerMove(scanner);
            frame++;
        }

        XCTAssertEqual(frame, frameLength);

        YASRelease(scanner);
    }

    YASRelease(data);
}

- (void)testSetPosition
{
    const NSUInteger frameLength = 16;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:1];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASAudioMutableScanner *mutableScanner = [[YASAudioMutableScanner alloc] initWithAudioData:data atChannel:0];

    const NSUInteger *index = mutableScanner.index;
    const YASAudioPointer *pointer = mutableScanner.pointer;
    const YASAudioMutablePointer *mutablePointer = mutableScanner.mutablePointer;

    XCTAssertEqual(*index, 0);

    while (mutablePointer->v) {
        *mutablePointer->f32 = (Float32)TestValue((UInt32)*index, 0, 0);
        YASAudioScannerMove(mutableScanner);
    }

    [mutableScanner setPosition:3];
    XCTAssertEqual(*index, 3);
    XCTAssertEqual(*pointer->f32, (Float32)TestValue(3, 0, 0));

    [mutableScanner setPosition:0];
    XCTAssertEqual(*index, 0);
    XCTAssertEqual(*pointer->f32, (Float32)TestValue(0, 0, 0));

    XCTAssertThrows([mutableScanner setPosition:16]);
    XCTAssertThrows([mutableScanner setPosition:100]);

    YASRelease(mutableScanner);
    YASRelease(data);
    YASRelease(format);
}

- (void)testStop
{
    const NSUInteger frameLength = 16;
    const NSUInteger stopIndex = 8;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:1];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    YASAudioScanner *scanner = [[YASAudioScanner alloc] initWithAudioData:data atChannel:0];
    const YASAudioPointer *pointer = scanner.pointer;
    const NSUInteger *index = scanner.index;

    NSUInteger frame = 0;
    while (pointer->v) {
        if (stopIndex == *index) {
            [scanner stop];
        }
        YASAudioScannerMove(scanner);
        frame++;
    }

    XCTAssertEqual(frame, stopIndex + 1);

    YASRelease(scanner);
    YASRelease(data);
}

- (void)testInitFailed
{
    YASAudioMutablePointer pointer = {NULL};

    XCTAssertThrows([[YASAudioScanner alloc] initWithPointer:pointer stride:1 length:1]);

    SInt16 val = 0;
    pointer.v = &val;

    XCTAssertThrows([[YASAudioScanner alloc] initWithPointer:pointer stride:0 length:1]);
    XCTAssertThrows([[YASAudioScanner alloc] initWithPointer:pointer stride:1 length:0]);
}

@end
