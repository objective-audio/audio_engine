//
//  YASAudioDevice.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "YASWeakSupport.h"

extern NSString *const YASAudioHardwareDidChangeNotification;
extern NSString *const YASAudioDeviceDidChangeNotification;
extern NSString *const YASAudioDeviceConfigurationChangeNotification;

extern NSString *const YASAudioDevicePropertiesKey;
extern NSString *const YASAudioDeviceSelectorKey;
extern NSString *const YASAudioDeviceScopeKey;

@class YASAudioFormat;

@interface YASAudioDevice : YASWeakProvider

@property (nonatomic, readonly) AudioDeviceID audioDeviceID;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *manufacture;
@property (nonatomic, readonly) NSArray *inputStreams;
@property (nonatomic, readonly) NSArray *outputStreams;
@property (atomic, readonly) YASAudioFormat *inputFormat;
@property (atomic, readonly) YASAudioFormat *outputFormat;
@property (nonatomic, readonly) Float64 nominalSampleRate;

+ (NSArray *)allDevices;
+ (NSArray *)outputDevices;
+ (NSArray *)inputDevices;
+ (YASAudioDevice *)defaultSystemOutputDevice;
+ (YASAudioDevice *)defaultOutputDevice;
+ (YASAudioDevice *)defaultInputDevice;
+ (YASAudioDevice *)deviceForID:(AudioDeviceID)audioDeviceID;

- (instancetype)init NS_UNAVAILABLE;

- (BOOL)isEqualToAudioDevice:(YASAudioDevice *)otherDevice;

@end

#endif
