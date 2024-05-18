//
//  module_utils.cpp
//

#include "module_utils.h"

using namespace yas;
using namespace yas::proc;

template <>
audio::pcm_format proc::pcm_format<double>() {
    return audio::pcm_format::float64;
}
template <>
audio::pcm_format proc::pcm_format<float>() {
    return audio::pcm_format::float32;
}
template <>
audio::pcm_format proc::pcm_format<int32_t>() {
    return audio::pcm_format::fixed824;
}
template <>
audio::pcm_format proc::pcm_format<int16_t>() {
    return audio::pcm_format::int16;
}

frame_index_t proc::module_frame(frame_index_t const &time_frame, frame_index_t const offset) {
    return time_frame - offset;
}

std::optional<module_file_range_result> proc::module_file_range(time::range const &time_range,
                                                                frame_index_t const module_offset,
                                                                frame_index_t const file_offset,
                                                                frame_index_t const file_length) {
    if (file_offset < 0 || file_length <= file_offset || file_length == 0) {
        return std::nullopt;
    }

    time::range const module_range = time_range.offset(-module_offset + file_offset);
    time::range const file_range{file_offset, static_cast<length_t>(file_length - file_offset)};

    if (std::optional<time::range> result_range = module_range.intersected(file_range)) {
        frame_index_t const result_offset = result_range.value().frame - module_range.frame;
        return module_file_range_result{.range = result_range.value(), result_offset};
    } else {
        return std::nullopt;
    }
}
