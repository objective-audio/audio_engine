//
//  YASAudioFrameScannerTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudio.h"

static UInt32 TestValue(UInt32 frame, UInt32 ch, UInt32 buf)
{
    return frame + 1024 * (ch + 1) + 512 * (buf + 1);
}

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

- (void)testReadBufferScanner
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    for (UInt32 buf = 0; buf < format.bufferCount; buf++) {
        YASAudioPointer pointer = [data pointerAtBuffer:buf];
        for (UInt32 frame = 0; frame < data.frameLength; frame++) {
            pointer.f32[frame] = TestValue(frame, 0, buf);
        }
    }

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        YASAudioScanner *bufferScanner = [[YASAudioScanner alloc] initWithAudioData:data atBuffer:buffer];
        const YASAudioConstPointer *pointer = bufferScanner.pointer;
        const NSUInteger *index = bufferScanner.index;

        for (NSInteger i = 0; i < 2; i++) {
            UInt32 frame = 0;
            while (pointer->v) {
                XCTAssertEqual(*index, frame);
                XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, 0, buffer));
                [bufferScanner move];
                frame++;
            }
            XCTAssertEqual(frame, frameLength);
            [bufferScanner reset];
        }

        YASRelease(bufferScanner);
    }

    YASRelease(data);
}

- (void)testWriteBufferScanner
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        YASAudioMutableScanner *mutableScanner =
            [[YASAudioMutableScanner alloc] initWithAudioData:data atBuffer:buffer];
        const YASAudioPointer *mutablePointer = mutableScanner.mutablePointer;
        const NSUInteger *index = mutableScanner.index;

        UInt32 frame = 0;
        while (mutablePointer->v) {
            XCTAssertEqual(*index, frame);
            *mutablePointer->f32 = (Float32)TestValue(frame, 0, buffer);
            [mutableScanner move];
            frame++;
        }

        XCTAssertEqual(frame, frameLength);

        YASRelease(mutableScanner);
    }

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        YASAudioScanner *scanner = [[YASAudioScanner alloc] initWithAudioData:data atBuffer:buffer];
        const YASAudioConstPointer *pointer = scanner.pointer;
        const NSUInteger *index = scanner.index;

        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*index, frame);
            XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, 0, buffer));
            [scanner move];
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
    YASAudioMutableScanner *mutableScanner = [[YASAudioMutableScanner alloc] initWithAudioData:data atBuffer:0];

    const NSUInteger *index = mutableScanner.index;
    const YASAudioConstPointer *pointer = mutableScanner.pointer;
    const YASAudioPointer *mutablePointer = mutableScanner.mutablePointer;

    XCTAssertEqual(*index, 0);

    while (mutablePointer->v) {
        *mutablePointer->f32 = (Float32)TestValue((UInt32)*index, 0, 0);
        [mutableScanner move];
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

- (void)testReadFrameScannerNonInterleaved
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    for (UInt32 buf = 0; buf < format.bufferCount; buf++) {
        YASAudioPointer pointer = [data pointerAtBuffer:buf];
        for (UInt32 frame = 0; frame < data.frameLength; frame++) {
            pointer.f32[frame] = TestValue(frame, 0, buf);
        }
    }

    YASAudioFrameScanner *frameScanner = [[YASAudioFrameScanner alloc] initWithAudioData:data];
    const YASAudioConstPointer *pointer = frameScanner.pointer;
    const NSUInteger *pointerFrame = frameScanner.frame;
    const NSUInteger *pointerChannel = frameScanner.channel;

    for (NSInteger i = 0; i < 2; i++) {
        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*pointerFrame, frame);
            UInt32 channel = 0;
            while (pointer->v) {
                XCTAssertEqual(*pointerChannel, channel);
                XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, 0, channel));
                [frameScanner moveChannel];
                channel++;
            }
            XCTAssertEqual(channel, channels);
            [frameScanner moveFrame];
            frame++;
        }
        XCTAssertEqual(frame, frameLength);
        [frameScanner reset];
    }

    YASRelease(frameScanner);
    YASRelease(data);
}

