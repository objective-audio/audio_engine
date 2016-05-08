//
//  yas_audio_pcm_buffer.cpp
//

#include <Accelerate/Accelerate.h>
#include <exception>
#include <functional>
#include <iostream>
#include <string>
#include "yas_audio_format.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_stl_utils.h"

using namespace yas;

#pragma mark - private

struct audio::pcm_buffer::impl {
    audio::format const format;
    const AudioBufferList *abl_ptr;
    UInt32 const frame_capacity;
    UInt32 frame_length;

    impl(audio::format const &format, AudioBufferList *ptr, UInt32 const frame_capacity)
        : format(format),
          abl_ptr(ptr),
          frame_capacity(frame_capacity),
          frame_length(frame_capacity),
          _abl(nullptr),
          _data(nullptr) {
    }

    impl(audio::format const &format, abl_uptr &&abl, abl_data_uptr &&data, UInt32 const frame_capacity)
        : format(format),
          frame_capacity(frame_capacity),
          frame_length(frame_capacity),
          abl_ptr(abl.get()),
          _abl(std::move(abl)),
          _data(std::move(data)) {
    }

    impl(audio::format const &format, abl_uptr &&abl, UInt32 const frame_capacity)
        : format(format),
          frame_capacity(frame_capacity),
          frame_length(frame_capacity),
          abl_ptr(abl.get()),
          _abl(std::move(abl)),
          _data(nullptr) {
    }

    flex_ptr flex_ptr_at_index(UInt32 const buf_idx) {
        if (buf_idx >= abl_ptr->mNumberBuffers) {
            throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. buf_idx(" +
                                    std::to_string(buf_idx) + ") _impl->abl_ptr.mNumberBuffers(" +
                                    std::to_string(abl_ptr->mNumberBuffers) + ")");
        }

        return flex_ptr(abl_ptr->mBuffers[buf_idx].mData);
    }

    flex_ptr flex_ptr_at_channel(UInt32 const ch_idx) {
        flex_ptr pointer;

        if (format.stride() > 1) {
            if (ch_idx < abl_ptr->mBuffers[0].mNumberChannels) {
                pointer.v = abl_ptr->mBuffers[0].mData;
                if (ch_idx > 0) {
                    pointer.u8 += ch_idx * format.sample_byte_count();
                }
            } else {
                throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. ch_idx(" +
                                        std::to_string(ch_idx) + ") mNumberChannels(" +
                                        std::to_string(abl_ptr->mBuffers[0].mNumberChannels) + ")");
            }
        } else {
            if (ch_idx < abl_ptr->mNumberBuffers) {
                pointer.v = abl_ptr->mBuffers[ch_idx].mData;
            } else {
                throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. ch_idx(" +
                                        std::to_string(ch_idx) + ") mNumberChannels(" +
                                        std::to_string(abl_ptr->mBuffers[0].mNumberChannels) + ")");
            }
        }

        return pointer;
    }

    static std::vector<UInt8> &dummy_data() {
        static std::vector<UInt8> _dummy_data(4096 * 4);
        return _dummy_data;
    }

   private:
    abl_uptr const _abl;
    abl_data_uptr const _data;
};

std::pair<audio::abl_uptr, audio::abl_data_uptr> audio::allocate_audio_buffer_list(UInt32 const buffer_count,
                                                                                   UInt32 const channel_count,
                                                                                   UInt32 const size) {
    abl_uptr abl_ptr((AudioBufferList *)calloc(1, sizeof(AudioBufferList) + buffer_count * sizeof(AudioBuffer)),
                     [](AudioBufferList *abl) { free(abl); });

    abl_ptr->mNumberBuffers = buffer_count;
    auto data_ptr = std::make_unique<std::vector<std::vector<UInt8>>>();
    if (size > 0) {
        data_ptr->reserve(buffer_count);
    } else {
        data_ptr = nullptr;
    }

    for (UInt32 i = 0; i < buffer_count; ++i) {
        abl_ptr->mBuffers[i].mNumberChannels = channel_count;
        abl_ptr->mBuffers[i].mDataByteSize = size;
        if (size > 0) {
            data_ptr->push_back(std::vector<UInt8>(size));
            abl_ptr->mBuffers[i].mData = data_ptr->at(i).data();
        } else {
            abl_ptr->mBuffers[i].mData = nullptr;
        }
    }

    return std::make_pair(std::move(abl_ptr), std::move(data_ptr));
}

