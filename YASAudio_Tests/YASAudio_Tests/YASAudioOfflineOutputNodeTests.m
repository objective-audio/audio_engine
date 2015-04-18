//
//  YASAudioOfflineOutputNodeTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioTestUtils.h"

@interface YASAudioOfflineOutputNodeTests : XCTestCase

@end

@implementation YASAudioOfflineOutputNodeTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testOfflineRenderWithAudioEngine
{
    const Float64 sampleRate = 44100;
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:2];
    YASAudioEngine *engine = [[YASAudioEngine alloc] init];
    YASAudioOfflineOutputNode *outputNode = [[YASAudioOfflineOutputNode alloc] init];
    YASAudioUnitNode *sampleDelayNode =
        [[YASAudioUnitNode alloc] initWithType:kAudioUnitType_Effect subType:kAudioUnitSubType_SampleDelay];
    YASAudioTapNode *tapNode = [[YASAudioTapNode alloc] init];

    [engine connectFromNode:sampleDelayNode toNode:outputNode format:format];
    [engine connectFromNode:tapNode toNode:sampleDelayNode format:format];

    XCTestExpectation *renderExpectation = [self expectationWithDescription:@"OfflineOutputNode Render"];
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"OfflineOutputNode Completion"];
    XCTestExpectation *tapNodeExpectation = [self expectationWithDescription:@"TapNode Render"];

    const UInt32 framesPerRender = 1024;
    const UInt32 length = 4196;
    __block UInt32 tapRenderFrame = 0;
    tapNode.renderBlock = ^(YASAudioData *data, NSNumber *bus, YASAudioTime *when, id nodeCore) {
        XCTAssertEqual(when.sampleTime, tapRenderFrame);
        XCTAssertEqual(when.sampleRate, sampleRate);
        XCTAssertEqual(data.frameLength, framesPerRender);
        XCTAssertEqualObjects(data.format, format);

        for (UInt32 buf = 0; buf < data.format.bufferCount; buf++) {
            YASAudioMutablePointer pointer = [data pointerAtBuffer:buf];
            for (UInt32 frame = 0; frame < data.frameLength; frame++) {
                pointer.f32[frame] = TestValue(frame + tapRenderFrame, 0, buf);
            }
        }

        tapRenderFrame += data.frameLength;
        if (tapRenderFrame >= length) {
            [tapNodeExpectation fulfill];
        }
    };

    __block UInt32 outputRenderFrame = 0;
    NSError *error = nil;
    BOOL result =
        [engine startOfflineRenderWithOutputCallbackBlock:^(YASAudioData *data, YASAudioTime *when, BOOL *stop) {
            XCTAssertEqual(when.sampleTime, outputRenderFrame);
            XCTAssertEqual(when.sampleRate, sampleRate);
            XCTAssertEqual(data.frameLength, framesPerRender);
            XCTAssertEqualObjects(data.format, format);

            for (UInt32 buf = 0; buf < data.format.bufferCount; buf++) {
                YASAudioConstPointer pointer = {[data pointerAtBuffer:buf].v};
                for (UInt32 frame = 0; frame < data.frameLength; frame++) {
                    XCTAssertEqual(pointer.f32[frame], TestValue(frame + outputRenderFrame, 0, buf));
                }
            }

            outputRenderFrame += data.frameLength;
            if (outputRenderFrame >= length) {
                *stop = YES;
                [renderExpectation fulfill];
            }
        } completionBlock:^(BOOL cancelled) {
            XCTAssertFalse(cancelled);
            [completionExpectation fulfill];
        } error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    YASRelease(tapNode);
    YASRelease(sampleDelayNode);
    YASRelease(outputNode);
    YASRelease(engine);
}

- (void)testOfflineRenderWithoutAudioEngine
{
    const Float64 sampleRate = 48000;
    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:2];
    YASAudioOfflineOutputNode *outputNode = [[YASAudioOfflineOutputNode alloc] init];
    YASAudioTapNode *tapNode = [[YASAudioTapNode alloc] init];

    YASAudioConnection *connection = [[YASAudioConnection alloc] initWithSourceNode:tapNode
                                                                          sourceBus:@0
                                                                    destinationNode:outputNode
                                                                     destinationBus:@0
                                                                             format:format];

    [outputNode addConnection:connection];
    [outputNode updateNodeCore];
    [tapNode addConnection:connection];
    [tapNode updateNodeCore];

    XCTestExpectation *renderExpectation = [self expectationWithDescription:@"OfflineOutputNode Render"];
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"OfflineOutputNode Completion"];
    XCTestExpectation *tapNodeExpectation = [self expectationWithDescription:@"TapNode Render"];

    const UInt32 framesPerRender = 1024;
    const UInt32 length = 4196;

    __block UInt32 tapRenderFrame = 0;

    tapNode.renderBlock = ^(YASAudioData *data, NSNumber *bus, YASAudioTime *when, id nodeCore) {
        XCTAssertEqual(when.sampleTime, tapRenderFrame);
        XCTAssertEqual(when.sampleRate, sampleRate);
        XCTAssertEqual(data.frameLength, framesPerRender);
        XCTAssertEqualObjects(data.format, format);

        for (UInt32 buf = 0; buf < data.format.bufferCount; buf++) {
            YASAudioMutablePointer pointer = [data pointerAtBuffer:buf];
            for (UInt32 frame = 0; frame < data.frameLength; frame++) {
                pointer.f32[frame] = TestValue(frame + tapRenderFrame, 0, buf);
            }
        }

        tapRenderFrame += data.frameLength;
        if (tapRenderFrame >= length) {
            [tapNodeExpectation fulfill];
        }
    };

    __block UInt32 outputRenderFrame = 0;
    NSError *error = nil;

    BOOL result = [outputNode startWithOutputCallbackBlock:^(YASAudioData *data, YASAudioTime *when, BOOL *stop) {
        XCTAssertEqual(when.sampleTime, outputRenderFrame);
        XCTAssertEqual(when.sampleRate, sampleRate);
        XCTAssertEqual(data.frameLength, framesPerRender);
        XCTAssertEqualObjects(data.format, format);

        for (UInt32 buf = 0; buf < data.format.bufferCount; buf++) {
            YASAudioConstPointer pointer = {[data pointerAtBuffer:buf].v};
            for (UInt32 frame = 0; frame < data.frameLength; frame++) {
                XCTAssertEqual(pointer.f32[frame], TestValue(frame + outputRenderFrame, 0, buf));
            }
        }

        outputRenderFrame += data.frameLength;
        if (outputRenderFrame >= length) {
            *stop = YES;
            [renderExpectation fulfill];
        }
    } completionBlock:^(BOOL cancelled) {
        XCTAssertFalse(cancelled);
        [completionExpectation fulfill];
    } error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    YASRelease(connection);
    YASRelease(tapNode);
    YASRelease(outputNode);
    YASRelease(format);
}

@end
