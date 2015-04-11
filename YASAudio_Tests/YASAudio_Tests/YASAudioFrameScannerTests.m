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
    YASAudioPCMBuffer *pcmBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    for (UInt32 buf = 0; buf < format.bufferCount; buf++) {
        YASAudioPointer pointer = [pcmBuffer dataAtBufferIndex:buf];
        for (UInt32 frame = 0; frame < pcmBuffer.frameLength; frame++) {
            pointer.f32[frame] = TestValue(frame, 0, buf);
        }
    }

    YASAudioFrameScanner *frameScanner = [[YASAudioFrameScanner alloc] initWithPCMBuffer:pcmBuffer];
    YASAudioConstPointer *pointer = frameScanner.pointer;
    const NSUInteger *pointerFrame = frameScanner.frame;
    const NSUInteger *pointerChannel = frameScanner.channel;
    const BOOL *isAtFrameEnd = frameScanner.isAtFrameEnd;
    const BOOL *isAtChannelEnd = frameScanner.isAtChannelEnd;

    for (NSInteger i = 0; i < 2; i++) {
        UInt32 frame = 0;
        while (!*isAtFrameEnd) {
            XCTAssertEqual(*pointerFrame, frame);
            UInt32 channel = 0;
            while (!*isAtChannelEnd) {
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
    YASRelease(pcmBuffer);
}

- (void)testReadFrameScannerInterleaved
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 3;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:channels
                                                                interleaved:YES];
    YASAudioPCMBuffer *pcmBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.stride, channels);

    YASAudioPointer bufferPointer = [pcmBuffer dataAtBufferIndex:0];
    for (UInt32 ch = 0; ch < format.stride; ch++) {
        for (UInt32 frame = 0; frame < pcmBuffer.frameLength; frame++) {
            bufferPointer.f32[frame * channels + ch] = TestValue(frame, ch, 0);
        }
    }

    YASAudioFrameScanner *frameScanner = [[YASAudioFrameScanner alloc] initWithPCMBuffer:pcmBuffer];
    YASAudioConstPointer *pointer = frameScanner.pointer;
    const NSUInteger *pointerFrame = frameScanner.frame;
    const NSUInteger *pointerChannel = frameScanner.channel;
    const BOOL *isAtFrameEnd = frameScanner.isAtFrameEnd;
    const BOOL *isAtChannelEnd = frameScanner.isAtChannelEnd;

    for (NSInteger i = 0; i < 2; i++) {
        UInt32 frame = 0;
        while (!*isAtFrameEnd) {
            XCTAssertEqual(*pointerFrame, frame);
            UInt32 channel = 0;
            while (!*isAtChannelEnd) {
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
    YASRelease(pcmBuffer);
}

- (void)testWriteFrameScanner
{
    const UInt32 frameLength = 16;
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:channels];
    YASAudioPCMBuffer *pcmBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
    YASRelease(format);

    XCTAssertEqual(format.bufferCount, channels);

    @autoreleasepool
    {
        YASAudioMutableFrameScanner *mutableFrameScanner =
            [[YASAudioMutableFrameScanner alloc] initWithPCMBuffer:pcmBuffer];
        YASAudioPointer *mutablePointer = mutableFrameScanner.mutablePointer;
        const NSUInteger *mutablePointerFrame = mutableFrameScanner.frame;
        const NSUInteger *mutablePointerChannel = mutableFrameScanner.channel;
        const BOOL *isMutableAtFrameEnd = mutableFrameScanner.isAtFrameEnd;
        const BOOL *isMutableAtChannelEnd = mutableFrameScanner.isAtChannelEnd;

        NSUInteger frame = 0;
        while (!*isMutableAtFrameEnd) {
            XCTAssertEqual(*mutablePointerFrame, frame);
            UInt32 channel = 0;
            while (!*isMutableAtChannelEnd) {
                XCTAssertEqual(*mutablePointerChannel, channel);
                *mutablePointer->f32 =
                    (Float32)TestValue((UInt32)*mutablePointerFrame, 0, (UInt32)*mutablePointerChannel);
                [mutableFrameScanner moveChannel];
                channel++;
            }
            [mutableFrameScanner moveFrame];
            frame++;
        }
        XCTAssertEqual(frame, frameLength);
        YASRelease(mutableFrameScanner);
    }

    @autoreleasepool
    {
        YASAudioFrameScanner *frameScanner = [[YASAudioFrameScanner alloc] initWithPCMBuffer:pcmBuffer];
        YASAudioConstPointer *pointer = frameScanner.pointer;
        const NSUInteger *pointerFrame = frameScanner.frame;
        const NSUInteger *pointerChannel = frameScanner.channel;
        const BOOL *isAtFrameEnd = frameScanner.isAtFrameEnd;
        const BOOL *isChannelEnd = frameScanner.isAtChannelEnd;

        while (!*isAtFrameEnd) {
            while (!*isChannelEnd) {
                XCTAssertEqual(*pointer->f32, (Float32)TestValue((UInt32)*pointerFrame, 0, (UInt32)*pointerChannel));
                [frameScanner moveChannel];
            }
            [frameScanner moveFrame];
        }

        YASRelease(frameScanner);
    }

    YASRelease(pcmBuffer);
}

- (void)testSetFramePosition
{
    const UInt32 frameLength = 16;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:1];
    YASAudioPCMBuffer *pcmBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
    YASRelease(format);

    YASAudioPointer bufferPointer = [pcmBuffer dataAtBufferIndex:0];
    for (UInt32 frame = 0; frame < frameLength; frame++) {
        bufferPointer.f32[frame] = TestValue(frame, 0, 0);
    }

    YASAudioFrameScanner *frameScanner = [[YASAudioFrameScanner alloc] initWithPCMBuffer:pcmBuffer];
    YASAudioConstPointer *pointer = frameScanner.pointer;
    const NSUInteger *pointerFrame = frameScanner.frame;

    XCTAssertEqual(*pointerFrame, 0);
    XCTAssertEqual(*pointer->f32, TestValue(0, 0, 0));

    [frameScanner setFramePosition:3];
    XCTAssertEqual(*pointerFrame, 3);
    XCTAssertEqual(*pointer->f32, TestValue(3, 0, 0));

    XCTAssertThrows([frameScanner setFramePosition:16]);
    XCTAssertThrows([frameScanner setFramePosition:100]);

    YASRelease(frameScanner);
    YASRelease(pcmBuffer);
}

- (void)testSetChannelPosition
{
    const UInt32 channels = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:channels
                                                                interleaved:YES];
    YASAudioPCMBuffer *pcmBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:1];
    YASRelease(format);

    YASAudioPointer bufferPointer = [pcmBuffer dataAtBufferIndex:0];
    for (UInt32 ch = 0; ch < channels; ch++) {
        bufferPointer.f32[ch] = TestValue(0, ch, 0);
    }

    YASAudioFrameScanner *frameScanner = [[YASAudioFrameScanner alloc] initWithPCMBuffer:pcmBuffer];
    YASAudioConstPointer *pointer = frameScanner.pointer;
    const NSUInteger *pointerChannel = frameScanner.channel;

    XCTAssertEqual(*pointerChannel, 0);
    XCTAssertEqual(*pointer->f32, TestValue(0, 0, 0));

    [frameScanner setChannelPosition:2];
    XCTAssertEqual(*pointerChannel, 2);
    XCTAssertEqual(*pointer->f32, TestValue(0, 2, 0));

    XCTAssertThrows([frameScanner setFramePosition:4]);
    XCTAssertThrows([frameScanner setFramePosition:100]);

    YASRelease(frameScanner);
    YASRelease(pcmBuffer);
}

@end