static void set_data_byte_size(audio::pcm_buffer &data, UInt32 const data_byte_size) {
    AudioBufferList *abl = data.audio_buffer_list();
    for (UInt32 i = 0; i < abl->mNumberBuffers; i++) {
        abl->mBuffers[i].mDataByteSize = data_byte_size;
    }
}

static void reset_data_byte_size(audio::pcm_buffer &data) {
    UInt32 const data_byte_size =
        (UInt32 const)(data.frame_capacity() * data.format().stream_description().mBytesPerFrame);
    set_data_byte_size(data, data_byte_size);
}

template <typename T>
static bool validate_pcm_format(audio::pcm_format const &pcm_format) {
    switch (pcm_format) {
        case audio::pcm_format::float32:
            return typeid(T) == typeid(Float32);
        case audio::pcm_format::float64:
            return typeid(T) == typeid(Float64);
        case audio::pcm_format::fixed824:
            return typeid(T) == typeid(SInt32);
        case audio::pcm_format::int16:
            return typeid(T) == typeid(SInt16);
        default:
            return false;
    }
}

namespace yas {
namespace audio {
    struct abl_info {
        UInt32 channel_count;
        UInt32 frame_length;
        std::vector<UInt8 *> datas;
        std::vector<UInt32> strides;

        abl_info() : channel_count(0), frame_length(0), datas(0), strides(0) {
        }
    };

    using get_abl_info_result_t = result<abl_info, pcm_buffer::copy_error_t>;

    static get_abl_info_result_t get_abl_info(const AudioBufferList *abl, UInt32 const sample_byte_count) {
        if (!abl || sample_byte_count == 0 || sample_byte_count > 8) {
            return get_abl_info_result_t(pcm_buffer::copy_error_t::invalid_argument);
        }

        UInt32 const buffer_count = abl->mNumberBuffers;

        audio::abl_info data_info;

        for (UInt32 buf_idx = 0; buf_idx < buffer_count; ++buf_idx) {
            UInt32 const stride = abl->mBuffers[buf_idx].mNumberChannels;
            UInt32 const frame_length = abl->mBuffers[buf_idx].mDataByteSize / stride / sample_byte_count;
            if (data_info.frame_length == 0) {
                data_info.frame_length = frame_length;
            } else if (data_info.frame_length != frame_length) {
                return get_abl_info_result_t(pcm_buffer::copy_error_t::invalid_abl);
            }
            data_info.channel_count += stride;
        }

        if (data_info.channel_count > 0) {
            for (UInt32 buf_idx = 0; buf_idx < buffer_count; buf_idx++) {
                UInt32 const stride = abl->mBuffers[buf_idx].mNumberChannels;
                UInt8 *data = static_cast<UInt8 *>(abl->mBuffers[buf_idx].mData);
                for (UInt32 ch_idx = 0; ch_idx < stride; ++ch_idx) {
                    data_info.datas.push_back(&data[ch_idx * sample_byte_count]);
                    data_info.strides.push_back(stride);
                }
            }
        }

        return get_abl_info_result_t(std::move(data_info));
    }
}
}

#pragma mark - public

audio::pcm_buffer::pcm_buffer(std::nullptr_t) : _impl(nullptr) {
}

audio::pcm_buffer::pcm_buffer(audio::format const &format, AudioBufferList *abl) {
    if (!format || !abl) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    _impl = std::make_shared<impl>(format, abl,
                                   abl->mBuffers[0].mDataByteSize / format.stream_description().mBytesPerFrame);
}

