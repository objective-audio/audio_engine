//
//  yas_flex_ptr.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_flex_ptr.h"

using namespace yas;

flex_ptr::flex_ptr(std::nullptr_t) : v(nullptr) {
}

template <typename T>
flex_ptr::flex_ptr(const T *const p)
    : v(static_cast<void *>(const_cast<T *>(p))) {
}

template yas::flex_ptr::flex_ptr(const void *);
template yas::flex_ptr::flex_ptr(const Float32 *);
template yas::flex_ptr::flex_ptr(const Float64 *);
template yas::flex_ptr::flex_ptr(const SInt32 *);
template yas::flex_ptr::flex_ptr(const UInt32 *);
template yas::flex_ptr::flex_ptr(const SInt16 *);
template yas::flex_ptr::flex_ptr(const UInt16 *);
template yas::flex_ptr::flex_ptr(const SInt8 *);
template yas::flex_ptr::flex_ptr(const UInt8 *);
