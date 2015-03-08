//
//  YASAudioDeviceTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioChannelRoute.h"
#import "YASAudioFormat.h"
#import "YASMacros.h"

@interface YASAudioDeviceTests : XCTestCase

@end

@implementation YASAudioDeviceTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testAudioChannelRouteFull
{
    const UInt32 sourceBus = 0;
    const UInt32 sourceChannel = 1;
    const UInt32 destBus = 2;
    const UInt32 destChannel = 3;

    YASAudioChannelRoute *channelRoute = [[YASAudioChannelRoute alloc] initWithSourceBus:sourceBus
                                                                           sourceChannel:sourceChannel
                                                                          destinationBus:destBus
                                                                      destinationChannel:destChannel];

    XCTAssertNotNil(channelRoute);
    XCTAssertEqual(channelRoute.sourceBus, sourceBus);
    XCTAssertEqual(channelRoute.sourceChannel, sourceChannel);
    XCTAssertEqual(channelRoute.destinationBus, destBus);
    XCTAssertEqual(channelRoute.destinationChannel, destChannel);

    YASRelease(channelRoute);
}

- (void)testAudioChannelRouteSimple
{
    const UInt32 bus = 4;
    const UInt32 channel = 5;

    YASAudioChannelRoute *channelRoute = [[YASAudioChannelRoute alloc] initWithBus:bus channel:channel];

    XCTAssertNotNil(channelRoute);
    XCTAssertEqual(channelRoute.sourceBus, bus);
    XCTAssertEqual(channelRoute.sourceChannel, channel);
    XCTAssertEqual(channelRoute.destinationBus, bus);
    XCTAssertEqual(channelRoute.destinationChannel, channel);

    YASRelease(channelRoute);
}

- (void)testDefaultAudioChannelRoute
{
    const UInt32 bus = 6;
    const UInt32 channels = 4;

    XCTAssertNil([YASAudioChannelRoute defaultChannelRoutesWithBus:bus format:nil]);

    YASAudioFormat *interleavedFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                            sampleRate:44100
                                                                              channels:channels
                                                                           interleaved:YES];

    XCTAssertNil([YASAudioChannelRoute defaultChannelRoutesWithBus:bus format:interleavedFormat]);

    YASAudioFormat *nonInterleavedFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:YASAudioBitDepthFormatFloat32
                                                                               sampleRate:44100
                                                                                 channels:channels
                                                                              interleaved:NO];

    NSArray *channelRoutes = [YASAudioChannelRoute defaultChannelRoutesWithBus:bus format:nonInterleavedFormat];

    XCTAssertNotNil(channelRoutes);
    XCTAssertEqual(channelRoutes.count, channels);

    for (UInt32 ch = 0; ch < channels; ch++) {
        YASAudioChannelRoute *channelRoute = channelRoutes[ch];
        XCTAssertTrue([channelRoute isKindOfClass:[YASAudioChannelRoute class]]);
        XCTAssertEqual(channelRoute.sourceBus, bus);
        XCTAssertEqual(channelRoute.sourceChannel, ch);
        XCTAssertEqual(channelRoute.destinationBus, bus);
        XCTAssertEqual(channelRoute.destinationChannel, ch);
    }
}

@end
