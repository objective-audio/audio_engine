//
//  YASAudioPCMBufferTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudio.h"

static UInt32 TestValue(UInt32 frame, UInt32 ch, UInt32 buf)
{
    return frame + 1024 * (ch + 1) + 512 * (buf + 1);
}

@interface YASAudioPCMBufferTests : XCTestCase

@end

@implementation YASAudioPCMBufferTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testCreateStandardBuffer
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:4];

    XCTAssertNotNil(buffer);
    XCTAssertEqualObjects(buffer.format, format);
    XCTAssert([buffer float32DataAtBufferIndex:0]);
    XCTAssert([buffer float32DataAtBufferIndex:1]);
    XCTAssertThrows([buffer float32DataAtBufferIndex:2]);
    XCTAssertThrows([buffer float64DataAtBufferIndex:0]);
    XCTAssertThrows([buffer int16DataAtBufferIndex:0]);
    XCTAssertThrows([buffer int32DataAtBufferIndex:0]);

    YASRelease(format);
    YASRelease(buffer);
}

- (void)testCreateFloat32Interleaved1chBuffer
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:1
                                                                interleaved:YES];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:4];

    XCTAssert([buffer float32DataAtBufferIndex:0]);
    XCTAssertThrows([buffer float32DataAtBufferIndex:1]);
    XCTAssertThrows([buffer float64DataAtBufferIndex:0]);
    XCTAssertThrows([buffer int16DataAtBufferIndex:0]);
    XCTAssertThrows([buffer int32DataAtBufferIndex:0]);

    YASRelease(format);
    YASRelease(buffer);
}

- (void)testCreateFloat64NonInterleaved2chBuffer
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat64
                                                                 sampleRate:48000
                                                                   channels:2
                                                                interleaved:NO];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:4];

    XCTAssert([buffer float64DataAtBufferIndex:0]);
    XCTAssertThrows([buffer float64DataAtBufferIndex:2]);
    XCTAssertThrows([buffer float32DataAtBufferIndex:0]);
    XCTAssertThrows([buffer int16DataAtBufferIndex:0]);
    XCTAssertThrows([buffer int32DataAtBufferIndex:0]);

    YASRelease(format);
    YASRelease(buffer);
}

- (void)testCreateInt32Interleaved3chBuffer
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatInt32
                                                                 sampleRate:48000
                                                                   channels:3
                                                                interleaved:YES];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:4];

    XCTAssert([buffer int32DataAtBufferIndex:0]);
    XCTAssertThrows([buffer int32DataAtBufferIndex:3]);
    XCTAssertThrows([buffer int16DataAtBufferIndex:0]);
    XCTAssertThrows([buffer float64DataAtBufferIndex:0]);
    XCTAssertThrows([buffer float32DataAtBufferIndex:0]);

    YASRelease(format);
    YASRelease(buffer);
}

- (void)testCreateInt16NonInterleaved4chBuffer
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatInt16
                                                                 sampleRate:48000
                                                                   channels:4
                                                                interleaved:NO];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:4];

    XCTAssert([buffer int16DataAtBufferIndex:0]);
    XCTAssertThrows([buffer int16DataAtBufferIndex:4]);
    XCTAssertThrows([buffer int32DataAtBufferIndex:0]);
    XCTAssertThrows([buffer float64DataAtBufferIndex:0]);
    XCTAssertThrows([buffer float32DataAtBufferIndex:0]);

    YASRelease(format);
    YASRelease(buffer);
}

- (void)testSetFrameLength
{
    const UInt32 frameCapacity = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:1];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameCapacity];

    XCTAssertEqual(buffer.frameLength, frameCapacity);

    buffer.frameLength = 2;

    XCTAssertEqual(buffer.frameLength, 2);

    buffer.frameLength = 0;

    XCTAssertEqual(buffer.frameLength, 0);

    XCTAssertThrows(buffer.frameLength = 5);

    XCTAssertEqual(buffer.frameLength, 0);

    YASRelease(format);
    YASRelease(buffer);
}

- (void)testClearDataNonInterleaved
{
    const UInt32 frameLength = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:2
                                                                interleaved:NO];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];

    [self _testClearData:buffer];

    YASRelease(format);
    YASRelease(buffer);
}

- (void)testClearDataInterleaved
{
    const UInt32 frameLength = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:2
                                                                interleaved:YES];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];

    [self _testClearData:buffer];

    YASRelease(format);
    YASRelease(buffer);
}

