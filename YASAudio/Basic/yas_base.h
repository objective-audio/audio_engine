//
//  yas_base.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <memory>
#include <map>

namespace yas
{
    class base
    {
       public:
        class impl
        {
           public:
            virtual ~impl() = default;
        };

        explicit base(std::nullptr_t) : _impl(nullptr)
        {
        }

        virtual ~base() = default;

        base(const base &) = default;
        base(base &&) = default;
        base &operator=(const base &) = default;
        base &operator=(base &&) = default;

        bool operator==(const base &other) const
        {
            return _impl && other._impl && _impl == other._impl;
        }

        bool operator!=(const base &other) const
        {
            return !_impl || !other._impl || _impl != other._impl;
        }

        bool operator<(const base &other) const
        {
            if (_impl && other._impl) {
                return _impl < other._impl;
            }
            return false;
        }

        operator bool() const
        {
            return _impl != nullptr;
        }

        bool expired() const
        {
            return !_impl;
        }

        uintptr_t key() const
        {
            return reinterpret_cast<uintptr_t>(&*_impl);
        }

        template <typename T, typename I = typename T::impl>
        T cast() const
        {
            static_assert(std::is_base_of<base, T>(), "base class is not base.");

            auto obj = T(nullptr);
            obj.set_impl_ptr(std::dynamic_pointer_cast<I>(_impl));
            return obj;
        }

        std::shared_ptr<impl> &impl_ptr()
        {
            return _impl;
        }

        template <typename T = class impl>
        const std::shared_ptr<T> impl_ptr() const
        {
            return std::static_pointer_cast<T>(_impl);
        }

        void set_impl_ptr(const std::shared_ptr<impl> &impl)
        {
            _impl = impl;
        }

       protected:
        base(const std::shared_ptr<class impl> &impl) : _impl(impl)
        {
        }

       private:
        std::shared_ptr<class impl> _impl;
    };

    template <typename T>
    class base_weak
    {
       public:
        base_weak() : _impl()
        {
        }

        base_weak(const T &obj) : _impl(obj.impl_ptr())
        {
        }

        base_weak<T>(const base_weak<T> &) = default;
        base_weak<T>(base_weak<T> &&) = default;
        base_weak<T> &operator=(const base_weak<T> &) = default;
        base_weak<T> &operator=(base_weak<T> &&) = default;

        base_weak<T> &operator=(const T &obj)
        {
            _impl = obj.impl_ptr();

            return *this;
        }

        explicit operator bool() const
        {
            return !_impl.expired();
        }

        T lock() const
        {
            if (_impl.expired()) {
                return T{nullptr};
            } else {
                T obj{nullptr};
                obj.set_impl_ptr(_impl.lock());
                return obj;
            }
        }

        void reset()
        {
            _impl.reset();
        }

       private:
        std::weak_ptr<base::impl> _impl;
    };

    template <typename K, typename T>
    std::map<K, T> lock_values(const std::map<K, base_weak<T>> &map)
    {
        std::map<K, T> unwrapped_map;

        for (auto &pair : map) {
            if (auto shared = pair.second.lock()) {
                unwrapped_map.insert(std::make_pair(pair.first, shared));
            }
        }

        return unwrapped_map;
    }

    template <typename T>
    base_weak<T> to_base_weak(const T &obj)
    {
        return base_weak<T>(obj);
    }
}
