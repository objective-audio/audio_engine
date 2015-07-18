//
//  yas_cf_utils.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <CoreFoundation/CoreFoundation.h>

template <typename T>
void yas::set_cf_property(T &_property, const T &value)
{
    if (_property != value) {
        if (_property) {
            CFRelease(_property);
        }

        _property = value;

        if (value) {
            CFRetain(value);
        }
    }
}

template <typename T>
T yas::get_cf_property(T &_property)
{
    if (_property) {
        return (T)CFAutorelease(CFRetain(_property));
    }
    return nullptr;
}

template <typename T>
CFNumberRef yas::to_cf_object(const T &value)
{
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, cf_number_type(value), &value);
    CFAutorelease(number);
    return number;
}

template CFNumberRef yas::to_cf_object(const Float32 &);
template CFNumberRef yas::to_cf_object(const Float64 &);
template CFNumberRef yas::to_cf_object(const SInt32 &);
template CFNumberRef yas::to_cf_object(const SInt16 &);
