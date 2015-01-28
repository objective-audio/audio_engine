//
//  NSException+YASAudio.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "NSException+YASAudio.h"

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
        [self yas_raiseWithName:YASAudioAudioUnitErrorException reason:[NSString stringWithFormat:@"AudioUnit Error = %@", @(err)]];
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

@end