- (void)_testClearData:(YASAudioPCMBuffer *)buffer
{
    [self _fillDataToBuffer:buffer];

    XCTAssertTrue([self _isFilledDataWithBuffer:buffer]);

    [buffer clearData];

    XCTAssertTrue([self _isClearedDataWithBuffer:buffer]);

    [self _fillDataToBuffer:buffer];

    [buffer clearDataWithStartFrame:1 length:2];

    for (UInt32 buf = 0; buf < buffer.bufferCount; buf++) {
        Float32 *ptr = [buffer float32DataAtBufferIndex:buf];
        for (UInt32 frame = 0; frame < buffer.frameLength; frame++) {
            for (UInt32 ch = 0; ch < buffer.stride; ch++) {
                if (frame == 1 || frame == 2) {
                    XCTAssertEqual(ptr[frame * buffer.stride + ch], 0);
                } else {
                    XCTAssertNotEqual(ptr[frame * buffer.stride + ch], 0);
                }
            }
        }
    }
}

- (void)testCopyDataInterleavedFormatSuccess
{
    [self _testCopyDataFormatSuccessWithInterleaved:NO];
    [self _testCopyDataFormatSuccessWithInterleaved:YES];
}

- (void)_testCopyDataFormatSuccessWithInterleaved:(BOOL)interleaved
{
    const UInt32 frameLength = 4;

    for (YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat32;
         bitDepthFormat <= YASAudioBitDepthFormatInt32; bitDepthFormat++) {
        YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                     sampleRate:48000
                                                                       channels:2
                                                                    interleaved:interleaved];

        YASAudioPCMBuffer *fromBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
        YASAudioPCMBuffer *toBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];

        [self _fillDataToBuffer:fromBuffer];

        XCTAssertTrue([toBuffer copyDataFromBuffer:fromBuffer]);

        [self _compareBufferFlexiblyWithBuffer:fromBuffer otherBuffer:toBuffer];

        YASRelease(format);
        YASRelease(fromBuffer);
        YASRelease(toBuffer);
    }
}

- (void)testCopyDataDifferentInterleavedFormatFailed
{
    const Float64 sampleRate = 48000;
    const UInt32 frameLength = 4;
    const UInt32 channels = 3;

    for (YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat32;
         bitDepthFormat <= YASAudioBitDepthFormatInt32; bitDepthFormat++) {
        YASAudioFormat *fromFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                         sampleRate:sampleRate
                                                                           channels:channels
                                                                        interleaved:YES];
        YASAudioFormat *toFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                       sampleRate:sampleRate
                                                                         channels:channels
                                                                      interleaved:NO];

        YASAudioPCMBuffer *fromBuffer =
            [[YASAudioPCMBuffer alloc] initWithPCMFormat:fromFormat frameCapacity:frameLength];
        YASAudioPCMBuffer *toBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:toFormat frameCapacity:frameLength];

        [self _fillDataToBuffer:fromBuffer];

        XCTAssertFalse([toBuffer copyDataFromBuffer:fromBuffer]);
        XCTAssertThrows([toBuffer copyDataFromBuffer:nil]);

        YASRelease(fromFormat);
        YASRelease(toFormat);
        YASRelease(fromBuffer);
        YASRelease(toBuffer);
    }
}

- (void)testCopyDataDifferentFrameLength
{
    const Float64 sampleRate = 48000;
    const UInt32 channels = 1;
    const UInt32 fromFrameLength = 4;
    const UInt32 toFrameLength = 2;

    for (YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat32;
         bitDepthFormat <= YASAudioBitDepthFormatInt32; bitDepthFormat++) {
        YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                     sampleRate:sampleRate
                                                                       channels:channels
                                                                    interleaved:YES];

        YASAudioPCMBuffer *fromBuffer =
            [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:fromFrameLength];
        YASAudioPCMBuffer *toBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:toFrameLength];

        [self _fillDataToBuffer:fromBuffer];

        XCTAssertFalse([toBuffer copyDataFromBuffer:fromBuffer fromStartFrame:0 toStartFrame:0 length:fromFrameLength]);
        XCTAssertTrue([toBuffer copyDataFromBuffer:fromBuffer fromStartFrame:0 toStartFrame:0 length:toFrameLength]);
        XCTAssertFalse([self _compareBufferFlexiblyWithBuffer:fromBuffer otherBuffer:toBuffer]);

        YASRelease(format);
        YASRelease(fromBuffer);
        YASRelease(toBuffer);
    }
}

- (void)testCopyDataStartFrame
{
    [self _testCopyDataStartFrameWithInterleaved:YES];
    [self _testCopyDataStartFrameWithInterleaved:NO];
}

