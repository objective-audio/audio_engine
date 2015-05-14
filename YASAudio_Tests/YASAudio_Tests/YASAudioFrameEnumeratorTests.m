//
//  YASAudioFrameEnumeratorTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioTestUtils.h"

@interface YASAudioFrameEnumeratorTests : XCTestCase

@end

@implementation YASAudioFrameEnumeratorTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testReadFrameEnumeratorNonInterleaved
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    [YASAudioTestUtils fillTestValuesToData:data];

    YASAudioFrameEnumerator *enumerator = [[YASAudioFrameEnumerator alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = enumerator.pointer;
    const NSUInteger *pointerFrame = enumerator.frame;
    const NSUInteger *pointerChannel = enumerator.channel;

    for (NSInteger i = 0; i < 2; i++) {
        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*pointerFrame, frame);
            UInt32 channel = 0;
            while (pointer->v) {
                XCTAssertEqual(*pointerChannel, channel);
                XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, 0, channel));
                YASAudioFrameEnumeratorMoveChannel(enumerator);
                channel++;
            }
            XCTAssertEqual(channel, channels);
            YASAudioFrameEnumeratorMoveFrame(enumerator);
            frame++;
        }
        XCTAssertEqual(frame, frameLength);
        YASAudioFrameEnumeratorReset(enumerator);
    }

    YASRelease(enumerator);
    YASRelease(data);
}

- (void)testReadFrameEnumeratorInterleavedUseMacro
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 3;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithPCMFormat:YASAudioPCMFormatFloat32
                                                            sampleRate:48000
                                                              channels:channels
                                                           interleaved:YES];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.stride, channels);

    [YASAudioTestUtils fillTestValuesToData:data];

    YASAudioFrameEnumerator *enumerator = [[YASAudioFrameEnumerator alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = enumerator.pointer;
    const NSUInteger *pointerFrame = enumerator.frame;
    const NSUInteger *pointerChannel = enumerator.channel;

    for (NSInteger i = 0; i < 2; i++) {
        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*pointerFrame, frame);
            UInt32 channel = 0;
            while (pointer->v) {
                XCTAssertEqual(*pointerChannel, channel);
                XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, channel, 0));
                YASAudioFrameEnumeratorMoveChannel(enumerator);
                channel++;
            }
            XCTAssertEqual(channel, channels);
            YASAudioFrameEnumeratorMoveFrame(enumerator);
            frame++;
        }
        XCTAssertEqual(frame, frameLength);
        YASAudioFrameEnumeratorReset(enumerator);
    }

    YASRelease(enumerator);
    YASRelease(data);
}

- (void)testReadFrameEnumeratorUseMethod
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 3;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithPCMFormat:YASAudioPCMFormatFloat32
                                                            sampleRate:48000
                                                              channels:channels
                                                           interleaved:YES];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.stride, channels);

    [YASAudioTestUtils fillTestValuesToData:data];

    YASAudioFrameEnumerator *enumerator = [[YASAudioFrameEnumerator alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = enumerator.pointer;
    const NSUInteger *pointerFrame = enumerator.frame;
    const NSUInteger *pointerChannel = enumerator.channel;

    for (NSInteger i = 0; i < 2; i++) {
        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*pointerFrame, frame);
            UInt32 channel = 0;
            while (pointer->v) {
                XCTAssertEqual(*pointerChannel, channel);
                XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, channel, 0));
                [enumerator moveChannel];
                channel++;
            }
            XCTAssertEqual(channel, channels);
            [enumerator moveFrame];
            frame++;
        }
        XCTAssertEqual(frame, frameLength);
        [enumerator reset];
    }

    YASRelease(enumerator);
    YASRelease(data);
}

