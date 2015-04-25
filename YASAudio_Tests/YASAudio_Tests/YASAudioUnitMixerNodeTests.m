//
//  YASAudioUnitMixerNodeTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudio.h"

@interface YASAudioUnitMixerNodeTests : XCTestCase

@end

@implementation YASAudioUnitMixerNodeTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testParameters
{
    YASAudioUnitMixerNode *mixerNode = [[YASAudioUnitMixerNode alloc] init];

    NSDictionary *inputParameters = mixerNode.parameters[@(kAudioUnitScope_Input)];
    NSDictionary *outputParameters = mixerNode.parameters[@(kAudioUnitScope_Output)];

    NSArray *inputParameterIDs = @[
        @(kMultiChannelMixerParam_Volume),
        @(kMultiChannelMixerParam_Enable),
        @(kMultiChannelMixerParam_Pan),
        @(kMultiChannelMixerParam_PreAveragePower),
        @(kMultiChannelMixerParam_PrePeakHoldLevel),
        @(kMultiChannelMixerParam_PostAveragePower),
        @(kMultiChannelMixerParam_PostPeakHoldLevel)
    ];

    for (NSNumber *key in inputParameterIDs) {
        XCTAssertNotNil(inputParameters[key]);
    }

    NSArray *outputParameterIDs = @[@(kMultiChannelMixerParam_Volume), @(kMultiChannelMixerParam_Pan)];

    for (NSNumber *key in outputParameterIDs) {
        XCTAssertNotNil(outputParameters[key]);
    }

    YASRelease(mixerNode);
}

@end