- (void)_testCopyDataStartFrameWithInterleaved:(BOOL)interleaved
{
    const Float64 sampleRate = 48000;
    const UInt32 fromFrameLength = 4;
    const UInt32 toFrameLength = 8;
    const UInt32 fromStartFrame = 2;
    const UInt32 toStartFrame = 4;
    const UInt32 channels = 2;

    for (YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat32;
         bitDepthFormat <= YASAudioBitDepthFormatInt32; bitDepthFormat++) {
        YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                     sampleRate:sampleRate
                                                                       channels:channels
                                                                    interleaved:interleaved];

        YASAudioPCMBuffer *fromBuffer =
            [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:fromFrameLength];
        YASAudioPCMBuffer *toBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:toFrameLength];

        [self _fillDataToBuffer:fromBuffer];

        BOOL result = NO;
        const UInt32 length = 2;
        XCTAssertNoThrow(result = [toBuffer copyDataFromBuffer:fromBuffer
                                                fromStartFrame:fromStartFrame
                                                  toStartFrame:toStartFrame
                                                        length:length]);
        XCTAssertTrue(result);

        for (UInt32 ch = 0; ch < channels; ch++) {
            for (UInt32 i = 0; i < length; i++) {
                Byte *fromPtr = [self _dataPointerWithBuffer:fromBuffer channel:ch frame:fromStartFrame + i];
                Byte *toPtr = [self _dataPointerWithBuffer:toBuffer channel:ch frame:toStartFrame + i];
                XCTAssertEqual(memcmp(fromPtr, toPtr, format.sampleByteCount), 0);
                BOOL isFromNotZero = NO;
                BOOL isToNotZero = NO;
                for (UInt32 j = 0; j < format.sampleByteCount; j++) {
                    if (fromPtr[j] != 0) {
                        isFromNotZero = YES;
                    }
                    if (toPtr[j] != 0) {
                        isToNotZero = YES;
                    }
                }
                XCTAssertTrue(isFromNotZero);
                XCTAssertTrue(isToNotZero);
            }
        }

        YASRelease(format);
        YASRelease(fromBuffer);
        YASRelease(toBuffer);
    }
}

- (void)testCopyDataFlexiblySameFormat
{
    [self _testCopyDataFormatSuccessWithInterleaved:NO];
    [self _testCopyDataFormatSuccessWithInterleaved:YES];
}

- (void)_testCopyDataFlexiblySameFormatWithInterleaved:(BOOL)interleaved
{
    const Float64 sampleRate = 48000.0;
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;

    for (YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat32;
         bitDepthFormat <= YASAudioBitDepthFormatInt32; bitDepthFormat++) {
        YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                     sampleRate:sampleRate
                                                                       channels:channels
                                                                    interleaved:interleaved];

        YASAudioPCMBuffer *fromBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
        YASAudioPCMBuffer *toBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];

        [self _fillDataToBuffer:fromBuffer];

        XCTAssertNoThrow([toBuffer copyDataFlexiblyFromBuffer:fromBuffer]);
        XCTAssertTrue([self _compareBufferFlexiblyWithBuffer:fromBuffer otherBuffer:toBuffer]);

        YASRelease(format);
        YASRelease(fromBuffer);
        YASRelease(toBuffer);
    }
}

- (void)testCopyDataFlexiblyDifferentFormatSuccess
{
    [self _testCopyDataFlexiblyDifferentFormatSuccessFromInterleaved:NO];
    [self _testCopyDataFlexiblyDifferentFormatSuccessFromInterleaved:YES];
}

- (void)_testCopyDataFlexiblyDifferentFormatSuccessFromInterleaved:(BOOL)interleaved
{
    const Float64 sampleRate = 48000.0;
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;

    for (YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat32;
         bitDepthFormat <= YASAudioBitDepthFormatInt32; bitDepthFormat++) {
        YASAudioFormat *fromFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                         sampleRate:sampleRate
                                                                           channels:channels
                                                                        interleaved:interleaved];
        YASAudioFormat *toFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                       sampleRate:sampleRate
                                                                         channels:channels
                                                                      interleaved:!interleaved];

        YASAudioPCMBuffer *fromBuffer =
            [[YASAudioPCMBuffer alloc] initWithPCMFormat:fromFormat frameCapacity:frameLength];
        YASAudioPCMBuffer *toBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:toFormat frameCapacity:frameLength];

        [self _fillDataToBuffer:fromBuffer];

        XCTAssertNoThrow([toBuffer copyDataFlexiblyFromBuffer:fromBuffer]);
        XCTAssertTrue([self _compareBufferFlexiblyWithBuffer:fromBuffer otherBuffer:toBuffer]);
        XCTAssertEqual(toBuffer.frameLength, frameLength);

        YASRelease(fromFormat);
        YASRelease(toFormat);
        YASRelease(fromBuffer);
        YASRelease(toBuffer);
    }
}

