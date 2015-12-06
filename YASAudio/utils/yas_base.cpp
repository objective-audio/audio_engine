//
//  yas_base.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_base.h"

using namespace yas;

#pragma mark - base::impl

base::impl::~impl() = default;

#pragma mark - base

base::base(std::nullptr_t) : _impl(nullptr) {
}

base::base(const std::shared_ptr<class impl> &impl) : _impl(impl) {
}

base::~base() = default;

base::base(const base &) = default;
base::base(base &&) = default;
base &base::operator=(const base &) = default;
base &base::operator=(base &&) = default;

bool base::operator==(const base &rhs) const {
    return _impl && rhs._impl && _impl == rhs._impl;
}

bool base::operator!=(const base &rhs) const {
    return !_impl || !rhs._impl || _impl != rhs._impl;
}

bool base::operator==(std::nullptr_t) const {
    return _impl == nullptr;
}

bool base::operator!=(std::nullptr_t) const {
    return _impl != nullptr;
}

bool base::operator<(const base &rhs) const {
    if (_impl && rhs._impl) {
        return _impl < rhs._impl;
    }
    return false;
}

base::operator bool() const {
    return _impl != nullptr;
}

bool base::expired() const {
    return !_impl;
}

uintptr_t base::identifier() const {
    return reinterpret_cast<uintptr_t>(&*_impl);
}

std::shared_ptr<base::impl> &base::impl_ptr() {
    return _impl;
}

void base::set_impl_ptr(const std::shared_ptr<impl> &impl) {
    _impl = impl;
}

void base::set_impl_ptr(std::shared_ptr<impl> &&impl) {
    _impl = std::move(impl);
}
