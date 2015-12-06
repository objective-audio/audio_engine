//
//  yas_any.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_any.h"

using namespace yas;

any::any() : _container(nullptr) {
}

any::any(const any &other) : _container(other._container ? other._container->copy() : nullptr) {
}

any &any::operator=(const any &rhs) {
    _container = rhs._container ? rhs._container->copy() : nullptr;
    return *this;
}

any::operator bool() const {
    return !!_container;
}

const std::type_info &any::type() const {
    return _container ? _container->type() : typeid(void);
}
