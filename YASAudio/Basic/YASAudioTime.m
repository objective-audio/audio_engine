//
//  YASAudioTime.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioTime.h"
#import "YASMacros.h"
#import <mach/mach_time.h>

#pragma mark - C Function

static const mach_timebase_info_data_t *GetTimebaseInfo()
{
    static mach_timebase_info_data_t _timebaseInfo = {0, 0};
    if (_timebaseInfo.denom == 0) {
        mach_timebase_info(&_timebaseInfo);
    }
    return &_timebaseInfo;
}

#pragma mark - Main

@implementation YASAudioTime

- (instancetype)initWithAudioTimeStamp:(const AudioTimeStamp *)ts sampleRate:(Float64)sampleRate
{
    self = [super init];
    if (self) {
        _audioTimeStamp = *ts;
        _sampleRate = sampleRate;
    }
    return self;
}

- (instancetype)initWithHostTime:(UInt64)hostTime
{
    AudioTimeStamp ts = {
        .mHostTime = hostTime, .mFlags = kAudioTimeStampHostTimeValid,
    };

    return [self initWithAudioTimeStamp:&ts sampleRate:0];
}

- (instancetype)initWithSampleTime:(SInt64)sampleTime atRate:(Float64)sampleRate
{
    AudioTimeStamp ts = {
        .mSampleTime = sampleTime, .mFlags = kAudioTimeStampSampleTimeValid,
    };
    return [self initWithAudioTimeStamp:&ts sampleRate:sampleRate];
}

- (instancetype)initWithHostTime:(UInt64)hostTime sampleTime:(SInt64)sampleTime atRate:(Float64)sampleRate
{
    AudioTimeStamp ts = {
        .mHostTime = hostTime,
        .mSampleTime = sampleTime,
        .mFlags = kAudioTimeStampHostTimeValid | kAudioTimeStampSampleTimeValid,
    };
    return [self initWithAudioTimeStamp:&ts sampleRate:sampleRate];
}

+ (instancetype)timeWithAudioTimeStamp:(const AudioTimeStamp *)ts sampleRate:(Float64)sampleRate
{
    YASAudioTime *audioTime = [[self alloc] initWithAudioTimeStamp:ts sampleRate:sampleRate];
    return YASAutorelease(audioTime);
}

+ (instancetype)timeWithHostTime:(UInt64)hostTime
{
    YASAudioTime *audioTime = [[self alloc] initWithHostTime:hostTime];
    return YASAutorelease(audioTime);
}

+ (instancetype)timeWithSampleTime:(SInt64)sampleTime atRate:(Float64)sampleRate
{
    YASAudioTime *audioTime = [[self alloc] initWithSampleTime:sampleTime atRate:sampleRate];
    return YASAutorelease(audioTime);
}

+ (instancetype)timeWithHostTime:(UInt64)hostTime sampleTime:(SInt64)sampleTime atRate:(Float64)sampleRate
{
    YASAudioTime *audioTime = [[self alloc] initWithHostTime:hostTime sampleTime:sampleTime atRate:sampleRate];
    return YASAutorelease(audioTime);
}

+ (UInt64)hostTimeForSeconds:(NSTimeInterval)seconds
{
    UInt64 nanoSec = seconds * pow(10, 9);
    const mach_timebase_info_data_t *timebaseInfo = GetTimebaseInfo();
    return nanoSec * timebaseInfo->denom / timebaseInfo->numer;
}

+ (NSTimeInterval)secondsForHostTime:(UInt64)hostTime
{
    const mach_timebase_info_data_t *timebaseInfo = GetTimebaseInfo();
    Float64 nanoSec = hostTime * timebaseInfo->numer / timebaseInfo->denom;
    return nanoSec * pow(10, -9);
}

- (NSString *)description
{
    return
        [NSString stringWithFormat:
                      @"<%@: %p> hostTime=%@, isHostTimeValid=%@, sampleTime=%@, isSampleTimeValid=%@, sampleRate=%@",
                      NSStringFromClass(self.class), self, @(self.hostTime), @(self.isHostTimeValid),
                      @(self.sampleTime), @(self.isSampleTimeValid), @(self.sampleRate)];
}

- (YASAudioTime *)extrapolateTimeFromAnchor:(YASAudioTime *)anchorTime
{
    YASAudioTime *result = nil;

    if (anchorTime.isHostTimeValid && anchorTime.isSampleTimeValid && self.isSampleTimeValid) {
        NSTimeInterval anchorHostSeconds = [self.class secondsForHostTime:anchorTime.hostTime];
        NSTimeInterval sampleTimeSeconds =
            (_audioTimeStamp.mSampleTime / _sampleRate - anchorTime.audioTimeStamp.mSampleTime / anchorTime.sampleRate);
        UInt64 hostTime = [self.class hostTimeForSeconds:anchorHostSeconds + sampleTimeSeconds];
        result = [self.class timeWithHostTime:hostTime sampleTime:self.sampleTime atRate:self.sampleRate];
    }

    return result;
}

- (BOOL)isHostTimeValid
{
    return (_audioTimeStamp.mFlags & kAudioTimeStampHostTimeValid) != 0;
}

- (UInt64)hostTime
{
    return _audioTimeStamp.mHostTime;
}

- (BOOL)isSampleTimeValid
{
    return (_audioTimeStamp.mFlags & kAudioTimeStampSampleTimeValid) != 0;
}

- (SInt64)sampleTime
{
    return _audioTimeStamp.mSampleTime;
}

@end
