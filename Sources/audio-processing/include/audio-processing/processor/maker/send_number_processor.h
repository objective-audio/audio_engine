//
//  send_number_processor.h
//

#pragma once

#include <audio-processing/common/common_types.h>
#include <audio-processing/event/number_event.h>
#include <audio-processing/processor/processor.h>
#include <audio-processing/sync_source/sync_source.h>
#include <audio-processing/time/time.h>

#include <functional>

namespace yas::proc {
template <typename T>
using send_number_process_f = std::function<number_event::value_map_t<T>(
    proc::time::range const &, sync_source const &, channel_index_t const, connector_index_t const)>;

template <typename T>
[[nodiscard]] processor_f make_send_number_processor(send_number_process_f<T>);
}  // namespace yas::proc
