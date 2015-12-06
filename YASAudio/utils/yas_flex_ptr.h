//
//  yas_flex_ptr.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <cstddef>
#include <MacTypes.h>

namespace yas {
class flex_ptr {
   public:
    union {
        void *v;
        Float32 *f32;
        Float64 *f64;
        SInt32 *i32;
        UInt32 *u32;
        SInt16 *i16;
        UInt16 *u16;
        SInt8 *i8;
        UInt8 *u8;
    };

    flex_ptr(std::nullptr_t n = nullptr);
    template <typename T>
    flex_ptr(const T *const p);
};
}
