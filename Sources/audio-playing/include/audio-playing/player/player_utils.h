//
//  player_utils.h
//

#pragma once

#include <audio-engine/format/format.h>
#include <audio-playing/common/types.h>

namespace yas::playing::player_utils {
std::optional<fragment_index_t> top_fragment_idx(sample_rate_t const frag_length, frame_index_t const);

uint32_t process_length(frame_index_t const frame, frame_index_t const next_frame, uint32_t const frag_length);
std::optional<fragment_index_t> advancing_fragment_index(frame_index_t const frame, uint32_t const proc_length,
                                                         uint32_t const frag_length);
}  // namespace yas::playing::player_utils