audio::pcm_buffer::pcm_buffer(audio::format const &format, UInt32 const frame_capacity) {
    if (frame_capacity == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    auto pair = allocate_audio_buffer_list(format.buffer_count(), format.stride(),
                                           frame_capacity * format.stream_description().mBytesPerFrame);
    _impl = std::make_shared<impl>(format, std::move(pair.first), std::move(pair.second), frame_capacity);
}

audio::pcm_buffer::pcm_buffer(audio::format const &format, audio::pcm_buffer const &from_buffer,
                              channel_map_t const &channel_map) {
    auto const &from_format = from_buffer.format();

    if (channel_map.size() != format.channel_count() || format.is_interleaved() || from_format.is_interleaved() ||
        format.pcm_format() != from_format.pcm_format()) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid format.");
    }

    auto pair = allocate_audio_buffer_list(format.buffer_count(), format.stride(), 0);
    abl_uptr &to_abl = pair.first;

    const AudioBufferList *const from_abl = from_buffer.audio_buffer_list();
    UInt32 bytesPerFrame = format.stream_description().mBytesPerFrame;
    UInt32 const frame_length = from_buffer.frame_length();
    UInt32 to_ch_idx = 0;
    abl_data_uptr data = nullptr;

    for (auto const &from_ch_idx : channel_map) {
        if (from_ch_idx != -1) {
            to_abl->mBuffers[to_ch_idx].mData = from_abl->mBuffers[from_ch_idx].mData;
            to_abl->mBuffers[to_ch_idx].mDataByteSize = from_abl->mBuffers[from_ch_idx].mDataByteSize;
            UInt32 actual_frame_length = from_abl->mBuffers[0].mDataByteSize / bytesPerFrame;
            if (frame_length != actual_frame_length) {
                throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) +
                                            " : invalid frame length. frame_length(" + std::to_string(frame_length) +
                                            ") actual_frame_length(" + std::to_string(actual_frame_length) + ")");
            }
        } else {
            if (to_abl->mBuffers[to_ch_idx].mData == nullptr) {
                UInt32 const size = bytesPerFrame * frame_length;
                auto dummy_data = pcm_buffer::impl::dummy_data();
                if (size <= dummy_data.size()) {
                    to_abl->mBuffers[to_ch_idx].mData = dummy_data.data();
                    to_abl->mBuffers[to_ch_idx].mDataByteSize = size;
                } else {
                    throw std::overflow_error(std::string(__PRETTY_FUNCTION__) + " : buffer size is overflow(" +
                                              std::to_string(size) + ")");
                }
            }
        }
        ++to_ch_idx;
    }

    _impl = std::make_shared<impl>(format, std::move(to_abl), std::move(data), frame_length);
}

audio::pcm_buffer::operator bool() const {
    return _impl != nullptr;
}

audio::format const &audio::pcm_buffer::format() const {
    if (_impl) {
        return _impl->format;
    }
    return format::null_format();
}

AudioBufferList *audio::pcm_buffer::audio_buffer_list() {
    if (_impl) {
        return const_cast<AudioBufferList *>(_impl->abl_ptr);
    }
    return nullptr;
}

const AudioBufferList *audio::pcm_buffer::audio_buffer_list() const {
    if (_impl) {
        return _impl->abl_ptr;
    }
    return nullptr;
}

flex_ptr audio::pcm_buffer::flex_ptr_at_index(UInt32 const buf_idx) const {
    if (_impl) {
        return _impl->flex_ptr_at_index(buf_idx);
    }
    return nullptr;
}

flex_ptr audio::pcm_buffer::flex_ptr_at_channel(UInt32 const ch_idx) const {
    if (_impl) {
        return _impl->flex_ptr_at_channel(ch_idx);
    }
    return nullptr;
}

