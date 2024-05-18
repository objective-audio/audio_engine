//
//  timeline_utils.h
//

#pragma once

#include <audio-processing/time/time.h>

#include <observing/umbrella.hpp>

#include "timeline_types.h"

namespace yas::proc {
[[nodiscard]] timeline_event_type to_timeline_event_type(observing::map::event_type const &);

[[nodiscard]] timeline_track_map_t copy_tracks(timeline_track_map_t const &);

[[nodiscard]] std::optional<time::range> total_range(std::map<track_index_t, track_ptr> const &);
}  // namespace yas::proc
