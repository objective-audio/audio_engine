//
//  YASAudioTime.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>

@interface YASAudioTime : NSObject

@property (nonatomic, readonly, getter=isHostTimeValid) BOOL hostTimeValid;
@property (nonatomic, readonly) UInt64 hostTime;
@property (nonatomic, readonly, getter=isSampleTimeValid) BOOL sampleTimeValid;
@property (nonatomic, readonly) SInt64 sampleTime;
@property (nonatomic, readonly) Float64 sampleRate;
@property (nonatomic, readonly) AudioTimeStamp audioTimeStamp;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithAudioTimeStamp:(const AudioTimeStamp *)ts sampleRate:(Float64)sampleRate;
- (instancetype)initWithHostTime:(UInt64)hostTime;
- (instancetype)initWithSampleTime:(SInt64)sampleTime atRate:(Float64)sampleRate;
- (instancetype)initWithHostTime:(UInt64)hostTime sampleTime:(SInt64)sampleTime atRate:(Float64)sampleRate;
+ (instancetype)timeWithAudioTimeStamp:(const AudioTimeStamp *)ts sampleRate:(Float64)sampleRate;
+ (instancetype)timeWithHostTime:(UInt64)hostTime;
+ (instancetype)timeWithSampleTime:(SInt64)sampleTime atRate:(Float64)sampleRate;
+ (instancetype)timeWithHostTime:(UInt64)hostTime sampleTime:(SInt64)sampleTime atRate:(Float64)sampleRate;

+ (UInt64)hostTimeForSeconds:(NSTimeInterval)seconds;
+ (NSTimeInterval)secondsForHostTime:(UInt64)hostTime;
- (YASAudioTime *)extrapolateTimeFromAnchor:(YASAudioTime *)anchorTime;

@end
