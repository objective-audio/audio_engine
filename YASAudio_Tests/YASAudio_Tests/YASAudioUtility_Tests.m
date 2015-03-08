//
//  YASAudioUtility_Tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioUtility.h"

@interface YASAudioUtility_Tests : XCTestCase

@end

@implementation YASAudioUtility_Tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testAllocateAudioBufferListInterleaved
{
    const UInt32 ch = 2;
    const UInt32 size = 4;

    AudioBufferList *abl = YASAudioAllocateAudioBufferList(1, ch, size);

    XCTAssertTrue(abl != NULL);
    XCTAssertEqual(abl->mNumberBuffers, 1);
    XCTAssertEqual(abl->mBuffers[0].mNumberChannels, ch);
    XCTAssertEqual(abl->mBuffers[0].mDataByteSize, size);
    XCTAssertTrue(abl->mBuffers[0].mData != NULL);

    YASAudioRemoveAudioBufferList(abl);
}

- (void)testAllocateAudioBufferListNonInterleaved
{
    const UInt32 buf = 2;
    const UInt32 size = 4;

    AudioBufferList *abl = YASAudioAllocateAudioBufferList(buf, 1, size);

    XCTAssertTrue(abl != NULL);
    XCTAssertEqual(abl->mNumberBuffers, buf);
    for (UInt32 i = 0; i < buf; i++) {
        XCTAssertEqual(abl->mBuffers[i].mNumberChannels, 1);
        XCTAssertEqual(abl->mBuffers[i].mDataByteSize, size);
        XCTAssertTrue(abl->mBuffers[i].mData != NULL);
    }

    YASAudioRemoveAudioBufferList(abl);
}

- (void)testAllocateAudioBufferListWithoutData
{
    AudioBufferList *abl;
    UInt32 bufferCount = 1;
    UInt32 numberChannels = 1;

    abl = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, 0);

    XCTAssertTrue(abl != NULL);
    for (UInt32 i = 0; i < bufferCount; i++) {
        XCTAssertEqual(abl->mBuffers[i].mNumberChannels, numberChannels);
        XCTAssertEqual(abl->mBuffers[i].mDataByteSize, 0);
        XCTAssertTrue(abl->mBuffers[i].mData == NULL);
    }

    YASAudioRemoveAudioBufferList(abl);

    abl = YASAudioAllocateAudioBufferListWithoutData(bufferCount, numberChannels);

    XCTAssertTrue(abl != NULL);
    XCTAssertEqual(abl->mNumberBuffers, bufferCount);
    for (UInt32 i = 0; i < bufferCount; i++) {
        XCTAssertEqual(abl->mBuffers[i].mNumberChannels, numberChannels);
        XCTAssertEqual(abl->mBuffers[i].mDataByteSize, 0);
        XCTAssertTrue(abl->mBuffers[i].mData == NULL);
    }

    YASAudioRemoveAudioBufferList(abl);
}

