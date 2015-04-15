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
