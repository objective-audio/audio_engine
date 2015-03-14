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

#define YASRaiseWithReason(__v) [NSException yas_raiseWithReason:__v]
#define YASRaiseIfError(__v) [NSException yas_raiseIfError:__v]
#define YASRaiseIfMainThread [NSException yas_raiseIfMainThread]
#define YASRaiseIfSubThread [NSException yas_raiseIfSubThread]
#define YASRaiseIfAUError(__v) [NSException yas_raiseIfAudioUnitError:__v]

#if DEBUG
#define YASLog(...) NSLog(__VA_ARGS__)
#else
#define YASLog(...)
#endif