template <typename T>
T *audio::pcm_buffer::data_ptr_at_index(UInt32 const buf_idx) {
    if (_impl) {
        if (!validate_pcm_format<T>(format().pcm_format())) {
            throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
            return nullptr;
        }

        return static_cast<T *>(flex_ptr_at_index(buf_idx).v);
    }
    return nullptr;
}

template Float32 *audio::pcm_buffer::data_ptr_at_index(UInt32 const buf_idx);
template Float64 *audio::pcm_buffer::data_ptr_at_index(UInt32 const buf_idx);
template SInt32 *audio::pcm_buffer::data_ptr_at_index(UInt32 const buf_idx);
template SInt16 *audio::pcm_buffer::data_ptr_at_index(UInt32 const buf_idx);

template <typename T>
T *audio::pcm_buffer::data_ptr_at_channel(UInt32 const ch_idx) {
    if (_impl) {
        if (!validate_pcm_format<T>(format().pcm_format())) {
            throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
            return nullptr;
        }

        return static_cast<T *>(flex_ptr_at_channel(ch_idx).v);
    }
    return nullptr;
}

template Float32 *audio::pcm_buffer::data_ptr_at_channel(UInt32 const ch_idx);
template Float64 *audio::pcm_buffer::data_ptr_at_channel(UInt32 const ch_idx);
template SInt32 *audio::pcm_buffer::data_ptr_at_channel(UInt32 const ch_idx);
template SInt16 *audio::pcm_buffer::data_ptr_at_channel(UInt32 const ch_idx);

template <typename T>
const T *audio::pcm_buffer::data_ptr_at_index(UInt32 const buf_idx) const {
    if (_impl) {
        if (!validate_pcm_format<T>(format().pcm_format())) {
            throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
            return nullptr;
        }

        return static_cast<const T *>(flex_ptr_at_index(buf_idx).v);
    }
    return nullptr;
}

template const Float32 *audio::pcm_buffer::data_ptr_at_index(UInt32 const buf_idx) const;
template const Float64 *audio::pcm_buffer::data_ptr_at_index(UInt32 const buf_idx) const;
template const SInt32 *audio::pcm_buffer::data_ptr_at_index(UInt32 const buf_idx) const;
template const SInt16 *audio::pcm_buffer::data_ptr_at_index(UInt32 const buf_idx) const;

template <typename T>
const T *audio::pcm_buffer::data_ptr_at_channel(UInt32 const ch_idx) const {
    if (_impl) {
        if (!validate_pcm_format<T>(format().pcm_format())) {
            throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
            return nullptr;
        }

        return static_cast<const T *>(flex_ptr_at_channel(ch_idx).v);
    }
    return nullptr;
}

template const Float32 *audio::pcm_buffer::data_ptr_at_channel(UInt32 const ch_idx) const;
template const Float64 *audio::pcm_buffer::data_ptr_at_channel(UInt32 const ch_idx) const;
template const SInt32 *audio::pcm_buffer::data_ptr_at_channel(UInt32 const ch_idx) const;
template const SInt16 *audio::pcm_buffer::data_ptr_at_channel(UInt32 const ch_idx) const;

UInt32 audio::pcm_buffer::frame_capacity() const {
    if (_impl) {
        return _impl->frame_capacity;
    }
    return 0;
}

UInt32 audio::pcm_buffer::frame_length() const {
    if (_impl) {
        return _impl->frame_length;
    }
    return 0;
}

void audio::pcm_buffer::set_frame_length(UInt32 const length) {
    if (_impl) {
        if (length > frame_capacity()) {
            throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. frame_length(" +
                                    std::to_string(length) + ") frame_capacity(" + std::to_string(frame_capacity()) +
                                    ")");
            return;
        }

        _impl->frame_length = length;

        UInt32 const data_byte_size = format().stream_description().mBytesPerFrame * length;
        set_data_byte_size(*this, data_byte_size);
    }
}

