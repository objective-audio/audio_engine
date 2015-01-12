//
//  NSException+YASAudio.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>

extern NSString *const YASAudioGenericException;
extern NSString *const YASAudioAudioUnitErrorException;
extern NSString *const YASAudioNSErrorException;

@interface NSException (YASAudio)

+ (void)yas_raiseWithReason:(NSString *)reason;
+ (void)yas_raiseIfError:(NSError *)error;
+ (void)yas_raiseIfAudioUnitError:(OSStatus)err;
+ (void)yas_raiseIfMainThread;
+ (void)yas_raiseIfSubThread;

@end

#if DEBUG
    #define YASRaiseWithReason(__v) [NSException yas_raiseWithReason:__v]
    #define YASRaiseIfError(__v) [NSException yas_raiseIfError:__v]
    #define YASRaiseIfMainThread [NSException yas_raiseIfMainThread]
    #define YASRaiseIfSubThread [NSException yas_raiseIfSubThread]
    #define YASRaiseIfAUError(__v) [NSException yas_raiseIfAudioUnitError:__v]
    #define YASLog(...) NSLog(__VA_ARGS__)
#else
    #define YASRaiseWithReason(__v)
    #define YASRaiseIfError(__v)
    #define YASRaiseIfMainThread
    #define YASRaiseIfSubThread
    #define YASRaiseIfAUError(__v) __v
    #define YASLog(...)
#endif
