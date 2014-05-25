//
//  YASAudioSampleTests.m
//  YASAudioSampleTests
//
//  Created by Yuki Yasoshima on 2014/01/13.
//  Copyright (c) 2014年 Yuki Yasoshima. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "YASAudioUtilities.h"
#import <AudioToolbox/AudioToolbox.h>

@interface YASAudioUtilitiesTests : XCTestCase

@end

@implementation YASAudioUtilitiesTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testIsEqualFormat
{
    AudioStreamBasicDescription format1a, format1b, format2;
    const Float64 samplerate1 = 44100;
    const Float64 samplerate2 = 48000;
    
    YASGetFloat32NonInterleavedStereoFormat(&format1a, samplerate1);
    YASGetFloat32NonInterleavedStereoFormat(&format1b, samplerate1);
    YASGetSInt16InterleavedStereoFormat(&format2, samplerate2);
    
    XCTAssert(YASIsEqualFormat(&format1a, &format1b), @"");
    XCTAssertFalse(YASIsEqualFormat(&format1a, &format2), @"");
}

- (void)testAudioBufferList
{
    AudioBufferList *list1, *list2;
    const UInt32 bufCount = 2;
    const UInt32 size = 16;
    
    list1 = YASAllocateAudioBufferList(bufCount, 1, size);
    list2 = YASAllocateAudioBufferList(bufCount, 1, size);
    
    YASFillFloat32SinewaveToAudioBufferList(list1, 1);
    
    for (NSInteger i = 0; i < bufCount; i++) {
        XCTAssertFalse(memcmp(list1->mBuffers[i].mData, list2->mBuffers[i].mData, size) == 0, @"");
    }
    
    YASFillFloat32SinewaveToAudioBufferList(list2, 1);
    
    for (NSInteger i = 0; i < bufCount; i++) {
        XCTAssert(memcmp(list1->mBuffers[i].mData, list2->mBuffers[i].mData, size) == 0, @"");
    }
    
    const UInt32 newSize = 4;
    YASSetDataByteSizeToAudioBufferList(list1, newSize);
    for (NSInteger i = 0; i < bufCount; i++) {
        XCTAssert(list1->mBuffers[i].mDataByteSize == newSize, @"");
    }
    
    YASRemoveAudioBufferList(list1);
    YASRemoveAudioBufferList(list2);
}

@end
