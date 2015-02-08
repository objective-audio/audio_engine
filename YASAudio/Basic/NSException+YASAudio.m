//
//  NSException+YASAudio.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "NSException+YASAudio.h"
#import <AudioToolbox/AudioToolbox.h>

NSString *const YASAudioGenericException = @"YASAudioEngineGenericException";
NSString *const YASAudioAudioUnitErrorException = @"YASAudioAudioUnitErrorException";
NSString *const YASAudioNSErrorException = @"YASAudioNSErrorException";

@implementation NSException (YASAudio)

+ (void)yas_raiseWithName:(NSString *)name reason:(NSString *)reason
{
    if ([NSThread isMainThread]) {
        [[NSException exceptionWithName:name reason:reason userInfo:nil] raise];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [[NSException exceptionWithName:name reason:reason userInfo:nil] raise];
        });
    }
}

+ (void)yas_raiseWithReason:(NSString *)reason
{
    [self yas_raiseWithName:YASAudioGenericException reason:reason];
}

+ (void)yas_raiseIfError:(NSError *)error
{
    if (error) {
        [self yas_raiseWithName:YASAudioNSErrorException reason:error.description];
    }
}

+ (void)yas_raiseIfAudioUnitError:(OSStatus)err
{
    if (err != noErr) {
        [self yas_raiseWithName:YASAudioAudioUnitErrorException reason:[NSString stringWithFormat:@"AudioUnit Error = %@ - %@", @(err), [self audioUnitErrorDescription:err]]];
    }
}

+ (void)yas_raiseIfMainThread
{
    if ([NSThread isMainThread]) {
        [self yas_raiseWithName:YASAudioGenericException reason:@"Called on main thread."];
    }
}

+ (void)yas_raiseIfSubThread
{
    if (![NSThread isMainThread]) {
        [self yas_raiseWithName:YASAudioGenericException reason:@"Called on sub thread."];
    }
}

#pragma mark -

+ (NSString *)audioUnitErrorDescription:(OSStatus)err
{
    switch (err) {
        case kAudioUnitErr_InvalidProperty:
            return @"InvalidProperty";
        case kAudioUnitErr_InvalidParameter:
            return @"InvalidParameter";
        case kAudioUnitErr_InvalidElement:
            return @"InvalidElement";
        case kAudioUnitErr_NoConnection:
            return @"NoConnection";
        case kAudioUnitErr_FailedInitialization:
            return @"FailedInitialization";
        case kAudioUnitErr_TooManyFramesToProcess:
            return @"TooManyFramesToProcess";
        case kAudioUnitErr_InvalidFile:
            return @"InvalidFile";
        case kAudioUnitErr_FormatNotSupported:
            return @"FormatNotSupported";
        case kAudioUnitErr_Uninitialized:
            return @"Uninitialized";
        case kAudioUnitErr_InvalidScope:
            return @"InvalidScope";
        case kAudioUnitErr_PropertyNotWritable:
            return @"PropertyNotWritable";
        case kAudioUnitErr_CannotDoInCurrentContext:
            return @"CannotDoInCurrentContext";
        case kAudioUnitErr_InvalidPropertyValue:
            return @"InvalidPropertyValue";
        case kAudioUnitErr_PropertyNotInUse:
            return @"PropertyNotInUse";
        case kAudioUnitErr_Initialized:
            return @"Initialized";
        case kAudioUnitErr_InvalidOfflineRender:
            return @"InvalidOfflineRender";
        case kAudioUnitErr_Unauthorized:
            return @"Unauthorized";
        default:
            return @"Unknown";
    }
}

@end
