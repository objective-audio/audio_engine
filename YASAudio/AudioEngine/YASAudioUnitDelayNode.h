//
//  YASAudioDelayNode.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnitNode.h"

@interface YASAudioUnitDelayNode : YASAudioUnitNode

- (instancetype)init;

@property (nonatomic, assign) Float32 delayTime;
@property (nonatomic, assign) Float32 feedback;
@property (nonatomic, assign) Float32 lowPassCutoff;
@property (nonatomic, assign) Float32 wetDryMix;

@end
