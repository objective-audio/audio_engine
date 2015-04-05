//
//  YASAudioConnection.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASWeakSupport.h"

@class YASAudioNode, YASAudioFormat, YASAudioTapNode;

@interface YASAudioConnection : YASWeakProvider

@property (nonatomic, strong, readonly) NSNumber *sourceBus;
@property (nonatomic, strong, readonly) NSNumber *destinationBus;

@end

@interface YASAudioConnection (YASInternal)

@property (atomic, strong, readonly) YASAudioNode *sourceNode;
@property (atomic, strong, readonly) YASAudioNode *destinationNode;
@property (nonatomic, strong, readonly) YASAudioFormat *format;

- (instancetype)initWithSourceNode:(YASAudioNode *)sourceNode
                         sourceBus:(NSNumber *)sourceBus
                   destinationNode:(YASAudioNode *)destinationNode
                    destinationBus:(NSNumber *)destinationBus
                            format:(YASAudioFormat *)format;

- (void)removeNodes;
- (void)removeSourceNode;
- (void)removeDestinationNode;

@end
