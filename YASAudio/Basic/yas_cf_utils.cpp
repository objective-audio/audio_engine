//
//  yas_cf_utils.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_cf_utils.h"

std::string yas::to_string(const CFStringRef &cf_string)
{
    return std::string(CFStringGetCStringPtr(cf_string, kCFStringEncodingUTF8));
}

CFStringRef yas::to_cf_object(const std::string &string)
{
    CFStringRef cf_string = CFStringCreateWithCString(kCFAllocatorDefault, string.c_str(), kCFStringEncodingUTF8);
    CFAutorelease(cf_string);
    return cf_string;
}