- (void)testCopyDataFlexiblyDifferentBitDepthFormatFailed
{
    const Float64 sampleRate = 48000.0;
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;
    const YASAudioBitDepthFormat fromBitDepthFormat = YASAudioBitDepthFormatFloat32;
    const YASAudioBitDepthFormat toBitDepthFormat = YASAudioBitDepthFormatInt32;

    YASAudioFormat *fromFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:fromBitDepthFormat
                                                                     sampleRate:sampleRate
                                                                       channels:channels
                                                                    interleaved:NO];
    YASAudioFormat *toFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:toBitDepthFormat
                                                                   sampleRate:sampleRate
                                                                     channels:channels
                                                                  interleaved:!NO];
    YASAudioPCMBuffer *fromBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:fromFormat frameCapacity:frameLength];
    YASAudioPCMBuffer *toBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:toFormat frameCapacity:frameLength];

    XCTAssertThrows([toBuffer copyDataFlexiblyFromBuffer:nil]);
    XCTAssertFalse([toBuffer copyDataFlexiblyFromBuffer:fromBuffer]);

    YASRelease(fromFormat);
    YASRelease(toFormat);
    YASRelease(fromBuffer);
    YASRelease(toBuffer);
}

- (void)testCopyDataFlexiblyFromAudioBufferListSameFormat
{
    const Float64 sampleRate = 48000.0;
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;

    for (YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat32;
         bitDepthFormat <= YASAudioBitDepthFormatInt32; bitDepthFormat++) {
        YASAudioFormat *interleavedFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                                sampleRate:sampleRate
                                                                                  channels:channels
                                                                               interleaved:YES];
        YASAudioFormat *nonInterleavedFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                                   sampleRate:sampleRate
                                                                                     channels:channels
                                                                                  interleaved:NO];

        YASAudioPCMBuffer *interleavedBuffer =
            [[YASAudioPCMBuffer alloc] initWithPCMFormat:interleavedFormat frameCapacity:frameLength];
        YASAudioPCMBuffer *nonInterleavedBuffer =
            [[YASAudioPCMBuffer alloc] initWithPCMFormat:nonInterleavedFormat frameCapacity:frameLength];

        [self _fillDataToBuffer:interleavedBuffer];

        XCTAssertNoThrow([nonInterleavedBuffer copyDataFlexiblyFromAudioBufferList:interleavedBuffer.audioBufferList]);
        XCTAssertTrue([self _compareBufferFlexiblyWithBuffer:interleavedBuffer otherBuffer:nonInterleavedBuffer]);
        XCTAssertEqual(nonInterleavedBuffer.frameLength, frameLength);

        [interleavedBuffer clearData];
        [nonInterleavedBuffer clearData];

        [self _fillDataToBuffer:nonInterleavedBuffer];

        XCTAssertNoThrow([interleavedBuffer copyDataFlexiblyFromAudioBufferList:nonInterleavedBuffer.audioBufferList]);
        XCTAssertTrue([self _compareBufferFlexiblyWithBuffer:interleavedBuffer otherBuffer:nonInterleavedBuffer]);
        XCTAssertEqual(interleavedBuffer.frameLength, frameLength);

        XCTAssertThrows([interleavedBuffer copyDataFlexiblyFromAudioBufferList:nil]);

        YASRelease(interleavedFormat);
        YASRelease(nonInterleavedFormat);
        YASRelease(interleavedBuffer);
        YASRelease(nonInterleavedBuffer);
    }
}

- (void)testCopyDataFlexiblyToAudioBufferList
{
    const Float64 sampleRate = 48000.0;
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;

    for (YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat32;
         bitDepthFormat <= YASAudioBitDepthFormatInt32; bitDepthFormat++) {
        YASAudioFormat *interleavedFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                                sampleRate:sampleRate
                                                                                  channels:channels
                                                                               interleaved:YES];
        YASAudioFormat *nonInterleavedFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                                   sampleRate:sampleRate
                                                                                     channels:channels
                                                                                  interleaved:NO];

        YASAudioPCMBuffer *interleavedBuffer =
            [[YASAudioPCMBuffer alloc] initWithPCMFormat:interleavedFormat frameCapacity:frameLength];
        YASAudioPCMBuffer *nonInterleavedBuffer =
            [[YASAudioPCMBuffer alloc] initWithPCMFormat:nonInterleavedFormat frameCapacity:frameLength];

        [self _fillDataToBuffer:interleavedBuffer];

        XCTAssertNoThrow(
            [interleavedBuffer copyDataFlexiblyToAudioBufferList:nonInterleavedBuffer.mutableAudioBufferList]);
        XCTAssertTrue([self _compareBufferFlexiblyWithBuffer:interleavedBuffer otherBuffer:nonInterleavedBuffer]);

        [interleavedBuffer clearData];
        [nonInterleavedBuffer clearData];

        [self _fillDataToBuffer:nonInterleavedBuffer];

        XCTAssertNoThrow(
            [nonInterleavedBuffer copyDataFlexiblyToAudioBufferList:interleavedBuffer.mutableAudioBufferList]);
        XCTAssertTrue([self _compareBufferFlexiblyWithBuffer:interleavedBuffer otherBuffer:nonInterleavedBuffer]);

        XCTAssertThrows([interleavedBuffer copyDataFlexiblyToAudioBufferList:nil]);

        YASRelease(interleavedFormat);
        YASRelease(nonInterleavedFormat);
        YASRelease(interleavedBuffer);
        YASRelease(nonInterleavedBuffer);
    }
}

