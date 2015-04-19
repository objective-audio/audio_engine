//
//  YASAudioDataTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioTestUtils.h"

@interface YASAudioDataTests : XCTestCase

@end

@implementation YASAudioDataTests

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
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:4];

    XCTAssertNotNil(data);
    XCTAssertEqualObjects(data.format, format);
    XCTAssert([data pointerAtBuffer:0].v);
    XCTAssert([data pointerAtBuffer:1].v);
    XCTAssertThrows([data pointerAtBuffer:2]);

    YASRelease(format);
    YASRelease(data);
}

- (void)testCreateFloat32Interleaved1chBuffer
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:1
                                                                interleaved:YES];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:4];

    XCTAssert([data pointerAtBuffer:0].v);
    XCTAssertThrows([data pointerAtBuffer:1]);

    YASRelease(format);
    YASRelease(data);
}

- (void)testCreateFloat64NonInterleaved2chBuffer
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat64
                                                                 sampleRate:48000
                                                                   channels:2
                                                                interleaved:NO];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:4];

    XCTAssert([data pointerAtBuffer:0].v);
    XCTAssertThrows([data pointerAtBuffer:2]);

    YASRelease(format);
    YASRelease(data);
}

- (void)testCreateInt32Interleaved3chBuffer
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFixed824
                                                                 sampleRate:48000
                                                                   channels:3
                                                                interleaved:YES];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:4];

    XCTAssert([data pointerAtBuffer:0].v);
    XCTAssertThrows([data pointerAtBuffer:3]);

    YASRelease(format);
    YASRelease(data);
}

- (void)testCreateInt16NonInterleaved4chBuffer
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatInt16
                                                                 sampleRate:48000
                                                                   channels:4
                                                                interleaved:NO];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:4];

    XCTAssert([data pointerAtBuffer:0].v);
    XCTAssertThrows([data pointerAtBuffer:4]);

    YASRelease(format);
    YASRelease(data);
}

- (void)testSetFrameLength
{
    const UInt32 frameCapacity = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:1];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameCapacity];

    XCTAssertEqual(data.frameLength, frameCapacity);

    data.frameLength = 2;

    XCTAssertEqual(data.frameLength, 2);

    data.frameLength = 0;

    XCTAssertEqual(data.frameLength, 0);

    XCTAssertThrows(data.frameLength = 5);

    XCTAssertEqual(data.frameLength, 0);

    YASRelease(format);
    YASRelease(data);
}

- (void)testClearDataNonInterleaved
{
    const UInt32 frameLength = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:2
                                                                interleaved:NO];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];

    [self _testClearData:data];

    YASRelease(format);
    YASRelease(data);
}

- (void)testClearDataInterleaved
{
    const UInt32 frameLength = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                 sampleRate:48000
                                                                   channels:2
                                                                interleaved:YES];
    YASAudioData *data = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];

    [self _testClearData:data];

    YASRelease(format);
    YASRelease(data);
}

- (void)_testClearData:(YASAudioData *)data
{
    [YASAudioTestUtils fillTestValuesToData:data];

    XCTAssertTrue([YASAudioTestUtils isFilledData:data]);

    [data clear];

    XCTAssertTrue([YASAudioTestUtils isClearedDataWithBuffer:data]);

    [YASAudioTestUtils fillTestValuesToData:data];

    [data clearWithStartFrame:1 length:2];

    const UInt32 bufferCount = data.format.bufferCount;
    const UInt32 stride = data.format.stride;

    for (UInt32 buffer = 0; buffer < bufferCount; buffer++) {
        Float32 *ptr = [data pointerAtBuffer:buffer].v;
        for (UInt32 frame = 0; frame < data.frameLength; frame++) {
            for (UInt32 ch = 0; ch < stride; ch++) {
                if (frame == 1 || frame == 2) {
                    XCTAssertEqual(ptr[frame * stride + ch], 0);
                } else {
                    XCTAssertNotEqual(ptr[frame * stride + ch], 0);
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
         bitDepthFormat <= YASAudioBitDepthFormatFixed824; bitDepthFormat++) {
        YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                     sampleRate:48000
                                                                       channels:2
                                                                    interleaved:interleaved];

        YASAudioData *fromData = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
        YASAudioData *toData = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];

        [YASAudioTestUtils fillTestValuesToData:fromData];

        XCTAssertTrue([toData copyFromData:fromData]);

        [YASAudioTestUtils compareDataFlexiblyWithData:fromData otherData:toData];

        YASRelease(format);
        YASRelease(fromData);
        YASRelease(toData);
    }
}

- (void)testCopyDataDifferentInterleavedFormatFailed
{
    const Float64 sampleRate = 48000;
    const UInt32 frameLength = 4;
    const UInt32 channels = 3;

    for (YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat32;
         bitDepthFormat <= YASAudioBitDepthFormatFixed824; bitDepthFormat++) {
        YASAudioFormat *fromFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                         sampleRate:sampleRate
                                                                           channels:channels
                                                                        interleaved:YES];
        YASAudioFormat *toFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                       sampleRate:sampleRate
                                                                         channels:channels
                                                                      interleaved:NO];

        YASAudioData *fromData = [[YASAudioData alloc] initWithFormat:fromFormat frameCapacity:frameLength];
        YASAudioData *toData = [[YASAudioData alloc] initWithFormat:toFormat frameCapacity:frameLength];

        [YASAudioTestUtils fillTestValuesToData:fromData];

        XCTAssertFalse([toData copyFromData:fromData]);
        XCTAssertThrows([toData copyFromData:nil]);

        YASRelease(fromFormat);
        YASRelease(toFormat);
        YASRelease(fromData);
        YASRelease(toData);
    }
}

