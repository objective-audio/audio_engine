//
//  YASAudioNodeTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioNode+Internal.h"
#import "YASAudioEngine.h"
#import "YASAudioFormat.h"
#import "YASAudioConnection+Internal.h"
#import "YASAudioTime.h"
#import "YASMacros.h"

@interface YASAudioNodeTestNode : YASAudioNode

@end

@implementation YASAudioNodeTestNode

- (UInt32)inputBusCount
{
    return 2;
}

- (UInt32)outputBusCount
{
    return 1;
}

@end

@interface YASAudioNodeTests : XCTestCase

@end

@implementation YASAudioNodeTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testCreateAudioNode
{
    YASAudioNodeTestNode *node = [[YASAudioNodeTestNode alloc] init];

    XCTAssertEqual(node.inputBusCount, 2);
    XCTAssertEqual(node.outputBusCount, 1);

    XCTAssertEqual(node.inputConnections.count, 0);
    XCTAssertEqual(node.outputConnections.count, 0);
    XCTAssertEqualObjects(node.nextAvailableInputBus, @0);
    XCTAssertEqualObjects(node.nextAvailableOutputBus, @0);

    YASRelease(node);
}

- (void)testConnection
{
    YASAudioNodeTestNode *sourceNode = [[YASAudioNodeTestNode alloc] init];
    YASAudioNodeTestNode *destinationNode = [[YASAudioNodeTestNode alloc] init];
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2];

    NSNumber *sourceBus = sourceNode.nextAvailableOutputBus;
    NSNumber *destinationBus = destinationNode.nextAvailableInputBus;

    XCTAssertEqualObjects(sourceBus, @0);
    XCTAssertEqualObjects(destinationBus, @0);

    YASAudioConnection *connection = [[YASAudioConnection alloc] initWithSourceNode:sourceNode
                                                                          sourceBus:sourceBus
                                                                    destinationNode:destinationNode
                                                                     destinationBus:destinationBus
                                                                             format:format];

    [sourceNode addConnection:connection];
    [destinationNode addConnection:connection];

    XCTAssertEqual(sourceNode.outputConnections.count, 1);
    XCTAssertEqual(destinationNode.inputConnections.count, 1);
    XCTAssertEqualObjects([sourceNode outputConnectionForBus:sourceBus], connection);
    XCTAssertEqualObjects([destinationNode inputConnectionForBus:destinationBus], connection);
    XCTAssertEqualObjects([sourceNode outputFormatForBus:sourceBus], format);
    XCTAssertEqualObjects([destinationNode inputFormatForBus:destinationBus], format);

    XCTAssertNil(sourceNode.nextAvailableOutputBus);
    XCTAssertEqualObjects(destinationNode.nextAvailableInputBus, @1);

    [sourceNode removeConnection:connection];
    [destinationNode removeConnection:connection];

    XCTAssertEqualObjects(sourceBus, @0);
    XCTAssertEqualObjects(destinationBus, @0);

    YASRelease(connection);
    YASRelease(format);
    YASRelease(destinationNode);
    YASRelease(sourceNode);
}

- (void)testReset
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    YASAudioNode *sourceNode = [[YASAudioNodeTestNode alloc] init];
    YASAudioNode *destinationNode = [[YASAudioNodeTestNode alloc] init];

    NSNumber *sourceBus = sourceNode.nextAvailableOutputBus;
    NSNumber *destinationBus = destinationNode.nextAvailableInputBus;

    YASAudioConnection *connection = [[YASAudioConnection alloc] initWithSourceNode:sourceNode
                                                                          sourceBus:sourceBus
                                                                    destinationNode:destinationNode
                                                                     destinationBus:destinationBus
                                                                             format:format];

    [sourceNode addConnection:connection];
    [destinationNode addConnection:connection];

    XCTAssertEqual(sourceNode.outputConnections.count, 1);
    XCTAssertEqual(destinationNode.inputConnections.count, 1);

    [sourceNode reset];
    XCTAssertEqual(sourceNode.outputConnections.count, 0);

    [destinationNode reset];
    XCTAssertEqual(destinationNode.inputConnections.count, 0);

    YASRelease(connection);
    YASRelease(sourceNode);
    YASRelease(destinationNode);
}