- (void)testInternal
{
    const UInt32 frameLength = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    YASAudioPCMBuffer *sourceBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];

    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format
                                                             audioBufferList:sourceBuffer.mutableAudioBufferList
                                                                   needsFree:NO];
    XCTAssertNotNil(buffer);

    YASRelease(buffer);
    buffer = nil;

    XCTAssertThrows(buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format audioBufferList:NULL needsFree:NO]);
    XCTAssertNil(buffer);

    XCTAssertThrows(buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:nil
                                                          audioBufferList:sourceBuffer.mutableAudioBufferList
                                                                needsFree:NO]);
    XCTAssertNil(buffer);

    YASRelease(format);
    YASRelease(sourceBuffer);
}

- (void)testCopyObject
{
    const UInt32 frameLength = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];

    YASAudioPCMBuffer *sourceBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
    [self _fillDataToBuffer:sourceBuffer];

    YASAudioPCMBuffer *destBuffer = [sourceBuffer copy];

    XCTAssertNotEqualObjects(sourceBuffer, destBuffer);
    XCTAssertTrue([self _compareBufferFlexiblyWithBuffer:sourceBuffer otherBuffer:destBuffer]);

    YASRelease(destBuffer);
    YASRelease(sourceBuffer);
    YASRelease(format);
}

#if (!TARGET_OS_IPHONE && TARGET_OS_MAC)

- (void)testInitWithOutputChannelRoutes
{
    const UInt32 frameLength = 4;
    const UInt32 sourceChannels = 2;
    const UInt32 destChannels = 4;
    const UInt32 bus = 0;
    const UInt32 sampleRate = 48000;
    const UInt32 destChannelIndices[2] = {3, 0};

    YASAudioFormat *destFormat =
        [[YASAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:destChannels];
    YASAudioPCMBuffer *destBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:destFormat frameCapacity:frameLength];
    [self _fillDataToBuffer:destBuffer];
    YASRelease(destFormat);

    NSMutableArray *channelRoutes = [[NSMutableArray alloc] initWithCapacity:2];
    for (UInt32 i = 0; i < sourceChannels; i++) {
        YASAudioChannelRoute *channelRoute = [[YASAudioChannelRoute alloc] initWithSourceBus:bus
                                                                               sourceChannel:i
                                                                              destinationBus:bus
                                                                          destinationChannel:destChannelIndices[i]];
        [channelRoutes addObject:channelRoute];
        YASRelease(channelRoute);
    }

    YASAudioFormat *sourceFormat =
        [[YASAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:sourceChannels];
    YASAudioPCMBuffer *sourceBuffer =
        [[YASAudioPCMBuffer alloc] initWithPCMFormat:sourceFormat buffer:destBuffer outputChannelRoutes:channelRoutes];
    YASRelease(sourceFormat);
    YASRelease(channelRoutes);

    for (UInt32 ch = 0; ch < sourceChannels; ch++) {
        Float32 *destPtr = [destBuffer float32DataAtBufferIndex:destChannelIndices[ch]];
        Float32 *sourcePtr = [sourceBuffer float32DataAtBufferIndex:ch];
        XCTAssertEqual(destPtr, sourcePtr);
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            Float32 value = sourcePtr[frame];
            Float32 testValue = TestValue(frame, 0, destChannelIndices[ch]);
            XCTAssertEqual(value, testValue);
        }
    }

    YASRelease(destBuffer);
    YASRelease(sourceBuffer);
}

