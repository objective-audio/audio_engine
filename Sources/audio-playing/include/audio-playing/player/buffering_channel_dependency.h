//
//  buffering_channel_dependency.h
//

#pragma once

#include <audio-engine/pcm_buffer/pcm_buffer.h>
#include <audio-playing/common/path.h>
#include <audio-playing/player/buffering_element_types.h>

namespace yas::playing {
struct buffering_element_for_buffering_channel {
    using state_t = audio_buffering_element_state;

    virtual ~buffering_element_for_buffering_channel() = default;

    [[nodiscard]] virtual state_t state() const = 0;
    [[nodiscard]] virtual fragment_index_t fragment_index_on_render() const = 0;

    [[nodiscard]] virtual bool write_if_needed_on_task(path::channel const &) = 0;
    virtual void force_write_on_task(path::channel const &, fragment_index_t const) = 0;

    [[nodiscard]] virtual bool contains_frame_on_render(frame_index_t const) = 0;
    [[nodiscard]] virtual bool read_into_buffer_on_render(audio::pcm_buffer *, frame_index_t const) = 0;
    virtual void advance_on_render(fragment_index_t const) = 0;
    virtual void overwrite_on_render() = 0;
};
}  // namespace yas::playing
