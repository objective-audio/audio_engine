//
//  remove_number_processor.h
//

#pragma once

#include <audio-processing/processor/processor.h>

namespace yas::proc {
template <typename T>
[[nodiscard]] processor_f make_remove_number_processor(connector_index_set_t);
}
