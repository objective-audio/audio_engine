//
//  timeline_utils.cpp
//

#include "timeline_utils.h"

#include <audio-processing/track/track.h>

using namespace yas;
using namespace yas::proc;

timeline_event_type proc::to_timeline_event_type(observing::map::event_type const &type) {
    switch (type) {
        case observing::map::event_type::any:
            return timeline_event_type::any;
        case observing::map::event_type::inserted:
            return timeline_event_type::inserted;
        case observing::map::event_type::replaced:
            return timeline_event_type::replaced;
        case observing::map::event_type::erased:
            return timeline_event_type::erased;
    }
}

timeline_track_map_t proc::copy_tracks(timeline_track_map_t const &src_tracks) {
    std::map<track_index_t, proc::track_ptr> tracks;
    for (auto const &pair : src_tracks) {
        tracks.emplace(pair.first, pair.second->copy());
    }
    return tracks;
}

std::optional<proc::time::range> proc::total_range(std::map<track_index_t, track_ptr> const &tracks) {
    std::optional<proc::time::range> result{std::nullopt};

    for (auto &track_pair : tracks) {
        if (auto const &track_range = track_pair.second->total_range()) {
            if (result) {
                result = result->merged(*track_range);
            } else {
                result = track_range;
            }
        }
    }

    return result;
}
