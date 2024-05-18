//
//  number_event.h
//

#pragma once

#include <audio-processing/event/event.h>
#include <audio-processing/time/time.h>

#include <map>

namespace yas::proc {
struct number_event final {
    using time_type = time::frame;

    template <typename T>
    using value_map_t = std::multimap<time::frame::type, T>;

    [[nodiscard]] std::type_info const &sample_type() const;
    [[nodiscard]] std::size_t sample_byte_count() const;

    template <typename T>
    [[nodiscard]] T const &get() const;

    [[nodiscard]] number_event_ptr copy() const;
    [[nodiscard]] bool validate_time(time const &) const;
    [[nodiscard]] bool is_equal(number_event_ptr const &) const;

   private:
    class impl;

    template <typename T>
    class type_impl;

    std::shared_ptr<impl> _impl;

    template <typename T>
    explicit number_event(T);

    number_event(number_event const &) = delete;
    number_event(number_event &&) = delete;
    number_event &operator=(number_event const &) = delete;
    number_event &operator=(number_event &&) = delete;

   public:
    template <typename T>
    static proc::number_event_ptr make_shared(T);
};
}  // namespace yas::proc

#include "number_event_private.h"
