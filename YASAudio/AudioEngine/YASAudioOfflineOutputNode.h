//
//  YASAudioOfflineOutputNode.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import "YASAudioTypes.h"
#import "YASAudioNode.h"

@class YASAudioFormat, YASAudioData;

@interface YASAudioOfflineOutputNode : YASAudioNode

@property (nonatomic, assign, readonly) BOOL isRunning;

@end

@interface YASAudioOfflineOutputNode (YASInternal)

- (BOOL)startWithOutputCallbackBlock:(YASAudioOfflineRenderCallbackBlock)outputBlock
                     completionBlock:(YASAudioOfflineRenderCompletionBlock)completionBlock
                               error:(NSError **)outError;
- (void)stop;

@end
