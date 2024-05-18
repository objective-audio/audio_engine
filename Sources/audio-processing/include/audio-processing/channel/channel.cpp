//
//  channel.cpp
//

#include "channel.h"

#include <audio-processing/event/signal_event.h>

using namespace yas;
using namespace yas::proc;

#pragma mark - proc::channel

proc::channel::channel() {
}

proc::channel::channel(events_map_t const &events) : _events(events) {
}

proc::channel::channel(events_map_t &&events) : _events(std::move(events)) {
}

proc::channel::events_map_t const &proc::channel::events() const {
    return this->_events;
}

proc::channel::events_map_t &proc::channel::events() {
    return this->_events;
}

void proc::channel::insert_event(time time, event event) {
    if (!event.validate_time(time)) {
        throw "invalid time for event.";
    }

    this->_events.emplace(std::move(time), std::move(event));
}

void proc::channel::insert_events(events_map_t events) {
    for (auto &event_pair : events) {
        this->insert_event(event_pair.first, std::move(event_pair.second));
    }
}

proc::signal_event::pair_t proc::channel::combine_signal_event(time::range const &insert_range,
                                                               signal_event_ptr const &signal) {
    auto const &sample_type = signal->sample_type();

    auto predicate = [&insert_range, &sample_type](std::pair<time, event> const &pair) {
        time const &time = pair.first;
        if (time.is_range_type()) {
            if (time.get<time::range>().can_combine(insert_range)) {
                if (auto const &signal = pair.second.get<signal_event>()) {
                    if (signal->sample_type() == sample_type) {
                        return true;
                    }
                }
            }
        }
        return false;
    };

    auto const filtered_events = filter(this->events(), predicate);

    if (filtered_events.size() > 0) {
        auto vec = to_vector<signal_event::pair_t>(filtered_events, [](std::pair<time, event> const &pair) {
            time const &time = pair.first;
            return std::make_pair(time.get<time::range>(), pair.second.get<signal_event>());
        });
        auto combined_pair = signal->combined(insert_range, vec);
        this->erase_event_if(predicate);
        this->insert_event(time{combined_pair.first}, combined_pair.second);
        return combined_pair;
    } else {
        this->insert_event(time{insert_range}, signal);
        return std::make_pair(insert_range, signal);
    }
}

proc::channel::events_map_t proc::channel::copied_events(time::range const &copy_range,
                                                         frame_index_t const offset) const {
    events_map_t result;

    for (auto const &event_pair : this->events()) {
        auto const &event_time = event_pair.first;
        auto const &event = event_pair.second;
        if (event_time.is_any_type()) {
            result.emplace(std::make_pair(event_time, event.copy()));
        } else if (event_time.is_frame_type()) {
            if (copy_range.is_contain(event_time.get<time::frame>())) {
                result.emplace(std::make_pair(make_frame_time(event_time.get<time::frame>() + offset), event.copy()));
            }
        } else if (event_time.is_range_type()) {
            auto const &event_range = event_time.get<time::range>();
            if (auto const overlap_range_opt = copy_range.intersected(event_range)) {
                auto const &overlap_range = *overlap_range_opt;
                auto const signal = event.get<signal_event>();
                auto copied_signal =
                    signal->copy_in_range(time::range{overlap_range.frame - event_range.frame, overlap_range.length});
                result.emplace(std::make_pair(time{overlap_range.offset(offset)}, std::move(copied_signal)));
            }
        } else {
            throw "unreachable code.";
        }
    }

    return result;
}

void proc::channel::erase_events(time::range const &erase_range) {
    signal_event::pair_vector_t remained_signal;

    std::erase_if(this->events(), [erase_range, &remained_signal](std::pair<time, event> const &event_pair) {
        time const &event_time = event_pair.first;
        if (event_time.is_any_type()) {
            return true;
        } else if (event_time.is_frame_type()) {
            if (erase_range.is_contain(event_time.get<time::frame>())) {
                return true;
            }
        } else if (event_time.is_range_type()) {
            auto const &event_range = event_time.get<time::range>();
            if (auto overlapped_range = erase_range.intersected(event_range)) {
                auto const &signal = event_pair.second.get<signal_event>();
                auto const range = time::range{overlapped_range->frame - event_range.frame, overlapped_range->length};
                signal_event::pair_vector_t cropped_signals = signal->cropped(range);
                for (auto const &cropped_signal : cropped_signals) {
                    auto const &cropped_range = cropped_signal.first;
                    remained_signal.emplace_back(
                        std::make_pair(cropped_range.offset(event_range.frame), cropped_signal.second));
                }

                return true;
            }
        } else {
            throw "unreachable code.";
        }

        return false;
    });

    if (remained_signal.size() > 0) {
        for (auto const &signal_pair : remained_signal) {
            this->insert_event(time{signal_pair.first}, signal_pair.second);
        }
    }
}
