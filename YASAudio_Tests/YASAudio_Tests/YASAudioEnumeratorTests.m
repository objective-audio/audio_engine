//
//  YASAudioFrameEnumeratorTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioTestUtils.h"

@interface YASAudioEnumeratorTests : XCTestCase

@end

@implementation YASAudioEnumeratorTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testReadEnumeratorNonInterleavedUseMacro
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    [YASAudioTestUtils fillTestValuesToData:data];

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        YASAudioEnumerator *enumerator = [[YASAudioEnumerator alloc] initWithAudioData:data atChannel:buffer];
        const YASAudioPointer *pointer = enumerator.pointer;
        const NSUInteger *index = enumerator.index;

        for (NSInteger i = 0; i < 2; i++) {
            UInt32 frame = 0;
            while (pointer->v) {
                XCTAssertEqual(*index, frame);
                XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, 0, buffer));
                YASAudioEnumeratorMove(enumerator);
                frame++;
            }
            XCTAssertEqual(frame, frameLength);
            YASAudioEnumeratorReset(enumerator);
        }

        YASRelease(enumerator);
    }

    YASRelease(data);
}

- (void)testReadEnumeratorNonInterleavedUseMethod
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    [YASAudioTestUtils fillTestValuesToData:data];

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        YASAudioEnumerator *enumerator = [[YASAudioEnumerator alloc] initWithAudioData:data atChannel:buffer];
        const YASAudioPointer *pointer = enumerator.pointer;
        const NSUInteger *index = enumerator.index;

        for (NSInteger i = 0; i < 2; i++) {
            UInt32 frame = 0;
            while (pointer->v) {
                XCTAssertEqual(*index, frame);
                XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, 0, buffer));
                [enumerator move];
                frame++;
            }
            XCTAssertEqual(frame, frameLength);
            [enumerator reset];
        }

        YASRelease(enumerator);
    }

    YASRelease(data);
}

- (void)testReadEnumeratorInterleaved
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithPCMFormat:YASAudioPCMFormatFloat32
                                                            sampleRate:48000
                                                              channels:channels
                                                           interleaved:YES];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.stride, channels);

    [YASAudioTestUtils fillTestValuesToData:data];

    for (UInt32 ch = 0; ch < channels; ch++) {
        YASAudioEnumerator *enumerator = [[YASAudioEnumerator alloc] initWithAudioData:data atChannel:ch];
        const YASAudioPointer *pointer = enumerator.pointer;
        const NSUInteger *index = enumerator.index;

        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(frame, *index);
            XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, ch, 0));
            YASAudioEnumeratorMove(enumerator);
            frame++;
        }

        YASRelease(enumerator);
    }

    YASRelease(data);
}

- (void)testWriteEnumerator
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        YASAudioMutableEnumerator *mutableEnumerator =
            [[YASAudioMutableEnumerator alloc] initWithAudioData:data atChannel:buffer];
        const YASAudioMutablePointer *mutablePointer = mutableEnumerator.mutablePointer;
        const NSUInteger *index = mutableEnumerator.index;

        UInt32 frame = 0;
        while (mutablePointer->v) {
            XCTAssertEqual(*index, frame);
            *mutablePointer->f32 = (Float32)TestValue(frame, 0, buffer);
            YASAudioEnumeratorMove(mutableEnumerator);
            frame++;
        }

        XCTAssertEqual(frame, frameLength);

        YASRelease(mutableEnumerator);
    }

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        YASAudioEnumerator *enumerator = [[YASAudioEnumerator alloc] initWithAudioData:data atChannel:buffer];
        const YASAudioPointer *pointer = enumerator.pointer;
        const NSUInteger *index = enumerator.index;

        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*index, frame);
            XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, 0, buffer));
            YASAudioEnumeratorMove(enumerator);
            frame++;
        }

        XCTAssertEqual(frame, frameLength);

        YASRelease(enumerator);
    }

    YASRelease(data);
}

- (void)testSetPosition
{
    const NSUInteger frameLength = 16;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:1];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASAudioMutableEnumerator *mutableEnumerator =
        [[YASAudioMutableEnumerator alloc] initWithAudioData:data atChannel:0];

    const NSUInteger *index = mutableEnumerator.index;
    const YASAudioPointer *pointer = mutableEnumerator.pointer;
    const YASAudioMutablePointer *mutablePointer = mutableEnumerator.mutablePointer;

    XCTAssertEqual(*index, 0);

    while (mutablePointer->v) {
        *mutablePointer->f32 = (Float32)TestValue((UInt32)*index, 0, 0);
        YASAudioEnumeratorMove(mutableEnumerator);
    }

    [mutableEnumerator setPosition:3];
    XCTAssertEqual(*index, 3);
    XCTAssertEqual(*pointer->f32, (Float32)TestValue(3, 0, 0));

    [mutableEnumerator setPosition:0];
    XCTAssertEqual(*index, 0);
    XCTAssertEqual(*pointer->f32, (Float32)TestValue(0, 0, 0));

    XCTAssertThrows([mutableEnumerator setPosition:16]);
    XCTAssertThrows([mutableEnumerator setPosition:100]);

    YASRelease(mutableEnumerator);
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

    YASAudioEnumerator *enumerator = [[YASAudioEnumerator alloc] initWithAudioData:data atChannel:0];
    const YASAudioPointer *pointer = enumerator.pointer;
    const NSUInteger *index = enumerator.index;

    NSUInteger frame = 0;
    while (pointer->v) {
        if (stopIndex == *index) {
            [enumerator stop];
        }
        YASAudioEnumeratorMove(enumerator);
        frame++;
    }

    XCTAssertEqual(frame, stopIndex + 1);

    YASRelease(enumerator);
    YASRelease(data);
}

- (void)testInitFailed
{
    YASAudioMutablePointer pointer = {NULL};

    XCTAssertThrows([[YASAudioEnumerator alloc] initWithPointer:pointer stride:1 length:1]);

    SInt16 val = 0;
    pointer.v = &val;

    XCTAssertThrows([[YASAudioEnumerator alloc] initWithPointer:pointer stride:0 length:1]);
    XCTAssertThrows([[YASAudioEnumerator alloc] initWithPointer:pointer stride:1 length:0]);
}

@end
