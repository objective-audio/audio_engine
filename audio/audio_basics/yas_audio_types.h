//
//  yas_audio_types.h
//

#pragma once

#include <AudioUnit/AUComponent.h>
#include <memory>
#include <optional>
#include <ostream>
#include <string>
#include <vector>

namespace yas::audio {
union render_id {
    void *v;
    struct {
        uint8_t graph;
        uint16_t unit;
    };
};

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

struct render_parameters {
    render_type in_render_type;
    AudioUnitRenderActionFlags *io_action_flags;
    const AudioTimeStamp *io_time_stamp;
    uint32_t in_bus_number;
    uint32_t in_number_frames;
    AudioBufferList *io_data;
    render_id render_id;
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
std::string to_string(audio::direction const &);
std::string to_string(AudioUnitScope const scope);
std::string to_string(audio::render_type const &);
std::string to_string(OSStatus const err);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::audio::pcm_format const &);
std::ostream &operator<<(std::ostream &, yas::audio::direction const &);
std::ostream &operator<<(std::ostream &, yas::audio::render_type const &);
