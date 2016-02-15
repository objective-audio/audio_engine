//
//  yas_audio_pcm_buffer.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <memory>
#include <vector>
#include "yas_audio_route.h"
#include "yas_audio_types.h"
#include "yas_flex_ptr.h"
#include "yas_result.h"

namespace yas {
namespace audio {
    class pcm_buffer {
       public:
        enum class copy_error_t {
            invalid_argument,
            invalid_abl,
            invalid_format,
            out_of_range,
            buffer_is_null,
        };

        using copy_result = result<UInt32, copy_error_t>;

        pcm_buffer(std::nullptr_t n = nullptr);
        pcm_buffer(audio::format const &format, AudioBufferList *abl);
        pcm_buffer(audio::format const &format, UInt32 const frame_capacity);
        pcm_buffer(audio::format const &format, pcm_buffer const &from_buffer, const channel_map_t &channel_map);

        pcm_buffer(pcm_buffer const &) = default;
        pcm_buffer(pcm_buffer &&) = default;
        pcm_buffer &operator=(pcm_buffer const &) = default;
        pcm_buffer &operator=(pcm_buffer &&) = default;

        explicit operator bool() const;

        audio::format const &format() const;
        AudioBufferList *audio_buffer_list();
        const AudioBufferList *audio_buffer_list() const;

        flex_ptr flex_ptr_at_index(UInt32 const buf_idx) const;
        flex_ptr flex_ptr_at_channel(UInt32 const ch_idx) const;

        template <typename T>
        T *data_ptr_at_index(UInt32 const buf_idx);
        template <typename T>
        T *data_ptr_at_channel(UInt32 const ch_idx);
        template <typename T>
        const T *data_ptr_at_index(UInt32 const buf_idx) const;
        template <typename T>
        const T *data_ptr_at_channel(UInt32 const ch_idx) const;

        UInt32 frame_capacity() const;
        UInt32 frame_length() const;
        void set_frame_length(UInt32 const length);

        void reset();
        void clear();
        void clear(UInt32 const start_frame, UInt32 const length);

        pcm_buffer::copy_result copy_from(pcm_buffer const &from_buffer, UInt32 const from_start_frame = 0,
                                          UInt32 const to_start_frame = 0, UInt32 const length = 0);
        pcm_buffer::copy_result copy_from(const AudioBufferList *const from_abl, UInt32 const from_start_frame = 0,
                                          UInt32 const to_start_frame = 0, UInt32 const length = 0);
        pcm_buffer::copy_result copy_to(AudioBufferList *const to_abl, UInt32 const from_start_frame = 0,
                                        UInt32 const to_start_frame = 0, UInt32 const length = 0);

       private:
        class impl;
        std::shared_ptr<impl> _impl;
    };

    void clear(AudioBufferList *abl);

    pcm_buffer::copy_result copy(const AudioBufferList *const from_abl, AudioBufferList *const to_abl,
                                 UInt32 const sample_byte_count, UInt32 const from_start_frame = 0,
                                 UInt32 const to_start_frame = 0, UInt32 const length = 0);

    UInt32 frame_length(const AudioBufferList *const abl, UInt32 const sample_byte_count);

    std::pair<abl_uptr, abl_data_uptr> allocate_audio_buffer_list(UInt32 const buffer_count, UInt32 const channel_count,
                                                                  UInt32 const size = 0);
    bool is_equal_structure(AudioBufferList const &abl1, AudioBufferList const &abl2);
}

std::string to_string(audio::pcm_buffer::copy_error_t const &error);
}
