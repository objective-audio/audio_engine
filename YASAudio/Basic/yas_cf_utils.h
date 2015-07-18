//
//  yas_cf_utils.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <string>
#include <CoreFoundation/CoreFoundation.h>

namespace yas
{
    template <typename T>
    void set_cf_property(T &_property, const T &value);

    template <typename T>
    T get_cf_property(T &_property);

    std::string to_string(const CFStringRef &cf_string);
    CFStringRef to_cf_string(const std::string &string);
}

#include "yas_cf_utils_private.h"