- (void)testCopyAudioBufferListDirectlyEachNonInterleavedSuccess
{
    AudioBufferList *abl1, *abl2;
    const UInt32 bufferCount = 2;
    const UInt32 numberChannels = 1;
    const UInt32 sampleByteCount = sizeof(SInt16);
    const UInt32 frameLength = 4;
    const UInt32 size = sampleByteCount * frameLength;

    abl1 = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, size);
    abl2 = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, size);

    [self _writeSInt16TestDataToAudioBufferList:abl1];

    XCTAssertTrue(YASAudioCopyAudioBufferListDirectly(abl1, abl2));

    for (UInt32 buf = 0; buf < bufferCount; buf++) {
        SInt16 *ptr1 = abl1->mBuffers[buf].mData;
        SInt16 *ptr2 = abl2->mBuffers[buf].mData;
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            XCTAssertEqual(ptr1[frame], ptr2[frame]);
        }
    }

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testCopyAudioBufferListDirectlyEachInterleavedSuccess
{
    AudioBufferList *abl1, *abl2;
    const UInt32 bufferCount = 1;
    const UInt32 numberChannels = 2;
    const UInt32 sampleByteCount = sizeof(SInt16);
    const UInt32 frameLength = 4;
    const UInt32 size = sampleByteCount * frameLength * numberChannels;

    abl1 = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, size);
    abl2 = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, size);

    [self _writeSInt16TestDataToAudioBufferList:abl1];

    XCTAssertTrue(YASAudioCopyAudioBufferListDirectly(abl1, abl2));

    for (UInt32 buf = 0; buf < bufferCount; buf++) {
        SInt16 *ptr1 = abl1->mBuffers[buf].mData;
        SInt16 *ptr2 = abl2->mBuffers[buf].mData;
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            for (UInt32 ch = 0; ch < numberChannels; ch++) {
                XCTAssertEqual(ptr1[frame * numberChannels + ch], ptr2[frame * numberChannels + ch]);
            }
        }
    }

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testCopyAudioBufferListDirectlySizeLargerThanSourceSuccess
{
    AudioBufferList *abl1, *abl2;
    const UInt32 bufferCount = 1;
    const UInt32 numberChannels = 1;
    const UInt32 sampleByteCount = sizeof(SInt16);
    const UInt32 fromFrameLength = 4;
    const UInt32 toFrameLength = 8;
    const UInt32 fromSize = sampleByteCount * fromFrameLength;
    const UInt32 toSize = sampleByteCount * toFrameLength;

    abl1 = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, fromSize);
    abl2 = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, toSize);

    [self _writeSInt16TestDataToAudioBufferList:abl1];

    XCTAssertTrue(YASAudioCopyAudioBufferListDirectly(abl1, abl2));

    for (UInt32 buf = 0; buf < bufferCount; buf++) {
        SInt16 *ptr1 = abl1->mBuffers[buf].mData;
        SInt16 *ptr2 = abl2->mBuffers[buf].mData;
        for (UInt32 frame = 0; frame < fromFrameLength; frame++) {
            XCTAssertEqual(ptr1[frame], ptr2[frame]);
        }
    }

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testCopyAudioBufferListDirectlyMismatchInterleavedFailed
{
    AudioBufferList *abl1, *abl2;
    const UInt32 size = 4;

    abl1 = YASAudioAllocateAudioBufferList(1, 2, size);
    abl2 = YASAudioAllocateAudioBufferList(2, 1, size);

    XCTAssertFalse(YASAudioCopyAudioBufferListDirectly(abl1, abl2));
    XCTAssertFalse(YASAudioCopyAudioBufferListDirectly(abl2, abl1));

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testCopyAudioBufferListDirectlySizeSmallerThanSourceFailed
{
    AudioBufferList *abl1, *abl2;

    abl1 = YASAudioAllocateAudioBufferList(2, 1, 8);
    abl2 = YASAudioAllocateAudioBufferList(2, 1, 4);

    [self _writeSInt16TestDataToAudioBufferList:abl1];

    XCTAssertFalse(YASAudioCopyAudioBufferListDirectly(abl1, abl2));

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testCopyAudioBufferListDirectlyChannelsSmallerThanSourceFailed
{
    AudioBufferList *abl1, *abl2;

    abl1 = YASAudioAllocateAudioBufferList(1, 2, 4);
    abl2 = YASAudioAllocateAudioBufferList(1, 1, 4);

    [self _writeSInt16TestDataToAudioBufferList:abl1];

    XCTAssertFalse(YASAudioCopyAudioBufferListDirectly(abl1, abl2));

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testCopyAudioBufferListFlexiblyEachNonInterleavedSuccess
{
    AudioBufferList *abl1, *abl2;
    const UInt32 bufferCount = 2;
    const UInt32 numberChannels = 1;
    const UInt32 sampleByteCount = sizeof(SInt16);
    const UInt32 frameLength = 4;
    const UInt32 size = sampleByteCount * frameLength;

    abl1 = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, size);
    abl2 = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, size);

    [self _writeSInt16TestDataToAudioBufferList:abl1];

    UInt32 outFrameLength = 0;

    XCTAssertTrue(YASAudioCopyAudioBufferListFlexibly(abl1, abl2, sampleByteCount, &outFrameLength));
    XCTAssertEqual(outFrameLength, frameLength);

    for (UInt32 buf = 0; buf < bufferCount; buf++) {
        SInt16 *ptr1 = abl1->mBuffers[buf].mData;
        SInt16 *ptr2 = abl2->mBuffers[buf].mData;
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            XCTAssertEqual(ptr1[frame], ptr2[frame]);
        }
    }

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testCopyAudioBufferListFlexiblyEachInterleavedSuccess
{
    AudioBufferList *abl1, *abl2;
    const UInt32 bufferCount = 1;
    const UInt32 numberChannels = 2;
    const UInt32 sampleByteCount = sizeof(SInt16);
    const UInt32 frameLength = 4;
    const UInt32 size = sampleByteCount * frameLength * numberChannels;

    abl1 = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, size);
    abl2 = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, size);

    [self _writeSInt16TestDataToAudioBufferList:abl1];

    UInt32 outFrameLength = 0;

    XCTAssertTrue(YASAudioCopyAudioBufferListFlexibly(abl1, abl2, sampleByteCount, &outFrameLength));
    XCTAssertEqual(outFrameLength, frameLength);

    for (UInt32 buf = 0; buf < bufferCount; buf++) {
        SInt16 *ptr1 = abl1->mBuffers[buf].mData;
        SInt16 *ptr2 = abl2->mBuffers[buf].mData;
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            for (UInt32 ch = 0; ch < numberChannels; ch++) {
                XCTAssertEqual(ptr1[frame * numberChannels + ch], ptr2[frame * numberChannels + ch]);
            }
        }
    }

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testCopyAudioBufferListFlexiblyMismatchInterleavedSuccess
{
    AudioBufferList *abl1, *abl2;

    const UInt32 channelCount = 2;
    const UInt32 sampleByteCount = sizeof(SInt16);
    const UInt32 frameLength = 4;

    abl1 = YASAudioAllocateAudioBufferList(1, channelCount, frameLength * sampleByteCount * channelCount);
    abl2 = YASAudioAllocateAudioBufferList(channelCount, 1, frameLength * sampleByteCount);

    // abl1 -> abl2

    [self _writeSInt16TestDataToAudioBufferList:abl1];

    UInt32 outFrameLength = 0;

    XCTAssertTrue(YASAudioCopyAudioBufferListFlexibly(abl1, abl2, sampleByteCount, &outFrameLength));
    XCTAssertEqual(outFrameLength, frameLength);

    for (UInt32 buf = 0; buf < channelCount; buf++) {
        SInt16 *ptr = abl2->mBuffers[buf].mData;
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            XCTAssertEqual(ptr[frame], [self _testSInt16ValueWithFrame:frame channel:buf]);
        }
    }

    YASAudioClearAudioBufferList(abl1);
    YASAudioClearAudioBufferList(abl2);
    outFrameLength = 0;

    // abl2 -> abl1

    [self _writeSInt16TestDataToAudioBufferList:abl2];

    XCTAssertTrue(YASAudioCopyAudioBufferListFlexibly(abl2, abl1, sampleByteCount, &outFrameLength));
    XCTAssertEqual(outFrameLength, frameLength);

    SInt16 *ptr = abl1->mBuffers[0].mData;
    const UInt32 numberChannels = abl1->mBuffers[0].mNumberChannels;
    for (UInt32 frame = 0; frame < frameLength; frame++) {
        for (UInt32 ch = 0; ch < numberChannels; ch++) {
            XCTAssertEqual(ptr[frame * numberChannels + ch], [self _testSInt16ValueWithFrame:frame channel:ch]);
        }
    }

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testCopyAudioBufferListFlexiblySizeLargerThanSourceSuccess
{
    AudioBufferList *abl1, *abl2;
    const UInt32 bufferCount = 1;
    const UInt32 numberChannels = 1;
    const UInt32 sampleByteCount = sizeof(SInt16);
    const UInt32 fromFrameLength = 4;
    const UInt32 toFrameLength = 8;
    const UInt32 fromSize = sampleByteCount * fromFrameLength;
    const UInt32 toSize = sampleByteCount * toFrameLength;

    abl1 = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, fromSize);
    abl2 = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, toSize);

    [self _writeSInt16TestDataToAudioBufferList:abl1];

    UInt32 outFrameLength = 0;

    XCTAssertTrue(YASAudioCopyAudioBufferListFlexibly(abl1, abl2, sampleByteCount, &outFrameLength));
    XCTAssertEqual(outFrameLength, fromFrameLength);

    for (UInt32 buf = 0; buf < bufferCount; buf++) {
        SInt16 *ptr1 = abl1->mBuffers[buf].mData;
        SInt16 *ptr2 = abl2->mBuffers[buf].mData;
        for (UInt32 frame = 0; frame < fromFrameLength; frame++) {
            XCTAssertEqual(ptr1[frame], ptr2[frame]);
        }
    }

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testCopyAudioBufferListFlexiblyChannelsLargerThanSourceSuccess
{
    AudioBufferList *abl1, *abl2;
    const UInt32 bufferCount = 1;
    const UInt32 fromNumberChannels = 1;
    const UInt32 toNumberChannels = 2;
    const UInt32 sampleByteCount = sizeof(SInt16);
    const UInt32 frameLength = 4;
    const UInt32 fromSize = sampleByteCount * frameLength;
    const UInt32 toSize = sampleByteCount * frameLength * toNumberChannels;

    abl1 = YASAudioAllocateAudioBufferList(bufferCount, fromNumberChannels, fromSize);
    abl2 = YASAudioAllocateAudioBufferList(bufferCount, toNumberChannels, toSize);

    [self _writeSInt16TestDataToAudioBufferList:abl1];

    UInt32 outFrameLength = 0;

    XCTAssertTrue(YASAudioCopyAudioBufferListFlexibly(abl1, abl2, sampleByteCount, &outFrameLength));
    XCTAssertEqual(outFrameLength, frameLength);

    for (UInt32 buf = 0; buf < bufferCount; buf++) {
        SInt16 *ptr = abl2->mBuffers[buf].mData;
        const UInt32 numberChannels = abl2->mBuffers[buf].mNumberChannels;
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            for (UInt32 ch = 0; ch < fromNumberChannels; ch++) {
                XCTAssertEqual(ptr[frame * numberChannels + ch], [self _testSInt16ValueWithFrame:frame channel:ch]);
            }
        }
    }

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testCopyAudioBufferListFlexiblySizeSmallerThanSourceFailed
{
    AudioBufferList *abl1, *abl2;
    const UInt32 bufferCount = 1;
    const UInt32 numberChannels = 1;
    const UInt32 sampleByteCount = sizeof(SInt16);
    const UInt32 fromFrameLength = 8;
    const UInt32 toFrameLength = 4;
    const UInt32 fromSize = sampleByteCount * fromFrameLength;
    const UInt32 toSize = sampleByteCount * toFrameLength;

    abl1 = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, fromSize);
    abl2 = YASAudioAllocateAudioBufferList(bufferCount, numberChannels, toSize);

    [self _writeSInt16TestDataToAudioBufferList:abl1];

    UInt32 outFrameLength = 0;

    XCTAssertFalse(YASAudioCopyAudioBufferListFlexibly(abl1, abl2, sampleByteCount, &outFrameLength));
    XCTAssertEqual(outFrameLength, 0);

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testCopyAudioBufferListFlexiblyChannelsSmallerThanSourceFailed
{
    AudioBufferList *abl1, *abl2;
    const UInt32 bufferCount = 1;
    const UInt32 fromNumberChannels = 2;
    const UInt32 toNumberChannels = 1;
    const UInt32 sampleByteCount = sizeof(SInt16);
    const UInt32 frameLength = 4;
    const UInt32 fromSize = sampleByteCount * frameLength * fromNumberChannels;
    const UInt32 toSize = sampleByteCount * frameLength * toNumberChannels;

    abl1 = YASAudioAllocateAudioBufferList(bufferCount, fromNumberChannels, fromSize);
    abl2 = YASAudioAllocateAudioBufferList(bufferCount, toNumberChannels, toSize);

    [self _writeSInt16TestDataToAudioBufferList:abl1];

    UInt32 outFrameLength = 0;

    XCTAssertFalse(YASAudioCopyAudioBufferListFlexibly(abl1, abl2, sampleByteCount, &outFrameLength));
    XCTAssertEqual(outFrameLength, 0);

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testCopyAudioBufferListFlexiblyFloat32
{
    AudioBufferList *abl1, *abl2;

    const UInt32 channelCount = 2;
    const UInt32 sampleByteCount = sizeof(Float32);
    const UInt32 frameLength = 4;

    abl1 = YASAudioAllocateAudioBufferList(1, channelCount, frameLength * sampleByteCount * channelCount);
    abl2 = YASAudioAllocateAudioBufferList(channelCount, 1, frameLength * sampleByteCount);

    // abl1 -> abl2

    [self _writeFloat32TestDataToAudioBufferList:abl1];

    UInt32 outFrameLength = 0;

    XCTAssertTrue(YASAudioCopyAudioBufferListFlexibly(abl1, abl2, sampleByteCount, &outFrameLength));
    XCTAssertEqual(outFrameLength, frameLength);

    for (UInt32 buf = 0; buf < channelCount; buf++) {
        Float32 *ptr = abl2->mBuffers[buf].mData;
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            XCTAssertEqual(ptr[frame], (Float32)[self _testSInt16ValueWithFrame:frame channel:buf]);
        }
    }

    YASAudioClearAudioBufferList(abl1);
    YASAudioClearAudioBufferList(abl2);
    outFrameLength = 0;

    // abl2 -> abl1

    [self _writeFloat32TestDataToAudioBufferList:abl2];

    XCTAssertTrue(YASAudioCopyAudioBufferListFlexibly(abl2, abl1, sampleByteCount, &outFrameLength));
    XCTAssertEqual(outFrameLength, frameLength);

    Float32 *ptr = abl1->mBuffers[0].mData;
    const UInt32 numberChannels = abl1->mBuffers[0].mNumberChannels;
    for (UInt32 frame = 0; frame < frameLength; frame++) {
        for (UInt32 ch = 0; ch < numberChannels; ch++) {
            XCTAssertEqual(ptr[frame * numberChannels + ch],
                           (Float32)[self _testSInt16ValueWithFrame:frame channel:ch]);
        }
    }

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testCopyAudioBufferListFlexiblyFloat64
{
    AudioBufferList *abl1, *abl2;

    const UInt32 channelCount = 2;
    const UInt32 sampleByteCount = sizeof(Float64);
    const UInt32 frameLength = 4;

    abl1 = YASAudioAllocateAudioBufferList(1, channelCount, frameLength * sampleByteCount * channelCount);
    abl2 = YASAudioAllocateAudioBufferList(channelCount, 1, frameLength * sampleByteCount);

    // abl1 -> abl2

    [self _writeFloat64TestDataToAudioBufferList:abl1];

    UInt32 outFrameLength = 0;

    XCTAssertTrue(YASAudioCopyAudioBufferListFlexibly(abl1, abl2, sampleByteCount, &outFrameLength));
    XCTAssertEqual(outFrameLength, frameLength);

    for (UInt32 buf = 0; buf < channelCount; buf++) {
        Float64 *ptr = abl2->mBuffers[buf].mData;
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            XCTAssertEqual(ptr[frame], (Float64)[self _testSInt16ValueWithFrame:frame channel:buf]);
        }
    }

    YASAudioClearAudioBufferList(abl1);
    YASAudioClearAudioBufferList(abl2);
    outFrameLength = 0;

    // abl2 -> abl1

    [self _writeFloat64TestDataToAudioBufferList:abl2];

    XCTAssertTrue(YASAudioCopyAudioBufferListFlexibly(abl2, abl1, sampleByteCount, &outFrameLength));
    XCTAssertEqual(outFrameLength, frameLength);

    Float64 *ptr = abl1->mBuffers[0].mData;
    const UInt32 numberChannels = abl1->mBuffers[0].mNumberChannels;
    for (UInt32 frame = 0; frame < frameLength; frame++) {
        for (UInt32 ch = 0; ch < numberChannels; ch++) {
            XCTAssertEqual(ptr[frame * numberChannels + ch],
                           (Float64)[self _testSInt16ValueWithFrame:frame channel:ch]);
        }
    }

    YASAudioRemoveAudioBufferList(abl1);
    YASAudioRemoveAudioBufferList(abl2);
}

