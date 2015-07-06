//
//  yas_cf_utils.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
    template <typename T>
    void set_cf_property(T &_property, const T &value);

    template <typename T>
    T get_cf_property(T &_property);
}

#include "yas_cf_utils_private.h"
