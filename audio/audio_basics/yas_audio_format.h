//
//  yas_format.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>

#include <string>

#include "yas_audio_types.h"

namespace yas::audio {
struct format final {
    struct args {
        double sample_rate;
        uint32_t channel_count;
        audio::pcm_format pcm_format = audio::pcm_format::float32;
        bool interleaved = false;
    };

    explicit format(AudioStreamBasicDescription asbd);
    explicit format(CFDictionaryRef const &settings);
    explicit format(args args);

    bool is_empty() const;
    bool is_broken() const;
    bool is_standard() const;
    audio::pcm_format pcm_format() const;
    uint32_t channel_count() const;
    uint32_t buffer_count() const;
    uint32_t stride() const;
    double sample_rate() const;
    bool is_interleaved() const;
    AudioStreamBasicDescription const &stream_description() const;
    uint32_t sample_byte_count() const;
    uint32_t buffer_frame_byte_count() const;
    CFStringRef description() const;

    bool operator==(format const &) const;
    bool operator!=(format const &) const;

   private:
    AudioStreamBasicDescription _asbd = {0};
    audio::pcm_format _pcm_format = audio::pcm_format::other;
    bool _standard = false;
};
}  // namespace yas::audio

namespace yas {
AudioStreamBasicDescription to_stream_description(CFDictionaryRef const &settings);
AudioStreamBasicDescription to_stream_description(double const sample_rate, uint32_t const channels,
                                                  audio::pcm_format const pcm_format, bool const interleaved);
bool is_equal(AudioStreamBasicDescription const &asbd1, AudioStreamBasicDescription const &asbd2);

std::string to_string(audio::format const &);
}  // namespace yas
