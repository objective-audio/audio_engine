//
//  YASAudioUnitMixerNodeTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudio.h"

@interface YASAudioUnitNode (YASAudioUnitMixerNodeTests)

- (void)_reloadAudioUnit;

@end

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

- (void)testParameterExists
{
    YASAudioUnitMixerNode *mixerNode = [[YASAudioUnitMixerNode alloc] init];

    NSDictionary *inputParameters = mixerNode.parameters[@(kAudioUnitScope_Input)];
    NSDictionary *outputParameters = mixerNode.parameters[@(kAudioUnitScope_Output)];

    XCTAssertGreaterThanOrEqual(inputParameters.count, 1);
    XCTAssertGreaterThanOrEqual(outputParameters.count, 1);

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

- (void)testElement
{
    YASAudioUnitMixerNode *mixerNode = [[YASAudioUnitMixerNode alloc] init];

    const UInt32 defaultElementCount = mixerNode.inputElementCount;

    XCTAssertGreaterThanOrEqual(defaultElementCount, 1);
    XCTAssertNoThrow([mixerNode setVolume:0.5 forBus:@0]);
    XCTAssertThrows([mixerNode setVolume:0.5 forBus:@(defaultElementCount)]);

    const UInt32 elementCount = defaultElementCount + 8;
    XCTAssertNoThrow([mixerNode.audioUnit setElementCount:elementCount scope:kAudioUnitScope_Input]);

    XCTAssertGreaterThanOrEqual(mixerNode.inputElementCount, elementCount);
    XCTAssertNoThrow([mixerNode setVolume:0.5 forBus:@(elementCount - 1)]);
    XCTAssertThrows([mixerNode setVolume:0.5 forBus:@(elementCount)]);

    YASRelease(mixerNode);
}

- (void)testRestoreParamters
{
    YASAudioUnitMixerNode *mixerNode = [[YASAudioUnitMixerNode alloc] init];

    NSNumber *bus = @0;
    const Float32 volume = 0.5f;
    const Float32 pan = 0.25;
    const BOOL enabled = NO;

    [mixerNode setVolume:volume forBus:bus];
    [mixerNode setPan:pan forBus:bus];
    [mixerNode setEnabled:enabled forBus:bus];

    XCTAssertEqual([mixerNode volumeForBus:bus], volume);
    XCTAssertEqual([mixerNode panForBus:bus], pan);
    XCTAssertEqual([mixerNode isEnabledForBus:bus], enabled);

    [mixerNode _reloadAudioUnit];
    
    XCTAssertNotEqual([mixerNode volumeForBus:bus], volume);
    XCTAssertNotEqual([mixerNode panForBus:bus], pan);
    XCTAssertNotEqual([mixerNode isEnabledForBus:bus], enabled);
    
    [mixerNode prepareParameters];
    
    XCTAssertEqual([mixerNode volumeForBus:bus], volume);
    XCTAssertEqual([mixerNode panForBus:bus], pan);
    XCTAssertEqual([mixerNode isEnabledForBus:bus], enabled);

    YASRelease(mixerNode);
}

@end
