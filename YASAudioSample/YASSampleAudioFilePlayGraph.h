//
//  YASSampleAudioFilePlayGraph.h
//  YASAudioSample
//
//  Created by Yuki Yasoshima on 2014/02/04.
//  Copyright (c) 2014年 Yuki Yasoshima. All rights reserved.
//

#import "YASAudioGraph.h"

@interface YASSampleAudioFilePlayGraph : YASAudioGraph

@property (assign, readonly) BOOL isPlaying;
@property (assign) CGFloat volume;

+ (instancetype)sampleAudioFilePlayGraph;

- (void)setAudioFileURL:(NSURL *)url;

- (void)play;
- (void)stop;

@end
