//
//  YASAudioOfflineOutputNode+Internal.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioOfflineOutputNode.h"

@interface YASAudioOfflineOutputNode (Internal)

- (BOOL)startWithOutputCallbackBlock:(YASAudioOfflineRenderCallbackBlock)outputBlock
                     completionBlock:(YASAudioOfflineRenderCompletionBlock)completionBlock
                               error:(NSError **)outError;
- (void)stop;

@end
