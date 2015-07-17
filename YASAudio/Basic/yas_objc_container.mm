//
//  yas_objc_container.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_objc_container.h"
#include "YASMacros.h"

using namespace yas;

objc_container_ptr objc_container::create()
{
    return create(nil);
}

objc_container_ptr objc_container::create(const id object)
{
    return create(object, yas::weak);
}

objc_container_ptr objc_container::create(const id object, strong_t)
{
    return std::make_shared<objc_container>(object, strong);
}

objc_container_ptr objc_container::create(const id object, weak_t)
{
    return std::make_shared<objc_container>(object, weak);
}

objc_container::objc_container() : _strong_object(nil), _weak_object(nil), _is_strong(false)
{
}

objc_container::objc_container(const id object, strong_t) : _strong_object(object), _weak_object(nil), _is_strong(true)
{
    YASRetain(object);
}

objc_container::objc_container(const id object, weak_t) : _strong_object(nil), _weak_object(object), _is_strong(false)
{
}

objc_container::~objc_container()
{
    if (_is_strong) {
        YASRelease(_strong_object);
    }
}

objc_container::objc_container(const objc_container &container)
    : _strong_object(nil), _weak_object(nil), _is_strong(false)
{
    if (this == &container) {
        return;
    }

    set_object(nil);

    _is_strong = container._is_strong;

    id object = container.retained_object();
    set_object(object);
    YASRelease(object);
}

objc_container::objc_container(objc_container &&container) : _strong_object(nil), _weak_object(nil), _is_strong(false)
{
    if (this == &container) {
        return;
    }

    set_object(nil);

    _is_strong = std::move(container._is_strong);

    id object = container.retained_object();
    set_object(object);
    YASRelease(object);

    container.set_object(nil);
}

objc_container &objc_container::operator=(const objc_container &container)
{
    if (this == &container) {
        return *this;
    }

    set_object(nil);

    _is_strong = container._is_strong;

    id object = container.retained_object();
    set_object(object);
    YASRelease(object);

    return *this;
}

objc_container &objc_container::operator=(objc_container &&container)
{
    if (this == &container) {
        return *this;
    }

    set_object(nil);

    _is_strong = std::move(container._is_strong);

    id object = container.retained_object();
    set_object(object);
    YASRelease(object);

    container.set_object(nil);

    return *this;
}

objc_container &objc_container::operator=(const id object)
{
    set_object(object);

    return *this;
}

void objc_container::set_object(const id object)
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    if (_is_strong) {
        YASRetain(object);
        YASRelease(_strong_object);
        _strong_object = object;
    } else {
        _weak_object = object;
    }
}

id objc_container::retained_object() const
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return YASRetain(_is_strong ? _strong_object : _weak_object);
}

id objc_container::autoreleased_object() const
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return YASRetainAndAutorelease(_is_strong ? _strong_object : _weak_object);
}