- (void)testCopyDataDifferentFrameLength
{
    const Float64 sampleRate = 48000;
    const UInt32 channels = 1;
    const UInt32 fromFrameLength = 4;
    const UInt32 toFrameLength = 2;

    for (YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat32;
         bitDepthFormat <= YASAudioBitDepthFormatFixed824; bitDepthFormat++) {
        YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                     sampleRate:sampleRate
                                                                       channels:channels
                                                                    interleaved:YES];

        YASAudioData *fromData = [[YASAudioData alloc] initWithFormat:format frameCapacity:fromFrameLength];
        YASAudioData *toData = [[YASAudioData alloc] initWithFormat:format frameCapacity:toFrameLength];

        [YASAudioTestUtils fillTestValuesToData:fromData];

        XCTAssertFalse([toData copyFromData:fromData fromStartFrame:0 toStartFrame:0 length:fromFrameLength]);
        XCTAssertTrue([toData copyFromData:fromData fromStartFrame:0 toStartFrame:0 length:toFrameLength]);
        XCTAssertFalse([YASAudioTestUtils compareDataFlexiblyWithData:fromData otherData:toData]);

        YASRelease(format);
        YASRelease(fromData);
        YASRelease(toData);
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
         bitDepthFormat <= YASAudioBitDepthFormatFixed824; bitDepthFormat++) {
        YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                     sampleRate:sampleRate
                                                                       channels:channels
                                                                    interleaved:interleaved];

        YASAudioData *fromData = [[YASAudioData alloc] initWithFormat:format frameCapacity:fromFrameLength];
        YASAudioData *toData = [[YASAudioData alloc] initWithFormat:format frameCapacity:toFrameLength];

        [YASAudioTestUtils fillTestValuesToData:fromData];

        BOOL result = NO;
        const UInt32 length = 2;
        XCTAssertNoThrow(
            result =
                [toData copyFromData:fromData fromStartFrame:fromStartFrame toStartFrame:toStartFrame length:length]);
        XCTAssertTrue(result);

        for (UInt32 ch = 0; ch < channels; ch++) {
            for (UInt32 i = 0; i < length; i++) {
                YASAudioMutablePointer fromPtr =
                    [YASAudioTestUtils mutablePointerWithData:fromData channel:ch frame:fromStartFrame + i];
                YASAudioMutablePointer toPtr =
                    [YASAudioTestUtils mutablePointerWithData:toData channel:ch frame:toStartFrame + i];
                XCTAssertEqual(memcmp(fromPtr.v, toPtr.v, format.sampleByteCount), 0);
                BOOL isFromNotZero = NO;
                BOOL isToNotZero = NO;
                for (UInt32 j = 0; j < format.sampleByteCount; j++) {
                    if (fromPtr.u8[j] != 0) {
                        isFromNotZero = YES;
                    }
                    if (toPtr.u8[j] != 0) {
                        isToNotZero = YES;
                    }
                }
                XCTAssertTrue(isFromNotZero);
                XCTAssertTrue(isToNotZero);
            }
        }

        YASRelease(format);
        YASRelease(fromData);
        YASRelease(toData);
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
         bitDepthFormat <= YASAudioBitDepthFormatFixed824; bitDepthFormat++) {
        YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                     sampleRate:sampleRate
                                                                       channels:channels
                                                                    interleaved:interleaved];

        YASAudioData *fromData = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
        YASAudioData *toData = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];

        [YASAudioTestUtils fillTestValuesToData:fromData];

        XCTAssertNoThrow([toData copyFlexiblyFromData:fromData]);
        XCTAssertTrue([YASAudioTestUtils compareDataFlexiblyWithData:fromData otherData:toData]);

        YASRelease(format);
        YASRelease(fromData);
        YASRelease(toData);
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
         bitDepthFormat <= YASAudioBitDepthFormatFixed824; bitDepthFormat++) {
        YASAudioFormat *fromFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                         sampleRate:sampleRate
                                                                           channels:channels
                                                                        interleaved:interleaved];
        YASAudioFormat *toFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                       sampleRate:sampleRate
                                                                         channels:channels
                                                                      interleaved:!interleaved];

        YASAudioData *fromData = [[YASAudioData alloc] initWithFormat:fromFormat frameCapacity:frameLength];
        YASAudioData *toData = [[YASAudioData alloc] initWithFormat:toFormat frameCapacity:frameLength];

        [YASAudioTestUtils fillTestValuesToData:fromData];

        XCTAssertNoThrow([toData copyFlexiblyFromData:fromData]);
        XCTAssertTrue([YASAudioTestUtils compareDataFlexiblyWithData:fromData otherData:toData]);
        XCTAssertEqual(toData.frameLength, frameLength);

        YASRelease(fromFormat);
        YASRelease(toFormat);
        YASRelease(fromData);
        YASRelease(toData);
    }
}

