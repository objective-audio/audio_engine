//
//  YASAudioUnit+Internal.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioUnit.h"

@interface YASAudioUnit (Internal)

@property (nonatomic, copy) NSNumber *graphKey;
@property (nonatomic, copy) NSNumber *key;

- (void)initialize;
- (void)uninitialize;

@end
