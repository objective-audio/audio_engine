//
//  YASAudioUnitNodeTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudio.h"

@interface YASAudioUnitNode (YASAudioUnitNodeTests)

- (void)_reloadAudioUnit;

@end

@interface YASAudioUnitNodeTests : XCTestCase

@end

@implementation YASAudioUnitNodeTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testRestoreParameters
{
    YASAudioEngine *engine = [[YASAudioEngine alloc] init];

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2];
    YASAudioOfflineOutputNode *outputNode = [[YASAudioOfflineOutputNode alloc] init];
    YASAudioUnitNode *delayNode =
        [[YASAudioUnitNode alloc] initWithType:kAudioUnitType_Effect subType:kAudioUnitSubType_Delay];

    NSDictionary *parameterInfos = delayNode.globalParameterInfos;
    XCTAssertEqual(parameterInfos.count, 4);

    for (NSNumber *key in parameterInfos) {
        YASAudioUnitParameter *info = parameterInfos[key];
        XCTAssertEqual(info.defaultValue, [delayNode globalParameterValue:info.parameterID]);
    }

    YASAudioConnection *connection = [engine connectFromNode:delayNode toNode:outputNode format:format];

    XCTestExpectation *expectation = [self expectationWithDescription:@"First Render"];

    NSError *error = nil;
    BOOL result = [engine startOfflineRenderWithOutputCallbackBlock:nil
                                                    completionBlock:^(BOOL cancelled) {
                                                        [expectation fulfill];
                                                    } error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    [delayNode setGlobalParameter:kDelayParam_DelayTime value:0.5];
    [delayNode setGlobalParameter:kDelayParam_Feedback value:-50.0];
    [delayNode setGlobalParameter:kDelayParam_LopassCutoff value:100.0];
    [delayNode setGlobalParameter:kDelayParam_WetDryMix value:10.0];

    XCTAssertEqual([delayNode globalParameterValue:kDelayParam_DelayTime], 0.5);
    XCTAssertEqual([delayNode globalParameterValue:kDelayParam_Feedback], -50.0);
    XCTAssertEqual([delayNode globalParameterValue:kDelayParam_LopassCutoff], 100.0);
    XCTAssertEqual([delayNode globalParameterValue:kDelayParam_WetDryMix], 10.0);

    [engine stop];

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    [engine disconnect:connection];

    [delayNode _reloadAudioUnit];

    [engine connectFromNode:delayNode toNode:outputNode format:format];

    expectation = [self expectationWithDescription:@"Second Render"];

    [engine startOfflineRenderWithOutputCallbackBlock:nil
                                      completionBlock:^(BOOL cancelled) {
                                          [expectation fulfill];
                                      } error:&error];

    XCTAssertEqual([delayNode globalParameterValue:kDelayParam_DelayTime], 0.5);
    XCTAssertEqual([delayNode globalParameterValue:kDelayParam_Feedback], -50.0);
    XCTAssertEqual([delayNode globalParameterValue:kDelayParam_LopassCutoff], 100.0);
    XCTAssertEqual([delayNode globalParameterValue:kDelayParam_WetDryMix], 10.0);

    [engine stop];

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    YASRelease(delayNode);
    YASRelease(outputNode);
    YASRelease(format);
    YASRelease(engine);
}

@end
