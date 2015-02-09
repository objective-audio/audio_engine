//
//  YASAudioUnit.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASWeakSupport.h"
#import "YASAudioTypes.h"
#import <AudioToolbox/AudioToolbox.h>

extern OSType const YASAudioUnitSubType_DefaultIO;

@class YASAudioGraph, YASAudioUnitParameterInfo;

typedef void (^YASAudioUnitCallbackBlock)(YASAudioUnitRenderParameters *renderParameters);

@interface YASAudioUnit : YASWeakProvider

@property (nonatomic, copy) YASAudioUnitCallbackBlock renderCallbackBlock;
@property (nonatomic, copy) YASAudioUnitCallbackBlock notifyCallbackBlock;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithGraph:(YASAudioGraph *)graph acd:(const AudioComponentDescription *)acd NS_DESIGNATED_INITIALIZER;

- (YASAudioGraph *)graph;
- (AudioUnit)audioUnitInstance;

- (void)setRenderCallback:(const UInt32)inputNumber;
- (void)removeRenderCallback:(const UInt32)inputNumber;
- (void)addRenderNotify;
- (void)removeRenderNotify;
- (void)setInputFormat:(const AudioStreamBasicDescription *)inAsbd busNumber:(const UInt32)bus;
- (void)setOutputFormat:(const AudioStreamBasicDescription *)inAsbd busNumber:(const UInt32)bus;
- (void)getInputFormat:(AudioStreamBasicDescription *)outAsbd busNumber:(const UInt32)bus;
- (void)getOutputFormat:(AudioStreamBasicDescription *)outAsbd busNumber:(const UInt32)bus;
- (void)setMaximumFramesPerSlice:(const UInt32)frames;
- (UInt32)maximumFramesPerSlice;
- (void)setParameter:(const AudioUnitParameterID)parameterID value:(const AudioUnitParameterValue)val scope:(const AudioUnitScope)scope element:(const AudioUnitElement)element;
- (Float32)getParameter:(const AudioUnitParameterID)parameterID scope:(const AudioUnitScope)scope element:(const AudioUnitElement)element;
- (YASAudioUnitParameterInfo *)parameterInfo:(const AudioUnitParameterID)parameterID scope:(const AudioUnitScope)scope;

- (void)setElementCount:(UInt32)count scope:(AudioUnitScope)scope;
- (UInt32)elementCountForScope:(AudioUnitScope)scope;

#pragma mark Render thread

- (void)renderCallbackBlock:(YASAudioUnitRenderParameters *)renderParameters;
- (void)audioUnitRender:(YASAudioUnitRenderParameters *)renderParameters;

@end

@interface YASAudioUnit (YASInternal)

@property (nonatomic, copy) NSNumber *key;

- (void)initialize;
- (void)uninitialize;

@end

@interface YASAudioIOUnit : YASAudioUnit

@property (nonatomic, copy) YASAudioUnitCallbackBlock inputCallbackBlock;
@property (nonatomic, assign, getter=isEnableOutput) BOOL enableOutput; // must call before running
@property (nonatomic, assign, getter=isEnableInput) BOOL enableInput; // must call before running
@property (nonatomic, assign, readonly) BOOL hasOutput;
@property (nonatomic, assign, readonly) BOOL hasInput;
@property (nonatomic, assign, readonly) BOOL isRunning;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
@property (nonatomic, assign) AudioDeviceID currentDevice;
#endif

- (void)setInputCallback;
- (void)removeInputCallback;
- (void)setChannelMap:(NSData *)mapData scope:(AudioUnitScope)scope;
- (NSData *)channelMapForScope:(AudioUnitScope)scope;
- (UInt32)channelMapCountForScope:(AudioUnitScope)scope;

- (void)start;
- (void)stop;

@end
