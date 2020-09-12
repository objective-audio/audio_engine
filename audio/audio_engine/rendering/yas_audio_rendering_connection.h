//
//  yas_audio_rendering_connection.h
//

#pragma once

#include <unordered_set>

namespace yas::audio {
struct rendering_connection {};

using rendering_connection_set = std::unordered_set<rendering_connection>;
}  // namespace yas::audio
