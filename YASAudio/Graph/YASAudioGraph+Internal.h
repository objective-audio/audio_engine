//
//  YASAudioGraph+Internal.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioGraph.h"

@interface YASAudioGraph (Internal)

@property (nonatomic, copy, readonly) NSNumber *key;

+ (void)audioUnitRender:(YASAudioUnitRenderParameters *)renderParameters;

@end
