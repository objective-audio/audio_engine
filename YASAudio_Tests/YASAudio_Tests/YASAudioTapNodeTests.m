//
//  YASAudioTapNodeTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudio.h"

@interface YASAudioTapNodeTests : XCTestCase

@end

@implementation YASAudioTapNodeTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testRenderWithBlock
{
    YASAudioEngine *engine = [[YASAudioEngine alloc] init];

    YASAudioOfflineOutputNode *outputNode = [[YASAudioOfflineOutputNode alloc] init];
    YASAudioTapNode *toNode = [[YASAudioTapNode alloc] init];
    YASAudioTapNode *fromNode = [[YASAudioTapNode alloc] init];
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];

    YASAudioConnection *toConnection = [engine connectFromNode:toNode toNode:outputNode format:format];
    YASAudioConnection *fromConnection = [engine connectFromNode:fromNode toNode:toNode format:format];

    XCTestExpectation *toExpectation = [self expectationWithDescription:@"To Node"];
    XCTestExpectation *fromExpectation = [self expectationWithDescription:@"From Node"];
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"Completion"];

    YASWeakContainer *toNodeContainer = toNode.weakContainer;
    toNode.renderBlock = ^(YASAudioData *data, NSNumber *bus, YASAudioTime *when) {
        YASAudioTapNode *node = toNodeContainer.retainedObject;

        XCTAssertEqual([node outputConnectionsOnRender].count, 1);
        XCTAssertEqualObjects(toConnection, [node outputConnectionOnRenderForBus:@0]);
        XCTAssertNil([node outputConnectionOnRenderForBus:@1]);

        XCTAssertEqual([node inputConnectionsOnRender].count, 1);
        XCTAssertEqualObjects(fromConnection, [node inputConnectionOnRenderForBus:@0]);
        XCTAssertNil([node inputConnectionOnRenderForBus:@1]);

        [node renderSourceNodeWithData:data bus:@0 when:when];
        YASRelease(node);

        [toExpectation fulfill];
    };

    fromNode.renderBlock = ^(YASAudioData *data, NSNumber *bus, YASAudioTime *when) {
        [fromExpectation fulfill];
    };

    [engine startOfflineRenderWithOutputCallbackBlock:^(YASAudioData *data, YASAudioTime *when, BOOL *stop) {
        *stop = YES;
    } completionBlock:^(BOOL cancelled) {
        [completionExpectation fulfill];
    } error:nil];

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    [NSThread sleepForTimeInterval:1.0];

    YASRelease(format);
    YASRelease(fromNode);
    YASRelease(toNode);
    YASRelease(outputNode);
    YASRelease(engine);
}

- (void)testRenderWithoutBlock
{
    YASAudioEngine *engine = [[YASAudioEngine alloc] init];

    YASAudioOfflineOutputNode *outputNode = [[YASAudioOfflineOutputNode alloc] init];
    YASAudioTapNode *toNode = [[YASAudioTapNode alloc] init];
    YASAudioTapNode *fromNode = [[YASAudioTapNode alloc] init];
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];

    [engine connectFromNode:toNode toNode:outputNode format:format];
    [engine connectFromNode:fromNode toNode:toNode format:format];

    XCTestExpectation *fromExpectation = [self expectationWithDescription:@"From Node"];

    fromNode.renderBlock = ^(YASAudioData *data, NSNumber *bus, YASAudioTime *when) {
        [fromExpectation fulfill];
    };

    [engine startOfflineRenderWithOutputCallbackBlock:^(YASAudioData *data, YASAudioTime *when, BOOL *stop) {
        *stop = YES;
    } completionBlock:NULL error:nil];

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    YASRelease(format);
    YASRelease(fromNode);
    YASRelease(toNode);
    YASRelease(outputNode);
    YASRelease(engine);
}

- (void)testBusCount
{
    YASAudioTapNode *node = [[YASAudioTapNode alloc] init];

    XCTAssertEqual(node.inputBusCount, 1);
    XCTAssertEqual(node.outputBusCount, 1);

    YASRelease(node);
}

@end
