//
//  YASAudioConnectionTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioConnection+Internal.h"
#import "YASAudioNode+Internal.h"
#import "YASAudioFormat.h"
#import "YASMacros.h"

@interface YASAudioConnectionTests : XCTestCase

@end

@implementation YASAudioConnectionTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testInitConnectionSuccess
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    YASAudioNode *sourceNode = [[YASAudioNode alloc] init];
    YASAudioNode *destinationNode = [[YASAudioNode alloc] init];
    NSNumber *sourceBus = @0;
    NSNumber *destinationBus = @1;

    YASAudioConnection *connection = [[YASAudioConnection alloc] initWithSourceNode:sourceNode
                                                                          sourceBus:sourceBus
                                                                    destinationNode:destinationNode
                                                                     destinationBus:destinationBus
                                                                             format:format];

    XCTAssertEqualObjects(connection.sourceNode, sourceNode);
    XCTAssertEqualObjects(connection.sourceBus, sourceBus);
    XCTAssertEqualObjects(connection.destinationNode, destinationNode);
    XCTAssertEqualObjects(connection.destinationBus, destinationBus);

    XCTAssertEqualObjects([sourceNode outputConnectionForBus:sourceBus], connection);
    XCTAssertEqualObjects([destinationNode inputConnectionForBus:destinationBus], connection);

    YASRelease(connection);
    YASRelease(destinationNode);
    YASRelease(sourceNode);
    YASRelease(format);
}

- (void)testRemoveNodes
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:1];
    YASAudioNode *sourceNode = [[YASAudioNode alloc] init];
    YASAudioNode *destinationNode = [[YASAudioNode alloc] init];
    NSNumber *sourceBus = @2;
    NSNumber *destinationBus = @3;

    YASAudioConnection *connection = [[YASAudioConnection alloc] initWithSourceNode:sourceNode
                                                                          sourceBus:sourceBus
                                                                    destinationNode:destinationNode
                                                                     destinationBus:destinationBus
                                                                             format:format];

    [connection removeNodes];

    XCTAssertNil(connection.sourceNode);
    XCTAssertNil(connection.destinationNode);

    YASRelease(connection);
    YASRelease(destinationNode);
    YASRelease(sourceNode);
    YASRelease(format);
}

- (void)testRemoveNodeSeparately
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:8000 channels:4];
    YASAudioNode *sourceNode = [[YASAudioNode alloc] init];
    YASAudioNode *destinationNode = [[YASAudioNode alloc] init];
    NSNumber *sourceBus = @5;
    NSNumber *destinationBus = @4;

    YASAudioConnection *connection = [[YASAudioConnection alloc] initWithSourceNode:sourceNode
                                                                          sourceBus:sourceBus
                                                                    destinationNode:destinationNode
                                                                     destinationBus:destinationBus
                                                                             format:format];

    [connection removeSourceNode];

    XCTAssertNil(connection.sourceNode);

    [connection removeDestinationNode];

    XCTAssertNil(connection.destinationNode);

    YASRelease(connection);
    YASRelease(destinationNode);
    YASRelease(sourceNode);
    YASRelease(format);
}

- (void)testInitConnectionFailed
{
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    YASAudioNode *sourceNode = [[YASAudioNode alloc] init];
    YASAudioNode *destinationNode = [[YASAudioNode alloc] init];
    NSNumber *sourceBus = @0;
    NSNumber *destinationBus = @1;

    XCTAssertThrows([[YASAudioConnection alloc] initWithSourceNode:nil
                                                         sourceBus:sourceBus
                                                   destinationNode:destinationNode
                                                    destinationBus:destinationBus
                                                            format:format]);

    XCTAssertThrows([[YASAudioConnection alloc] initWithSourceNode:sourceNode
                                                         sourceBus:nil
                                                   destinationNode:destinationNode
                                                    destinationBus:destinationBus
                                                            format:format]);

    XCTAssertThrows([[YASAudioConnection alloc] initWithSourceNode:sourceNode
                                                         sourceBus:sourceBus
                                                   destinationNode:nil
                                                    destinationBus:destinationBus
                                                            format:format]);

    XCTAssertThrows([[YASAudioConnection alloc] initWithSourceNode:sourceNode
                                                         sourceBus:sourceBus
                                                   destinationNode:destinationNode
                                                    destinationBus:nil
                                                            format:format]);

    XCTAssertThrows([[YASAudioConnection alloc] initWithSourceNode:sourceNode
                                                         sourceBus:sourceBus
                                                   destinationNode:destinationNode
                                                    destinationBus:destinationBus
                                                            format:nil]);

    YASRelease(destinationNode);
    YASRelease(sourceNode);
    YASRelease(format);
}

@end
