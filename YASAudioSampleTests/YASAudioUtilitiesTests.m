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

@end
