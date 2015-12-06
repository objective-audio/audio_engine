//
//  yas_any_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas {
#pragma mark - any

template <typename T>
any::any(const T &value)
    : _container(std::unique_ptr<any::container_base>(new container<T>(value))) {
}

template <typename T>
any &any::operator=(const T &value) {
    _container = std::unique_ptr<any::container_base>(new container<T>(value));
    return *this;
}

template <typename T>
const T &any::get() const {
    return dynamic_cast<container<T> &>(*_container).value();
}

#pragma mark - container

template <typename T>
any::container<T>::container(const T &value)
    : _value(value) {
}

template <typename T>
std::unique_ptr<any::container_base> any::container<T>::copy() const {
    return std::unique_ptr<any::container_base>(new container(_value));
}

template <typename T>
const std::type_info &any::container<T>::type() const {
    return typeid(T);
}

template <typename T>
const T &any::container<T>::value() {
    return _value;
}
}