//
//  yas_objc_container.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <Foundation/Foundation.h>
#include <mutex>
#include "yas_audio_types.h"
#include "YASMacros.h"

namespace yas
{
    class objc_strong_container
    {
       public:
        objc_strong_container(const id object = nil);

        ~objc_strong_container();

        objc_strong_container(const objc_strong_container &);
        objc_strong_container(objc_strong_container &&) noexcept;
        objc_strong_container &operator=(const objc_strong_container &);
        objc_strong_container &operator=(objc_strong_container &&) noexcept;
        objc_strong_container &operator=(const id object);

        objc_strong_container(const objc_weak_container &);
        objc_strong_container &operator=(const objc_weak_container &);

        explicit operator bool() const;

        void set_object(const id object);
        id object() const;
        id retained_object() const;
        id autoreleased_object() const;

       private:
        id _strong_object;
        mutable std::recursive_mutex _mutex;
    };

    class objc_weak_container
    {
       public:
        objc_weak_container(const id object = nil);

        ~objc_weak_container();

        objc_weak_container(const objc_weak_container &);
        objc_weak_container(objc_weak_container &&) noexcept;
        objc_weak_container &operator=(const objc_weak_container &);
        objc_weak_container &operator=(objc_weak_container &&) noexcept;
        objc_weak_container &operator=(const id object);

        objc_weak_container(const objc_strong_container &);
        objc_weak_container &operator=(const objc_strong_container &);

        explicit operator bool() const;

        void set_object(const id object);
        id object() const;
        id retained_object() const;
        id autoreleased_object() const;

        objc_strong_container lock() const;

       private:
        YASWeakForVariable id _weak_object;
        mutable std::recursive_mutex _mutex;
    };
}
