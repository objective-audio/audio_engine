//
//  yas_property_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
    template <typename K, typename T>
    class property<K, T>::impl
    {
       public:
        K key;
        T value;
        yas::subject subject;
        std::mutex notify_mutex;

        impl(const K &key) : key(key)
        {
        }

        impl(const K &key, const T &value) : key(key), value(value)
        {
        }
    };

    template <typename K, typename T>
    property<K, T>::property(const K &key)
        : _impl(std::make_shared<impl>(key))
    {
    }

    template <typename K, typename T>
    property<K, T>::property(const K &key, const T &value)
        : _impl(std::make_shared<impl>(key, value))
    {
    }

    template <typename K, typename T>
    const K &property<K, T>::key() const
    {
        return _impl->key;
    }

    template <typename K, typename T>
    void property<K, T>::set_value(const T &value)
    {
        if (auto lock = std::unique_lock<std::mutex>(_impl->notify_mutex, std::try_to_lock)) {
            if (lock.owns_lock()) {
                _impl->subject.notify(property_method::will_change, *this);
                _impl->value = value;
                _impl->subject.notify(property_method::did_change, *this);
            }
        }
    }

    template <typename K, typename T>
    T property<K, T>::value() const
    {
        return _impl->value;
    }

    template <typename K, typename T>
    subject &property<K, T>::subject()
    {
        return _impl->subject;
    }
}
