//
//  timeline_module.h
//

#pragma once

#include <audio-processing/common/common_types.h>
#include <audio-processing/common/ptr.h>

namespace yas::proc {
[[nodiscard]] module_ptr make_module(timeline_ptr const &, frame_index_t const offset = 0);
}  // namespace yas::proc
