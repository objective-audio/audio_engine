//
//  number_event.cpp
//

#include "number_event.h"

#include <cpp-utils/boolean.h>

using namespace yas;
using namespace yas::proc;

namespace yas::proc {
template <typename T>
struct proc::number_event::type_impl : impl {
    type_impl(T &&value) : _value(std::move(value)) {
    }

    std::type_info const &type() const override {
        return typeid(T);
    }

    std::size_t sample_byte_count() const override {
        return sizeof(T);
    }

    virtual bool is_equal(std::shared_ptr<number_event::impl> const &rhs) const override {
        if (auto casted_rhs = std::dynamic_pointer_cast<type_impl<T>>(rhs)) {
            return this->_value == casted_rhs->_value;
        }

        return false;
    }

    number_event_ptr copy() override {
        return number_event::make_shared(this->_value);
    }

    T _value;
};
}  // namespace yas::proc

template <typename T>
proc::number_event::number_event(T value) : _impl(std::make_shared<type_impl<T>>(std::move(value))) {
}

template proc::number_event::number_event(double);
template proc::number_event::number_event(float);
template proc::number_event::number_event(int64_t);
template proc::number_event::number_event(int32_t);
template proc::number_event::number_event(int16_t);
template proc::number_event::number_event(int8_t);
template proc::number_event::number_event(uint64_t);
template proc::number_event::number_event(uint32_t);
template proc::number_event::number_event(uint16_t);
template proc::number_event::number_event(uint8_t);
template proc::number_event::number_event(boolean);

std::type_info const &proc::number_event::sample_type() const {
    return this->_impl->type();
}

std::size_t proc::number_event::sample_byte_count() const {
    return this->_impl->sample_byte_count();
}

template <typename T>
T const &proc::number_event::get() const {
    return std::dynamic_pointer_cast<type_impl<T>>(this->_impl)->_value;
}

template double const &proc::number_event::get() const;
template float const &proc::number_event::get() const;
template int64_t const &proc::number_event::get() const;
template int32_t const &proc::number_event::get() const;
template int16_t const &proc::number_event::get() const;
template int8_t const &proc::number_event::get() const;
template uint64_t const &proc::number_event::get() const;
template uint32_t const &proc::number_event::get() const;
template uint16_t const &proc::number_event::get() const;
template uint8_t const &proc::number_event::get() const;
template boolean const &proc::number_event::get() const;

proc::number_event_ptr proc::number_event::copy() const {
    return this->_impl->copy();
}

bool proc::number_event::validate_time(time const &time) const {
    return time.is_frame_type();
}

bool proc::number_event::is_equal(number_event_ptr const &rhs) const {
    if (rhs) {
        return this->_impl->is_equal(rhs->_impl);
    }
    return false;
}

template <typename T>
proc::number_event_ptr proc::number_event::make_shared(T value) {
    return number_event_ptr(new number_event{std::move(value)});
}

template proc::number_event_ptr proc::number_event::make_shared(double);
template proc::number_event_ptr proc::number_event::make_shared(float);
template proc::number_event_ptr proc::number_event::make_shared(int64_t);
template proc::number_event_ptr proc::number_event::make_shared(int32_t);
template proc::number_event_ptr proc::number_event::make_shared(int16_t);
template proc::number_event_ptr proc::number_event::make_shared(int8_t);
template proc::number_event_ptr proc::number_event::make_shared(uint64_t);
template proc::number_event_ptr proc::number_event::make_shared(uint32_t);
template proc::number_event_ptr proc::number_event::make_shared(uint16_t);
template proc::number_event_ptr proc::number_event::make_shared(uint8_t);
template proc::number_event_ptr proc::number_event::make_shared(boolean);
