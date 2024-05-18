//
//  remove_processor.cpp
//

#include "remove_number_processor.h"

#include <cpp-utils/boolean.h>
#include <cpp-utils/stl_utils.h>
#include <audio-processing/channel/channel.h>
#include <audio-processing/event/number_event.h>
#include <audio-processing/stream/stream.h>

using namespace yas;
using namespace yas::proc;

template <typename T>
proc::processor_f proc::make_remove_number_processor(connector_index_set_t keys) {
    return [keys = std::move(keys)](time::range const &time_range, connector_map_t const &input_connectors,
                                    connector_map_t const &, stream &stream) {
        for (auto const &connector_pair : input_connectors) {
            if (keys.count(connector_pair.first) == 0) {
                continue;
            }

            auto const &connector = connector_pair.second;
            auto const &ch_idx = connector.channel_index;

            if (stream.has_channel(ch_idx)) {
                auto &channel = stream.channel(ch_idx);

                auto predicate = [&time_range](std::pair<time, event> const &pair) {
                    time const &time = pair.first;
                    if (time.type() == typeid(time::frame)) {
                        auto const &frame = time.get<time::frame>();
                        if (time_range.is_contain(frame)) {
                            if (auto const number = pair.second.get<number_event>()) {
                                return number->sample_type() == typeid(T);
                            }
                        }
                    }
                    return false;
                };

                channel.erase_event_if(predicate);
            }
        }
    };
}

template proc::processor_f proc::make_remove_number_processor<double>(connector_index_set_t);
template proc::processor_f proc::make_remove_number_processor<float>(connector_index_set_t);
template proc::processor_f proc::make_remove_number_processor<int64_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_number_processor<int32_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_number_processor<int16_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_number_processor<int8_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_number_processor<uint64_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_number_processor<uint32_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_number_processor<uint16_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_number_processor<uint8_t>(connector_index_set_t);
template proc::processor_f proc::make_remove_number_processor<boolean>(connector_index_set_t);
