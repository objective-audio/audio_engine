//
//  number_process_context_private.h
//

#pragma once

#include <cpp-utils/fast_each.h>

namespace yas::proc {
template <typename T, std::size_t N>
number_process_context<T, N>::number_process_context() : _last_values(N) {
    static_assert(N > 0, "N must greater than 0");
}

template <typename T, std::size_t N>
void number_process_context<T, N>::insert_input(frame_index_t const &frame, T const &value, std::size_t const idx) {
    if (this->_inputs.count(frame) == 0) {
        this->_inputs.emplace(frame, input{});
    }
    auto &input = this->_inputs.at(frame);
    input.values[idx] = value;
}

template <typename T, std::size_t N>
void number_process_context<T, N>::update_last_values(input const &input) {
    auto each = make_fast_each_ptr(this->_last_values.data(), N);
    while (yas_each_next(each)) {
        if (auto const &value = input.values[yas_each_index(each)]) {
            yas_each_value(each) = *value;
        }
    }
}

template <typename T, std::size_t N>
void number_process_context<T, N>::reset(time::range const &current_range) {
    if (_last_process_range) {
        if (current_range.frame != _last_process_range->next_frame()) {
            this->_last_values.resize(0);
            this->_last_values.resize(N);
        }

        this->_inputs.clear();
    }

    _last_process_range = current_range;
}

template <typename T, std::size_t N>
std::map<frame_index_t, typename number_process_context<T, N>::input> const &number_process_context<T, N>::inputs()
    const {
    return this->_inputs;
}

template <typename T, std::size_t N>
std::vector<T> const &number_process_context<T, N>::last_values() const {
    return this->_last_values;
}
}  // namespace yas::proc