- (void)testClearAudioBufferList
{
    const UInt32 frameLength = 4;
    const UInt32 sampleByteCount = sizeof(SInt16);
    const UInt32 size = frameLength * sampleByteCount;

    AudioBufferList *abl = YASAudioAllocateAudioBufferList(1, 1, size);

    SInt16 *ptr = abl->mBuffers[0].mData;
    for (UInt32 i = 0; i < frameLength; i++) {
        ptr[i] = 1;
    }

    YASAudioClearAudioBufferList(abl);

    for (UInt32 i = 0; i < frameLength; i++) {
        XCTAssertEqual(ptr[i], 0);
    }

    YASAudioRemoveAudioBufferList(abl);
}

- (void)testSetDataByteSize
{
    AudioBufferList *abl = YASAudioAllocateAudioBufferList(1, 1, 0);

    XCTAssertEqual(abl->mBuffers[0].mDataByteSize, 0);

    YASAudioSetDataByteSizeToAudioBufferList(abl, 2);
    XCTAssertEqual(abl->mBuffers[0].mDataByteSize, 2);

    YASAudioRemoveAudioBufferList(abl);
}

- (void)testGetFrameLength
{
    const UInt32 sampleByteCount = 4;
    const UInt32 frameLength = 4;

    AudioBufferList *abl = YASAudioAllocateAudioBufferList(2, 1, sampleByteCount * frameLength);

    UInt32 outFrameLength = YASAudioGetFrameLengthFromAudioBufferList(abl, sampleByteCount);
    XCTAssertEqual(outFrameLength, frameLength);

    abl->mBuffers[0].mDataByteSize = 1;

    outFrameLength = YASAudioGetFrameLengthFromAudioBufferList(abl, sampleByteCount);
    XCTAssertEqual(outFrameLength, 0);

    YASAudioRemoveAudioBufferList(abl);
}

