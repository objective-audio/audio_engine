//
//  yas_property_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas {
template <typename T, typename K>
class property<T, K>::impl : public base::impl {
   public:
    impl(const K &key, const T &value) : _key(key), _value(value) {
    }

    void set_property(const property &prop) {
        _weak_property = prop;
    }

    K &key() {
        return _key;
    }

    void set_value(const T &val) {
        if (auto lock = std::unique_lock<std::mutex>(_notify_mutex, std::try_to_lock)) {
            if (lock.owns_lock()) {
                if (auto property = _weak_property.lock()) {
                    _subject.notify(property_method::will_change, property);
                    _value = val;
                    _subject.notify(property_method::did_change, property);
                }
            }
        }
    }

    T &value() {
        return _value;
    }

    yas::subject<property<T, K>> &subject() {
        return _subject;
    }

   private:
    std::mutex _notify_mutex;
    K _key;
    T _value;
    yas::subject<property<T, K>> _subject;
    weak<property<T, K>> _weak_property;
};

template <typename T, typename K>
property<T, K>::property()
    : property(K{}, T{}) {
}

template <typename T, typename K>
property<T, K>::property(const K &key)
    : property(key, T{}) {
}

template <typename T, typename K>
property<T, K>::property(const K &key, const T &value)
    : super_class(std::make_shared<impl>(key, value)) {
    impl_ptr<impl>()->set_property(*this);
}

template <typename T, typename K>
property<T, K>::property(std::nullptr_t)
    : super_class(nullptr) {
}

template <typename T, typename K>
bool property<T, K>::operator==(const property &rhs) const {
    return impl_ptr() && rhs.impl_ptr() && (impl_ptr() == rhs.impl_ptr());
}

template <typename T, typename K>
bool property<T, K>::operator!=(const property &rhs) const {
    return !impl_ptr() || !rhs.impl_ptr() || (impl_ptr() != rhs.impl_ptr());
}

template <typename T, typename K>
bool property<T, K>::operator==(const T &rhs) const {
    return impl_ptr<impl>()->value() == rhs;
}

template <typename T, typename K>
bool property<T, K>::operator!=(const T &rhs) const {
    return impl_ptr<impl>()->value() != rhs;
}

template <typename T, typename K>
const K &property<T, K>::key() const {
    return impl_ptr<impl>()->key();
}

template <typename T, typename K>
void property<T, K>::set_value(const T &value) {
    impl_ptr<impl>()->set_value(value);
}

template <typename T, typename K>
const T &property<T, K>::value() const {
    return impl_ptr<impl>()->value();
}

template <typename T, typename K>
subject<property<T, K>> &property<T, K>::subject() {
    return impl_ptr<impl>()->subject();
}

template <typename T, typename K>
bool operator==(const T &lhs, const property<T, K> &rhs) {
    return lhs == rhs.value();
}

template <typename T, typename K>
bool operator!=(const T &lhs, const property<T, K> &rhs) {
    return lhs != rhs.value();
}
}