- (void)testInitWithInputChannelRoutes
{
    const UInt32 frameLength = 4;
    const UInt32 sourceChannels = 4;
    const UInt32 destChannels = 2;
    const UInt32 bus = 0;
    const UInt32 sampleRate = 48000;
    const UInt32 sourceChannelIndices[2] = {2, 1};

    YASAudioFormat *sourceFormat =
        [[YASAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:sourceChannels];
    YASAudioPCMBuffer *sourceBuffer =
        [[YASAudioPCMBuffer alloc] initWithPCMFormat:sourceFormat frameCapacity:frameLength];
    [self _fillDataToBuffer:sourceBuffer];
    YASRelease(sourceFormat);

    NSMutableArray *channelRoutes = [[NSMutableArray alloc] initWithCapacity:2];
    for (UInt32 i = 0; i < destChannels; i++) {
        YASAudioChannelRoute *channelRoute = [[YASAudioChannelRoute alloc] initWithSourceBus:bus
                                                                               sourceChannel:sourceChannelIndices[i]
                                                                              destinationBus:bus
                                                                          destinationChannel:i];
        [channelRoutes addObject:channelRoute];
        YASRelease(channelRoute);
    }

    YASAudioFormat *destFormat =
        [[YASAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:destChannels];
    YASAudioPCMBuffer *destBuffer =
        [[YASAudioPCMBuffer alloc] initWithPCMFormat:destFormat buffer:sourceBuffer inputChannelRoutes:channelRoutes];
    YASRelease(destFormat);
    YASRelease(channelRoutes);

    for (UInt32 ch = 0; ch < destChannels; ch++) {
        Float32 *destPtr = [destBuffer float32DataAtBufferIndex:ch];
        Float32 *sourcePtr = [sourceBuffer float32DataAtBufferIndex:sourceChannelIndices[ch]];
        XCTAssertEqual(destPtr, sourcePtr);
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            Float32 value = destPtr[frame];
            Float32 testValue = TestValue(frame, 0, sourceChannelIndices[ch]);
            XCTAssertEqual(value, testValue);
        }
    }

    YASRelease(destBuffer);
    YASRelease(sourceBuffer);
}

#endif

- (void)testReadData
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:4];
    YASRelease(format);

    [self _fillDataToBuffer:buffer];

    __block UInt32 bufferCount = 0;

    [buffer readData:^(const void *data, const UInt32 bufferIndex) {
        const Float32 *floatData = data;
        for (UInt32 i = 0; i < buffer.frameLength; i++) {
            XCTAssertEqual(floatData[i], TestValue(i, 0, bufferIndex));
        }
        bufferCount++;
    }];

    XCTAssertEqual(bufferCount, 2);

    YASRelease(buffer);
}

- (void)testWriteData
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    YASAudioPCMBuffer *writeBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:4];
    YASAudioPCMBuffer *fillBuffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:4];
    YASRelease(format);

    [self _fillDataToBuffer:fillBuffer];

    [writeBuffer writeData:^(void *data, const UInt32 bufferIndex) {
        Float32 *floatData = data;
        for (UInt32 i = 0; i < writeBuffer.frameLength; i++) {
            floatData[i] = TestValue(i, 0, bufferIndex);
        }
    }];

    XCTAssertTrue([self _isFilledDataWithBuffer:writeBuffer]);
    XCTAssertTrue([self _compareBufferFlexiblyWithBuffer:fillBuffer otherBuffer:writeBuffer]);

    YASRelease(fillBuffer);
    YASRelease(writeBuffer);
}

- (void)testReadValueFloat32
{
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:channels
                                                                interleaved:NO];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
    YASRelease(format);

    [self _fillDataToBuffer:buffer];

    __block UInt32 count = 0;

    [buffer enumerateReadValue:^(Float64 value, const UInt32 bufferIndex, const UInt32 channel, const UInt32 frame) {
        XCTAssertEqual((Float32)value, (Float32)TestValue(frame, channel, bufferIndex));
        count++;
    }];

    XCTAssertEqual(count, frameLength * channels);

    YASRelease(buffer);
}

- (void)testReadValueFloat64
{
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat64
                                                                 sampleRate:48000
                                                                   channels:channels
                                                                interleaved:NO];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
    YASRelease(format);

    [self _fillDataToBuffer:buffer];

    __block UInt32 count = 0;

    [buffer enumerateReadValue:^(Float64 value, const UInt32 bufferIndex, const UInt32 channel, const UInt32 frame) {
        XCTAssertEqual(value, (Float64)TestValue(frame, channel, bufferIndex));
        count++;
    }];

    XCTAssertEqual(count, frameLength * channels);

    YASRelease(buffer);
}

- (void)testReadValueInt16
{
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatInt16
                                                                 sampleRate:48000
                                                                   channels:channels
                                                                interleaved:NO];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
    YASRelease(format);

    [self _fillDataToBuffer:buffer];

    __block UInt32 count = 0;

    [buffer enumerateReadValue:^(Float64 value, const UInt32 bufferIndex, const UInt32 channel, const UInt32 frame) {
        XCTAssertEqual(value * INT16_MAX, TestValue(frame, channel, bufferIndex));
        count++;
    }];

    XCTAssertEqual(count, frameLength * channels);

    YASRelease(buffer);
}

