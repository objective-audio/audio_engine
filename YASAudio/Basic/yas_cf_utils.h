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
    CFStringRef to_cf_object(const std::string &string);

    // clang-format off
    constexpr CFNumberType cf_number_type(const Float32 &) { return kCFNumberFloat32Type; };
    constexpr CFNumberType cf_number_type(const Float64 &) { return kCFNumberFloat64Type; };
    constexpr CFNumberType cf_number_type(const SInt32 &) { return kCFNumberSInt32Type; };
    constexpr CFNumberType cf_number_type(const SInt16 &) { return kCFNumberSInt16Type; };
    // clang-format on

    template <typename T>
    CFNumberRef to_cf_object(const T &);
}

#include "yas_cf_utils_private.h"
