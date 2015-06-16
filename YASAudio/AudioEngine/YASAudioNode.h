//
//  YASAudioNode.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASWeakSupport.h"
#import <AudioUnit/AudioUnit.h>

@class YASAudioFormat, YASAudioEngine, YASAudioData, AVAudioTime;

@interface YASAudioNode : YASWeakProvider

- (void)reset;

- (YASAudioFormat *)inputFormatForBus:(NSNumber *)bus;
- (YASAudioFormat *)outputFormatForBus:(NSNumber *)bus;
- (NSNumber *)nextAvailableInputBus;
- (NSNumber *)nextAvailableOutputBus;
- (BOOL)isAvailableInputBus:(NSNumber *)bus;
- (BOOL)isAvailableOutputBus:(NSNumber *)bus;
- (YASAudioEngine *)engine;
- (AVAudioTime *)lastRenderTime;

#pragma mark - Override by Subclass

- (UInt32)inputBusCount;
- (UInt32)outputBusCount;

#pragma mark Render thread

- (void)renderWithData:(YASAudioData *)data bus:(NSNumber *)bus when:(AVAudioTime *)when;

@end
