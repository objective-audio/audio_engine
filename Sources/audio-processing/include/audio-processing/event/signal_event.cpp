//
//  signal_event.cpp
//

#include "signal_event.h"

using namespace yas;
using namespace yas::proc;

std::type_info const &proc::signal_event::sample_type() const {
    return this->_impl->type();
}

std::size_t proc::signal_event::sample_byte_count() const {
    return this->_impl->sample_byte_count();
}

std::size_t proc::signal_event::size() const {
    return this->_impl->size();
}

std::size_t proc::signal_event::byte_size() const {
    return this->_impl->byte_size();
}

void proc::signal_event::resize(std::size_t const size) {
    return this->_impl->resize(size);
}

void proc::signal_event::reserve(std::size_t const size) {
    return this->_impl->reserve(size);
}

proc::signal_event_ptr proc::signal_event::copy_in_range(time::range const &range) const {
    return this->_impl->copy_in_range(range);
}

std::vector<std::pair<proc::time::range, proc::signal_event_ptr>> proc::signal_event::cropped(
    time::range const &range) const {
    return this->_impl->cropped(range);
}

proc::signal_event::pair_t proc::signal_event::combined(time::range const &insert_range, pair_vector_t event_pairs) {
    return this->_impl->combined(insert_range, event_pairs);
}

proc::signal_event_ptr proc::signal_event::copy() const {
    return this->_impl->copy();
}

bool proc::signal_event::validate_time(proc::time const &time) const {
    if (time.is_range_type()) {
        return time.get<time::range>().length == this->size();
    }
    return false;
}

bool proc::signal_event::is_equal(signal_event_ptr const &rhs) const {
    return reinterpret_cast<uintptr_t>(this) == reinterpret_cast<uintptr_t>(rhs.get());
}
