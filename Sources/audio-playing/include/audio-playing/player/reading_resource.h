//
//  reading_resource.h
//

#pragma once

#include <audio-engine/format/format.h>
#include <audio-engine/pcm_buffer/pcm_buffer.h>
#include <audio-playing/common/ptr.h>
#include <audio-playing/player/player_resource_dependency.h>
#include <audio-playing/player/reading_resource_types.h>

namespace yas::playing {
struct reading_resource final : reading_resource_for_player_resource {
    [[nodiscard]] state_t state() const override;
    [[nodiscard]] audio::pcm_buffer *buffer_on_render() override;

    [[nodiscard]] bool needs_create_on_render(sample_rate_t const sample_rate, audio::pcm_format const,
                                              uint32_t const length) const override;
    void set_creating_on_render(sample_rate_t const sample_rate, audio::pcm_format const,
                                uint32_t const length) override;
    void create_buffer_on_task() override;

    static reading_resource_ptr make_shared();

   private:
    reading_resource();

    std::atomic<state_t> _current_state = state_t::initial;
    audio::pcm_buffer_ptr _buffer = nullptr;
    sample_rate_t _sample_rate = 0;
    audio::pcm_format _pcm_format = audio::pcm_format::float32;
    uint32_t _length = 0;
};
}  // namespace yas::playing
