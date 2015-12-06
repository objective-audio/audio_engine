//
//  yas_cf_utils_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <CoreFoundation/CoreFoundation.h>

template <typename T>
void yas::set_cf_property(T &_property, const T &value) {
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
T yas::get_cf_property(T &_property) {
    if (_property) {
        return (T)CFAutorelease(CFRetain(_property));
    }
    return nullptr;
}

template <typename T>
CFNumberRef yas::to_cf_object(const T &value) {
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, cf_number_type(value), &value);
    CFAutorelease(number);
    return number;
}

template CFNumberRef yas::to_cf_object(const Float32 &);
template CFNumberRef yas::to_cf_object(const Float64 &);
template CFNumberRef yas::to_cf_object(const SInt32 &);
template CFNumberRef yas::to_cf_object(const SInt16 &);

template <typename T>
CFArrayRef yas::to_cf_object(const std::vector<T> &vector) {
    CFMutableArrayRef array = CFArrayCreateMutable(kCFAllocatorDefault, vector.size(), &kCFTypeArrayCallBacks);

    for (const T &value : vector) {
        CFTypeRef cf_object = yas::to_cf_object(value);
        CFArrayAppendValue(array, cf_object);
    }
    return array;
}

template <typename K, typename T>
CFDictionaryRef yas::to_cf_object(const std::unordered_map<K, T> &map) {
    CFMutableDictionaryRef dictionary = CFDictionaryCreateMutable(
        kCFAllocatorDefault, map.size(), &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    for (const auto &pair : map) {
        const K &key = pair.first;
        const T &value = pair.second;
        const CFTypeRef key_object = yas::to_cf_object(key);
        const CFTypeRef value_object = yas::to_cf_object(value);
        CFDictionarySetValue(dictionary, key_object, value_object);
    }
    return dictionary;
}