- (void)testReadValueInt32
{
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatInt32
                                                                 sampleRate:48000
                                                                   channels:channels
                                                                interleaved:NO];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
    YASRelease(format);

    [self _fillDataToBuffer:buffer];

    __block UInt32 count = 0;

    [buffer enumerateReadValue:^(Float64 value, const UInt32 bufferIndex, const UInt32 channel, const UInt32 frame) {
        XCTAssertEqual(value * INT32_MAX, TestValue(frame, channel, bufferIndex));
        count++;
    }];

    XCTAssertEqual(count, frameLength * channels);

    YASRelease(buffer);
}

- (void)testWriteValueFloat32
{
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:channels
                                                                interleaved:NO];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
    YASRelease(format);

    __block UInt32 count = 0;

    [buffer enumerateWriteValue:^Float64(const UInt32 bufferIndex, const UInt32 channel, const UInt32 frame) {
        count++;
        return TestValue(frame, channel, bufferIndex);
    }];

    XCTAssertEqual(count, frameLength * channels);
    count = 0;

    [buffer enumerateReadValue:^(Float64 value, const UInt32 bufferIndex, const UInt32 channel, const UInt32 frame) {
        XCTAssertEqual((UInt32)value, TestValue(frame, channel, bufferIndex));
        count++;
    }];

    XCTAssertEqual(count, frameLength * channels);

    YASRelease(buffer);
}

- (void)testWriteValueFloat64
{
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat64
                                                                 sampleRate:48000
                                                                   channels:channels
                                                                interleaved:NO];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
    YASRelease(format);

    __block UInt32 count = 0;

    [buffer enumerateWriteValue:^Float64(const UInt32 bufferIndex, const UInt32 channel, const UInt32 frame) {
        count++;
        return TestValue(frame, channel, bufferIndex);
    }];

    XCTAssertEqual(count, frameLength * channels);
    count = 0;

    [buffer enumerateReadValue:^(Float64 value, const UInt32 bufferIndex, const UInt32 channel, const UInt32 frame) {
        XCTAssertEqual((UInt32)value, TestValue(frame, channel, bufferIndex));
        count++;
    }];

    XCTAssertEqual(count, frameLength * channels);

    YASRelease(buffer);
}

- (void)testWriteValueInt16
{
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatInt16
                                                                 sampleRate:48000
                                                                   channels:channels
                                                                interleaved:NO];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
    YASRelease(format);

    __block UInt32 count = 0;

    [buffer enumerateWriteValue:^Float64(const UInt32 bufferIndex, const UInt32 channel, const UInt32 frame) {
        count++;
        return (Float64)TestValue(frame, channel, bufferIndex) / INT16_MAX;
    }];

    XCTAssertEqual(count, frameLength * channels);
    count = 0;

    [buffer enumerateReadValue:^(Float64 value, const UInt32 bufferIndex, const UInt32 channel, const UInt32 frame) {
        XCTAssertEqual((UInt32)(value * INT16_MAX), TestValue(frame, channel, bufferIndex));
        count++;
    }];

    XCTAssertEqual(count, frameLength * channels);

    YASRelease(buffer);
}

- (void)testWriteValueInt32
{
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatInt32
                                                                 sampleRate:48000
                                                                   channels:channels
                                                                interleaved:NO];
    YASAudioPCMBuffer *buffer = [[YASAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frameLength];
    YASRelease(format);

    __block UInt32 count = 0;

    [buffer enumerateWriteValue:^Float64(const UInt32 bufferIndex, const UInt32 channel, const UInt32 frame) {
        count++;
        return (Float64)TestValue(frame, channel, bufferIndex) / INT32_MAX;
    }];

    XCTAssertEqual(count, frameLength * channels);
    count = 0;

    [buffer enumerateReadValue:^(Float64 value, const UInt32 bufferIndex, const UInt32 channel, const UInt32 frame) {
        XCTAssertEqual((UInt32)(value * INT32_MAX), TestValue(frame, channel, bufferIndex));
        count++;
    }];

    XCTAssertEqual(count, frameLength * channels);

    YASRelease(buffer);
}

#pragma mark -

