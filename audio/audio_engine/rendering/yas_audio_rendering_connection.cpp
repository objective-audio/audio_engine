//
//  yas_audio_rendering_connection.cpp
//

#include "yas_audio_rendering_connection.h"

#include <audio/yas_audio_rendering_node.h>

using namespace yas;

void audio::rendering_connection::render(audio::pcm_buffer *const buffer, audio::time const &time) {
    this->input_node->render({.buffer = buffer,
                              .bus_idx = this->input_bus_idx,
                              .time = time,
                              .input_connections = this->input_node->input_connections});
}
