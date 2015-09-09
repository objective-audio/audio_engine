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
    enum class property_method : UInt32 {
        will_change,
        did_change,
    };

    template <typename K, typename T>
    class property
    {
       public:
        using shared_ptr = std::shared_ptr<property<K, T>>;
        using dispatched_subject_t = subject<property_method, yas::property<K, T>::shared_ptr>;
        using dispatcher_sptr = typename observer<property_method, property<K, T>::shared_ptr>::sptr;

        static shared_ptr create(const K &key);
        static shared_ptr create(const K &key, const T &value);

        const K &key() const;
        void set_value(const T &value);
        T value() const;

        subject<property_method, shared_ptr> &subject();

       private:
        std::weak_ptr<property<K, T>> _weak_this;
        T _value;
        K _key;
        yas::subject<property_method, shared_ptr> _subject;
        std::mutex _notify_mutex;

        explicit property(const K &key);
        property(const K &key, const T &value);

        property(const property &) = delete;
        property(property &&) = delete;
        property &operator=(const property &) = delete;
        property &operator=(property &&) = delete;
    };

    template <typename K, typename T>
    auto make_property(const K &key, const T &value) -> typename property<K, T>::shared_ptr;
}

#include "yas_property_private.h"
