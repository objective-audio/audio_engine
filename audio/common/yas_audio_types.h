//
//  yas_audio_types.h
//

#pragma once

#include <AudioUnit/AUComponent.h>

#include <functional>
#include <memory>
#include <optional>
#include <ostream>
#include <string>
#include <vector>

namespace yas::audio {
enum class pcm_format : uint32_t {
    other = 0,
    float32,
    float64,
    int16,
    fixed824,
};

enum class render_type : uint32_t {
    normal = 0,
    input,
    notify,
    unknown,
};

enum class direction {
    output = 0,
    input = 1,
};

enum class continuation {
    abort,
    keep,
};

using bus_result_t = std::optional<uint32_t>;
using abl_uptr = std::unique_ptr<AudioBufferList, std::function<void(AudioBufferList *)>>;
using abl_data_uptr = std::unique_ptr<std::vector<std::vector<uint8_t>>>;
using channel_map_t = std::vector<uint32_t>;
}  // namespace yas::audio

namespace yas {
uint32_t to_uint32(audio::direction const &);
std::string to_string(audio::pcm_format const &);
std::type_info const &to_sample_type(audio::pcm_format const &);
uint32_t to_bit_depth(audio::pcm_format const &);
std::string to_string(audio::direction const &);
std::string to_string(AudioUnitScope const scope);
std::string to_string(audio::render_type const &);
std::string to_string(OSStatus const err);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::audio::pcm_format const &);
std::ostream &operator<<(std::ostream &, yas::audio::direction const &);
std::ostream &operator<<(std::ostream &, yas::audio::render_type const &);
