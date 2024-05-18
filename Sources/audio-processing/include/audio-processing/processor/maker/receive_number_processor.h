//
//  receive_number_processor.h
//

#pragma once

#include <audio-processing/common/common_types.h>
#include <audio-processing/processor/processor.h>
#include <audio-processing/time/time.h>

#include <functional>

namespace yas::proc {
template <typename T>
using receive_number_process_f =
    std::function<void(proc::time::frame::type const &, channel_index_t const, connector_index_t const, T const &)>;

template <typename T>
[[nodiscard]] processor_f make_receive_number_processor(receive_number_process_f<T>);
}  // namespace yas::proc
