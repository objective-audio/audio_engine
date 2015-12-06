//
//  yas_base_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas {
#pragma mark - base::impl

template <typename T, typename I>
T base::impl::cast() {
    static_assert(std::is_base_of<base, T>(), "base class is not yas::base.");
    static_assert(std::is_base_of<base::impl, I>(), "impl class is not yas::base::impl.");

    T obj{nullptr};
    obj.set_impl_ptr(std::dynamic_pointer_cast<I>(shared_from_this()));
    return obj;
}

#pragma mark - base

template <typename T, typename I>
T base::cast() const {
    static_assert(std::is_base_of<base, T>(), "base class is not yas::base.");
    static_assert(std::is_base_of<base::impl, I>(), "impl class is not yas::base::impl.");

    auto obj = T(nullptr);
    obj.set_impl_ptr(std::dynamic_pointer_cast<I>(_impl));
    return obj;
}

template <typename T>
const std::shared_ptr<T> base::impl_ptr() const {
    return std::static_pointer_cast<T>(_impl);
}

#pragma mark - weak

template <typename T>
weak<T>::weak()
    : _impl() {
}

template <typename T>
weak<T>::weak(const T &obj)
    : _impl(obj.impl_ptr()) {
}

template <typename T>
weak<T>::weak(const weak<T> &) = default;

template <typename T>
weak<T>::weak(weak<T> &&) = default;

template <typename T>
weak<T> &weak<T>::operator=(const weak<T> &) = default;

template <typename T>
weak<T> &weak<T>::operator=(weak<T> &&) = default;

template <typename T>
weak<T> &weak<T>::operator=(const T &obj) {
    _impl = obj.impl_ptr();

    return *this;
}

template <typename T>
weak<T>::operator bool() const {
    return !_impl.expired();
}

template <typename T>
bool weak<T>::operator==(const weak &rhs) const {
    if (_impl.expired() || rhs._impl.expired()) {
        return false;
    } else {
        auto impl = _impl.lock();
        auto rhs_impl = rhs._impl.lock();
        return impl == rhs_impl;
    }
}

template <typename T>
bool weak<T>::operator!=(const weak &rhs) const {
    if (_impl.expired() || rhs._impl.expired()) {
        return true;
    } else {
        auto impl = _impl.lock();
        auto rhs_impl = rhs._impl.lock();
        return impl != rhs_impl;
    }
}

template <typename T>
T weak<T>::lock() const {
    T obj{nullptr};
    if (!_impl.expired()) {
        obj.set_impl_ptr(_impl.lock());
    }
    return obj;
}

template <typename T>
void weak<T>::reset() {
    _impl.reset();
}

#pragma mark - global

template <typename K, typename T>
std::map<K, T> lock_values(const std::map<K, weak<T>> &map) {
    std::map<K, T> unwrapped_map;

    for (auto &pair : map) {
        if (auto shared = pair.second.lock()) {
            unwrapped_map.insert(std::make_pair(pair.first, shared));
        }
    }

    return unwrapped_map;
}

template <typename T>
weak<T> to_weak(const T &obj) {
    return weak<T>(obj);
}
}
