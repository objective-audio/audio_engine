//
//  YASAudioConnection+Internal.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioConnection.h"

@interface YASAudioConnection (Internal)

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
