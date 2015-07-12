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
    return std::make_shared<objc_container>(object);
}

objc_container::objc_container() : _objc_object(nil)
{
}

objc_container::objc_container(const id object) : _objc_object(object)
{
}

objc_container::~objc_container()
{
}

void objc_container::set_object(const id object)
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    _objc_object = object;
}

id objc_container::retained_object() const
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return YASRetain(_objc_object);
}

id objc_container::autoreleased_object() const
{
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return YASRetainAndAutorelease(_objc_object);
}
