//
//  send_signal_processor.h
//

#pragma once

#include <audio-processing/common/common_types.h>
#include <audio-processing/processor/processor.h>
#include <audio-processing/time/time.h>

#include <functional>
#include <string>

namespace yas::proc {
class sync_source;

template <typename T>
using send_signal_process_f = std::function<void(proc::time::range const &, sync_source const &, channel_index_t const,
                                                 connector_index_t const, T *const)>;

template <typename T>
[[nodiscard]] processor_f make_send_signal_processor(send_signal_process_f<T>);
}  // namespace yas::proc
