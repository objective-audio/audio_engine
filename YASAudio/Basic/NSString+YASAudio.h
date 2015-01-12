//
//  NSString+YASAudio.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>

@interface NSString (YASAudio)

+ (NSString *)yas_fileTypeStringWithHFSTypeCode:(OSType)fcc;
- (OSType)yas_HFSTypeCode;

@end
