//
//  yas_audio_pcm_buffer.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_result.h"
#include "yas_audio_route.h"
#include "yas_flex_ptr.h"
#include <memory>
#include <vector>

namespace yas
{
    class audio_pcm_buffer
    {
       public:
        enum class copy_error_t {
            invalid_argument,
            invalid_abl,
            invalid_format,
            out_of_range,
            buffer_is_null,
        };

        using copy_result = result<UInt32, copy_error_t>;

        audio_pcm_buffer(std::nullptr_t n = nullptr);
        audio_pcm_buffer(const audio::format &format, AudioBufferList *abl);
        audio_pcm_buffer(const audio::format &format, const UInt32 frame_capacity);
        audio_pcm_buffer(const audio::format &format, const audio_pcm_buffer &from_buffer, const channel_map_t &channel_map);

        audio_pcm_buffer(const audio_pcm_buffer &) = default;
        audio_pcm_buffer(audio_pcm_buffer &&) = default;
        audio_pcm_buffer &operator=(const audio_pcm_buffer &) = default;
        audio_pcm_buffer &operator=(audio_pcm_buffer &&) = default;

        explicit operator bool() const;

        const audio::format &format() const;
        AudioBufferList *audio_buffer_list();
        const AudioBufferList *audio_buffer_list() const;

        flex_ptr flex_ptr_at_index(const UInt32 buf_idx) const;
        flex_ptr flex_ptr_at_channel(const UInt32 ch_idx) const;

        template <typename T>
        T *data_ptr_at_index(const UInt32 buf_idx);
        template <typename T>
        T *data_ptr_at_channel(const UInt32 ch_idx);
        template <typename T>
        const T *data_ptr_at_index(const UInt32 buf_idx) const;
        template <typename T>
        const T *data_ptr_at_channel(const UInt32 ch_idx) const;

        const UInt32 frame_capacity() const;
        const UInt32 frame_length() const;
        void set_frame_length(const UInt32 length);

        void reset();
        void clear();
        void clear(const UInt32 start_frame, const UInt32 length);

        audio_pcm_buffer::copy_result copy_from(const audio_pcm_buffer &from_buffer, const UInt32 from_start_frame = 0,
                                                const UInt32 to_start_frame = 0, const UInt32 length = 0);
        audio_pcm_buffer::copy_result copy_from(const AudioBufferList *from_abl, const UInt32 from_start_frame = 0,
                                                const UInt32 to_start_frame = 0, const UInt32 length = 0);
        audio_pcm_buffer::copy_result copy_to(AudioBufferList *to_abl, const UInt32 from_start_frame = 0,
                                              const UInt32 to_start_frame = 0, const UInt32 length = 0);

       private:
        class impl;
        std::shared_ptr<impl> _impl;
    };

    void clear(AudioBufferList *abl);

    audio_pcm_buffer::copy_result copy(const AudioBufferList *from_abl, AudioBufferList *to_abl,
                                       const UInt32 sample_byte_count, const UInt32 from_start_frame = 0,
                                       const UInt32 to_start_frame = 0, const UInt32 length = 0);

    UInt32 frame_length(const AudioBufferList *abl, const UInt32 sample_byte_count);

    std::pair<abl_uptr, abl_data_uptr> allocate_audio_buffer_list(const UInt32 buffer_count, const UInt32 channel_count,
                                                                  const UInt32 size = 0);
    bool is_equal_structure(const AudioBufferList &abl1, const AudioBufferList &abl2);

    std::string to_string(const audio_pcm_buffer::copy_error_t &error);
}
