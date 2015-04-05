//
//  YASAudioGraph.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <AudioToolbox/AudioToolbox.h>
#import "YASWeakSupport.h"
#import "YASAudioTypes.h"

@class YASAudioUnit;

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
@class YASAudioDeviceIO;
#endif

@interface YASAudioGraph : YASWeakProvider

@property (nonatomic, assign, getter=isRunning) BOOL running;

- (void)addAudioUnit:(YASAudioUnit *)unit;
- (void)removeAudioUnit:(YASAudioUnit *)unit;

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
- (void)addAudioDeviceIO:(YASAudioDeviceIO *)audioDeviceIO;
- (void)removeAudioDeviceIO:(YASAudioDeviceIO *)audioDeviceIO;
#endif

+ (BOOL)isInterrupting;

@end

@interface YASAudioGraph (YASInternal)

@property (nonatomic, copy, readonly) NSNumber *key;

+ (void)audioUnitRender:(YASAudioUnitRenderParameters *)renderParameters
               graphKey:(NSNumber *)graphKey
                unitKey:(NSNumber *)unitKey;

@end
