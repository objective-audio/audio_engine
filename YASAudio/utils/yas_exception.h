//
//  yas_exception.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <string>

namespace yas {
void raise_with_reason(const std::string &reason);
void raise_if_main_thread();
void raise_if_sub_thread();
}
