//
//  YASAudioDeviceIO.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "YASWeakSupport.h"

typedef void (^YASAudioDeviceIOCallbackBlock)(AudioBufferList *outData, const AudioTimeStamp *inTime, const UInt32 inFrameLength);

@class YASAudioDevice, YASAudioGraph;

@interface YASAudioDeviceIO : YASWeakProvider

@property (nonatomic, strong) YASAudioDevice *audioDevice;
@property (atomic, copy) YASAudioDeviceIOCallbackBlock renderCallbackBlock;
@property (nonatomic, assign, readonly) BOOL isRunning;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithGraph:(YASAudioGraph *)graph NS_DESIGNATED_INITIALIZER;

- (void)start;
- (void)stop;

- (const AudioBufferList *)inputAudioBufferListOnRender;
- (const AudioTimeStamp *)inputTimeOnRender;

@end

#endif