- (void)_fillDataToBuffer:(YASAudioPCMBuffer *)buffer
{
    YASAudioBitDepthFormat bitDepthFormat = buffer.format.bitDepthFormat;

    for (UInt32 buf = 0; buf < buffer.bufferCount; buf++) {
        for (UInt32 frame = 0; frame < buffer.frameLength; frame++) {
            for (UInt32 ch = 0; ch < buffer.stride; ch++) {
                UInt32 index = frame * buffer.stride + ch;
                UInt32 value = TestValue(frame, ch, buf);
                switch (bitDepthFormat) {
                    case YASAudioBitDepthFormatFloat32: {
                        Float32 *ptr = [buffer float32DataAtBufferIndex:buf];
                        ptr[index] = value;
                    } break;
                    case YASAudioBitDepthFormatFloat64: {
                        Float64 *ptr = [buffer float64DataAtBufferIndex:buf];
                        ptr[index] = value;
                    } break;
                    case YASAudioBitDepthFormatInt16: {
                        SInt16 *ptr = [buffer int16DataAtBufferIndex:buf];
                        ptr[index] = value;
                    } break;
                    case YASAudioBitDepthFormatInt32: {
                        SInt32 *ptr = [buffer int32DataAtBufferIndex:buf];
                        ptr[index] = value;
                    } break;
                    default:
                        break;
                }
            }
        }
    }
}

- (BOOL)_isFilledDataWithBuffer:(YASAudioPCMBuffer *)buffer
{
    YASAudioBitDepthFormat bitDepthFormat = buffer.format.bitDepthFormat;

    for (UInt32 buf = 0; buf < buffer.bufferCount; buf++) {
        for (UInt32 frame = 0; frame < buffer.frameLength; frame++) {
            for (UInt32 ch = 0; ch < buffer.stride; ch++) {
                UInt32 index = frame * buffer.stride + ch;
                switch (bitDepthFormat) {
                    case YASAudioBitDepthFormatFloat32: {
                        Float32 *ptr = [buffer float32DataAtBufferIndex:buf];
                        if (ptr[index] == 0) {
                            return NO;
                        }
                    } break;
                    case YASAudioBitDepthFormatFloat64: {
                        Float64 *ptr = [buffer float64DataAtBufferIndex:buf];
                        if (ptr[index] == 0) {
                            return NO;
                        }
                    } break;
                    case YASAudioBitDepthFormatInt16: {
                        SInt16 *ptr = [buffer int16DataAtBufferIndex:buf];
                        if (ptr[index] == 0) {
                            return NO;
                        }
                    } break;
                    case YASAudioBitDepthFormatInt32: {
                        SInt32 *ptr = [buffer int32DataAtBufferIndex:buf];
                        if (ptr[index] == 0) {
                            return NO;
                        }
                    } break;
                    default:
                        return NO;
                }
            }
        }
    }

    return YES;
}

- (BOOL)_isClearedDataWithBuffer:(YASAudioPCMBuffer *)buffer
{
    const AudioBufferList *abl = buffer.audioBufferList;

    for (UInt32 buf = 0; buf < abl->mNumberBuffers; buf++) {
        Byte *ptr = abl->mBuffers[buf].mData;
        for (UInt32 frame = 0; frame < abl->mBuffers[buf].mDataByteSize; frame++) {
            if (ptr[frame] != 0) {
                return NO;
            }
        }
    }

    return YES;
}

- (BOOL)_compareBufferFlexiblyWithBuffer:(YASAudioPCMBuffer *)buffer1 otherBuffer:(YASAudioPCMBuffer *)buffer2
{
    if (buffer1.format.channelCount != buffer2.format.channelCount) {
        return NO;
    }

    if (buffer1.frameLength != buffer2.frameLength) {
        return NO;
    }

    if (buffer1.format.sampleByteCount != buffer2.format.sampleByteCount) {
        return NO;
    }

    if (buffer1.format.bitDepthFormat != buffer2.format.bitDepthFormat) {
        return NO;
    }

    for (UInt32 ch = 0; ch < buffer1.format.channelCount; ch++) {
        for (UInt32 frame = 0; frame < buffer1.frameLength; frame++) {
            void *ptr1 = [self _dataPointerWithBuffer:buffer1 channel:ch frame:frame];
            void *ptr2 = [self _dataPointerWithBuffer:buffer2 channel:ch frame:frame];
            int result = memcmp(ptr1, ptr2, buffer1.format.sampleByteCount);
            if (result) {
                return NO;
            }
        }
    }

    return YES;
}

- (void *)_dataPointerWithBuffer:(YASAudioPCMBuffer *)buffer channel:(UInt32)channel frame:(UInt32)frame
{
    const AudioBufferList *abl = buffer.audioBufferList;
    const UInt32 sampleByteCount = buffer.format.sampleByteCount;
    UInt32 index = 0;

    for (UInt32 buf = 0; buf < buffer.bufferCount; buf++) {
        Byte *ptr = abl->mBuffers[buf].mData;
        for (UInt32 ch = 0; ch < buffer.stride; ch++) {
            if (channel == index) {
                return &ptr[(frame * buffer.stride + ch) * sampleByteCount];
            }
            index++;
        }
    }

    return nil;
}

@end
