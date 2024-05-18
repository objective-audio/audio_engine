//
//  buffering_element.h
//

#pragma once

#include <audio-playing/common/ptr.h>
#include <audio-playing/player/buffering_channel_dependency.h>
#include <audio-playing/player/buffering_element_types.h>

namespace yas::playing {
struct buffering_element final : buffering_element_for_buffering_channel {
    [[nodiscard]] state_t state() const override;
    [[nodiscard]] frame_index_t begin_frame_on_render() const;
    [[nodiscard]] fragment_index_t fragment_index_on_render() const override;

    [[nodiscard]] bool write_if_needed_on_task(path::channel const &) override;
    void force_write_on_task(path::channel const &, fragment_index_t const) override;

    [[nodiscard]] bool contains_frame_on_render(frame_index_t const) override;
    [[nodiscard]] bool read_into_buffer_on_render(audio::pcm_buffer *, frame_index_t const) override;
    void advance_on_render(fragment_index_t const) override;
    void overwrite_on_render() override;

    [[nodiscard]] audio::pcm_buffer const &buffer_for_test() const;

    [[nodiscard]] static buffering_element_ptr make_shared(audio::format const &, sample_rate_t const frag_length);

   private:
    sample_rate_t const _frag_length;
    audio::pcm_buffer _buffer;

    std::atomic<state_t> _current_state{state_t::initial};
    fragment_index_t _frag_idx = 0;

    buffering_element(audio::format const &, sample_rate_t const frag_length);

    bool _write_on_task(path::channel const &ch_path);
};
}  // namespace yas::playing
