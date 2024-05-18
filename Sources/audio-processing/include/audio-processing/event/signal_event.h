//
//  signal_event.h
//

#pragma once

#include <audio-processing/event/event.h>
#include <audio-processing/time/time.h>

#include <vector>

namespace yas::proc {
struct signal_event final {
    using time_type = time::range;
    using pair_t = std::pair<time::range, signal_event_ptr>;
    using pair_vector_t = std::vector<pair_t>;

    [[nodiscard]] std::type_info const &sample_type() const;
    [[nodiscard]] std::size_t sample_byte_count() const;
    [[nodiscard]] std::size_t size() const;
    [[nodiscard]] std::size_t byte_size() const;
    void resize(std::size_t const);
    void reserve(std::size_t const);

    template <typename T>
    [[nodiscard]] std::vector<T> const &vector() const;
    template <typename T>
    [[nodiscard]] std::vector<T> &vector();

    template <typename T>
    [[nodiscard]] T const *data() const;
    template <typename T>
    [[nodiscard]] T *data();

    template <typename T>
    void copy_from(T const *, std::size_t const);
    template <typename T>
    void copy_to(T *, std::size_t const) const;

    [[nodiscard]] signal_event_ptr copy_in_range(time::range const &) const;
    [[nodiscard]] pair_vector_t cropped(time::range const &) const;
    [[nodiscard]] pair_t combined(time::range const &, pair_vector_t);

    [[nodiscard]] signal_event_ptr copy() const;
    [[nodiscard]] bool validate_time(time const &) const;
    [[nodiscard]] bool is_equal(signal_event_ptr const &) const;

   private:
    class impl;

    template <typename T>
    class type_impl;

    std::shared_ptr<impl> _impl;

    template <typename T>
    explicit signal_event(std::vector<T> &&bytes);
    template <typename T>
    explicit signal_event(std::vector<T> &bytes);

    signal_event(signal_event const &) = delete;
    signal_event(signal_event &&) = delete;
    signal_event &operator=(signal_event const &) = delete;
    signal_event &operator=(signal_event &&) = delete;

   public:
    template <typename T>
    static proc::signal_event_ptr make_shared(std::size_t const size);
    template <typename T>
    static proc::signal_event_ptr make_shared(std::size_t const size, std::size_t const reserve);
    template <typename T>
    static proc::signal_event_ptr make_shared(std::vector<T> &&);
    template <typename T>
    static proc::signal_event_ptr make_shared(std::vector<T> &);
};
}  // namespace yas::proc

#include "signal_event_private.h"
