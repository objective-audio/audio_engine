//
//  yas_objc_utils.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#import <AVFoundation/AVFoundation.h>

namespace yas
{
#if TARGET_OS_IPHONE
    channel_map to_channel_map(const NSArray *channelAssignments, const AudioUnitScope scope);
#endif
}
