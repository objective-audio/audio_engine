//
//  YASAudioDeviceStream+Internal.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioDeviceStream.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

@interface YASAudioDeviceStream (Internal)

- (instancetype)initWithAudioStreamID:(AudioStreamID)audioStreamID device:(YASAudioDevice *)device;

@end

#endif
