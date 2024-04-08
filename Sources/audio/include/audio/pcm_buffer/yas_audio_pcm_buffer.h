//
//  yas_audio_pcm_buffer.h
//

#pragma once

#include <audio/common/yas_audio_ptr.h>
#include <audio/common/yas_audio_types.h>
#include <audio/format/yas_audio_format.h>
#include <cpp-utils/yas_result.h>

#include <ostream>

namespace yas {
template <typename T, typename U>
class result;
}

namespace yas::audio {
struct pcm_buffer final {
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
        out_of_range_channel,
    };

    using copy_result = result<uint32_t, copy_error_t>;

    pcm_buffer(audio::format const &format, AudioBufferList *abl);
    pcm_buffer(audio::format const &format, uint32_t const frame_capacity);
    pcm_buffer(audio::format const &format, pcm_buffer const &from_buffer, channel_map_t const &channel_map);

    pcm_buffer(pcm_buffer &&);

    [[nodiscard]] audio::format const &format() const;
    [[nodiscard]] AudioBufferList *audio_buffer_list();
    [[nodiscard]] AudioBufferList const *audio_buffer_list() const;

    template <typename T>
    [[nodiscard]] T *data_ptr_at_index(uint32_t const buf_idx);
    template <typename T>
    [[nodiscard]] T *data_ptr_at_channel(uint32_t const ch_idx);
    template <typename T>
    [[nodiscard]] T const *data_ptr_at_index(uint32_t const buf_idx) const;
    template <typename T>
    [[nodiscard]] T const *data_ptr_at_channel(uint32_t const ch_idx) const;

    [[nodiscard]] uint32_t frame_capacity() const;
    [[nodiscard]] uint32_t frame_length() const;
    void set_frame_length(uint32_t const length);

    void reset_buffer();
    void clear();
    void clear(uint32_t const begin_frame, uint32_t const length);

    bool is_empty() const;

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

   private:
    audio::format _format;
    AudioBufferList *_abl_ptr;
    uint32_t const _frame_capacity;
    uint32_t _frame_length;
    abl_uptr _abl;
    abl_data_uptr _data;

    pcm_buffer(audio::format const &format, std::pair<audio::abl_uptr, audio::abl_data_uptr> &&abl_pair,
               uint32_t const frame_capacity);
    pcm_buffer(audio::format const &format, audio::abl_uptr &&abl, audio::pcm_buffer const &from_buffer,
               channel_map_t const &channel_map);
    pcm_buffer(audio::format const &format, AudioBufferList *ptr, uint32_t const frame_capacity);
    pcm_buffer(audio::format const &format, abl_uptr &&abl, abl_data_uptr &&data, uint32_t const frame_capacity);
    pcm_buffer(audio::format const &format, abl_uptr &&abl, uint32_t const frame_capacity);

    pcm_buffer &operator=(pcm_buffer &&) = delete;
    pcm_buffer(pcm_buffer const &) = delete;
    pcm_buffer &operator=(pcm_buffer const &) = delete;

    template <typename T>
    T *_data_ptr_at_index(uint32_t const buf_idx) const;
    template <typename T>
    T *_data_ptr_at_channel(uint32_t const ch_idx) const;
};

static std::optional<pcm_buffer> const null_pcm_buffer_opt{std::nullopt};
static std::optional<pcm_buffer_ptr> const null_pcm_buffer_ptr_opt{std::nullopt};

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
