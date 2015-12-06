//
//  yas_base.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <memory>
#include <map>

namespace yas {
class base {
   public:
    class impl : public std::enable_shared_from_this<base::impl> {
       public:
        virtual ~impl();

        template <typename T, typename I = typename T::impl>
        T cast();
    };

    base(std::nullptr_t);
    virtual ~base();

    base(const base &);
    base(base &&);
    base &operator=(const base &);
    base &operator=(base &&);

    bool operator==(const base &rhs) const;
    bool operator!=(const base &rhs) const;
    bool operator==(std::nullptr_t) const;
    bool operator!=(std::nullptr_t) const;
    bool operator<(const base &rhs) const;

    operator bool() const;
    bool expired() const;

    uintptr_t identifier() const;

    template <typename T, typename I = typename T::impl>
    T cast() const;

    std::shared_ptr<impl> &impl_ptr();
    void set_impl_ptr(const std::shared_ptr<impl> &);
    void set_impl_ptr(std::shared_ptr<impl> &&);

    template <typename T = class impl>
    const std::shared_ptr<T> impl_ptr() const;

   protected:
    base(const std::shared_ptr<class impl> &);

   private:
    std::shared_ptr<class impl> _impl;
};

template <typename T>
class weak {
   public:
    weak();
    weak(const T &);

    weak(const weak<T> &);
    weak(weak<T> &&);
    weak<T> &operator=(const weak<T> &);
    weak<T> &operator=(weak<T> &&);
    weak<T> &operator=(const T &);

    explicit operator bool() const;

    bool operator==(const weak &rhs) const;
    bool operator!=(const weak &rhs) const;

    T lock() const;

    void reset();

   private:
    std::weak_ptr<base::impl> _impl;
};

template <typename K, typename T>
std::map<K, T> lock_values(const std::map<K, weak<T>> &);

template <typename T>
weak<T> to_weak(const T &);
}

#include "yas_base_private.h"
