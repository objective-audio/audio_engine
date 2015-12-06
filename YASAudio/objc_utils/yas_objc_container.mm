//
//  yas_objc_container.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_objc_container.h"
#include "yas_objc_macros.h"
#include <Foundation/Foundation.h>

using namespace yas::objc;

strong_holder::strong_holder() : _object(nil) {
}

strong_holder::strong_holder(const id object) : _object(object) {
    YASRetainOrIgnore(object);
}

strong_holder::~strong_holder() {
    YASRelease(_object);
    _object = nil;
}

void strong_holder::set_object(const id object) {
    YASRetainOrIgnore(object);
    YASRelease(_object);
    _object = object;
}

weak_holder::weak_holder() : _object(nil) {
}

weak_holder::weak_holder(const id object) : _object(object) {
}

weak_holder::~weak_holder() {
    _object = nil;
}

void weak_holder::set_object(const id object) {
    _object = object;
}

#pragma mark -

template <typename T>
container<T>::container(const id object)
    : _holder(object) {
}

template container<strong_holder>::container(const id object);
template container<weak_holder>::container(const id object);

template <typename T>
container<T>::container(const container &other) {
    id obj = other.retained_object();
    set_object(obj);
    YASRelease(obj);
}

template container<strong_holder>::container(const container<strong_holder> &);
template container<weak_holder>::container(const container<weak_holder> &);

template <typename T>
container<T>::container(container &&other) {
    id obj = other.retained_object();
    set_object(obj);
    YASRelease(obj);
    other.set_object(nil);
}

template container<strong_holder>::container(container<strong_holder> &&);
template container<weak_holder>::container(container<weak_holder> &&);

template <typename T>
container<T> &container<T>::operator=(const container<T> &rhs) {
    id obj = rhs.retained_object();
    set_object(obj);
    YASRelease(obj);

    return *this;
}

template container<strong_holder> &container<strong_holder>::operator=(const container<strong_holder> &);
template container<weak_holder> &container<weak_holder>::operator=(const container<weak_holder> &);

template <typename T>
container<T> &container<T>::operator=(container<T> &&rhs) {
    id obj = rhs.retained_object();
    set_object(obj);
    YASRelease(obj);
    rhs.set_object(nil);

    return *this;
}

template container<strong_holder> &container<strong_holder>::operator=(container<strong_holder> &&);
template container<weak_holder> &container<weak_holder>::operator=(container<weak_holder> &&);

template <typename T>
container<T> &container<T>::operator=(const id rhs) {
    set_object(rhs);

    return *this;
}

template container<strong_holder> &container<strong_holder>::operator=(const id);
template container<weak_holder> &container<weak_holder>::operator=(const id);

template <typename T>
container<T>::operator bool() const {
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return !!_holder._object;
}

template container<strong_holder>::operator bool() const;
template container<weak_holder>::operator bool() const;

template <typename T>
void container<T>::set_object(const id object) {
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    _holder.set_object(object);
}

template void container<strong_holder>::set_object(const id);
template void container<weak_holder>::set_object(const id);

template <typename T>
id container<T>::object() const {
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return _holder._object;
}

template id container<strong_holder>::object() const;
template id container<weak_holder>::object() const;

template <typename T>
id container<T>::retained_object() const {
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return YASRetain(_holder._object);
}

template id container<strong_holder>::retained_object() const;
template id container<weak_holder>::retained_object() const;

template <typename T>
id container<T>::autoreleased_object() const {
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return YASRetainAndAutorelease(_holder._object);
}

template id container<strong_holder>::autoreleased_object() const;
template id container<weak_holder>::autoreleased_object() const;

template <typename T>
container<strong_holder> container<T>::lock() const {
    id obj = retained_object();
    container<strong> strong_container(obj);
    YASRelease(obj);
    return strong_container;
}

template container<strong_holder> container<strong_holder>::lock() const;
template container<strong_holder> container<weak_holder>::lock() const;
