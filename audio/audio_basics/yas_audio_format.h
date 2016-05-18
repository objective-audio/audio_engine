//
//  yas_format.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <memory>
#include <string>
#include "yas_audio_types.h"
#include "yas_base.h"

namespace yas {
namespace audio {
    class format : public base {
        class impl;

       public:
        struct args {
            double sample_rate;
            uint32_t channel_count;
            audio::pcm_format pcm_format = audio::pcm_format::float32;
            bool interleaved = false;
        };

        explicit format(AudioStreamBasicDescription asbd);
        explicit format(CFDictionaryRef const &settings);
        format(args args);
        format(std::nullptr_t);

        bool is_empty() const;
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

        static format const &null_format();
    };
}

std::string to_string(audio::pcm_format const &pcm_format);
AudioStreamBasicDescription to_stream_description(CFDictionaryRef const &settings);
AudioStreamBasicDescription to_stream_description(double const sample_rate, uint32_t const channels,
                                                  audio::pcm_format const pcm_format, bool const interleaved);
bool is_equal(AudioStreamBasicDescription const &asbd1, AudioStreamBasicDescription const &asbd2);
}