void audio::pcm_buffer::reset() {
    if (_impl) {
        set_frame_length(frame_capacity());
        audio::clear(audio_buffer_list());
    }
}

void audio::pcm_buffer::clear() {
    clear(0, frame_length());
}

void audio::pcm_buffer::clear(UInt32 const start_frame, UInt32 const length) {
    if (_impl) {
        if ((start_frame + length) > frame_length()) {
            throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. frame(" +
                                    std::to_string(start_frame) + " length(" + std::to_string(length) +
                                    " frame_length(" + std::to_string(frame_length()) + ")");
        }

        UInt32 const bytes_per_frame = format().stream_description().mBytesPerFrame;
        for (UInt32 i = 0; i < format().buffer_count(); i++) {
            UInt8 *byte_data = static_cast<UInt8 *>(audio_buffer_list()->mBuffers[i].mData);
            memset(&byte_data[start_frame * bytes_per_frame], 0, length * bytes_per_frame);
        }
    }
}

audio::pcm_buffer::copy_result audio::pcm_buffer::copy_from(audio::pcm_buffer const &from_buffer,
                                                            UInt32 const from_start_frame, UInt32 const to_start_frame,
                                                            UInt32 const length) {
    if (!_impl || !from_buffer) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_t::buffer_is_null);
    }

    auto from_format = from_buffer.format();

    if ((from_format.pcm_format() != format().pcm_format()) ||
        (from_format.channel_count() != format().channel_count())) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_t::invalid_format);
    }

    const AudioBufferList *const from_abl = from_buffer.audio_buffer_list();
    AudioBufferList *const to_abl = audio_buffer_list();

    auto result = copy(from_abl, to_abl, from_format.sample_byte_count(), from_start_frame, to_start_frame, length);

    if (result && from_start_frame == 0 && to_start_frame == 0 && length == 0) {
        set_frame_length(result.value());
    }

    return result;
}

audio::pcm_buffer::copy_result audio::pcm_buffer::copy_from(const AudioBufferList *const from_abl,
                                                            UInt32 const from_start_frame, UInt32 const to_start_frame,
                                                            UInt32 const length) {
    if (!_impl) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_t::buffer_is_null);
    }

    set_frame_length(0);
    reset_data_byte_size(*this);

    AudioBufferList *to_abl = audio_buffer_list();

    auto result = copy(from_abl, to_abl, format().sample_byte_count(), from_start_frame, to_start_frame, length);

    if (result) {
        set_frame_length(result.value());
    }

    return result;
}

audio::pcm_buffer::copy_result audio::pcm_buffer::copy_to(AudioBufferList *const to_abl, UInt32 const from_start_frame,
                                                          UInt32 const to_start_frame, UInt32 const length) {
    if (!_impl) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_t::buffer_is_null);
    }

    const AudioBufferList *const from_abl = audio_buffer_list();

    return copy(from_abl, to_abl, format().sample_byte_count(), from_start_frame, to_start_frame, length);
}

#pragma mark - global

void audio::clear(AudioBufferList *abl) {
    for (UInt32 i = 0; i < abl->mNumberBuffers; ++i) {
        if (abl->mBuffers[i].mData) {
            memset(abl->mBuffers[i].mData, 0, abl->mBuffers[i].mDataByteSize);
        }
    }
}

