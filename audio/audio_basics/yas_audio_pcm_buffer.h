//
//  yas_audio_pcm_buffer.h
//

#pragma once

#include "yas_audio_types.h"
#include "yas_base.h"

namespace yas {
template <typename T, typename U>
class result;
}

namespace yas::audio {
class format;

class pcm_buffer : public base {
    class impl;

   public:
    struct copy_options {
        uint32_t const from_begin_frame = 0;
        uint32_t const to_begin_frame = 0;
        uint32_t const length = 0;
    };

    struct copy_channel_options {
        uint32_t const from_begin_frame = 0;
        uint32_t const from_channel = 0;
        uint32_t const to_begin_frame = 0;
        uint32_t const to_channel = 0;
        uint32_t const length = 0;
    };

    enum class copy_error_t {
        invalid_argument,
        invalid_abl,
        invalid_format,
        out_of_range_frame,
        buffer_is_null,
        out_of_range_channel,
    };

    using copy_result = result<uint32_t, copy_error_t>;

    pcm_buffer(audio::format const &format, AudioBufferList *abl);
    pcm_buffer(audio::format const &format, uint32_t const frame_capacity);
    pcm_buffer(audio::format const &format, pcm_buffer const &from_buffer, channel_map_t const &channel_map);
    pcm_buffer(std::nullptr_t);

    virtual ~pcm_buffer() final;

    audio::format const &format() const;
    AudioBufferList *audio_buffer_list();
    AudioBufferList const *audio_buffer_list() const;

    template <typename T>
    T *data_ptr_at_index(uint32_t const buf_idx);
    template <typename T>
    T *data_ptr_at_channel(uint32_t const ch_idx);
    template <typename T>
    T const *data_ptr_at_index(uint32_t const buf_idx) const;
    template <typename T>
    T const *data_ptr_at_channel(uint32_t const ch_idx) const;

    uint32_t frame_capacity() const;
    uint32_t frame_length() const;
    void set_frame_length(uint32_t const length);

    void reset();
    void clear();
    void clear(uint32_t const begin_frame, uint32_t const length);

    pcm_buffer::copy_result copy_from(pcm_buffer const &);
    pcm_buffer::copy_result copy_from(pcm_buffer const &, copy_options);
    pcm_buffer::copy_result copy_channel_from(pcm_buffer const &);
    pcm_buffer::copy_result copy_channel_from(pcm_buffer const &, copy_channel_options);
    pcm_buffer::copy_result copy_from(AudioBufferList const *const from_abl, uint32_t const from_begin_frame = 0,
                                      uint32_t const to_begin_frame = 0, uint32_t const length = 0);
    pcm_buffer::copy_result copy_to(AudioBufferList *const to_abl, uint32_t const from_begin_frame = 0,
                                    uint32_t const to_begin_frame = 0, uint32_t const length = 0) const;

    template <typename T>
    pcm_buffer::copy_result copy_from(T const *const from_ptr, uint32_t const from_stride,
                                      uint32_t const from_begin_frame, uint32_t const to_ch_idx,
                                      uint32_t const to_begin_frame, uint32_t const copy_length);
    template <typename T>
    pcm_buffer::copy_result copy_to(T *const to_ptr, uint32_t const to_stride, uint32_t const to_begin_frame,
                                    uint32_t const from_ch_idx, uint32_t const from_begin_frame,
                                    uint32_t const copy_length) const;
};

void clear(AudioBufferList *abl);

void copy(void const *const from_ptr, uint32_t const from_stride, void *const to_ptr, uint32_t const to_stride,
          uint32_t const length, uint32_t const sample_byte_count);

pcm_buffer::copy_result copy(AudioBufferList const *const from_abl, AudioBufferList *const to_abl,
                             uint32_t const sample_byte_count, uint32_t const from_begin_frame = 0,
                             uint32_t const to_begin_frame = 0, uint32_t const length = 0);

uint32_t frame_length(AudioBufferList const *const abl, uint32_t const sample_byte_count);

std::pair<abl_uptr, abl_data_uptr> allocate_audio_buffer_list(uint32_t const buffer_count, uint32_t const channel_count,
                                                              uint32_t const size = 0);
bool is_equal_structure(AudioBufferList const &abl1, AudioBufferList const &abl2);
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::pcm_buffer::copy_error_t const &error);
}

std::ostream &operator<<(std::ostream &, yas::audio::pcm_buffer::copy_error_t const &);
