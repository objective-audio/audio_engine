//
//  yas_weak.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <memory>

namespace yas
{
    template <typename T, typename I>
    class weak
    {
       public:
        weak() : _impl()
        {
        }

        explicit weak(const T &obj) : _impl(obj._impl)
        {
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
        std::weak_ptr<I> _impl;
    };
}
