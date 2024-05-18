//
//  remove_signal_processor.cpp
//

#include "remove_signal_processor.h"

#include <audio-processing/channel/channel.h>
#include <audio-processing/event/signal_event.h>
#include <audio-processing/stream/stream.h>
#include <cpp-utils/boolean.h>

using namespace yas;
using namespace yas::proc;

template <typename T>
proc::processor_f proc::make_remove_signal_processor(connector_index_set_t keys) {
    return [keys = std::move(keys)](time::range const &current_time_range, connector_map_t const &input_connectors,
                                    connector_map_t const &, stream &stream) {
        for (auto const &connector_pair : input_connectors) {
            if (keys.count(connector_pair.first) == 0) {
                continue;
            }

            auto const &connector = connector_pair.second;
            auto const &ch_idx = connector.channel_index;

            if (stream.has_channel(ch_idx)) {
                auto &channel = stream.channel(ch_idx);

                auto predicate = [&current_time_range](auto const &pair) {
                    time::range const &event_time_range = pair.first;
                    return event_time_range.is_overlap(current_time_range);
                };

                auto const filtered_events = channel.filtered_events<T, signal_event>(predicate);

                std::vector<std::pair<time::range, signal_event_ptr>> cropped_signals;

                for (auto const &event_pair : filtered_events) {
                    auto const &src_frame = event_pair.first.frame;
                    auto const cropped_ranges = event_pair.first.cropped(current_time_range);
                    signal_event_ptr const &src_signal = event_pair.second;
                    for (auto const &cropped_range : cropped_ranges) {
                        signal_event_ptr dst_signal = signal_event::make_shared<T>(cropped_range.length);
                        auto const *src_ptr = &src_signal->data<T>()[cropped_range.frame - src_frame];
                        dst_signal->copy_from(src_ptr, cropped_range.length);
                        cropped_signals.emplace_back(std::make_pair(cropped_range, std::move(dst_signal)));
                    }
                }

                channel.erase_event<T, signal_event>(std::move(predicate));

                for (auto const &pair : cropped_signals) {
                    channel.insert_event(time{pair.first}, pair.second);
                }
            }
        }
    };
}

template proc::processor_f proc::make_remove_signal_processor<double>(connector_index_set_t);
template proc::processor_f proc::make_remove_signal_processor<float>(connector_index_set_t);
template proc::processor_f proc::make_remove_signal_processor<int64_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_signal_processor<int32_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_signal_processor<int16_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_signal_processor<int8_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_signal_processor<uint64_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_signal_processor<uint32_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_signal_processor<uint16_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_signal_processor<uint8_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_signal_processor<boolean>(connector_index_set_t);
