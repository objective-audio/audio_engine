//
//  yas_format.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include <AudioToolbox/AudioToolbox.h>
#include <memory>
#include <string>

namespace yas
{
    namespace audio
    {
        class format
        {
           public:
            format(std::nullptr_t n = nullptr);
            explicit format(const AudioStreamBasicDescription &asbd);
            explicit format(const CFDictionaryRef &settings);
            format(const Float64 sample_rate, const UInt32 channel_count,
                   const yas::pcm_format pcm_format = yas::pcm_format::float32, const bool interleaved = false);

            format(const format &) = default;
            format(format &&) = default;
            format &operator=(const format &) = default;
            format &operator=(format &&) = default;

            ~format() = default;

            bool operator==(const format &) const;
            bool operator!=(const format &) const;

            explicit operator bool() const;

            bool is_empty() const;
            bool is_standard() const;
            yas::pcm_format pcm_format() const;
            UInt32 channel_count() const;
            UInt32 buffer_count() const;
            UInt32 stride() const;
            Float64 sample_rate() const;
            bool is_interleaved() const;
            const AudioStreamBasicDescription &stream_description() const;
            UInt32 sample_byte_count() const;
            UInt32 buffer_frame_byte_count() const;
            CFStringRef description() const;

            static const format &null_format();

           private:
            class impl;
            std::shared_ptr<impl> _impl;
        };
    }

    std::string to_string(const yas::pcm_format &pcm_format);
    AudioStreamBasicDescription to_stream_description(const CFDictionaryRef &settings);
    AudioStreamBasicDescription to_stream_description(const Float64 sample_rate, const UInt32 channels,
                                                      const yas::pcm_format pcm_format, const bool interleaved);
    bool is_equal(const AudioStreamBasicDescription &asbd1, const AudioStreamBasicDescription &asbd2);
}
