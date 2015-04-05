//
//  YASAudioEngineTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudio.h"

@interface YASAudioEngineTestNode : YASAudioNode

@end

@implementation YASAudioEngineTestNode

- (UInt32)inputBusCount
{
    return 1;
}

- (UInt32)outputBusCount
{
    return 1;
}

@end

@interface YASAudioEngine (YASAudioEngineTests)

@property (nonatomic, strong, readonly) NSMutableSet *nodes;
@property (nonatomic, strong, readonly) NSMutableSet *connections;

@end

@interface YASAudioEngineTests : XCTestCase

@end

@implementation YASAudioEngineTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testConnectSuccess
{
    YASAudioEngine *engine = [[YASAudioEngine alloc] init];
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    YASAudioEngineTestNode *fromNode = [[YASAudioEngineTestNode alloc] init];
    YASAudioEngineTestNode *toNode = [[YASAudioEngineTestNode alloc] init];

    XCTAssertEqual(engine.nodes.count, 0);
    XCTAssertEqual(engine.connections.count, 0);

    YASAudioConnection *connection = nil;
    XCTAssertNoThrow(connection = [engine connectFromNode:fromNode toNode:toNode format:format]);
    XCTAssertNotNil(connection);

    XCTAssertTrue([engine.nodes containsObject:fromNode]);
    XCTAssertTrue([engine.nodes containsObject:toNode]);
    XCTAssertEqual(engine.connections.count, 1);
    XCTAssertEqualObjects(engine.connections.anyObject, connection);

    YASRelease(format);
    YASRelease(fromNode);
    YASRelease(toNode);
    YASRelease(engine);
}

- (void)testConnectFailedNonBus
{
    YASAudioEngine *engine = [[YASAudioEngine alloc] init];
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    YASAudioNode *fromNode = [[YASAudioNode alloc] init];
    YASAudioNode *toNode = [[YASAudioNode alloc] init];

    YASAudioConnection *connection = nil;
    XCTAssertThrows(connection = [engine connectFromNode:fromNode toNode:toNode format:format]);
    XCTAssertNil(connection);

    XCTAssertEqual(engine.connections.count, 0);

    YASRelease(format);
    YASRelease(fromNode);
    YASRelease(toNode);
    YASRelease(engine);
}

- (void)testConnectAndDisconnect
{
    YASAudioEngine *engine = [[YASAudioEngine alloc] init];
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];

    YASAudioEngineTestNode *fromNode = [[YASAudioEngineTestNode alloc] init];
    YASAudioEngineTestNode *relayNode = [[YASAudioEngineTestNode alloc] init];
    YASAudioEngineTestNode *toNode = [[YASAudioEngineTestNode alloc] init];

    [engine connectFromNode:fromNode toNode:relayNode format:format];

    XCTAssertTrue([engine.nodes containsObject:fromNode]);
    XCTAssertTrue([engine.nodes containsObject:relayNode]);
    XCTAssertFalse([engine.nodes containsObject:toNode]);

    [engine connectFromNode:relayNode toNode:toNode format:format];

    XCTAssertTrue([engine.nodes containsObject:fromNode]);
    XCTAssertTrue([engine.nodes containsObject:relayNode]);
    XCTAssertTrue([engine.nodes containsObject:toNode]);

    [engine disconnectNode:relayNode];

    XCTAssertFalse([engine.nodes containsObject:fromNode]);
    XCTAssertFalse([engine.nodes containsObject:relayNode]);
    XCTAssertFalse([engine.nodes containsObject:toNode]);

    YASRelease(fromNode);
    YASRelease(relayNode);
    YASRelease(toNode);
}

@end
