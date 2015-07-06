//
//  yas_result.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma mark -

#include <memory>
#include <string>
#include <experimental/optional>

namespace yas
{
    template <typename T, typename U>
    class result
    {
       public:
        explicit result(T &&value);
        explicit result(U &&error);

        ~result();

        result(const result<T, U> &other);
        result(result<T, U> &&other);

        explicit operator bool() const;

        bool is_success() const;

        const T &value() const;
        const U &error() const;

       private:
        std::experimental::optional<T> _value;
        std::experimental::optional<U> _error;
    };
}

#include "yas_result_private.h"
