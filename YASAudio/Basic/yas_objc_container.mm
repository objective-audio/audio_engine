//
//  yas_objc_container.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_objc_container.h"
#include "YASMacros.h"

using namespace yas;

#pragma mark - strong

objc_strong_container_ptr objc_strong_container::create(const id object)
{
    return std::make_shared<objc_strong_container>(object);
}

objc_strong_container::objc_strong_container(const id object) : _strong_object(object)
{
    YASRetainOrIgnore(object);
}

objc_strong_container::~objc_strong_container()
{
    YASRelease(_strong_object);
}

objc_strong_container::objc_strong_container(const objc_strong_container &container) : _strong_object(nil)
{
    id object = container.retained_object();
    set_object(object);
    YASRelease(object);
}

objc_strong_container::objc_strong_container(objc_strong_container &&container) : _strong_object(nil)
{
    id object = container.retained_object();
    set_object(object);
    YASRelease(object);

    container.set_object(nil);
}

objc_strong_container &objc_strong_container::operator=(const objc_strong_container &container)
{
    if (this == &container) {
        return *this;
    }

    id object = container.retained_object();
    set_object(object);
    YASRelease(object);

    return *this;
}

objc_strong_container &objc_strong_container::operator=(objc_strong_container &&container)
{
    if (this == &container) {
        return *this;
    }

    id object = container.retained_object();
    set_object(object);
    YASRelease(object);

    container.set_object(nil);

    return *this;
}

objc_strong_container &objc_strong_container::operator=(const id object)
{
    set_object(object);

    return *this;
}

objc_strong_container::objc_strong_container(const objc_weak_container &container) : _strong_object(nil)
{
    id object = container.retained_object();
    set_object(object);
    YASRelease(object);
}

objc_strong_container &objc_strong_container::operator=(const objc_weak_container &container)
{
    id object = container.retained_object();
    set_object(object);
    YASRelease(object);

    return *this;
}

objc_strong_container::operator bool() const
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return !!_strong_object;
}

void objc_strong_container::set_object(const id object)
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    YASRetainOrIgnore(object);
    YASRelease(_strong_object);
    _strong_object = object;
}

id objc_strong_container::object() const
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return _strong_object;
}

id objc_strong_container::retained_object() const
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return YASRetain(_strong_object);
}

id objc_strong_container::autoreleased_object() const
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return YASRetainAndAutorelease(_strong_object);
}

#pragma mark - weak

objc_weak_container_ptr objc_weak_container::create(const id object)
{
    return std::make_shared<objc_weak_container>(object);
}

objc_weak_container::objc_weak_container(const id object) : _weak_object(object)
{
}

objc_weak_container::~objc_weak_container() = default;

objc_weak_container::objc_weak_container(const objc_weak_container &container) : _weak_object(nil)
{
    id object = container.retained_object();
    set_object(object);
    YASRelease(object);
}

objc_weak_container::objc_weak_container(objc_weak_container &&container) : _weak_object(nil)
{
    id object = container.retained_object();
    set_object(object);
    YASRelease(object);

    container.set_object(nil);
}

objc_weak_container &objc_weak_container::operator=(const objc_weak_container &container)
{
    if (this == &container) {
        return *this;
    }

    id object = container.retained_object();
    set_object(object);
    YASRelease(object);

    return *this;
}

objc_weak_container &objc_weak_container::operator=(objc_weak_container &&container)
{
    if (this == &container) {
        return *this;
    }

    id object = container.retained_object();
    set_object(object);
    YASRelease(object);

    container.set_object(nil);

    return *this;
}

objc_weak_container &objc_weak_container::operator=(const id object)
{
    set_object(object);

    return *this;
}

objc_weak_container::objc_weak_container(const objc_strong_container &container) : _weak_object(nil)
{
    id object = container.retained_object();
    set_object(object);
    YASRelease(object);
}

objc_weak_container &objc_weak_container::operator=(const objc_strong_container &container)
{
    id object = container.retained_object();
    set_object(object);
    YASRelease(object);

    return *this;
}

objc_weak_container::operator bool() const
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return !!_weak_object;
}

void objc_weak_container::set_object(const id object)
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    _weak_object = object;
}

id objc_weak_container::object() const
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return _weak_object;
}

id objc_weak_container::retained_object() const
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return YASRetain(_weak_object);
}

id objc_weak_container::autoreleased_object() const
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return YASRetainAndAutorelease(_weak_object);
}

objc_strong_container objc_weak_container::lock() const
{
    id object = retained_object();
    objc_strong_container container(object);
    YASRelease(object);
    return container;
}
