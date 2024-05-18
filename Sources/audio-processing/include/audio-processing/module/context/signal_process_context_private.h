//
//  signal_process_context_private.h
//

#pragma once

#include <cpp-utils/fast_each.h>

namespace yas::proc {
template <typename T, std::size_t N>
signal_process_context<T, N>::signal_process_context() {
    static_assert(N > 0, "N must greater than 0");

    this->_inputs.reserve(N);

    auto each = make_fast_each(N);
    while (yas_each_next(each)) {
        this->_inputs.emplace_back(std::make_pair(proc::time{nullptr}, signal_event::make_shared(std::vector<T>(0))));
    }
}

template <typename T, std::size_t N>
void signal_process_context<T, N>::reset(std::size_t const reserve_size) {
    for (auto &input_pair : this->_inputs) {
        input_pair.first = nullptr;
        input_pair.second->reserve(reserve_size);
        input_pair.second->resize(0);
    }
}

template <typename T, std::size_t N>
typename signal_process_context<T, N>::pair_vector_t const &signal_process_context<T, N>::inputs() const {
    return this->_inputs;
}

template <typename T, std::size_t N>
void signal_process_context<T, N>::copy_data_from(T const *ptr, std::size_t const size, std::size_t const idx) {
    signal_event_ptr &signal = this->_inputs.at(idx).second;
    signal->copy_from<T>(ptr, size);
}

template <typename T, std::size_t N>
T const *signal_process_context<T, N>::data(std::size_t const idx) const {
    signal_event_ptr const &signal = this->_inputs.at(idx).second;
    return signal->data<T>();
}

template <typename T, std::size_t N>
void signal_process_context<T, N>::set_time(proc::time time, std::size_t const idx) {
    if (!time.is_range_type()) {
        throw "time is not range type.";
    }
    this->_inputs.at(idx).first = time;
}

template <typename T, std::size_t N>
time const &signal_process_context<T, N>::time(std::size_t const idx) const {
    return this->_inputs.at(idx).first;
}
}  // namespace yas::proc
