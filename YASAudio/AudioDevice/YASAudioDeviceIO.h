//
//  YASAudioDeviceIO.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "YASAudioBlocks.h"
#import "YASWeakSupport.h"

@class YASAudioDevice, YASAudioGraph, AVAudioTime;

@interface YASAudioDeviceIO : YASWeakProvider

@property (nonatomic, strong) YASAudioDevice *audioDevice;
@property (atomic, copy) YASAudioDeviceIOCallbackBlock renderCallbackBlock;
@property (nonatomic, assign, readonly) BOOL isRunning;

- (instancetype)init;
- (instancetype)initWithAudioDevice:(YASAudioDevice *)device;

- (void)start;
- (void)stop;

- (YASAudioData *)inputDataOnRender;
- (AVAudioTime *)inputTimeOnRender;

@end

#endif
