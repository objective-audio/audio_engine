//
//  event.cpp
//

#include "event.h"

#include <audio-processing/event/number_event.h>
#include <audio-processing/event/signal_event.h>
#include <audio-processing/time/time.h>

using namespace yas;
using namespace yas::proc;

event::event() = default;

event::event(number_event_ptr const &number) : _number(number) {
}

event::event(signal_event_ptr const &signal) : _signal(signal) {
}

bool event::validate_time(time const &time) const {
    switch (this->type()) {
        case event_type::number:
            return this->_number->validate_time(time);
        case event_type::signal:
            return this->_signal->validate_time(time);
    }
}

event event::copy() const {
    switch (this->type()) {
        case event_type::number:
            return event{this->_number->copy()};
        case event_type::signal:
            return event{this->_signal->copy()};
    }
}

bool event::is_equal(event const &rhs) const {
    if (this->_number && rhs._number) {
        return this->_number->is_equal(rhs._number);
    } else if (this->_signal && rhs._signal) {
        return this->_signal->is_equal(rhs._signal);
    } else {
        return false;
    }
}

std::type_info const &event::sample_type() const {
    switch (this->type()) {
        case event_type::number:
            return this->_number->sample_type();
        case event_type::signal:
            return this->_signal->sample_type();
    }
}

event_type event::type() const {
    if (this->_number) {
        return event_type::number;
    } else if (this->_signal) {
        return event_type::signal;
    } else {
        throw std::runtime_error("event not found.");
    }
}

template <>
number_event_ptr const &event::get() const {
    return this->_number;
}

template <>
signal_event_ptr const &event::get() const {
    return this->_signal;
}

std::type_info const &proc::to_time_type(event_type const type) {
    switch (type) {
        case event_type::number:
            return typeid(number_event::time_type);
        case event_type::signal:
            return typeid(signal_event::time_type);
    }
}
