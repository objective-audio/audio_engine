//
//  channel_mapping.h
//

#pragma once

#include <audio-playing/common/ptr.h>
#include <audio-playing/common/types.h>

#include <vector>

namespace yas::playing {
struct channel_mapping final {
    std::vector<channel_index_t> indices;

    std::optional<channel_index_t> file_index(channel_index_t const out_idx, std::size_t const ch_count) const;
    std::optional<channel_index_t> out_index(channel_index_t const file_idx, std::size_t const ch_count) const;

    bool operator==(channel_mapping const &rhs) const;
    bool operator!=(channel_mapping const &rhs) const;
};
};  // namespace yas::playing