- (void)testRenderTime
{
    YASAudioNode *node = [[YASAudioNode alloc] init];
    YASAudioTime *time = [[YASAudioTime alloc] initWithSampleTime:100 atRate:48000];

    XCTestExpectation *renderExpectation = [self expectationWithDescription:@"Node Render"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [node renderWithData:nil bus:nil when:time];
        [renderExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:0.1
                                 handler:^(NSError *error){

                                 }];

    XCTAssertEqualObjects(time, [node lastRenderTime]);

    YASRelease(time);
    YASRelease(node);
}

- (void)testEngine
{
    YASAudioNode *node = [[YASAudioNode alloc] init];
    YASAudioEngine *engine = [[YASAudioEngine alloc] init];

    XCTAssertNil([node engine]);

    [node setEngine:engine];

    XCTAssertEqualObjects(engine, [node engine]);

    [node setEngine:nil];

    XCTAssertNil([node engine]);

    YASRelease(engine);
    YASRelease(node);
}

- (void)testNodeCore
{
    YASAudioFormat *outputFormat = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    YASAudioFormat *inputFormat = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:1];

    YASAudioNode *outNode = [[YASAudioNode alloc] init];
    YASAudioNode *relayNode = [[YASAudioNodeTestNode alloc] init];
    YASAudioConnection *outputConnection = [[YASAudioConnection alloc] initWithSourceNode:relayNode
                                                                                sourceBus:@0
                                                                          destinationNode:outNode
                                                                           destinationBus:@0
                                                                                   format:outputFormat];
    [relayNode addConnection:outputConnection];

    NSMutableArray *inputConnections = [[NSMutableArray alloc] initWithCapacity:relayNode.inputBusCount];
    for (NSInteger i = 0; i < relayNode.inputBusCount; i++) {
        YASAudioNode *inputNode = [[YASAudioNode alloc] init];
        YASAudioConnection *inputConnection = [[YASAudioConnection alloc] initWithSourceNode:inputNode
                                                                                   sourceBus:@0
                                                                             destinationNode:relayNode
                                                                              destinationBus:@(i)
                                                                                      format:inputFormat];
        [relayNode addConnection:inputConnection];
        [inputConnections addObject:inputConnection];
        YASRelease(inputConnection);
        YASRelease(inputNode);
    }

    [relayNode updateNodeCore];

    XCTestExpectation *expectation = [self expectationWithDescription:@"NodeCore Connections"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        YASAudioNodeCore *nodeCore = relayNode.nodeCore;
        XCTAssertEqual(nodeCore.outputConnections.count, 1);
        XCTAssertEqual(nodeCore.inputConnections.count, 2);
        XCTAssertEqualObjects([nodeCore outputConnectionForBus:@0], outputConnection);
        XCTAssertEqualObjects([nodeCore inputConnectionForBus:@0], inputConnections[0]);
        XCTAssertEqualObjects([nodeCore inputConnectionForBus:@1], inputConnections[1]);
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:0.1
                                 handler:^(NSError *error){

                                 }];

    YASRelease(outputConnection);
    YASRelease(relayNode);
    YASRelease(outNode);
    YASRelease(inputFormat);
    YASRelease(outputFormat);
}

- (void)testAvailableBus
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    YASAudioNodeTestNode *sourceNode0 = [[YASAudioNodeTestNode alloc] init];
    YASAudioNodeTestNode *sourceNode1 = [[YASAudioNodeTestNode alloc] init];
    YASAudioNodeTestNode *destNode = [[YASAudioNodeTestNode alloc] init];

    XCTAssertTrue([sourceNode0 isAvailableOutputBus:@0]);
    XCTAssertFalse([sourceNode0 isAvailableOutputBus:@1]);
    XCTAssertTrue([sourceNode1 isAvailableOutputBus:@0]);
    XCTAssertTrue([destNode isAvailableInputBus:@0]);
    XCTAssertTrue([destNode isAvailableInputBus:@1]);
    XCTAssertFalse([destNode isAvailableInputBus:@2]);

    YASAudioConnection *connection1 = [[YASAudioConnection alloc] initWithSourceNode:sourceNode1
                                                                           sourceBus:@0
                                                                     destinationNode:destNode
                                                                      destinationBus:@1
                                                                              format:format];
    [sourceNode1 addConnection:connection1];
    [destNode addConnection:connection1];

    XCTAssertFalse([sourceNode1 isAvailableOutputBus:@0]);
    XCTAssertTrue([destNode isAvailableInputBus:@0]);
    XCTAssertFalse([destNode isAvailableInputBus:@1]);

    YASAudioConnection *connection0 = [[YASAudioConnection alloc] initWithSourceNode:sourceNode0
                                                                           sourceBus:@0
                                                                     destinationNode:destNode
                                                                      destinationBus:@0
                                                                              format:format];

    [sourceNode0 addConnection:connection0];
    [destNode addConnection:connection0];

    XCTAssertFalse([sourceNode0 isAvailableOutputBus:@0]);
    XCTAssertFalse([destNode isAvailableInputBus:@0]);

    YASRelease(connection1);
    YASRelease(destNode);
    YASRelease(sourceNode1);
    YASRelease(sourceNode0);
    YASRelease(format);
}

@end
