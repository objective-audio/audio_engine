//
//  yas_audio_pcm_buffer.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_result.h"
#include "yas_audio_channel_route.h"
#include <memory>
#include <vector>

namespace yas
{
    class pcm_buffer;
    using pcm_buffer_ptr = std::shared_ptr<pcm_buffer>;
    using abl_unique_ptr = std::unique_ptr<AudioBufferList, std::function<void(AudioBufferList *)>>;
    using abl_data_unique_ptr = std::unique_ptr<std::vector<std::vector<UInt8>>>;

    class pcm_buffer
    {
       public:
        enum class copy_error_type {
            invalid_argument,
            invalid_format,
            invalid_pcm_format,
            out_of_range_frame_length,
            flexible_copy_failed,
        };

        using copy_result = result<std::nullptr_t, copy_error_type>;

        static pcm_buffer_ptr create(const audio_format_ptr &format, AudioBufferList *abl);
        static pcm_buffer_ptr create(const audio_format_ptr &format, const UInt32 frame_capacity);
        static pcm_buffer_ptr create(const audio_format_ptr &format, const pcm_buffer &data,
                                     const std::vector<channel_route_ptr> &channel_routes, const bool is_output);

        audio_format_ptr format() const;
        AudioBufferList *audio_buffer_list();
        const AudioBufferList *audio_buffer_list() const;

        flex_pointer audio_ptr_at_buffer(const UInt32 buffer) const;
        flex_pointer audio_ptr_at_channel(const UInt32 channel) const;

        template <typename T>
        T *audio_ptr_at_buffer(const UInt32 buffer) const;
        template <typename T>
        T *audio_ptr_at_channel(const UInt32 channel) const;

        const UInt32 frame_capacity() const;
        const UInt32 frame_length() const;
        void set_frame_length(const UInt32 length);

        void clear();
        void clear(const UInt32 start_frame, const UInt32 length);

       private:
        class impl;
        std::shared_ptr<impl> _impl;

        pcm_buffer(const audio_format_ptr &format, AudioBufferList *abl);
        pcm_buffer(const audio_format_ptr &format, const UInt32 frame_capacity);
        pcm_buffer(const audio_format_ptr &format, const pcm_buffer &data,
                   const std::vector<channel_route_ptr> channel_routes, const bool is_output);

        pcm_buffer(const pcm_buffer &) = delete;
        pcm_buffer(pcm_buffer &&) = delete;
        pcm_buffer &operator=(const pcm_buffer &) = delete;
        pcm_buffer &operator=(pcm_buffer &&) = delete;
    };

    void clear(AudioBufferList *abl);

    pcm_buffer::copy_result copy_data(const pcm_buffer_ptr &from_data, pcm_buffer_ptr &to_data);
    pcm_buffer::copy_result copy_data(const pcm_buffer_ptr &from_data, pcm_buffer_ptr &to_data,
                                      const UInt32 from_start_frame, const UInt32 to_start_frame, const UInt32 length);
    pcm_buffer::copy_result copy_data_flexibly(const AudioBufferList *&from_abl, AudioBufferList *&to_abl,
                                               const UInt32 sample_byte_count, UInt32 *out_frame_length);
    pcm_buffer::copy_result copy_data_flexibly(const pcm_buffer_ptr &from_data, pcm_buffer_ptr &to_data);
    pcm_buffer::copy_result copy_data_flexibly(const pcm_buffer_ptr &from_data, AudioBufferList *to_abl);
    pcm_buffer::copy_result copy_data_flexibly(const AudioBufferList *from_abl, pcm_buffer_ptr &to_data);

    UInt32 frame_length(const AudioBufferList *abl, const UInt32 sample_byte_count);

    std::pair<abl_unique_ptr, abl_data_unique_ptr> allocate_audio_buffer_list(const UInt32 buffer_count,
                                                                              const UInt32 channels, const UInt32 size);
}
