//
//  YASAudioDeviceStream.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import <AudioToolbox/AudioToolbox.h>
#import "YASWeakSupport.h"

extern NSString *const YASAudioDeviceStreamVirtualFormatDidChangeNotification;
extern NSString *const YASAudioDeviceStreamIsActiveDidChangeNotification;

typedef NS_ENUM(UInt32, YASAudioDeviceStreamDirection) {
    YASAudioDeviceStreamDirectionOutput = 0,
    YASAudioDeviceStreamDirectionInput = 1,
};

@class YASAudioFormat, YASAudioDevice;

@interface YASAudioDeviceStream : YASWeakProvider

@property (nonatomic, readonly) AudioStreamID audioStreamID;
@property (nonatomic, readonly) YASAudioDevice *device;
@property (nonatomic, readonly) BOOL isActive;
@property (nonatomic, readonly) YASAudioDeviceStreamDirection direction;
@property (nonatomic, readonly) YASAudioFormat *virtualFormat;
@property (nonatomic, readonly) UInt32 startingChannel;

- (instancetype)init NS_UNAVAILABLE;

- (BOOL)isEqualToAudioDeviceStream:(YASAudioDeviceStream *)otherStream;

@end

@interface YASAudioDeviceStream (YASInternal)

- (instancetype)initWithAudioStreamID:(AudioStreamID)audioStreamID device:(YASAudioDevice *)device;

@end

#endif