- (void)testIsEqualAudioBufferListStructureTrue
{
    AudioBufferList *abl1 = YASAudioAllocateAudioBufferListWithoutData(2, 2);
    AudioBufferList *abl2 = YASAudioAllocateAudioBufferListWithoutData(2, 2);

    void *buffer1 = malloc(1);
    void *buffer2 = malloc(1);

    abl1->mBuffers[0].mData = abl2->mBuffers[0].mData = buffer1;
    abl1->mBuffers[1].mData = abl2->mBuffers[1].mData = buffer2;

    XCTAssertTrue(YASAudioIsEqualAudioBufferListStructure(abl1, abl2));

    free(buffer1);
    free(buffer2);

    YASAudioRemoveAudioBufferListWithoutData(abl1);
    YASAudioRemoveAudioBufferListWithoutData(abl2);
}

- (void)testIsEqualAudioBufferListStructureMismatchBufferFalse
{
    AudioBufferList *abl1 = YASAudioAllocateAudioBufferListWithoutData(1, 1);
    AudioBufferList *abl2 = YASAudioAllocateAudioBufferListWithoutData(1, 1);

    void *buffer1 = malloc(1);
    void *buffer2 = malloc(1);

    abl1->mBuffers[0].mData = buffer1;
    abl2->mBuffers[0].mData = buffer2;

    XCTAssertFalse(YASAudioIsEqualAudioBufferListStructure(abl1, abl2));

    free(buffer1);
    free(buffer2);

    YASAudioRemoveAudioBufferListWithoutData(abl1);
    YASAudioRemoveAudioBufferListWithoutData(abl2);
}

