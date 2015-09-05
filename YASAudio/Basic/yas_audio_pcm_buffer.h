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
    class audio_pcm_buffer
    {
       public:
        enum class copy_error_t {
            invalid_argument,
            invalid_abl,
            invalid_format,
            out_of_range,
        };

        using copy_result = result<UInt32, copy_error_t>;

        static audio_pcm_buffer_sptr create(const audio_format_sptr &format, AudioBufferList *abl);
        static audio_pcm_buffer_sptr create(const audio_format_sptr &format, const UInt32 frame_capacity);
        static audio_pcm_buffer_sptr create(const audio_format_sptr &format, const audio_pcm_buffer_sptr &buffer,
                                            const std::vector<channel_route_sptr> &channel_routes,
                                            const direction direction);

        audio_format_sptr format() const;
        AudioBufferList *audio_buffer_list();
        const AudioBufferList *audio_buffer_list() const;

        flex_pointer audio_ptr_at_index(const UInt32 buf_idx) const;
        flex_pointer audio_ptr_at_channel(const UInt32 ch_idx) const;

        template <typename T>
        T *audio_ptr_at_index(const UInt32 buf_idx) const;
        template <typename T>
        T *audio_ptr_at_channel(const UInt32 ch_idx) const;

        const UInt32 frame_capacity() const;
        const UInt32 frame_length() const;
        void set_frame_length(const UInt32 length);

        void reset();
        void clear();
        void clear(const UInt32 start_frame, const UInt32 length);

        audio_pcm_buffer::copy_result copy_from(const audio_pcm_buffer_sptr &from_buffer,
                                                const UInt32 from_start_frame = 0, const UInt32 to_start_frame = 0,
                                                const UInt32 length = 0);
        audio_pcm_buffer::copy_result copy_from(const AudioBufferList *from_abl, const UInt32 from_start_frame = 0,
                                                const UInt32 to_start_frame = 0, const UInt32 length = 0);
        audio_pcm_buffer::copy_result copy_to(AudioBufferList *to_abl, const UInt32 from_start_frame = 0,
                                              const UInt32 to_start_frame = 0, const UInt32 length = 0);

       private:
        class impl;
        std::shared_ptr<impl> _impl;

        audio_pcm_buffer(const audio_format_sptr &format, AudioBufferList *abl);
        audio_pcm_buffer(const audio_format_sptr &format, const UInt32 frame_capacity);
        audio_pcm_buffer(const audio_format_sptr &format, const audio_pcm_buffer &data,
                         const std::vector<channel_route_sptr> channel_routes, const direction direction);

        audio_pcm_buffer(const audio_pcm_buffer &) = delete;
        audio_pcm_buffer(audio_pcm_buffer &&) = delete;
        audio_pcm_buffer &operator=(const audio_pcm_buffer &) = delete;
        audio_pcm_buffer &operator=(audio_pcm_buffer &&) = delete;
    };

    void clear(AudioBufferList *abl);

    audio_pcm_buffer::copy_result copy(const AudioBufferList *from_abl, AudioBufferList *to_abl,
                                       const UInt32 sample_byte_count, const UInt32 from_start_frame = 0,
                                       const UInt32 to_start_frame = 0, const UInt32 length = 0);

    UInt32 frame_length(const AudioBufferList *abl, const UInt32 sample_byte_count);

    std::pair<abl_uptr, abl_data_uptr> allocate_audio_buffer_list(const UInt32 buffer_count, const UInt32 channel_count,
                                                                  const UInt32 size = 0);
    bool is_equal(const AudioBufferList &abl1, const AudioBufferList &abl2);
    bool is_equal_structure(const AudioBufferList &abl1, const AudioBufferList &abl2);

    std::string to_string(const audio_pcm_buffer::copy_error_t &error);
}
