//
//  NSError+YASAudio.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>

extern NSString *const YASAudioErrorDomain;
extern NSString *const YASAudioErrorCodeNumberKey;
extern NSString *const YASAudioErrorCodeDescriptionKey;

typedef NS_ENUM(NSInteger, YASAudioFileErrorCode)
{
    YASAudioFileErrorCodeInvalidFormat = 1000,
    YASAudioFileErrorCodeNotOpen,
    YASAudioFileErrorCodeNotCreate,
    YASAudioFileErrorCodeReadFailed,
    YASAudioFileErrorCodeWriteFailed,
    YASAudioFileErrorCodeTellFailed,
    YASAudioFileErrorCodeArgumentIsNil,
};

@interface NSError (YASAudio)

+ (void)yas_error:(NSError **)outError code:(NSInteger)code;
+ (void)yas_error:(NSError **)outError code:(NSInteger)code audioErrorCode:(OSStatus)audioErrorCode;

@end
