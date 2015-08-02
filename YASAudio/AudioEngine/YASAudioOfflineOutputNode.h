//
//  YASAudioOfflineOutputNode.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import "YASAudioTypes.h"
#import "YASAudioNode.h"

@interface YASAudioOfflineOutputNode : YASAudioNode

@property (nonatomic, assign, readonly) BOOL isRunning;

@end
