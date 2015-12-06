//
//  yas_stl_utils_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas {
template <typename T, typename U>
std::experimental::optional<T> min_empty_key(const std::map<T, U> &map) {
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
T filter(const T &collection, P predicate) {
    T filtered;

    for (auto &obj : collection) {
        if (predicate(obj)) {
            filtered.insert(filtered.end(), obj);
        }
    }

    return filtered;
}

template <typename T, typename P>
void erase_if(T &collection, P predicate) {
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
void enumerate(T &collection, F function) {
    auto it = collection.begin();

    while (it != collection.end()) {
        it = function(it);
    }
}

template <typename T>
std::vector<T> to_vector(std::unordered_set<T> &set) {
    return std::vector<T>{set.begin(), set.end()};
}
}
