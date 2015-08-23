//
//  yas_audio_format.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include <AudioToolbox/AudioToolbox.h>
#include <memory>
#include <string>

namespace yas
{
    class audio_format;

    using audio_format_ptr = std::shared_ptr<audio_format>;

    class audio_format
    {
       public:
        static audio_format_ptr create(const AudioStreamBasicDescription &asbd);
        static audio_format_ptr create(const CFDictionaryRef &settings);
        static audio_format_ptr create(const Float64 sample_rate, const UInt32 channel_count,
                                       const yas::pcm_format pcm_format = yas::pcm_format::float32,
                                       const bool interleaved = false);
        ~audio_format();

        bool operator==(const audio_format &) const;
        bool operator!=(const audio_format &) const;

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
        std::string description() const;

       private:
        class impl;
        std::shared_ptr<impl> _impl;

        explicit audio_format(const AudioStreamBasicDescription &asbd);
        explicit audio_format(const CFDictionaryRef &settings);
        audio_format(const Float64 sample_rate, const UInt32 channel_count, const yas::pcm_format pcm_format,
                     const bool interleaved);

        audio_format(const audio_format &) = delete;
        audio_format(const audio_format &&) = delete;
        audio_format &operator=(const audio_format &) = delete;
        audio_format &operator=(const audio_format &&) = delete;
    };

    std::string to_string(const yas::pcm_format &pcm_format);
    AudioStreamBasicDescription to_stream_description(const CFDictionaryRef &settings);
    AudioStreamBasicDescription to_stream_description(const Float64 sample_rate, const UInt32 channels,
                                                      const yas::pcm_format pcm_format, const bool interleaved);
    bool is_equal(const AudioStreamBasicDescription &asbd1, const AudioStreamBasicDescription &asbd2);
    std::string file_type_string(OSType fcc);
}
