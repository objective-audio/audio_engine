//
//  yas_cf_utils.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_cf_utils.h"
#include <Foundation/Foundation.h>

std::string yas::to_string(const CFStringRef &cf_string)
{
    if (cf_string && CFStringGetLength(cf_string) > 0) {
        NSString *objc_str = (__bridge NSString *)cf_string;
        return std::string([objc_str UTF8String]);
    }
    return std::string();
}

CFStringRef yas::to_cf_object(const std::string &string)
{
    CFStringRef cf_string = CFStringCreateWithCString(kCFAllocatorDefault, string.c_str(), kCFStringEncodingUTF8);
    CFAutorelease(cf_string);
    return cf_string;
}