audio::pcm_buffer::copy_result audio::copy(const AudioBufferList *const from_abl, AudioBufferList *const to_abl,
                                           UInt32 const sample_byte_count, UInt32 const from_start_frame,
                                           UInt32 const to_start_frame, UInt32 const length) {
    auto from_result = get_abl_info(from_abl, sample_byte_count);
    if (!from_result) {
        return pcm_buffer::copy_result(from_result.error());
    }

    auto to_result = get_abl_info(to_abl, sample_byte_count);
    if (!to_result) {
        return pcm_buffer::copy_result(to_result.error());
    }

    auto from_info = from_result.value();
    auto to_info = to_result.value();

    UInt32 const copy_length = length ?: (from_info.frame_length - from_start_frame);

    if ((from_start_frame + copy_length) > from_info.frame_length ||
        (to_start_frame + copy_length) > to_info.frame_length || from_info.channel_count > to_info.channel_count) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_t::out_of_range);
    }

    for (UInt32 ch_idx = 0; ch_idx < from_info.channel_count; ch_idx++) {
        UInt32 const &from_stride = from_info.strides[ch_idx];
        UInt32 const &to_stride = to_info.strides[ch_idx];
        const void *from_data = &(from_info.datas[ch_idx][from_start_frame * sample_byte_count * from_stride]);
        void *to_data = &(to_info.datas[ch_idx][to_start_frame * sample_byte_count * to_stride]);

        if (from_stride == 1 && to_stride == 1) {
            memcpy(to_data, from_data, copy_length * sample_byte_count);
        } else {
            if (sample_byte_count == sizeof(Float32)) {
                auto from_float_data = static_cast<const Float32 *>(from_data);
                auto to_float_data = static_cast<Float32 *>(to_data);
                cblas_scopy(copy_length, from_float_data, from_stride, to_float_data, to_stride);
            } else if (sample_byte_count == sizeof(Float64)) {
                auto from_float64_data = static_cast<const Float64 *>(from_data);
                auto to_float64_data = static_cast<Float64 *>(to_data);
                cblas_dcopy(copy_length, from_float64_data, from_stride, to_float64_data, to_stride);
            } else {
                for (UInt32 frame = 0; frame < copy_length; ++frame) {
                    UInt32 const sample_frame = frame * sample_byte_count;
                    auto from_byte_data = static_cast<const UInt8 *>(from_data);
                    auto to_byte_data = static_cast<UInt8 *>(to_data);
                    memcpy(&to_byte_data[sample_frame * to_stride], &from_byte_data[sample_frame * from_stride],
                           sample_byte_count);
                }
            }
        }
    }

    return pcm_buffer::copy_result(copy_length);
}

UInt32 audio::frame_length(const AudioBufferList *const abl, UInt32 const sample_byte_count) {
    if (sample_byte_count > 0) {
        UInt32 out_frame_length = 0;
        for (UInt32 buf = 0; buf < abl->mNumberBuffers; buf++) {
            const AudioBuffer *const ab = &abl->mBuffers[buf];
            UInt32 const stride = ab->mNumberChannels;
            UInt32 const frame_length = ab->mDataByteSize / stride / sample_byte_count;
            if (buf == 0) {
                out_frame_length = frame_length;
            } else if (out_frame_length != frame_length) {
                return 0;
            }
        }
        return out_frame_length;
    } else {
        return 0;
    }
}

bool audio::is_equal_structure(AudioBufferList const &abl1, AudioBufferList const &abl2) {
    if (abl1.mNumberBuffers != abl2.mNumberBuffers) {
        return false;
    }

    for (UInt32 i = 0; i < abl1.mNumberBuffers; i++) {
        if (abl1.mBuffers[i].mData != abl2.mBuffers[i].mData) {
            return false;
        } else if (abl1.mBuffers[i].mNumberChannels != abl2.mBuffers[i].mNumberChannels) {
            return false;
        }
    }

    return true;
}

std::string yas::to_string(audio::pcm_buffer::copy_error_t const &error) {
    switch (error) {
        case audio::pcm_buffer::copy_error_t::invalid_argument:
            return "invalid_argument";
        case audio::pcm_buffer::copy_error_t::invalid_abl:
            return "invalid_abl";
        case audio::pcm_buffer::copy_error_t::invalid_format:
            return "invalid_format";
        case audio::pcm_buffer::copy_error_t::out_of_range:
            return "out_of_range";
        case audio::pcm_buffer::copy_error_t::buffer_is_null:
            return "buffer_is_null";
    }
}
