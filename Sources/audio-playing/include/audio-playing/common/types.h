//
//  types.h
//

#pragma once

#include <audio-processing/common/common_types.h>

namespace yas::playing {
using channel_index_t = proc::channel_index_t;
using fragment_index_t = int64_t;
using track_index_t = proc::track_index_t;
using frame_index_t = proc::frame_index_t;
using module_index_t = proc::module_index_t;
using length_t = proc::length_t;
using sample_rate_t = proc::sample_rate_t;

struct fragment_range {
    fragment_index_t index;
    length_t length;

    fragment_index_t end_index() const {
        return this->index + static_cast<fragment_index_t>(this->length);
    }

    bool contains(fragment_index_t const idx) const {
        return this->index <= idx && idx < this->end_index();
    }

    bool operator==(fragment_range const &rhs) const {
        return this->index == rhs.index && this->length == rhs.length;
    }

    bool operator!=(fragment_range const &rhs) const {
        return !(*this == rhs);
    }
};

struct element_address {
    std::optional<channel_index_t> file_channel_index;  // nulloptは全ch
    fragment_range fragment_range;

    bool operator==(element_address const &rhs) const {
        return this->file_channel_index == rhs.file_channel_index && this->fragment_range == rhs.fragment_range;
    }

    bool operator!=(element_address const &rhs) const {
        return !(*this == rhs);
    }
};

enum class sample_store_type : char {
    unknown = 0,
    float64 = 1,
    float32 = 2,
    int64 = 3,
    uint64 = 4,
    int32 = 5,
    uint32 = 6,
    int16 = 7,
    uint16 = 8,
    int8 = 9,
    uint8 = 10,
    boolean = 11,
};
}  // namespace yas::playing
