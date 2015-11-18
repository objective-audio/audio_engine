//
//  yas_property.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_observing.h"
#include <memory>
#include <mutex>

namespace yas
{
    namespace property_method
    {
        static const auto will_change = "yas.property.will_change";
        static const auto did_change = "yas.property.did_change";
    };

    template <typename T, typename K = std::nullptr_t>
    class property
    {
       public:
        property();
        explicit property(const K &key);
        property(const K &key, const T &value);

        property(const property &) = default;
        property(property &&) = default;
        property &operator=(const property &) = default;
        property &operator=(property &&) = default;

        bool operator==(const property &);
        bool operator!=(const property &);
        bool operator==(const T &);
        bool operator!=(const T &);

        const K &key() const;
        void set_value(const T &value);
        const T &value() const;

        subject &subject();

       private:
        class impl;
        std::shared_ptr<impl> _impl;
    };
}

#include "yas_property_private.h"
