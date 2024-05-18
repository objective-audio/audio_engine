//
//  processor.h
//

#pragma once

#include <audio-processing/connector/connector.h>
#include <audio-processing/time/time.h>

#include <functional>

namespace yas::proc {
class stream;

using processor_f =
    std::function<void(time::range const &, connector_map_t const &inputs, connector_map_t const &outputs, stream &)>;
}  // namespace yas::proc
