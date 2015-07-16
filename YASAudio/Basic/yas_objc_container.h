//
//  yas_objc_container.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <Foundation/Foundation.h>
#include <mutex>
#include <memory>
#include "YASMacros.h"

namespace yas
{
    // clang-format off
    
    class objc_container;
    using objc_container_ptr = std::shared_ptr<objc_container>;

    struct strong_t {};
    struct weak_t {};
    constexpr strong_t strong = strong_t();
    constexpr weak_t weak = weak_t();

    // clang-format on

    class objc_container
    {
       public:
        static objc_container_ptr create();
        static objc_container_ptr create(const id object);
        static objc_container_ptr create(const id object, strong_t);
        static objc_container_ptr create(const id object, weak_t);

        objc_container();
        objc_container(const id object, strong_t);
        objc_container(const id object, weak_t);
        ~objc_container();

        objc_container(const objc_container &);
        objc_container(objc_container &&);
        objc_container &operator=(const objc_container &);
        objc_container &operator=(objc_container &&);

        void set_object(const id object);
        id retained_object() const;
        id autoreleased_object() const;

       private:
        id _strong_object;
        YASWeakForVariable id _weak_object;
        mutable std::recursive_mutex _mutex;
        bool _is_strong;
    };
}
