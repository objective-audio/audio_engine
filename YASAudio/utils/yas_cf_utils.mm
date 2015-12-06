//
//  yas_cf_utils.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_cf_utils.h"
#include <Foundation/Foundation.h>

std::string yas::to_string(const CFStringRef &cf_string) {
    if (cf_string && CFStringGetLength(cf_string) > 0) {
        NSString *objc_str = (__bridge NSString *)cf_string;
        return std::string([objc_str UTF8String]);
    }
    return std::string();
}

CFStringRef yas::to_cf_object(const std::string &string) {
    CFStringRef cf_string = CFStringCreateWithCString(kCFAllocatorDefault, string.c_str(), kCFStringEncodingUTF8);
    CFAutorelease(cf_string);
    return cf_string;
}

CFStringRef yas::file_type_for_hfs_type_code(const OSType fcc) {
#if TARGET_OS_IPHONE
    const char fourChar[5] = {static_cast<char>((fcc >> 24) & 0xFF), static_cast<char>((fcc >> 16) & 0xFF),
                              static_cast<char>((fcc >> 8) & 0xFF), static_cast<char>(fcc & 0xFF), 0};
    NSString *fourCharString = [NSString stringWithCString:fourChar encoding:NSUTF8StringEncoding];
    return (__bridge CFStringRef)[NSString stringWithFormat:@"'%@'", fourCharString];
#elif TARGET_OS_MAC
    NSString *fileTypeString = NSFileTypeForHFSTypeCode(fcc);
    return (__bridge CFStringRef)fileTypeString;
#endif
}

OSType yas::hfs_type_code_from_file_type(const CFStringRef cfStr) {
#if TARGET_OS_IPHONE
    if (CFStringGetLength(cfStr) != 6) {
        return 0;
    }

    const CFStringRef quote = CFSTR("'");
    const CFStringRef topStr = CFStringCreateWithSubstring(nullptr, cfStr, CFRangeMake(0, 1));
    const CFStringRef lastStr = CFStringCreateWithSubstring(nullptr, cfStr, CFRangeMake(5, 1));
    CFAutorelease(topStr);
    CFAutorelease(lastStr);

    if (CFStringCompare(quote, topStr, kNilOptions) != kCFCompareEqualTo ||
        CFStringCompare(quote, lastStr, kNilOptions) != kCFCompareEqualTo) {
        return 0;
    }

    const CFStringRef fourCharFileType = CFStringCreateWithSubstring(nullptr, cfStr, CFRangeMake(1, 4));
    CFAutorelease(fourCharFileType);

    if (CFStringGetLength(fourCharFileType) != 4) {
        return 0;
    }

    OSType result = 0;

    for (CFIndex i = 0; i < 4; ++i) {
        unichar uc = CFStringGetCharacterAtIndex(fourCharFileType, i);
        if (uc > UINT8_MAX) {
            return 0;
        }
        result |= uc << ((3 - i) * 8);
    }
    return result;
#elif TARGET_OS_MAC
    return NSHFSTypeCodeFromFileType((__bridge NSString *)cfStr);
#endif
}
