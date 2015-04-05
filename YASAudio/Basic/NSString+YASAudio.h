//
//  NSString+YASAudio.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface NSString (YASAudio)

+ (NSString *)yas_fileTypeStringWithHFSTypeCode:(OSType)fcc;
- (OSType)yas_HFSTypeCode;

+ (NSString *)yas_stringWithAudioUnitScope:(AudioUnitScope)scope;
+ (NSString *)yas_stringWithAudioUnitParameterUnit:(AudioUnitParameterUnit)parameterUnit;

- (NSString *)stringByAppendingLinePrefix:(NSString *)prefix;

@end
