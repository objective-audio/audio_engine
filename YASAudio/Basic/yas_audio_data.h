//
//  yas_audio_audio_data.h
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
    class audio_data;
    using audio_data_ptr = std::shared_ptr<audio_data>;
    using abl_unique_ptr = std::unique_ptr<AudioBufferList, std::function<void(AudioBufferList *)>>;
    using abl_data_unique_ptr = std::unique_ptr<std::vector<std::vector<UInt8>>>;

    class audio_data
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

        static audio_data_ptr create(const audio_format_ptr &format, AudioBufferList *abl);
        static audio_data_ptr create(const audio_format_ptr &format, const UInt32 frame_capacity);
        static audio_data_ptr create(const audio_format_ptr &format, const audio_data &data,
                                     const std::vector<channel_route_ptr> &channel_routes, const bool is_output);

        audio_format_ptr format() const;
        AudioBufferList *audio_buffer_list();
        const AudioBufferList *audio_buffer_list() const;

        audio_pointer audio_ptr_at_buffer(const UInt32 buffer) const;
        audio_pointer audio_ptr_at_channel(const UInt32 channel) const;

        const UInt32 frame_capacity() const;
        const UInt32 frame_length() const;
        void set_frame_length(const UInt32 length);

        void clear();
        void clear(const UInt32 start_frame, const UInt32 length);

       private:
        class impl;
        std::shared_ptr<impl> _impl;

        audio_data(const audio_format_ptr &format, AudioBufferList *abl);
        audio_data(const audio_format_ptr &format, const UInt32 frame_capacity);
        audio_data(const audio_format_ptr &format, const audio_data &data,
                   const std::vector<channel_route_ptr> channel_routes, const bool is_output);

        audio_data(const audio_data &) = delete;
        audio_data(audio_data &&) = delete;
        audio_data &operator=(const audio_data &) = delete;
        audio_data &operator=(audio_data &&) = delete;
    };

    void clear(AudioBufferList *abl);

    audio_data::copy_result copy_data(const audio_data_ptr &from_data, audio_data_ptr &to_data);
    audio_data::copy_result copy_data(const audio_data_ptr &from_data, audio_data_ptr &to_data,
                                      const UInt32 from_start_frame, const UInt32 to_start_frame, const UInt32 length);
    audio_data::copy_result copy_data_flexibly(const AudioBufferList *&from_abl, AudioBufferList *&to_abl,
                                               const UInt32 sample_byte_count, UInt32 *out_frame_length);
    audio_data::copy_result copy_data_flexibly(const audio_data_ptr &from_data, audio_data_ptr &to_data);
    audio_data::copy_result copy_data_flexibly(const audio_data_ptr &from_data, AudioBufferList *to_abl);
    audio_data::copy_result copy_data_flexibly(const AudioBufferList *from_abl, audio_data_ptr &to_data);

    UInt32 frame_length(const AudioBufferList *abl, const UInt32 sample_byte_count);

    std::pair<abl_unique_ptr, abl_data_unique_ptr> allocate_audio_buffer_list(const UInt32 buffer_count,
                                                                              const UInt32 channels, const UInt32 size);
}
