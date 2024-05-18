//
//  track_utils.h
//

#pragma once

#include <audio-processing/track/track_types.h>

namespace yas::proc {
[[nodiscard]] track_event_type to_track_event_type(observing::map::event_type const &);

[[nodiscard]] track_module_set_map_t copy_module_sets(track_module_set_map_t const &);
}  // namespace yas::proc
