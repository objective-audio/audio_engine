//
//  yas_property_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
    template <typename T, typename K>
    class property<T, K>::impl
    {
       public:
        K key;
        T value;
        yas::subject subject;
        std::mutex notify_mutex;

        impl()
        {
        }

        impl(const K &key) : key(key)
        {
        }

        impl(const K &key, const T &value) : key(key), value(value)
        {
        }
    };

    template <typename T, typename K>
    property<T, K>::property()
        : _impl(std::make_shared<impl>())
    {
    }

    template <typename T, typename K>
    property<T, K>::property(const K &key)
        : _impl(std::make_shared<impl>(key))
    {
    }

    template <typename T, typename K>
    property<T, K>::property(const K &key, const T &value)
        : _impl(std::make_shared<impl>(key, value))
    {
    }

    template <typename T, typename K>
    bool property<T, K>::operator==(const property &rhs)
    {
        return _impl == rhs._impl;
    }

    template <typename T, typename K>
    bool property<T, K>::operator!=(const property &rhs)
    {
        return _impl != rhs._impl;
    }

    template <typename T, typename K>
    bool property<T, K>::operator==(const T &rhs)
    {
        return _impl->value == rhs;
    }

    template <typename T, typename K>
    bool property<T, K>::operator!=(const T &rhs)
    {
        return _impl->value != rhs;
    }

    template <typename T, typename K>
    const K &property<T, K>::key() const
    {
        return _impl->key;
    }

    template <typename T, typename K>
    void property<T, K>::set_value(const T &value)
    {
        if (auto lock = std::unique_lock<std::mutex>(_impl->notify_mutex, std::try_to_lock)) {
            if (lock.owns_lock()) {
                _impl->subject.notify(property_method::will_change, *this);
                _impl->value = value;
                _impl->subject.notify(property_method::did_change, *this);
            }
        }
    }

    template <typename T, typename K>
    const T &property<T, K>::value() const
    {
        return _impl->value;
    }

    template <typename T, typename K>
    subject &property<T, K>::subject()
    {
        return _impl->subject;
    }

    template <typename T, typename K>
    bool operator==(const T &lhs, const property<T, K> &rhs)
    {
        return lhs == rhs.value();
    }

    template <typename T, typename K>
    bool operator!=(const T &lhs, const property<T, K> &rhs)
    {
        return lhs != rhs.value();
    }
}