- (void)testIsEqualAudioBufferListStructureMismatchBuffersFalse
{
    AudioBufferList *abl1 = YASAudioAllocateAudioBufferListWithoutData(1, 1);
    AudioBufferList *abl2 = YASAudioAllocateAudioBufferListWithoutData(2, 1);

    void *buffer = malloc(1);

    abl1->mBuffers[0].mData = abl2->mBuffers[0].mData = buffer;

    XCTAssertFalse(YASAudioIsEqualAudioBufferListStructure(abl1, abl2));

    free(buffer);

    YASAudioRemoveAudioBufferListWithoutData(abl1);
    YASAudioRemoveAudioBufferListWithoutData(abl2);
}

- (void)testIsEqualAudioBufferListStructureMismatchChannelsFalse
{
    AudioBufferList *abl1 = YASAudioAllocateAudioBufferListWithoutData(1, 1);
    AudioBufferList *abl2 = YASAudioAllocateAudioBufferListWithoutData(1, 2);

    void *buffer = malloc(1);

    abl1->mBuffers[0].mData = abl2->mBuffers[0].mData = buffer;

    XCTAssertFalse(YASAudioIsEqualAudioBufferListStructure(abl1, abl2));

    free(buffer);

    YASAudioRemoveAudioBufferListWithoutData(abl1);
    YASAudioRemoveAudioBufferListWithoutData(abl2);
}

