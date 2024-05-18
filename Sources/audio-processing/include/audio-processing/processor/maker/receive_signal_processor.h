//
//  receive_signal_processor.h
//

#pragma once

#include <audio-processing/common/common_types.h>
#include <audio-processing/processor/processor.h>
#include <audio-processing/sync_source/sync_source.h>
#include <audio-processing/time/time.h>

#include <functional>

namespace yas::proc {
template <typename T>
using receive_signal_process_f = std::function<void(proc::time::range const &, sync_source const &,
                                                    channel_index_t const, connector_index_t const, T const *const)>;

template <typename T>
[[nodiscard]] processor_f make_receive_signal_processor(receive_signal_process_f<T>);
}  // namespace yas::proc
