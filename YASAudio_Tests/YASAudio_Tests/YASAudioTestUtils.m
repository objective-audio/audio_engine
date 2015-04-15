//
//  YASAudioTestUtils.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioTestUtils.h"

UInt32 TestValue(UInt32 frame, UInt32 channel, UInt32 buffer)
{
    return frame + 1024 * (channel + 1) + 512 * (buffer + 1);
}

@implementation YASAudioTestUtils

@end