- (void)testReadFrameScannerInterleaved
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

    YASAudioPointer bufferPointer = [data pointerAtBuffer:0];
    for (UInt32 ch = 0; ch < format.stride; ch++) {
        for (UInt32 frame = 0; frame < data.frameLength; frame++) {
            bufferPointer.f32[frame * channels + ch] = TestValue(frame, ch, 0);
        }
    }

    YASAudioFrameScanner *frameScanner = [[YASAudioFrameScanner alloc] initWithAudioData:data];
    const YASAudioConstPointer *pointer = frameScanner.pointer;
    const NSUInteger *pointerFrame = frameScanner.frame;
    const NSUInteger *pointerChannel = frameScanner.channel;

    for (NSInteger i = 0; i < 2; i++) {
        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*pointerFrame, frame);
            UInt32 channel = 0;
            while (pointer->v) {
                XCTAssertEqual(*pointerChannel, channel);
                XCTAssertEqual(*pointer->f32, (Float32)TestValue(frame, channel, 0));
                [frameScanner moveChannel];
                channel++;
            }
            XCTAssertEqual(channel, channels);
            [frameScanner moveFrame];
            frame++;
        }
        XCTAssertEqual(frame, frameLength);
        [frameScanner reset];
    }

    YASRelease(frameScanner);
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

    YASAudioMutableFrameScanner *mutableFrameScanner = [[YASAudioMutableFrameScanner alloc] initWithAudioData:data];
    const YASAudioPointer *mutablePointer = mutableFrameScanner.mutablePointer;
    const NSUInteger *mutablePointerFrame = mutableFrameScanner.frame;
    const NSUInteger *mutablePointerChannel = mutableFrameScanner.channel;

    NSUInteger frame = 0;
    while (mutablePointer->v) {
        XCTAssertEqual(*mutablePointerFrame, frame);
        UInt32 channel = 0;
        while (mutablePointer->v) {
            XCTAssertEqual(*mutablePointerChannel, channel);
            *mutablePointer->f32 = (Float32)TestValue((UInt32)*mutablePointerFrame, 0, (UInt32)*mutablePointerChannel);
            [mutableFrameScanner moveChannel];
            channel++;
        }
        [mutableFrameScanner moveFrame];
        frame++;
    }
    XCTAssertEqual(frame, frameLength);
    YASRelease(mutableFrameScanner);

    YASAudioFrameScanner *frameScanner = [[YASAudioFrameScanner alloc] initWithAudioData:data];
    const YASAudioConstPointer *pointer = frameScanner.pointer;
    const NSUInteger *pointerFrame = frameScanner.frame;
    const NSUInteger *pointerChannel = frameScanner.channel;

    while (pointer->v) {
        while (pointer->v) {
            XCTAssertEqual(*pointer->f32, (Float32)TestValue((UInt32)*pointerFrame, 0, (UInt32)*pointerChannel));
            [frameScanner moveChannel];
        }
        [frameScanner moveFrame];
    }

    YASRelease(frameScanner);

    YASRelease(data);
}

- (void)testSetFramePosition
{
    const UInt32 frameLength = 16;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:1];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    YASRelease(format);

    YASAudioPointer bufferPointer = [data pointerAtBuffer:0];
    for (UInt32 frame = 0; frame < frameLength; frame++) {
        bufferPointer.f32[frame] = TestValue(frame, 0, 0);
    }

    YASAudioFrameScanner *frameScanner = [[YASAudioFrameScanner alloc] initWithAudioData:data];
    const YASAudioConstPointer *pointer = frameScanner.pointer;
    const NSUInteger *pointerFrame = frameScanner.frame;

    XCTAssertEqual(*pointerFrame, 0);
    XCTAssertEqual(*pointer->f32, TestValue(0, 0, 0));

    [frameScanner setFramePosition:3];
    XCTAssertEqual(*pointerFrame, 3);
    XCTAssertEqual(*pointer->f32, TestValue(3, 0, 0));

    XCTAssertThrows([frameScanner setFramePosition:16]);
    XCTAssertThrows([frameScanner setFramePosition:100]);

    YASRelease(frameScanner);
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

    YASAudioPointer bufferPointer = [data pointerAtBuffer:0];
    for (UInt32 ch = 0; ch < channels; ch++) {
        bufferPointer.f32[ch] = TestValue(0, ch, 0);
    }

    YASAudioFrameScanner *frameScanner = [[YASAudioFrameScanner alloc] initWithAudioData:data];
    const YASAudioConstPointer *pointer = frameScanner.pointer;
    const NSUInteger *pointerChannel = frameScanner.channel;

    XCTAssertEqual(*pointerChannel, 0);
    XCTAssertEqual(*pointer->f32, TestValue(0, 0, 0));

    [frameScanner setChannelPosition:2];
    XCTAssertEqual(*pointerChannel, 2);
    XCTAssertEqual(*pointer->f32, TestValue(0, 2, 0));

    XCTAssertThrows([frameScanner setFramePosition:4]);
    XCTAssertThrows([frameScanner setFramePosition:100]);

    YASRelease(frameScanner);
    YASRelease(data);
}

@end