- (void)testCopyDataFlexiblyDifferentBitDepthFormatFailed
{
    const Float64 sampleRate = 48000.0;
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;
    const YASAudioBitDepthFormat fromBitDepthFormat = YASAudioBitDepthFormatFloat32;
    const YASAudioBitDepthFormat toBitDepthFormat = YASAudioBitDepthFormatFixed824;

    YASAudioFormat *fromFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:fromBitDepthFormat
                                                                     sampleRate:sampleRate
                                                                       channels:channels
                                                                    interleaved:NO];
    YASAudioFormat *toFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:toBitDepthFormat
                                                                   sampleRate:sampleRate
                                                                     channels:channels
                                                                  interleaved:!NO];
    YASAudioData *fromData = [[YASAudioData alloc] initWithFormat:fromFormat frameCapacity:frameLength];
    YASAudioData *toData = [[YASAudioData alloc] initWithFormat:toFormat frameCapacity:frameLength];

    XCTAssertThrows([toData copyFlexiblyFromData:nil]);
    XCTAssertFalse([toData copyFlexiblyFromData:fromData]);

    YASRelease(fromFormat);
    YASRelease(toFormat);
    YASRelease(fromData);
    YASRelease(toData);
}

- (void)testCopyDataFlexiblyFromAudioBufferListSameFormat
{
    const Float64 sampleRate = 48000.0;
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;

    for (YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat32;
         bitDepthFormat <= YASAudioBitDepthFormatFixed824; bitDepthFormat++) {
        YASAudioFormat *interleavedFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                                sampleRate:sampleRate
                                                                                  channels:channels
                                                                               interleaved:YES];
        YASAudioFormat *nonInterleavedFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                                   sampleRate:sampleRate
                                                                                     channels:channels
                                                                                  interleaved:NO];

        YASAudioData *interleavedData =
            [[YASAudioData alloc] initWithFormat:interleavedFormat frameCapacity:frameLength];
        YASAudioData *nonInterleavedData =
            [[YASAudioData alloc] initWithFormat:nonInterleavedFormat frameCapacity:frameLength];

        [YASAudioTestUtils fillTestValuesToData:interleavedData];

        XCTAssertNoThrow([nonInterleavedData copyFlexiblyFromAudioBufferList:interleavedData.audioBufferList]);
        XCTAssertTrue([YASAudioTestUtils compareDataFlexiblyWithData:interleavedData otherData:nonInterleavedData]);
        XCTAssertEqual(nonInterleavedData.frameLength, frameLength);

        [interleavedData clear];
        [nonInterleavedData clear];

        [YASAudioTestUtils fillTestValuesToData:nonInterleavedData];

        XCTAssertNoThrow([interleavedData copyFlexiblyFromAudioBufferList:nonInterleavedData.audioBufferList]);
        XCTAssertTrue([YASAudioTestUtils compareDataFlexiblyWithData:interleavedData otherData:nonInterleavedData]);
        XCTAssertEqual(interleavedData.frameLength, frameLength);

        XCTAssertThrows([interleavedData copyFlexiblyFromAudioBufferList:nil]);

        YASRelease(interleavedFormat);
        YASRelease(nonInterleavedFormat);
        YASRelease(interleavedData);
        YASRelease(nonInterleavedData);
    }
}

