//
//  yas_stl_utils_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
    template <typename T, typename U>
    std::experimental::optional<T> min_empty_key(const std::map<T, U> &map)
    {
        auto map_size = map.size();

        if (map_size == 0) {
            return 0;
        }

        if (map_size >= std::numeric_limits<T>::max()) {
            return nullopt;
        }

        T next = map.rbegin()->first + 1;
        if (next == map.size()) {
            return next;
        }

        next = 0;
        while (map.count(next) > 0) {
            ++next;
        }
        return next;
    }

    template <typename T, typename P>
    T filter(const T &collection, P predicate)
    {
        T filtered;

        for (auto &obj : collection) {
            if (predicate(obj)) {
                filtered.insert(obj);
            }
        }

        return filtered;
    }

    template <typename K, typename T>
    std::map<K, std::shared_ptr<T>> lock_values(const std::map<K, std::weak_ptr<T>> &map)
    {
        std::map<K, std::shared_ptr<T>> unwrapped_map;

        for (auto &pair : map) {
            if (auto shared = pair.second.lock()) {
                unwrapped_map.insert(std::make_pair(pair.first, shared));
            }
        }

        return unwrapped_map;
    }

    template <typename T, typename P>
    void erase_if(T &collection, P predicate)
    {
        auto it = collection.begin();

        while (it != collection.end()) {
            if (predicate(*it)) {
                it = collection.erase(it);
            } else {
                ++it;
            }
        }
    }

    template <typename T, typename F>
    void enumerate(T &collection, F function)
    {
        auto it = collection.begin();

        while (it != collection.end()) {
            it = function(it);
        }
    }
}
