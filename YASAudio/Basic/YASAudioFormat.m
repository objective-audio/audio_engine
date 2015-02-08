//
//  YASAudioFormat.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioFormat.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"
#import "NSString+YASAudio.h"
#import <AVFoundation/AVFoundation.h>

@implementation YASAudioFormat {
    AudioStreamBasicDescription _asbd;
	YASAudioBitDepthFormat _bitDepthFormat;
}

- (instancetype)initWithStreamDescription:(const AudioStreamBasicDescription *)asbd
{
    self = [super init];
    if (self) {
        _asbd = *asbd;
        _asbd.mReserved = 0;
        _bitDepthFormat = YASAudioBitDepthFormatOther;
        _standard = NO;
        if (_asbd.mFormatID == kAudioFormatLinearPCM) {
            if ((_asbd.mFormatFlags & kAudioFormatFlagIsFloat) &&
                ((_asbd.mFormatFlags & kAudioFormatFlagIsBigEndian) == kAudioFormatFlagsNativeEndian) &&
                (_asbd.mFormatFlags & kAudioFormatFlagIsPacked)) {
                if (_asbd.mBitsPerChannel == 64) {
                    _bitDepthFormat = YASAudioBitDepthFormatFloat64;
                } else if (_asbd.mBitsPerChannel == 32) {
                    _bitDepthFormat = YASAudioBitDepthFormatFloat32;
                    if (_asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
                        _standard = YES;
                    }
                }
            } else if ((_asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger) &&
                       ((_asbd.mFormatFlags & kAudioFormatFlagIsBigEndian) == kAudioFormatFlagsNativeEndian) &&
                       (_asbd.mFormatFlags & kAudioFormatFlagIsPacked)) {
                if (_asbd.mBitsPerChannel == 32) {
                    _bitDepthFormat = YASAudioBitDepthFormatInt32;
                } else if (_asbd.mBitsPerChannel == 16) {
                    _bitDepthFormat = YASAudioBitDepthFormatInt16;
                }
            }
        }
    }
    return self;
}

- (instancetype)initStandardFormatWithSampleRate:(double)sampleRate channels:(UInt32)channels
{
    return [self initWithBitDepthFormat:YASAudioBitDepthFormatFloat32 sampleRate:sampleRate channels:channels interleaved:NO];
}

- (instancetype)initWithBitDepthFormat:(YASAudioBitDepthFormat)format sampleRate:(double)sampleRate channels:(UInt32)channels interleaved:(BOOL)interleaved
{
    if (format == YASAudioBitDepthFormatOther || channels == 0) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s - Invalid argument.", __PRETTY_FUNCTION__]));
        YASRelease(self);
        return nil;
    }
    
    AudioStreamBasicDescription asbd = {
        .mSampleRate = sampleRate,
        .mFormatID = kAudioFormatLinearPCM,
    };
    
    if (format == YASAudioBitDepthFormatFloat32 || format == YASAudioBitDepthFormatFloat64) {
        asbd.mFormatFlags = kAudioFormatFlagsNativeFloatPacked;
    } else if (format == YASAudioBitDepthFormatInt16 || format == YASAudioBitDepthFormatInt32) {
        asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    }
    
    if (!interleaved) {
        asbd.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
    }
    
    if (format == YASAudioBitDepthFormatFloat64) {
        asbd.mBitsPerChannel = 64;
    } else if (format == YASAudioBitDepthFormatInt16) {
        asbd.mBitsPerChannel = 16;
    } else {
        asbd.mBitsPerChannel = 32;
    }
    
    asbd.mChannelsPerFrame = channels;
    
    UInt32 size = sizeof(AudioStreamBasicDescription);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &asbd);
    
    return [self initWithStreamDescription:&asbd];
}

- (instancetype)initWithSettings:(NSDictionary *)settings
{
    AudioStreamBasicDescription asbd;
    [settings yas_getStreamDescription:&asbd];
    return [self initWithStreamDescription:&asbd];
}

- (UInt32)channelCount
{
    return _asbd.mChannelsPerFrame;
}

- (UInt32)bufferCount
{
    return self.isInterleaved ? 1 : _asbd.mChannelsPerFrame;
}

- (UInt32)stride
{
    return self.isInterleaved ? _asbd.mChannelsPerFrame : 1;
}

- (double)sampleRate
{
    return _asbd.mSampleRate;
}

- (BOOL)isInterleaved
{
    return !(_asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
}

- (const AudioStreamBasicDescription *)streamDescription
{
    return &_asbd;
}

- (UInt32)sampleByteCount
{
    return [self.class _sampleByteCountWithBitDepthFormat:_bitDepthFormat];
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    } else if (![other isKindOfClass:self.class]) {
        return NO;
    } else {
        return [self isEqualToAudioFormat:other];
    }
}

- (BOOL)isEqualToAudioFormat:(YASAudioFormat *)otherFormat
{
    if (self == otherFormat) {
        return YES;
    } else {
        return memcmp(self.streamDescription, otherFormat.streamDescription, sizeof(AudioStreamBasicDescription)) == 0;
    }
}

