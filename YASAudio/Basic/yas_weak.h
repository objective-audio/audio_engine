//
//  yas_weak.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <memory>
#include <map>

namespace yas
{
    template <typename T>
    class weak
    {
       public:
        weak() : _impl()
        {
        }

        weak(const T &obj) : _impl(std::static_pointer_cast<typename T::impl>(obj._impl))
        {
        }

        weak<T> &operator=(const T &obj)
        {
            _impl = obj._impl;

            return *this;
        }

        T lock() const
        {
            return T(_impl.lock());
        }

        void reset()
        {
            _impl.reset();
        }

       private:
        std::weak_ptr<typename T::impl> _impl;
    };

    template <typename K, typename T>
    std::map<K, T> lock_values(const std::map<K, weak<T>> &map)
    {
        std::map<K, T> unwrapped_map;

        for (auto &pair : map) {
            if (auto shared = pair.second.lock()) {
                unwrapped_map.insert(std::make_pair(pair.first, shared));
            }
        }

        return unwrapped_map;
    }
}
