//
//  signal_event_private.h
//

#pragma once

#include <audio-processing/time/time.h>

namespace yas {
struct proc::signal_event::impl {
    virtual ~impl() = default;
    virtual std::type_info const &type() const = 0;
    virtual std::size_t sample_byte_count() const = 0;
    virtual std::size_t size() const = 0;
    virtual std::size_t byte_size() const = 0;
    virtual void resize(std::size_t const) = 0;
    virtual void reserve(std::size_t const) = 0;
    virtual signal_event_ptr copy_in_range(time::range const &) = 0;
    virtual std::vector<std::pair<time::range, signal_event_ptr>> cropped(time::range const &) = 0;
    virtual pair_t combined(time::range const &, pair_vector_t) = 0;
    virtual signal_event_ptr copy() = 0;
};

template <typename T>
struct proc::signal_event::type_impl : impl {
    type_impl(std::vector<T> &&bytes) : _vector(std::move(bytes)), _vector_ref(_vector) {
    }

    type_impl(std::vector<T> &bytes) : _vector_ref(bytes) {
    }

    signal_event_ptr copy() override {
        return signal_event::make_shared(std::vector<T>{_vector_ref});
    }

    std::type_info const &type() const override {
        return typeid(T);
    }

    std::size_t sample_byte_count() const override {
        return sizeof(T);
    }

    std::size_t size() const override {
        return this->_vector_ref.size();
    }

    std::size_t byte_size() const override {
        return sizeof(T) * this->_vector_ref.size();
    }

    void resize(std::size_t const size) override {
        this->_vector_ref.resize(size);
    }

    void reserve(std::size_t const size) override {
        this->_vector_ref.reserve(size);
    }

    void copy_from(T const *ptr, std::size_t const size) {
        auto &vec = this->_vector_ref;
        vec.resize(size);
        memcpy(vec.data(), ptr, size * sizeof(T));
    }

    void copy_to(T *ptr, std::size_t const size) const {
        auto &vec = this->_vector_ref;
        if (size > vec.size()) {
            throw "out of range.";
        }
        memcpy(ptr, vec.data(), size * sizeof(T));
    }

    signal_event_ptr copy_in_range(time::range const &range) override {
        if (!time::range{0, static_cast<length_t>(this->size())}.is_contain(range)) {
            throw "out of range.";
        }

        std::vector<T> vec(range.length);
        memcpy(vec.data(), &this->_vector_ref.at(range.frame), range.length);
        return signal_event::make_shared(std::move(vec));
    }

    pair_vector_t cropped(time::range const &range) override {
        time::range this_range{0, static_cast<length_t>(this->size())};

        if (!this_range.is_contain(range)) {
            throw "out of range.";
        }

        pair_vector_t result;

        auto const cropped_ranges = this_range.cropped(range);

        for (auto const &cropped_range : cropped_ranges) {
            auto const &length = cropped_range.length;
            std::vector<T> vec(length);
            memcpy(vec.data(), &this->_vector_ref.at(cropped_range.frame), length);
            result.emplace_back(std::make_pair(cropped_range, signal_event::make_shared(std::move(vec))));
        }

        return result;
    }

    pair_t combined(time::range const &current_range, pair_vector_t event_pairs) override {
        if (event_pairs.size() == 0) {
            throw "argument is empty.";
        }

        if (event_pairs.size() == 1) {
            return *event_pairs.cbegin();
        }

        time::range combined_range = current_range;
        for (auto const &event_pair : event_pairs) {
            combined_range = *combined_range.combined(event_pair.first);
        }

        std::vector<T> vec(combined_range.length);

        for (auto const &event_pair : event_pairs) {
            auto const &event_range = event_pair.first;
            signal_event_ptr const &event_signal = event_pair.second;

            if (event_signal->sample_type() != typeid(T)) {
                throw "sample type mismatch.";
            }

            event_signal->copy_to<T>(&vec[event_range.frame - combined_range.frame], event_range.length);
        }

        this->copy_to(&vec[current_range.frame - combined_range.frame], current_range.length);

        return std::make_pair(combined_range, signal_event::make_shared(std::move(vec)));
    }

    std::vector<T> &vector() {
        return this->_vector_ref;
    }

   private:
    std::vector<T> _vector;
    std::vector<T> &_vector_ref;
};

template <typename T>
proc::signal_event::signal_event(std::vector<T> &&bytes) : _impl(std::make_shared<type_impl<T>>(std::move(bytes))) {
}

template <typename T>
proc::signal_event::signal_event(std::vector<T> &bytes) : _impl(std::make_shared<type_impl<T>>(bytes)) {
}

template <typename T>
std::vector<T> const &proc::signal_event::vector() const {
    return std::dynamic_pointer_cast<signal_event::type_impl<T>>(this->_impl)->vector();
}

template <typename T>
std::vector<T> &proc::signal_event::vector() {
    return std::dynamic_pointer_cast<signal_event::type_impl<T>>(this->_impl)->vector();
}

template <typename T>
T const *proc::signal_event::data() const {
    return std::dynamic_pointer_cast<signal_event::type_impl<T>>(this->_impl)->vector().data();
}

template <typename T>
T *proc::signal_event::data() {
    return std::dynamic_pointer_cast<signal_event::type_impl<T>>(this->_impl)->vector().data();
}

template <typename T>
void proc::signal_event::copy_from(T const *ptr, std::size_t const size) {
    std::dynamic_pointer_cast<signal_event::type_impl<T>>(this->_impl)->copy_from(ptr, size);
}

template <typename T>
void proc::signal_event::copy_to(T *ptr, std::size_t const size) const {
    std::dynamic_pointer_cast<signal_event::type_impl<T>>(this->_impl)->copy_to(ptr, size);
}

template <typename T>
proc::signal_event_ptr proc::signal_event::make_shared(std::size_t const size) {
    return proc::signal_event_ptr(new signal_event{std::vector<T>(size)});
}

template <typename T>
proc::signal_event_ptr proc::signal_event::make_shared(std::size_t const size, std::size_t const reserve) {
    auto vec = std::vector<T>(size);
    vec.reserve(reserve);
    return proc::signal_event_ptr(new signal_event{std::move(vec)});
}

template <typename T>
proc::signal_event_ptr proc::signal_event::make_shared(std::vector<T> &&vec) {
    return proc::signal_event_ptr(new signal_event{std::move(vec)});
}

template <typename T>
proc::signal_event_ptr proc::signal_event::make_shared(std::vector<T> &vec) {
    return proc::signal_event_ptr(new signal_event{vec});
}
}  // namespace yas
