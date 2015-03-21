//
//  NSError+YASAudio.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>

extern NSString *const YASAudioErrorDomain;
extern NSString *const YASAudioErrorCodeNumberKey;
extern NSString *const YASAudioErrorCodeDescriptionKey;

typedef NS_ENUM(NSInteger, YASAudioFileErrorCode) {
    YASAudioFileErrorCodeInvalidFormat = 1000,
    YASAudioFileErrorCodeNotOpen,
    YASAudioFileErrorCodeNotCreate,
    YASAudioFileErrorCodeReadFailed,
    YASAudioFileErrorCodeWriteFailed,
    YASAudioFileErrorCodeTellFailed,
    YASAudioFileErrorCodeArgumentIsNil,
};

@interface NSError (YASAudio)

+ (NSError *)yas_errorWithCode:(NSInteger)code;
+ (NSError *)yas_errorWithCode:(NSInteger)code audioErrorCode:(OSStatus)audioErrorCode;

@end
