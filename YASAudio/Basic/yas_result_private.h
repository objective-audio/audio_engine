//
//  yas_result_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_exception.h"
#include <iostream>

namespace yas
{
    template <typename T, typename U>
    result<T, U>::result(T &&value)
        : _value(std::experimental::make_optional<T>(std::move(value))), _error(std::experimental::nullopt)
    {
    }

    template <typename T, typename U>
    result<T, U>::result(U &&error)
        : _value(std::experimental::nullopt), _error(std::experimental::make_optional<U>(std::move(error)))
    {
    }

    template <typename T, typename U>
    result<T, U>::~result()
    {
    }

    template <typename T, typename U>
    result<T, U>::result(const result<T, U> &other)
    {
        if (other._value) {
            this->_value = other._value;
        } else if (other._error) {
            this->_error = other._error;
        } else {
            throw std::logic_error(std::string(__PRETTY_FUNCTION__) + " : value or error are not found.");
        }
    }

    template <typename T, typename U>
    result<T, U>::result(result<T, U> &&other)
    {
        if (other._value) {
            this->_value = std::move(other._value);
        } else if (other._error) {
            this->_error = std::move(other._error);
        } else {
            throw std::logic_error(std::string(__PRETTY_FUNCTION__) + " : value or error are not found.");
        }
    }

    template <typename T, typename U>
    result<T, U>::operator bool() const
    {
        return is_success();
    }

    template <typename T, typename U>
    bool result<T, U>::is_success() const
    {
        if (_value) {
            return true;
        } else if (_error) {
            return false;
        } else {
            throw std::logic_error(std::string(__PRETTY_FUNCTION__) + " : value or error are not found.");
            return false;
        }
    }

    template <typename T, typename U>
    const T &result<T, U>::value() const
    {
        return *_value;
    }

    template <typename T, typename U>
    const U &result<T, U>::error() const
    {
        return *_error;
    }
}