- (void)testIsEqualDoubleWithAccuracy
{
    const double val1 = 1.0;
    const double accuracy = 0.1;

    double val2 = 1.0;
    XCTAssertTrue(YASAudioIsEqualDoubleWithAccuracy(val1, val2, accuracy));

    val2 = 1.05;
    XCTAssertTrue(YASAudioIsEqualDoubleWithAccuracy(val1, val2, accuracy));

    val2 = 0.95;
    XCTAssertTrue(YASAudioIsEqualDoubleWithAccuracy(val1, val2, accuracy));

    val2 = 1.2;
    XCTAssertFalse(YASAudioIsEqualDoubleWithAccuracy(val1, val2, accuracy));

    val2 = 0.85;
    XCTAssertFalse(YASAudioIsEqualDoubleWithAccuracy(val1, val2, accuracy));
}

- (void)testIsEqualData
{
    const UInt32 size = 4;

    Byte *data1 = malloc(size);
    Byte *data2 = malloc(size);

    for (Byte i = 0; i < size; i++) {
        data1[i] = data2[i] = i;
    }

    XCTAssertTrue(YASAudioIsEqualData(data1, data2, size));

    data2[0] = 4;

    XCTAssertFalse(YASAudioIsEqualData(data1, data2, size));
}

- (void)testIsEqualAudioTimeStamp
{
    SMPTETime smpteTime = {
        .mSubframes = 1,
        .mSubframeDivisor = 1,
        .mCounter = 1,
        .mType = 1,
        .mFlags = 1,
        .mHours = 1,
        .mMinutes = 1,
        .mSeconds = 1,
        .mFrames = 1,
    };

    AudioTimeStamp timeStamp1 = {
        .mSampleTime = 1, .mHostTime = 1, .mRateScalar = 1, .mWordClockTime = 1, .mSMPTETime = smpteTime, .mFlags = 1,
    };

    AudioTimeStamp timeStamp2 = timeStamp1;

    XCTAssertTrue(YASAudioIsEqualAudioTimeStamp(&timeStamp1, &timeStamp2));

    timeStamp2 = timeStamp1;
    timeStamp2.mSampleTime = 2;

    XCTAssertFalse(YASAudioIsEqualAudioTimeStamp(&timeStamp1, &timeStamp2));

    timeStamp2 = timeStamp1;
    timeStamp2.mHostTime = 2;

    XCTAssertFalse(YASAudioIsEqualAudioTimeStamp(&timeStamp1, &timeStamp2));

    timeStamp2 = timeStamp1;
    timeStamp2.mRateScalar = 2;

    XCTAssertFalse(YASAudioIsEqualAudioTimeStamp(&timeStamp1, &timeStamp2));

    timeStamp2 = timeStamp1;
    timeStamp2.mWordClockTime = 2;

    XCTAssertFalse(YASAudioIsEqualAudioTimeStamp(&timeStamp1, &timeStamp2));

    timeStamp2 = timeStamp1;
    timeStamp2.mSMPTETime.mType = 2;

    XCTAssertFalse(YASAudioIsEqualAudioTimeStamp(&timeStamp1, &timeStamp2));

    timeStamp2 = timeStamp1;
    timeStamp2.mFlags = 2;

    XCTAssertFalse(YASAudioIsEqualAudioTimeStamp(&timeStamp1, &timeStamp2));
}

