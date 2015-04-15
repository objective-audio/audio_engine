//
//  YASAudioData+Internal.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioData.h"

@interface YASAudioData (Internal)

- (instancetype)initWithFormat:(YASAudioFormat *)format
               audioBufferList:(AudioBufferList *)abl
                     needsFree:(BOOL)needsFree;

#if (!TARGET_OS_IPHONE && TARGET_OS_MAC)
- (instancetype)initWithFormat:(YASAudioFormat *)format
                          data:(YASAudioData *)data
           outputChannelRoutes:(NSArray *)channelRoutes;
- (instancetype)initWithFormat:(YASAudioFormat *)format
                          data:(YASAudioData *)data
            inputChannelRoutes:(NSArray *)channelRoutes;
#endif

@end
