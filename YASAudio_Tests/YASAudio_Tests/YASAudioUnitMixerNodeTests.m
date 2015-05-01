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
    XCTAssertNoThrow([mixerNode setInputVolume:0.5 forBus:@0]);
    XCTAssertThrows([mixerNode setInputVolume:0.5 forBus:@(defaultElementCount)]);

    const UInt32 elementCount = defaultElementCount + 8;
    XCTAssertNoThrow([mixerNode.audioUnit setElementCount:elementCount scope:kAudioUnitScope_Input]);

    XCTAssertGreaterThanOrEqual(mixerNode.inputElementCount, elementCount);
    XCTAssertNoThrow([mixerNode setInputVolume:0.5 forBus:@(elementCount - 1)]);
    XCTAssertThrows([mixerNode setInputVolume:0.5 forBus:@(elementCount)]);

    YASRelease(mixerNode);
}

- (void)testRestoreParamters
{
    YASAudioUnitMixerNode *mixerNode = [[YASAudioUnitMixerNode alloc] init];

    NSNumber *bus = @0;
    const Float32 volume = 0.5f;
    const Float32 pan = 0.25;
    const BOOL enabled = NO;

    [mixerNode setInputVolume:volume forBus:bus];
    [mixerNode setInputPan:pan forBus:bus];
    [mixerNode setInputEnabled:enabled forBus:bus];
    [mixerNode setOutputVolume:volume forBus:bus];
    [mixerNode setOutputPan:pan forBus:bus];

    XCTAssertEqual([mixerNode inputVolumeForBus:bus], volume);
    XCTAssertEqual([mixerNode inputPanForBus:bus], pan);
    XCTAssertEqual([mixerNode isInputEnabledForBus:bus], enabled);
    XCTAssertEqual([mixerNode outputVolumeForBus:bus], volume);
    XCTAssertEqual([mixerNode outputPanForBus:bus], pan);

    [mixerNode _reloadAudioUnit];

    XCTAssertNotEqual([mixerNode inputVolumeForBus:bus], volume);
    XCTAssertNotEqual([mixerNode inputPanForBus:bus], pan);
    XCTAssertNotEqual([mixerNode isInputEnabledForBus:bus], enabled);
    XCTAssertNotEqual([mixerNode outputVolumeForBus:bus], volume);
    XCTAssertNotEqual([mixerNode outputPanForBus:bus], pan);

    [mixerNode prepareParameters];

    XCTAssertEqual([mixerNode inputVolumeForBus:bus], volume);
    XCTAssertEqual([mixerNode inputPanForBus:bus], pan);
    XCTAssertEqual([mixerNode isInputEnabledForBus:bus], enabled);
    XCTAssertEqual([mixerNode outputVolumeForBus:bus], volume);
    XCTAssertEqual([mixerNode outputPanForBus:bus], pan);

    YASRelease(mixerNode);
}

@end