- (void)testIsEqualASBD
{
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

    XCTAssertTrue(YASAudioIsEqualASBD(&asbd1, &asbd2));

    asbd2 = asbd1;
    asbd2.mSampleRate = 2;

    XCTAssertFalse(YASAudioIsEqualASBD(&asbd1, &asbd2));

    asbd2 = asbd1;
    asbd2.mFormatID = 2;

    XCTAssertFalse(YASAudioIsEqualASBD(&asbd1, &asbd2));

    asbd2 = asbd1;
    asbd2.mFormatFlags = 2;

    XCTAssertFalse(YASAudioIsEqualASBD(&asbd1, &asbd2));

    asbd2 = asbd1;
    asbd2.mBytesPerPacket = 2;

    XCTAssertFalse(YASAudioIsEqualASBD(&asbd1, &asbd2));

    asbd2 = asbd1;
    asbd2.mFramesPerPacket = 2;

    XCTAssertFalse(YASAudioIsEqualASBD(&asbd1, &asbd2));

    asbd2 = asbd1;
    asbd2.mBytesPerFrame = 2;

    XCTAssertFalse(YASAudioIsEqualASBD(&asbd1, &asbd2));

    asbd2 = asbd1;
    asbd2.mChannelsPerFrame = 2;

    XCTAssertFalse(YASAudioIsEqualASBD(&asbd1, &asbd2));

    asbd2 = asbd1;
    asbd2.mBitsPerChannel = 2;

    XCTAssertFalse(YASAudioIsEqualASBD(&asbd1, &asbd2));
}