- (void)testReadFrameEnumeratorByMove
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    [YASAudioTestUtils fillTestValuesToData:data];

    YASAudioFrameEnumerator *enumerator = [[YASAudioFrameEnumerator alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = enumerator.pointer;
    const NSUInteger *pointerFrame = enumerator.frame;
    const NSUInteger *pointerChannel = enumerator.channel;

    NSUInteger frame = 0;
    NSUInteger channel = 0;
    while (pointer->v) {
        XCTAssertEqual(frame, *pointerFrame);
        XCTAssertEqual(channel, *pointerChannel);
        XCTAssertEqual(*pointer->f32, TestValue((UInt32)*pointerFrame, 0, (UInt32)*pointerChannel));

        [enumerator move];

        channel++;
        if (channel == channels) {
            channel = 0;
            frame++;
        }
    }

    XCTAssertEqual(frame, frameLength);

    YASRelease(enumerator);
    YASRelease(data);
}

- (void)testWriteFrameEnumerator
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    YASAudioMutableFrameEnumerator *mutableEnumerator = [[YASAudioMutableFrameEnumerator alloc] initWithAudioData:data];
    const YASAudioMutablePointer *mutablePointer = mutableEnumerator.mutablePointer;
    const NSUInteger *mutablePointerFrame = mutableEnumerator.frame;
    const NSUInteger *mutablePointerChannel = mutableEnumerator.channel;

    NSUInteger frame = 0;
    while (mutablePointer->v) {
        XCTAssertEqual(*mutablePointerFrame, frame);
        UInt32 channel = 0;
        while (mutablePointer->v) {
            XCTAssertEqual(*mutablePointerChannel, channel);
            *mutablePointer->f32 = (Float32)TestValue((UInt32)*mutablePointerFrame, 0, (UInt32)*mutablePointerChannel);
            YASAudioFrameEnumeratorMoveChannel(mutableEnumerator);
            channel++;
        }
        YASAudioFrameEnumeratorMoveFrame(mutableEnumerator);
        frame++;
    }
    XCTAssertEqual(frame, frameLength);
    YASRelease(mutableEnumerator);

    YASAudioFrameEnumerator *enumerator = [[YASAudioFrameEnumerator alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = enumerator.pointer;
    const NSUInteger *pointerFrame = enumerator.frame;
    const NSUInteger *pointerChannel = enumerator.channel;

    while (pointer->v) {
        XCTAssertEqual(*pointer->f32, (Float32)TestValue((UInt32)*pointerFrame, 0, (UInt32)*pointerChannel));
        YASAudioFrameEnumeratorMove(enumerator);
    }

    XCTAssertEqual(*pointerFrame, frameLength);
    XCTAssertEqual(*pointerChannel, channels);

    YASRelease(enumerator);

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

    YASAudioFrameEnumerator *enumerator = [[YASAudioFrameEnumerator alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = enumerator.pointer;
    const NSUInteger *pointerFrame = enumerator.frame;

    XCTAssertEqual(*pointerFrame, 0);
    XCTAssertEqual(*pointer->f32, TestValue(0, 0, 0));

    [enumerator setFramePosition:3];
    XCTAssertEqual(*pointerFrame, 3);
    XCTAssertEqual(*pointer->f32, TestValue(3, 0, 0));

    while (pointer->v) {
        YASAudioFrameEnumeratorMoveChannel(enumerator);
    }

    [enumerator setFramePosition:5];
    XCTAssertFalse(pointer->v);

    [enumerator setChannelPosition:0];
    XCTAssertEqual(*pointer->f32, TestValue(5, 0, 0));

    XCTAssertThrows([enumerator setFramePosition:16]);
    XCTAssertThrows([enumerator setFramePosition:100]);

    YASRelease(enumerator);
    YASRelease(data);
}

- (void)testSetChannelPosition
{
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithPCMFormat:YASAudioPCMFormatFloat32
                                                            sampleRate:48000
                                                              channels:channels
                                                           interleaved:YES];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:1];
    YASRelease(format);

    YASAudioMutablePointer bufferPointer = [data pointerAtBuffer:0];
    for (UInt32 ch = 0; ch < channels; ch++) {
        bufferPointer.f32[ch] = TestValue(0, ch, 0);
    }

    YASAudioFrameEnumerator *enumerator = [[YASAudioFrameEnumerator alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = enumerator.pointer;
    const NSUInteger *pointerChannel = enumerator.channel;

    XCTAssertEqual(*pointerChannel, 0);
    XCTAssertEqual(*pointer->f32, TestValue(0, 0, 0));

    [enumerator setChannelPosition:2];
    XCTAssertEqual(*pointerChannel, 2);
    XCTAssertEqual(*pointer->f32, TestValue(0, 2, 0));

    XCTAssertThrows([enumerator setChannelPosition:4]);
    XCTAssertThrows([enumerator setChannelPosition:100]);

    YASRelease(enumerator);
    YASRelease(data);
}

- (void)testReadFrameEnumeratorEachPCMFormat
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    for (NSUInteger pcmFormat = YASAudioPCMFormatFloat32; pcmFormat <= YASAudioPCMFormatFixed824; pcmFormat++) {
        YASAudioFormat *format =
            [[YASAudioFormat alloc] initWithPCMFormat:pcmFormat sampleRate:48000 channels:channels interleaved:NO];
        YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
        YASRelease(format);

        [YASAudioTestUtils fillTestValuesToData:data];

        YASAudioFrameEnumerator *enumerator = [[YASAudioFrameEnumerator alloc] initWithAudioData:data];
        const YASAudioPointer *pointer = enumerator.pointer;
        const NSUInteger *frame = enumerator.frame;
        const NSUInteger *channel = enumerator.channel;

        while (pointer->v) {
            while (pointer->v) {
                UInt32 testValue = (Float64)TestValue((UInt32)*frame, 0, (UInt32)*channel);
                switch (pcmFormat) {
                    case YASAudioPCMFormatFloat32:
                        XCTAssertEqual(*pointer->f32, (Float32)testValue);
                        break;
                    case YASAudioPCMFormatFloat64:
                        XCTAssertEqual(*pointer->f64, (Float64)testValue);
                        break;
                    case YASAudioPCMFormatInt16:
                        XCTAssertEqual(*pointer->i16, (SInt16)testValue);
                        break;
                    case YASAudioPCMFormatFixed824:
                        XCTAssertEqual(*pointer->i32, (SInt32)testValue);
                        break;
                    default:
                        XCTAssert(0);
                        break;
                }

                YASAudioFrameEnumeratorMoveChannel(enumerator);
            }
            XCTAssertEqual(*channel, channels);
            YASAudioFrameEnumeratorMoveFrame(enumerator);
        }

        XCTAssertEqual(*frame, frameLength);

        YASRelease(enumerator);
        YASRelease(data);
    }
}

- (void)testStop
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;
    const NSUInteger stopFrame = 8;
    const NSUInteger stopChannel = 2;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithPCMFormat:YASAudioPCMFormatFloat32
                                                            sampleRate:48000
                                                              channels:channels
                                                           interleaved:YES];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    YASAudioFrameEnumerator *enumerator = [[YASAudioFrameEnumerator alloc] initWithAudioData:data];
    const YASAudioPointer *pointer = enumerator.pointer;
    const NSUInteger *frame = enumerator.frame;
    const NSUInteger *channel = enumerator.channel;

    NSUInteger fr = 0;
    NSUInteger ch;
    while (pointer->v) {
        ch = 0;
        while (pointer->v) {
            if (*frame == stopFrame && *channel == stopChannel) {
                [enumerator stop];
            }
            YASAudioFrameEnumeratorMoveChannel(enumerator);
            ch++;
        }
        YASAudioFrameEnumeratorMoveFrame(enumerator);
        fr++;
    }

    XCTAssertEqual(fr, stopFrame + 1);
    XCTAssertEqual(ch, stopChannel + 1);

    YASRelease(enumerator);
    YASRelease(data);
}

@end
