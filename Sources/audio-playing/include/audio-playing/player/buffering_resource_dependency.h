//
//  buffering_resource_dependency.h
//

#pragma once

#include <audio-engine/pcm_buffer/pcm_buffer.h>
#include <audio-playing/common/path.h>

namespace yas::playing {
struct buffering_channel_for_buffering_resource {
    virtual ~buffering_channel_for_buffering_resource() = default;

    virtual void write_all_elements_on_task(path::channel const &, fragment_index_t const top_frag_idx) = 0;
    [[nodiscard]] virtual bool write_elements_if_needed_on_task() = 0;

    virtual void advance_on_render(fragment_index_t const prev_frag_idx) = 0;
    virtual void overwrite_element_on_render(fragment_range const) = 0;
    [[nodiscard]] virtual bool read_into_buffer_on_render(audio::pcm_buffer *, frame_index_t const) = 0;
};
}  // namespace yas::playing
