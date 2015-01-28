//
//  NSError+YASAudio.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "NSError+YASAudio.h"
#import <AudioToolbox/AudioToolbox.h>

NSString *const YASAudioErrorDomain = @"jp.objective-audio.YASAudio";
NSString *const YASAudioErrorCodeNumberKey = @"audio_error_code_number";
NSString *const YASAudioErrorCodeDescriptionKey = @"audio_error_code_description";

@implementation NSError (YASAudio)

+ (void)yas_error:(NSError **)outError code:(NSInteger)code
{
    return [self yas_error:outError code:code audioErrorCode:noErr];
}

+ (void)yas_error:(NSError **)outError code:(NSInteger)code audioErrorCode:(OSStatus)audioErrorCode
{
    if (outError) {
        NSDictionary *dictionary = nil;
        if (audioErrorCode != noErr) {
            dictionary = @{YASAudioErrorCodeNumberKey: @(audioErrorCode),
                           YASAudioErrorCodeDescriptionKey: [self _descriptionForAudioErrorCode:audioErrorCode]};
        }
        *outError = [NSError errorWithDomain:YASAudioErrorDomain code:code userInfo:dictionary];
    }
}

+ (NSString *)_descriptionForAudioErrorCode:(OSStatus)audioErrorCode
{
    switch (audioErrorCode) {
        case kAudioUnitErr_InvalidProperty:
            return @"AudioUnit Error - Invalid Property";
        case kAudioUnitErr_InvalidParameter:
            return @"AudioUnit Error - Invalid Parameter";
        case kAudioUnitErr_InvalidElement:
            return @"AudioUnit Error - Invalid Element";
        case kAudioUnitErr_NoConnection:
            return @"AudioUnit Error - No Connection";
        case kAudioUnitErr_FailedInitialization:
            return @"AudioUnit Error - Failed Initialization";
        case kAudioUnitErr_TooManyFramesToProcess:
            return @"AudioUnit Error - Too Many Frames To Process";
        case kAudioUnitErr_InvalidFile:
            return @"AudioUnit Error - Invalid File";
        case kAudioUnitErr_FormatNotSupported:
            return @"AudioUnit Error - Format Not Supported";
        case kAudioUnitErr_Uninitialized:
            return @"AudioUnit Error - Uninitialized";
        case kAudioUnitErr_InvalidScope:
            return @"AudioUnit Error - Invalid Scope";
        case kAudioUnitErr_PropertyNotWritable:
            return @"AudioUnit Error - Property Not Writable";
        case kAudioUnitErr_CannotDoInCurrentContext:
            return @"AudioUnit Error - Cannot Do In Current Context";
        case kAudioUnitErr_InvalidPropertyValue:
            return @"AudioUnit Error - Invalid Property Value";
        case kAudioUnitErr_PropertyNotInUse:
            return @"AudioUnit Error - Property Not In Use";
        case kAudioUnitErr_Initialized:
            return @"AudioUnit Error - Initialized";
        case kAudioUnitErr_InvalidOfflineRender:
            return @"AudioUnit Error - Invalid Offline Render";
        case kAudioUnitErr_Unauthorized:
            return @"AudioUnit Error - Unauthorized";
        default:
            return @"";
    }
}

@end
