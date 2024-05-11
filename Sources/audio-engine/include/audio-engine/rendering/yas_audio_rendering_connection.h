//
//  yas_audio_rendering_connection.h
//

#pragma once

#include <audio-engine/common/yas_audio_time.h>
#include <audio-engine/format/yas_audio_format.h>
#include <audio-engine/pcm_buffer/yas_audio_pcm_buffer.h>

namespace yas::audio {
class rendering_node;

struct rendering_connection {
    uint32_t const source_bus_idx;
    audio::format const format;
    rendering_node const *const source_node;

    rendering_connection(uint32_t const src_bus_idx, rendering_node const *const src_node, audio::format const format);

    bool render(audio::pcm_buffer *const, audio::time const &) const;
};
}  // namespace yas::audio
