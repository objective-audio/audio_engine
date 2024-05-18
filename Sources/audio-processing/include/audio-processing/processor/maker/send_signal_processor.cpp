//
//  send_signal_processor.cpp
//

#include "send_signal_processor.h"

#include <audio-processing/channel/channel.h>
#include <audio-processing/event/signal_event.h>
#include <audio-processing/module/module.h>
#include <cpp-utils/boolean.h>
#include <cpp-utils/stl_utils.h>

using namespace yas;
using namespace yas::proc;

template <typename T>
proc::processor_f proc::make_send_signal_processor(proc::send_signal_process_f<T> handler) {
    return [handler = std::move(handler)](time::range const &current_time_range, connector_map_t const &,
                                          connector_map_t const &output_connectors, stream &stream) {
        if (handler) {
            for (auto const &connector_pair : output_connectors) {
                auto const &co_idx = connector_pair.first;
                auto const &connector = connector_pair.second;

                auto const &ch_idx = connector.channel_index;
                auto &channel = stream.add_channel(ch_idx);

                if (channel.events().size() > 0) {
                    proc::time::range combined_time_range = current_time_range;

                    auto predicate = [&current_time_range](auto const &pair) {
                        if (pair.first.can_combine(current_time_range)) {
                            return true;
                        }
                        return false;
                    };

                    auto const filtered_events = channel.filtered_events<T, signal_event>(predicate);

                    if (filtered_events.size() > 0) {
                        for (auto const &pair : filtered_events) {
                            combined_time_range = *combined_time_range.combined(pair.first);
                        }

                        std::vector<T> vec(combined_time_range.length);
                        for (auto const &pair : filtered_events) {
                            auto const &time_range = pair.first;
                            auto const length = time_range.length;
                            auto const dst_idx = time_range.frame - combined_time_range.frame;
                            auto *dst_ptr = &vec[dst_idx];
                            signal_event_ptr const &signal = pair.second;
                            signal->copy_to<T>(dst_ptr, length);
                        }

                        channel.erase_event<T, signal_event>(std::move(predicate));

                        handler(current_time_range, stream.sync_source(), ch_idx, co_idx,
                                &vec[current_time_range.frame - combined_time_range.frame]);

                        channel.insert_event(time{combined_time_range},
                                             proc::signal_event::make_shared(std::move(vec)));

                        continue;
                    }
                }

                std::vector<T> vec(current_time_range.length);

                handler(current_time_range, stream.sync_source(), ch_idx, co_idx, vec.data());

                channel.insert_event(time{current_time_range}, signal_event::make_shared(std::move(vec)));
            }
        }
    };
}

template proc::processor_f proc::make_send_signal_processor(proc::send_signal_process_f<double>);
template proc::processor_f proc::make_send_signal_processor(proc::send_signal_process_f<float>);
template proc::processor_f proc::make_send_signal_processor(proc::send_signal_process_f<int64_t>);
template proc::processor_f proc::make_send_signal_processor(proc::send_signal_process_f<int32_t>);
template proc::processor_f proc::make_send_signal_processor(proc::send_signal_process_f<int16_t>);
template proc::processor_f proc::make_send_signal_processor(proc::send_signal_process_f<int8_t>);
template proc::processor_f proc::make_send_signal_processor(proc::send_signal_process_f<uint64_t>);
template proc::processor_f proc::make_send_signal_processor(proc::send_signal_process_f<uint32_t>);
template proc::processor_f proc::make_send_signal_processor(proc::send_signal_process_f<uint16_t>);
template proc::processor_f proc::make_send_signal_processor(proc::send_signal_process_f<uint8_t>);
template proc::processor_f proc::make_send_signal_processor(proc::send_signal_process_f<boolean>);