- (NSUInteger)hash
{
    NSUInteger hash = _asbd.mFormatID + _asbd.mFormatFlags + _asbd.mChannelsPerFrame + _asbd.mBitsPerChannel;
    return hash;
}

- (NSString *)description
{
    NSMutableString *result = [NSMutableString stringWithFormat:@"<%@: %p>\n", self.class, self];
    NSDictionary *asbdDict = @{@"bitDepthFormat": [self _bitDepthFormatString],
                               @"sampleRate": @(_asbd.mSampleRate),
                               @"bitsPerChannel": @(_asbd.mBitsPerChannel),
                               @"bytesPerFrame": @(_asbd.mBytesPerFrame),
                               @"bytesPerPacket": @(_asbd.mBytesPerPacket),
                               @"channelsPerFrame": @(_asbd.mChannelsPerFrame),
                               @"formatFlags": [self _formatFlagsString],
                               @"formatID": [NSString yas_fileTypeStringWithHFSTypeCode:_asbd.mFormatID],
                               @"framesPerPacket": @(_asbd.mFramesPerPacket)};
    [result appendString:asbdDict.description];
    return result;
}

- (NSString *)_bitDepthFormatString
{
    NSDictionary *bitDepthFormats = @{@(YASAudioBitDepthFormatFloat32): @"YASAudioBitDepthFormatFloat32",
                                    @(YASAudioBitDepthFormatFloat64): @"YASAudioBitDepthFormatFloat64",
                                    @(YASAudioBitDepthFormatInt16): @"YASAudioBitDepthFormatInt16",
                                    @(YASAudioBitDepthFormatInt32): @"YASAudioBitDepthFormatInt32"};
    NSString *result = bitDepthFormats[@(_bitDepthFormat)];
    if (!result) {
        result = @"Unknown";
    }
    return result;
}

- (NSString *)_formatFlagsString
{
    NSDictionary *flags = @{@(kAudioFormatFlagIsFloat): @"kAudioFormatFlagIsFloat",
                            @(kAudioFormatFlagIsBigEndian): @"kAudioFormatFlagIsBigEndian",
                            @(kAudioFormatFlagIsSignedInteger): @"kAudioFormatFlagIsSignedInteger",
                            @(kAudioFormatFlagIsPacked): @"kAudioFormatFlagIsPacked",
                            @(kAudioFormatFlagIsAlignedHigh): @"kAudioFormatFlagIsAlignedHigh",
                            @(kAudioFormatFlagIsNonInterleaved): @"kAudioFormatFlagIsNonInterleaved",
                            @(kAudioFormatFlagIsNonMixable): @"kAudioFormatFlagIsNonMixable"};
    NSMutableString *result = [NSMutableString string];
    for (NSNumber *flag in flags) {
        if (_asbd.mFormatFlags & flag.unsignedIntegerValue) {
            if (result.length != 0) {
                [result appendString:@" | "];
            }
            [result appendString:flags[flag]];
        }
    }
    return result;
}

+ (UInt32)_sampleByteCountWithBitDepthFormat:(YASAudioBitDepthFormat)bitDepthFormat
{
    switch (bitDepthFormat) {
        case YASAudioBitDepthFormatFloat32:
        case YASAudioBitDepthFormatInt32:
            return 4;
        case YASAudioBitDepthFormatInt16:
            return 2;
        case YASAudioBitDepthFormatFloat64:
            return 8;
        default:
            return 0;
    }
}

@end

@implementation NSDictionary (YASAudioFormat)

- (void)yas_getStreamDescription:(AudioStreamBasicDescription *)outFormat
{
    memset(outFormat, 0, sizeof(AudioStreamBasicDescription));
    
    NSNumber *formatID = self[AVFormatIDKey];
    NSNumber *sampleRate = self[AVSampleRateKey];
    NSNumber *numberOfChannels = self[AVNumberOfChannelsKey];
    NSNumber *bitDepth = self[AVLinearPCMBitDepthKey];
    
    outFormat->mFormatID = (UInt32)formatID.unsignedLongValue;
    outFormat->mSampleRate = (Float64)sampleRate.doubleValue;
    outFormat->mChannelsPerFrame = (UInt32)numberOfChannels.unsignedLongValue;
    outFormat->mBitsPerChannel = (UInt32)bitDepth.unsignedLongValue;
    
    if (outFormat->mFormatID == kAudioFormatLinearPCM) {
        NSNumber *isBigEndian = self[AVLinearPCMIsBigEndianKey];
        NSNumber *isFloat = self[AVLinearPCMIsFloatKey];
        NSNumber *isNonInterleaved = self[AVLinearPCMIsNonInterleaved];
        
        outFormat->mFormatFlags = kAudioFormatFlagIsPacked;
        if (isBigEndian.boolValue) {
            outFormat->mFormatFlags |= kAudioFormatFlagIsBigEndian;
        }
        if (isFloat.boolValue) {
            outFormat->mFormatFlags |= kAudioFormatFlagIsFloat;
        } else {
            outFormat->mFormatFlags |= kAudioFormatFlagIsSignedInteger;
        }
        if (isNonInterleaved.boolValue) {
            outFormat->mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
        }
    }
    
    UInt32 size = sizeof(AudioStreamBasicDescription);
    
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, outFormat);
}

@end
