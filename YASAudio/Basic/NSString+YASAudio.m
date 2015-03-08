//
//  NSString+YASAudio.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "NSString+YASAudio.h"

@implementation NSString (YASAudio)

+ (NSString *)yas_fileTypeStringWithHFSTypeCode:(OSType)fcc
{
#if TARGET_OS_IPHONE
    const char fourChar[5] = {(fcc >> 24) & 0xFF, (fcc >> 16) & 0xFF, (fcc >> 8) & 0xFF, fcc & 0xFF, 0};
    NSString *fourCharString = [NSString stringWithCString:fourChar encoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:@"'%@'", fourCharString];
#elif TARGET_OS_MAC
    return NSFileTypeForHFSTypeCode(fcc);
#endif
}

- (OSType)yas_HFSTypeCode
{
#if TARGET_OS_IPHONE
    if (self.length != 6) {
        return 0;
    }
    
    NSString *quote = @"'";
    if (![[self substringToIndex:1] isEqualToString:quote] || ![[self substringFromIndex:5] isEqualToString:quote]) {
        return 0;
    }
    
    NSString *fourCharFileType = [self substringWithRange:NSMakeRange(1, 4)];
    
    if (fourCharFileType.length != 4) {
        return 0;
    }
    
    OSType result = 0;
    
    for (NSInteger i = 0; i < 4; i++) {
        unichar uc = [fourCharFileType characterAtIndex:i];
        if (uc > UINT8_MAX) {
            return 0;
        }
        result |= uc << ((3 - i) * 8);
    }
    return result;
#elif TARGET_OS_MAC
    return NSHFSTypeCodeFromFileType(self);
#endif
}

- (NSString *)stringByAppendingLinePrefix:(NSString *)prefix
{
    NSArray *lines = [self componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *indentedLines = [NSMutableArray array];
    for (NSString *line in lines) {
        [indentedLines addObject:[NSString stringWithFormat:@"%@%@", prefix, line]];
    }
    
    return [indentedLines componentsJoinedByString:@"\n"];
}

@end
