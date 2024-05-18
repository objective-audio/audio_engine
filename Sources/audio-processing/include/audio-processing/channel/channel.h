//
//  channel.h
//

#pragma once

#include <audio-processing/common/ptr.h>
#include <audio-processing/time/time.h>

#include <map>

namespace yas::proc {
class event;
class signal_event;

struct channel {
    using events_map_t = std::multimap<time, event>;

    channel();
    explicit channel(events_map_t const &);
    explicit channel(events_map_t &&);

    channel(channel &&) = default;
    channel &operator=(channel &&) = default;

    [[nodiscard]] events_map_t const &events() const;
    [[nodiscard]] events_map_t &events();

    template <typename Event>
    [[nodiscard]] std::multimap<typename Event::time_type::type, std::shared_ptr<Event>> filtered_events() const;
    template <typename Event, typename P>
    [[nodiscard]] std::multimap<typename Event::time_type::type, std::shared_ptr<Event>> filtered_events(
        P predicate) const;
    template <typename SampleType, typename Event>
    [[nodiscard]] std::multimap<typename Event::time_type::type, std::shared_ptr<Event>> filtered_events() const;
    template <typename SampleType, typename Event, typename P>
    [[nodiscard]] std::multimap<typename Event::time_type::type, std::shared_ptr<Event>> filtered_events(
        P predicate) const;
    events_map_t copied_events(time::range const &, frame_index_t const offset) const;

    void insert_event(time, event);
    void insert_events(events_map_t);

    std::pair<time::range, signal_event_ptr> combine_signal_event(time::range const &, signal_event_ptr const &);

    template <typename P>
    void erase_event_if(P predicate);
    template <typename SampleType, typename Event>
    void erase_event();
    template <typename SampleType, typename Event, typename P>
    void erase_event(P predicate);
    void erase_events(time::range const &);

   private:
    events_map_t _events;

    channel(channel const &) = delete;
    channel &operator=(channel const &) = delete;
};
}  // namespace yas::proc

#include "channel_private.h"