#pragma mark -

- (void)_writeSInt16TestDataToAudioBufferList:(AudioBufferList *)abl
{
    for (UInt32 buf = 0; buf < abl->mNumberBuffers; buf++) {
        SInt16 *ptr = abl->mBuffers[buf].mData;
        const UInt32 numberChannels = abl->mBuffers[buf].mNumberChannels;
        const UInt32 frameLength = abl->mBuffers[buf].mDataByteSize / numberChannels / sizeof(SInt16);
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            for (UInt32 ch = 0; ch < numberChannels; ch++) {
                ptr[frame * numberChannels + ch] =
                    [self _testSInt16ValueWithFrame:frame channel:numberChannels > 1 ? ch : buf];
            }
        }
    }
}

- (void)_writeFloat32TestDataToAudioBufferList:(AudioBufferList *)abl
{
    for (UInt32 buf = 0; buf < abl->mNumberBuffers; buf++) {
        Float32 *ptr = abl->mBuffers[buf].mData;
        const UInt32 numberChannels = abl->mBuffers[buf].mNumberChannels;
        const UInt32 frameLength = abl->mBuffers[buf].mDataByteSize / numberChannels / sizeof(Float32);
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            for (UInt32 ch = 0; ch < numberChannels; ch++) {
                ptr[frame * numberChannels + ch] =
                    [self _testSInt16ValueWithFrame:frame channel:numberChannels > 1 ? ch : buf];
            }
        }
    }
}

- (void)_writeFloat64TestDataToAudioBufferList:(AudioBufferList *)abl
{
    for (UInt32 buf = 0; buf < abl->mNumberBuffers; buf++) {
        Float64 *ptr = abl->mBuffers[buf].mData;
        const UInt32 numberChannels = abl->mBuffers[buf].mNumberChannels;
        const UInt32 frameLength = abl->mBuffers[buf].mDataByteSize / numberChannels / sizeof(Float64);
        for (UInt32 frame = 0; frame < frameLength; frame++) {
            for (UInt32 ch = 0; ch < numberChannels; ch++) {
                ptr[frame * numberChannels + ch] =
                    [self _testSInt16ValueWithFrame:frame channel:numberChannels > 1 ? ch : buf];
            }
        }
    }
}

- (SInt16)_testSInt16ValueWithFrame:(UInt32)frame channel:(UInt32)ch
{
    return frame + 1024 * (ch + 1);
}

@end
