//
//  YASSampleIOGraph.h
//  YASAudioSample
//
//  Created by Yuki Yasoshima on 2014/02/02.
//  Copyright (c) 2014年 Yuki Yasoshima. All rights reserved.
//

#import "YASAudioGraph.h"

@interface YASSampleIOGraph : YASAudioGraph

@property (assign) CGFloat inputVolume;

+ (id)sampleIOGraph;

@end
