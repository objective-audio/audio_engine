//
//  track_types.h
//

#pragma once

#include <audio-processing/common/ptr.h>
#include <audio-processing/module_set/module_set_types.h>
#include <audio-processing/time/time.h>

#include <observing/umbrella.hpp>

namespace yas::proc {
using track_module_set_map_t = std::map<time::range, module_set_ptr>;

enum class track_event_type {
    any,
    replaced,
    inserted,
    erased,

    relayed,
};

struct track_event {
    track_event_type type;
    track_module_set_map_t const &module_sets;
    module_set_ptr const *inserted = nullptr;
    module_set_ptr const *erased = nullptr;
    module_set_ptr const *relayed = nullptr;
    std::optional<time::range> range = std::nullopt;
    module_set_event const *module_set_event = nullptr;
};
}  // namespace yas::proc
