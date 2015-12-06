//
//  yas_any.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <typeinfo>
#include <memory>

namespace yas {
class any {
   public:
    any();
    template <typename T>
    any(const T &);
    any(const any &);

    ~any() = default;

    template <typename T>
    any &operator=(const T &);
    any &operator=(const any &);

    explicit operator bool() const;

    const std::type_info &type() const;

    template <typename T>
    const T &get() const;

   private:
    class container_base {
       public:
        virtual ~container_base() = default;
        virtual std::unique_ptr<container_base> copy() const = 0;
        virtual const std::type_info &type() const = 0;
    };

    template <typename T>
    class container : public container_base {
       public:
        container(const T &value);
        virtual std::unique_ptr<container_base> copy() const;
        virtual const std::type_info &type() const;
        const T &value();

       private:
        T _value;
    };

    std::unique_ptr<container_base> _container;
};
}

#include "yas_any_private.h"
