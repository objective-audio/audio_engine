//
//  yas_property_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
    template <typename K, typename T>
    typename property<K, T>::shared_ptr property<K, T>::create(const K &key)
    {
        return shared_ptr(new property(key));
    }

    template <typename K, typename T>
    typename property<K, T>::shared_ptr property<K, T>::create(const K &key, const T &value)
    {
        return shared_ptr(new property(key, value));
    }

    template <typename K, typename T>
    property<K, T>::property(const K &key)
        : _key(key)
    {
    }

    template <typename K, typename T>
    property<K, T>::property(const K &key, const T &value)
        : _key(key), _value(value)
    {
    }

    template <typename K, typename T>
    const K &property<K, T>::key() const
    {
        return _key;
    }

    template <typename K, typename T>
    void property<K, T>::set_value(const T &value)
    {
        if (auto lock = std::unique_lock<std::mutex>(_notify_mutex, std::try_to_lock)) {
            if (lock.owns_lock()) {
                auto shared_this = this->shared_from_this();
                _subject.notify(property_method::will_change, shared_this);
                _value = value;
                _subject.notify(property_method::did_change, shared_this);
            }
        }
    }

    template <typename K, typename T>
    T property<K, T>::value() const
    {
        return _value;
    }

    template <typename K, typename T>
    subject<property_method, typename property<K, T>::shared_ptr> &property<K, T>::subject()
    {
        return _subject;
    }
    
    template <typename K, typename T>
    auto make_property(const K &key, const T &value) -> typename property<K, T>::shared_ptr
    {
        return property<K, T>::create(key, value);
    }
}
