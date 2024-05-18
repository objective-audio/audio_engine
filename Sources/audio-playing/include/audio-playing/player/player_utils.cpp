//
//  player_utils.cpp
//

#include "player_utils.h"

#include <audio-playing/common/math.h>
#include <cpp-utils/fast_each.h>

using namespace yas;
using namespace yas::playing;

std::optional<fragment_index_t> player_utils::top_fragment_idx(sample_rate_t const frag_length,
                                                               frame_index_t const frame) {
    if (frag_length > 0) {
        return math::floor_int(frame, frag_length) / frag_length;
    } else {
        return std::nullopt;
    }
}

uint32_t player_utils::process_length(frame_index_t const frame, frame_index_t const next_frame,
                                      uint32_t const frag_length) {
    return std::min(uint32_t(next_frame - frame), uint32_t(frag_length - math::mod_int(frame, frag_length)));
}

std::optional<fragment_index_t> player_utils::advancing_fragment_index(frame_index_t const frame,
                                                                       uint32_t const proc_length,
                                                                       uint32_t const frag_length) {
    if (math::mod_int(frame + proc_length, frag_length) == 0) {
        return math::floor_int(frame, frag_length) / frag_length;
    } else {
        return std::nullopt;
    }
}
