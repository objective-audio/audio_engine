//
//  YASAudioChannelAssignment.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import <Foundation/Foundation.h>

extern NSString *const YASAudioSourceBusKey;
extern NSString *const YASAudioSourceChannelKey;
extern NSString *const YASAudioDestinationBusKey;
extern NSString *const YASAudioDestinationChannelKey;

@class YASAudioFormat;

@interface YASAudioChannelRoute : NSObject

@property (nonatomic, assign, readonly) UInt32 sourceBus;
@property (nonatomic, assign, readonly) UInt32 sourceChannel;
@property (nonatomic, assign, readonly) UInt32 destinationBus;
@property (nonatomic, assign, readonly) UInt32 destinationChannel;

- (instancetype)initWithSourceBus:(UInt32)sourceBus
                    sourceChannel:(UInt32)sourceChannel
                   destinationBus:(UInt32)destinationBus
               destinationChannel:(UInt32)destinationChannel;
- (instancetype)initWithBus:(UInt32)bus channel:(UInt32)channel;

+ (NSArray *)defaultChannelRoutesWithBus:(UInt32)bus format:(YASAudioFormat *)format;

@end

#endif
