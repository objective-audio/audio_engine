//
//  common_types.h
//

#pragma once

#include <cstdint>
#include <unordered_set>

namespace yas::proc {
using channel_index_t = int64_t;
using track_index_t = int64_t;
using frame_index_t = int64_t;
using module_index_t = std::size_t;
using length_t = uint64_t;
using sample_rate_t = uint32_t;

using connector_index_t = uint32_t;
using connector_index_set_t = std::unordered_set<connector_index_t>;

enum class continuation {
    abort,
    keep,
};
}  // namespace yas::proc
