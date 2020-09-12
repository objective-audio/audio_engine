//
//  yas_audio_rendering_node.h
//

#pragma once

#include <unordered_set>

namespace yas::audio {
struct rendering_node {};

using rendering_node_set = std::unordered_set<rendering_node>;
}  // namespace yas::audio
