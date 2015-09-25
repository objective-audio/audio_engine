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

    template <typename K, typename T>
    class property
    {
       public:
        using sptr = std::shared_ptr<property<K, T>>;
        using dispatched_subject_t = subject;
        using dispatcher_sptr = observer::sptr;

        static sptr create(const K &key);
        static sptr create(const K &key, const T &value);

        const K &key() const;
        void set_value(const T &value);
        T value() const;

        subject &subject();

       private:
        std::weak_ptr<property<K, T>> _weak_this;
        T _value;
        K _key;
        yas::subject _subject;
        std::mutex _notify_mutex;

        explicit property(const K &key);
        property(const K &key, const T &value);

        property(const property &) = delete;
        property(property &&) = delete;
        property &operator=(const property &) = delete;
        property &operator=(property &&) = delete;
    };

    template <typename K, typename T>
    auto make_property(const K &key, const T &value) -> typename property<K, T>::sptr;
}

#include "yas_property_private.h"
