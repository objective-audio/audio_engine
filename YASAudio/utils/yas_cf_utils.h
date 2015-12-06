//
//  yas_cf_utils.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <string>
#include <unordered_map>
#include <vector>
#include <CoreFoundation/CoreFoundation.h>

namespace yas {
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

template <typename T>
CFArrayRef to_cf_object(const std::vector<T> &vector);

template <typename K, typename T>
CFDictionaryRef to_cf_object(const std::unordered_map<K, T> &map);

CFStringRef file_type_for_hfs_type_code(const OSType fcc);
OSType hfs_type_code_from_file_type(const CFStringRef cfStr);
}

#include "yas_cf_utils_private.h"
