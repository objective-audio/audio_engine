//
//  YASAudioFormat.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "YASAudioTypes.h"

@interface YASAudioFormat : NSObject

@property (nonatomic, readonly, getter=isStandard) BOOL standard;
@property (nonatomic, readonly) YASAudioBitDepthFormat bitDepthFormat;
@property (nonatomic, readonly) UInt32 channelCount;
@property (nonatomic, readonly) UInt32 bufferCount;
@property (nonatomic, readonly) UInt32 stride;
@property (nonatomic, readonly) double sampleRate;
@property (nonatomic, readonly) BOOL isInterleaved;
@property (nonatomic, readonly) const AudioStreamBasicDescription *streamDescription;
@property (nonatomic, readonly) UInt32 sampleByteCount;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithStreamDescription:(const AudioStreamBasicDescription *)asbd;
- (instancetype)initStandardFormatWithSampleRate:(double)sampleRate channels:(UInt32)channels;
- (instancetype)initWithBitDepthFormat:(YASAudioBitDepthFormat)bitDepthFormat
                            sampleRate:(double)sampleRate
                              channels:(UInt32)channels
                           interleaved:(BOOL)interleaved;
- (instancetype)initWithSettings:(NSDictionary *)settings;

- (BOOL)isEqualToAudioFormat:(YASAudioFormat *)otherFormat;

@end

@interface NSDictionary (YASAudioFormat)

- (void)yas_getStreamDescription:(AudioStreamBasicDescription *)outFormat;

@end
