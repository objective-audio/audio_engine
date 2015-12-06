//
//  yas_exception.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_exception.h"
#include <exception>
#include <CoreFoundation/CoreFoundation.h>

using namespace yas;

void yas::raise_with_reason(const std::string &reason) {
    throw std::runtime_error(reason);
}

void yas::raise_if_main_thread() {
    if (CFEqual(CFRunLoopGetCurrent(), CFRunLoopGetMain())) {
        throw std::runtime_error("invalid call on main thread.");
    }
}

void yas::raise_if_sub_thread() {
    if (!CFEqual(CFRunLoopGetCurrent(), CFRunLoopGetMain())) {
        throw std::runtime_error("invalid call on sub thread.");
    }
}