- (void)testCopyDataFlexiblyToAudioBufferList
{
    const Float64 sampleRate = 48000.0;
    const UInt32 frameLength = 4;
    const UInt32 channels = 2;

    for (YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat32;
         bitDepthFormat <= YASAudioBitDepthFormatFixed824; bitDepthFormat++) {
        YASAudioFormat *interleavedFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                                sampleRate:sampleRate
                                                                                  channels:channels
                                                                               interleaved:YES];
        YASAudioFormat *nonInterleavedFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                                   sampleRate:sampleRate
                                                                                     channels:channels
                                                                                  interleaved:NO];

        YASAudioData *interleavedData =
            [[YASAudioData alloc] initWithFormat:interleavedFormat frameCapacity:frameLength];
        YASAudioData *nonInterleavedData =
            [[YASAudioData alloc] initWithFormat:nonInterleavedFormat frameCapacity:frameLength];

        [YASAudioTestUtils fillTestValuesToData:interleavedData];

        XCTAssertNoThrow([interleavedData copyFlexiblyToAudioBufferList:nonInterleavedData.mutableAudioBufferList]);
        XCTAssertTrue([YASAudioTestUtils compareDataFlexiblyWithData:interleavedData otherData:nonInterleavedData]);

        [interleavedData clear];
        [nonInterleavedData clear];

        [YASAudioTestUtils fillTestValuesToData:nonInterleavedData];

        XCTAssertNoThrow([nonInterleavedData copyFlexiblyToAudioBufferList:interleavedData.mutableAudioBufferList]);
        XCTAssertTrue([YASAudioTestUtils compareDataFlexiblyWithData:interleavedData otherData:nonInterleavedData]);

        XCTAssertThrows([interleavedData copyFlexiblyToAudioBufferList:nil]);

        YASRelease(interleavedFormat);
        YASRelease(nonInterleavedFormat);
        YASRelease(interleavedData);
        YASRelease(nonInterleavedData);
    }
}

- (void)testInternal
{
    const UInt32 frameLength = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    YASAudioData *sourceBuffer = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];

    YASAudioData *data =
        [[YASAudioData alloc] initWithFormat:format audioBufferList:sourceBuffer.mutableAudioBufferList needsFree:NO];
    XCTAssertNotNil(data);

    YASRelease(data);
    data = nil;

    XCTAssertThrows(data = [[YASAudioData alloc] initWithFormat:format audioBufferList:NULL needsFree:NO]);
    XCTAssertNil(data);

    XCTAssertThrows(
        data =
            [[YASAudioData alloc] initWithFormat:nil audioBufferList:sourceBuffer.mutableAudioBufferList needsFree:NO]);
    XCTAssertNil(data);

    YASRelease(format);
    YASRelease(sourceBuffer);
}

- (void)testCopyObject
{
    const UInt32 frameLength = 4;

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];

    YASAudioData *sourceData = [[YASAudioData alloc] initWithFormat:format frameCapacity:frameLength];
    [YASAudioTestUtils fillTestValuesToData:sourceData];

    YASAudioData *destData = [sourceData copy];

    XCTAssertNotEqualObjects(sourceData, destData);
    XCTAssertTrue([YASAudioTestUtils compareDataFlexiblyWithData:sourceData otherData:destData]);

    YASRelease(destData);
    YASRelease(sourceData);
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
    YASAudioData *destData = [[YASAudioData alloc] initWithFormat:destFormat frameCapacity:frameLength];
    [YASAudioTestUtils fillTestValuesToData:destData];
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
    YASAudioData *sourceData =
        [[YASAudioData alloc] initWithFormat:sourceFormat data:destData outputChannelRoutes:channelRoutes];
    YASRelease(sourceFormat);
    YASRelease(channelRoutes);

    for (UInt32 ch = 0; ch < sourceChannels; ch++) {
        YASAudioMutablePointer destPtr = [destData pointerAtBuffer:destChannelIndices[ch]];
        YASAudioMutablePointer sourcePtr = [sourceData pointerAtBuffer:ch];
        XCTAssertEqual(destPtr.v, sourcePtr.v);
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            Float32 value = sourcePtr.f32[frame];
            Float32 testValue = TestValue(frame, 0, destChannelIndices[ch]);
            XCTAssertEqual(value, testValue);
        }
    }

    YASRelease(destData);
    YASRelease(sourceData);
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
    YASAudioData *sourceData = [[YASAudioData alloc] initWithFormat:sourceFormat frameCapacity:frameLength];
    [YASAudioTestUtils fillTestValuesToData:sourceData];
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
    YASAudioData *destBuffer =
        [[YASAudioData alloc] initWithFormat:destFormat data:sourceData inputChannelRoutes:channelRoutes];
    YASRelease(destFormat);
    YASRelease(channelRoutes);

    for (UInt32 ch = 0; ch < destChannels; ch++) {
        YASAudioMutablePointer destPtr = [destBuffer pointerAtBuffer:ch];
        YASAudioMutablePointer sourcePtr = [sourceData pointerAtBuffer:sourceChannelIndices[ch]];
        XCTAssertEqual(destPtr.v, sourcePtr.v);
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            Float32 value = destPtr.f32[frame];
            Float32 testValue = TestValue(frame, 0, sourceChannelIndices[ch]);
            XCTAssertEqual(value, testValue);
        }
    }

    YASRelease(destBuffer);
    YASRelease(sourceData);
}

#endif

@end
