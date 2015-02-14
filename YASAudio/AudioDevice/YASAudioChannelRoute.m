//
//  YASAudioChannelAssignment.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import "YASAudioChannelRoute.h"
#import "YASAudioFormat.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"

NSString *const YASAudioSourceBusKey = @"sourceBus";
NSString *const YASAudioSourceChannelKey = @"sourceChannel";
NSString *const YASAudioDestinationBusKey = @"destinationBus";
NSString *const YASAudioDestinationChannelKey = @"destinationChannel";

@implementation YASAudioChannelRoute

- (instancetype)initWithSourceBus:(UInt32)sourceBus
                    sourceChannel:(UInt32)sourceChannel
                   destinationBus:(UInt32)destinationBus
               destinationChannel:(UInt32)destinationChannel
{
    self = [super init];
    if (self) {
        _sourceBus = sourceBus;
        _sourceChannel = sourceChannel;
        _destinationBus = destinationBus;
        _destinationChannel = destinationChannel;
    }
    return self;
}

- (instancetype)initWithBus:(UInt32)bus channel:(UInt32)channel
{
    self = [super init];
    if (self) {
        _sourceBus = _destinationBus = bus;
        _sourceChannel = _destinationChannel = channel;
    }
    return self;
}

+ (NSArray *)defaultChannelRoutesWithBus:(UInt32)bus format:(YASAudioFormat *)format
{
    if (!format) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Argument is nil.", __PRETTY_FUNCTION__]));
        return nil;
    }
    
    if (format.isInterleaved) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Invalid format (interleaved).", __PRETTY_FUNCTION__]));
        return nil;
    }
    
    UInt32 channelCount = format.channelCount;
    NSMutableArray *routes = [[NSMutableArray alloc] initWithCapacity:channelCount];
    
    for (UInt32 ch = 0; ch < channelCount; ch++) {
        YASAudioChannelRoute *route = [[YASAudioChannelRoute alloc] initWithBus:bus channel:ch];
        [routes addObject:route];
        YASRelease(route);
    }
    
    return YASAutorelease(routes);
}

@end

#endif
