//
//  yas_audio_pcm_buffer.cpp
//

#include "yas_audio_pcm_buffer.h"

static_assert(ACCELERATE_NEW_LAPACK, "");
static_assert(ACCELERATE_LAPACK_ILP64, "");

#include <Accelerate/Accelerate.h>
#include <cpp-utils/yas_fast_each.h>
#include <cpp-utils/yas_result.h>
#include <cpp-utils/yas_stl_utils.h>

#include <exception>
#include <functional>
#include <string>

using namespace yas;
using namespace yas::audio;

#pragma mark - private

namespace yas::audio::pcm_buffer_utils {
static std::vector<uint8_t> _dummy_data(4096 * 4);
}

std::pair<audio::abl_uptr, audio::abl_data_uptr> audio::allocate_audio_buffer_list(uint32_t const buffer_count,
                                                                                   uint32_t const channel_count,
                                                                                   uint32_t const size) {
    abl_uptr abl_ptr((AudioBufferList *)calloc(1, sizeof(AudioBufferList) + buffer_count * sizeof(AudioBuffer)),
                     [](AudioBufferList *abl) { free(abl); });

    abl_ptr->mNumberBuffers = buffer_count;
    auto data_ptr = std::make_unique<std::vector<std::vector<uint8_t>>>();
    if (size > 0) {
        data_ptr->reserve(buffer_count);
    } else {
        data_ptr = nullptr;
    }

    for (uint32_t i = 0; i < buffer_count; ++i) {
        abl_ptr->mBuffers[i].mNumberChannels = channel_count;
        abl_ptr->mBuffers[i].mDataByteSize = size;
        if (size > 0) {
            data_ptr->push_back(std::vector<uint8_t>(size));
            abl_ptr->mBuffers[i].mData = data_ptr->at(i).data();
        } else {
            abl_ptr->mBuffers[i].mData = nullptr;
        }
    }

    return std::make_pair(std::move(abl_ptr), std::move(data_ptr));
}

static void set_data_byte_size(audio::pcm_buffer &data, uint32_t const data_byte_size) {
    AudioBufferList *abl = data.audio_buffer_list();
    for (uint32_t i = 0; i < abl->mNumberBuffers; i++) {
        abl->mBuffers[i].mDataByteSize = data_byte_size;
    }
}

static void reset_data_byte_size(audio::pcm_buffer &data) {
    uint32_t const data_byte_size =
        (uint32_t const)(data.frame_capacity() * data.format().stream_description().mBytesPerFrame);
    set_data_byte_size(data, data_byte_size);
}

template <typename T>
static bool validate_pcm_format(audio::pcm_format const &pcm_format) {
    switch (pcm_format) {
        case audio::pcm_format::float32:
            return typeid(T) == typeid(float);
        case audio::pcm_format::float64:
            return typeid(T) == typeid(double);
        case audio::pcm_format::fixed824:
            return typeid(T) == typeid(int32_t);
        case audio::pcm_format::int16:
            return typeid(T) == typeid(int16_t);
        default:
            return false;
    }
}

namespace yas::audio {
struct abl_info {
    uint32_t channel_count;
    uint32_t frame_length;
    std::vector<uint8_t *> datas;
    std::vector<uint32_t> strides;

    abl_info() : channel_count(0), frame_length(0), datas(0), strides(0) {
    }
};

using get_abl_info_result_t = result<abl_info, pcm_buffer::copy_error_t>;

static get_abl_info_result_t get_abl_info(AudioBufferList const *abl, uint32_t const sample_byte_count) {
    if (!abl || sample_byte_count == 0 || sample_byte_count > 8) {
        return get_abl_info_result_t(pcm_buffer::copy_error_t::invalid_argument);
    }

    uint32_t const buffer_count = abl->mNumberBuffers;

    audio::abl_info data_info;

    for (uint32_t buf_idx = 0; buf_idx < buffer_count; ++buf_idx) {
        uint32_t const stride = abl->mBuffers[buf_idx].mNumberChannels;
        uint32_t const frame_length = abl->mBuffers[buf_idx].mDataByteSize / stride / sample_byte_count;
        if (data_info.frame_length == 0) {
            data_info.frame_length = frame_length;
        } else if (data_info.frame_length != frame_length) {
            return get_abl_info_result_t(pcm_buffer::copy_error_t::invalid_abl);
        }
        data_info.channel_count += stride;
    }

    if (data_info.channel_count > 0) {
        for (uint32_t buf_idx = 0; buf_idx < buffer_count; buf_idx++) {
            uint32_t const stride = abl->mBuffers[buf_idx].mNumberChannels;
            uint8_t *data = static_cast<uint8_t *>(abl->mBuffers[buf_idx].mData);
            for (uint32_t ch_idx = 0; ch_idx < stride; ++ch_idx) {
                data_info.datas.push_back(&data[ch_idx * sample_byte_count]);
                data_info.strides.push_back(stride);
            }
        }
    }

    return get_abl_info_result_t(std::move(data_info));
}
}  // namespace yas::audio

pcm_buffer::pcm_buffer(audio::format const &format, std::pair<audio::abl_uptr, audio::abl_data_uptr> &&abl_pair,
                       uint32_t const frame_capacity)
    : pcm_buffer(format, std::move(abl_pair.first), std::move(abl_pair.second), frame_capacity) {
}

pcm_buffer::pcm_buffer(audio::format const &format, audio::abl_uptr &&abl, audio::pcm_buffer const &from_buffer,
                       channel_map_t const &channel_map)
    : pcm_buffer(format, std::move(abl), nullptr, from_buffer.frame_length()) {
    auto const &from_format = from_buffer.format();

    if (channel_map.size() != format.channel_count() || format.is_interleaved() || from_format.is_interleaved() ||
        format.pcm_format() != from_format.pcm_format()) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid format.");
    }

    abl_uptr const &to_abl = this->_abl;

    AudioBufferList const *const from_abl = from_buffer.audio_buffer_list();
    uint32_t bytesPerFrame = format.stream_description().mBytesPerFrame;
    uint32_t const frame_length = from_buffer.frame_length();
    uint32_t to_ch_idx = 0;

    for (auto const &from_ch_idx : channel_map) {
        if (from_ch_idx != -1) {
            to_abl->mBuffers[to_ch_idx].mData = from_abl->mBuffers[from_ch_idx].mData;
            to_abl->mBuffers[to_ch_idx].mDataByteSize = from_abl->mBuffers[from_ch_idx].mDataByteSize;
            uint32_t actual_frame_length = from_abl->mBuffers[0].mDataByteSize / bytesPerFrame;
            if (frame_length != actual_frame_length) {
                throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) +
                                            " : invalid frame length. frame_length(" + std::to_string(frame_length) +
                                            ") actual_frame_length(" + std::to_string(actual_frame_length) + ")");
            }
        } else {
            if (to_abl->mBuffers[to_ch_idx].mData == nullptr) {
                uint32_t const size = bytesPerFrame * frame_length;
                if (size <= pcm_buffer_utils::_dummy_data.size()) {
                    to_abl->mBuffers[to_ch_idx].mData = pcm_buffer_utils::_dummy_data.data();
                    to_abl->mBuffers[to_ch_idx].mDataByteSize = size;
                } else {
                    throw std::overflow_error(std::string(__PRETTY_FUNCTION__) + " : buffer size is overflow(" +
                                              std::to_string(size) + ")");
                }
            }
        }
        ++to_ch_idx;
    }
}

pcm_buffer::pcm_buffer(audio::format const &format, AudioBufferList *ptr, uint32_t const frame_capacity)
    : _format(format),
      _abl_ptr(ptr),
      _frame_capacity(frame_capacity),
      _frame_length(frame_capacity),
      _abl(nullptr),
      _data(nullptr) {
}

pcm_buffer::pcm_buffer(audio::format const &format, abl_uptr &&abl, abl_data_uptr &&data, uint32_t const frame_capacity)
    : _format(format),
      _frame_capacity(frame_capacity),
      _frame_length(frame_capacity),
      _abl_ptr(abl.get()),
      _abl(std::move(abl)),
      _data(std::move(data)) {
}

pcm_buffer::pcm_buffer(audio::format const &format, abl_uptr &&abl, uint32_t const frame_capacity)
    : _format(format),
      _frame_capacity(frame_capacity),
      _frame_length(frame_capacity),
      _abl_ptr(abl.get()),
      _abl(std::move(abl)),
      _data(nullptr) {
}

#pragma mark - public

pcm_buffer::pcm_buffer(audio::format const &format, AudioBufferList *abl)
    : pcm_buffer(format, abl, abl->mBuffers[0].mDataByteSize / format.stream_description().mBytesPerFrame) {
    if (!abl) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }
}

pcm_buffer::pcm_buffer(audio::format const &format, uint32_t const frame_capacity)
    : pcm_buffer(format,
                 allocate_audio_buffer_list(format.buffer_count(), format.stride(),
                                            frame_capacity * format.stream_description().mBytesPerFrame),
                 frame_capacity) {
    if (frame_capacity == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }
}

pcm_buffer::pcm_buffer(audio::format const &format, audio::pcm_buffer const &from_buffer,
                       channel_map_t const &channel_map)
    : pcm_buffer(format, allocate_audio_buffer_list(format.buffer_count(), format.stride(), 0).first, from_buffer,
                 channel_map) {
}

pcm_buffer::pcm_buffer(pcm_buffer &&other)
    : _format(other._format),
      _abl_ptr(other._abl_ptr),
      _frame_capacity(other._frame_capacity),
      _frame_length(other._frame_length),
      _abl(std::move(other._abl)),
      _data(std::move(other._data)) {
}

audio::format const &pcm_buffer::format() const {
    return this->_format;
}

AudioBufferList *pcm_buffer::audio_buffer_list() {
    return const_cast<AudioBufferList *>(this->_abl_ptr);
}

AudioBufferList const *pcm_buffer::audio_buffer_list() const {
    return this->_abl_ptr;
}

template <typename T>
T *pcm_buffer::_data_ptr_at_index(uint32_t const buf_idx) const {
    if (buf_idx >= this->_abl_ptr->mNumberBuffers) {
        throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. buf_idx(" +
                                std::to_string(buf_idx) + ") _impl->abl_ptr.mNumberBuffers(" +
                                std::to_string(this->_abl_ptr->mNumberBuffers) + ")");
    }

    return static_cast<T *>(this->_abl_ptr->mBuffers[buf_idx].mData);
}

template float *pcm_buffer::_data_ptr_at_index(uint32_t const buf_idx) const;
template double *pcm_buffer::_data_ptr_at_index(uint32_t const buf_idx) const;
template int32_t *pcm_buffer::_data_ptr_at_index(uint32_t const buf_idx) const;
template int16_t *pcm_buffer::_data_ptr_at_index(uint32_t const buf_idx) const;
template int8_t *pcm_buffer::_data_ptr_at_index(uint32_t const buf_idx) const;

template <typename T>
T *pcm_buffer::_data_ptr_at_channel(uint32_t const ch_idx) const {
    uint8_t *ptr;

    if (this->_format.stride() > 1) {
        if (ch_idx < this->_abl_ptr->mBuffers[0].mNumberChannels) {
            ptr = static_cast<uint8_t *>(this->_abl_ptr->mBuffers[0].mData);
            if (ch_idx > 0) {
                ptr += ch_idx * this->_format.sample_byte_count();
            }
        } else {
            throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. ch_idx(" +
                                    std::to_string(ch_idx) + ") mNumberChannels(" +
                                    std::to_string(this->_abl_ptr->mBuffers[0].mNumberChannels) + ")");
        }
    } else {
        if (ch_idx < this->_abl_ptr->mNumberBuffers) {
            ptr = static_cast<uint8_t *>(this->_abl_ptr->mBuffers[ch_idx].mData);
        } else {
            throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. ch_idx(" +
                                    std::to_string(ch_idx) + ") mNumberChannels(" +
                                    std::to_string(this->_abl_ptr->mBuffers[0].mNumberChannels) + ")");
        }
    }

    return (T *)ptr;
}

template float *pcm_buffer::_data_ptr_at_channel(uint32_t const ch_idx) const;
template double *pcm_buffer::_data_ptr_at_channel(uint32_t const ch_idx) const;
template int32_t *pcm_buffer::_data_ptr_at_channel(uint32_t const ch_idx) const;
template int16_t *pcm_buffer::_data_ptr_at_channel(uint32_t const ch_idx) const;

template <typename T>
T *pcm_buffer::data_ptr_at_index(uint32_t const buf_idx) {
    if (!validate_pcm_format<T>(this->format().pcm_format())) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
        return nullptr;
    }

    return this->_data_ptr_at_index<T>(buf_idx);
}

template float *pcm_buffer::data_ptr_at_index(uint32_t const buf_idx);
template double *pcm_buffer::data_ptr_at_index(uint32_t const buf_idx);
template int32_t *pcm_buffer::data_ptr_at_index(uint32_t const buf_idx);
template int16_t *pcm_buffer::data_ptr_at_index(uint32_t const buf_idx);

template <typename T>
T *pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx) {
    if (!validate_pcm_format<T>(this->format().pcm_format())) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
        return nullptr;
    }

    return this->_data_ptr_at_channel<T>(ch_idx);
}

template float *pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx);
template double *pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx);
template int32_t *pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx);
template int16_t *pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx);

template <typename T>
T const *pcm_buffer::data_ptr_at_index(uint32_t const buf_idx) const {
    if (!validate_pcm_format<T>(this->format().pcm_format())) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
        return nullptr;
    }

    return this->_data_ptr_at_index<T>(buf_idx);
}

template float const *pcm_buffer::data_ptr_at_index(uint32_t const buf_idx) const;
template double const *pcm_buffer::data_ptr_at_index(uint32_t const buf_idx) const;
template int32_t const *pcm_buffer::data_ptr_at_index(uint32_t const buf_idx) const;
template int16_t const *pcm_buffer::data_ptr_at_index(uint32_t const buf_idx) const;

template <typename T>
T const *pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx) const {
    if (!validate_pcm_format<T>(this->format().pcm_format())) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
        return nullptr;
    }

    return this->_data_ptr_at_channel<T>(ch_idx);
}

template float const *pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx) const;
template double const *pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx) const;
template int32_t const *pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx) const;
template int16_t const *pcm_buffer::data_ptr_at_channel(uint32_t const ch_idx) const;

uint32_t pcm_buffer::frame_capacity() const {
    return this->_frame_capacity;
}

uint32_t pcm_buffer::frame_length() const {
    return this->_frame_length;
}

void pcm_buffer::set_frame_length(uint32_t const length) {
    if (length > this->frame_capacity()) {
        throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. frame_length(" +
                                std::to_string(length) + ") frame_capacity(" + std::to_string(frame_capacity()) + ")");
        return;
    }

    this->_frame_length = length;

    uint32_t const data_byte_size = this->format().stream_description().mBytesPerFrame * length;
    set_data_byte_size(*this, data_byte_size);
}

void pcm_buffer::reset_buffer() {
    this->set_frame_length(frame_capacity());
    audio::clear(this->audio_buffer_list());
}

void pcm_buffer::clear() {
    this->clear(0, this->frame_length());
}

void pcm_buffer::clear(uint32_t const begin_frame, uint32_t const length) {
    if ((begin_frame + length) > this->frame_length()) {
        throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. frame(" +
                                std::to_string(begin_frame) + " length(" + std::to_string(length) + " frame_length(" +
                                std::to_string(this->frame_length()) + ")");
    }

    uint32_t const bytes_per_frame = this->format().stream_description().mBytesPerFrame;
    for (uint32_t i = 0; i < this->format().buffer_count(); i++) {
        uint8_t *byte_data = static_cast<uint8_t *>(audio_buffer_list()->mBuffers[i].mData);
        memset(&byte_data[begin_frame * bytes_per_frame], 0, length * bytes_per_frame);
    }
}

bool pcm_buffer::is_empty() const {
    uint32_t const frame_size = this->_format.frame_byte_count();
    int8_t zero_data[frame_size];
    memset(zero_data, 0, frame_size);

    auto buffer_each = make_fast_each(this->_format.buffer_count());
    while (yas_each_next(buffer_each)) {
        int8_t const *data = this->_data_ptr_at_index<int8_t>(yas_each_index(buffer_each));

        auto frame_each = make_fast_each(this->_frame_length);
        while (yas_each_next(frame_each)) {
            if (memcmp(&data[yas_each_index(frame_each) * frame_size], zero_data, frame_size) != 0) {
                return false;
            }
        }
    }
    return true;
}

pcm_buffer::copy_result pcm_buffer::copy_from(pcm_buffer const &from_buffer) {
    return this->copy_from(from_buffer, {});
}

pcm_buffer::copy_result pcm_buffer::copy_from(pcm_buffer const &from_buffer, copy_options args) {
    audio::format const &from_format = from_buffer.format();

    if ((from_format.pcm_format() != this->format().pcm_format()) ||
        (from_format.channel_count() != this->format().channel_count())) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_t::invalid_format);
    }

    AudioBufferList const *const from_abl = from_buffer.audio_buffer_list();
    AudioBufferList *const to_abl = this->audio_buffer_list();

    auto result = copy(from_abl, to_abl, from_format.sample_byte_count(), args.from_begin_frame, args.to_begin_frame,
                       args.length);

    if (result && args.from_begin_frame == 0 && args.to_begin_frame == 0 && args.length == 0) {
        this->set_frame_length(result.value());
    }

    return result;
}

pcm_buffer::copy_result pcm_buffer::copy_channel_from(pcm_buffer const &from_buffer) {
    return this->copy_channel_from(from_buffer, {});
}

pcm_buffer::copy_result pcm_buffer::copy_channel_from(pcm_buffer const &from_buffer, copy_channel_options args) {
    audio::format const &from_format = from_buffer.format();

    if (from_format.pcm_format() != format().pcm_format()) {
        return copy_result(copy_error_t::invalid_format);
    }

    uint32_t const from_frame_length = from_buffer.frame_length();

    if (args.from_begin_frame >= from_frame_length || args.to_begin_frame >= this->frame_length()) {
        return copy_result(copy_error_t::out_of_range_frame);
    }

    uint32_t const to_frame_length = this->frame_length();

    if (args.length > 0 && (args.from_begin_frame + args.length > from_buffer.frame_length() ||
                            args.to_begin_frame + args.length > to_frame_length)) {
        return copy_result(copy_error_t::out_of_range_frame);
    }

    audio::format const &to_format = this->format();

    if (args.from_channel >= from_format.channel_count() || args.to_channel >= to_format.channel_count()) {
        return copy_result(copy_error_t::out_of_range_channel);
    }

    void const *from_ptr = nullptr;
    void *to_ptr = nullptr;

    uint32_t const from_idx = args.from_begin_frame * from_format.stride();
    uint32_t const to_idx = args.to_begin_frame * to_format.stride();

    switch (from_format.pcm_format()) {
        case pcm_format::float32:
            from_ptr = &from_buffer.data_ptr_at_channel<Float32>(args.from_channel)[from_idx];
            to_ptr = &this->data_ptr_at_channel<Float32>(args.to_channel)[to_idx];
            break;
        case pcm_format::float64:
            from_ptr = &from_buffer.data_ptr_at_channel<Float64>(args.from_channel)[from_idx];
            to_ptr = &this->data_ptr_at_channel<Float64>(args.to_channel)[to_idx];
            break;
        case pcm_format::int16:
            from_ptr = &from_buffer.data_ptr_at_channel<int16_t>(args.from_channel)[from_idx];
            to_ptr = &this->data_ptr_at_channel<int16_t>(args.to_channel)[to_idx];
            break;
        case pcm_format::fixed824:
            from_ptr = &from_buffer.data_ptr_at_channel<int32_t>(args.from_channel)[from_idx];
            to_ptr = &this->data_ptr_at_channel<int32_t>(args.to_channel)[to_idx];
            break;
        default:
            throw std::runtime_error("invalid pcm_format");
    }

    uint32_t const copy_length =
        args.length ?: std::min(from_frame_length - args.from_begin_frame, to_frame_length - args.to_begin_frame);

    copy(from_ptr, from_format.stride(), to_ptr, to_format.stride(), copy_length, this->format().sample_byte_count());

    return copy_result{args.length};
}

pcm_buffer::copy_result pcm_buffer::copy_from(AudioBufferList const *const from_abl, uint32_t const from_begin_frame,
                                              uint32_t const to_begin_frame, uint32_t const length) {
    this->set_frame_length(0);
    reset_data_byte_size(*this);

    AudioBufferList *to_abl = this->audio_buffer_list();

    auto result = copy(from_abl, to_abl, this->format().sample_byte_count(), from_begin_frame, to_begin_frame, length);

    if (result) {
        this->set_frame_length(result.value());
    }

    return result;
}

pcm_buffer::copy_result pcm_buffer::copy_to(AudioBufferList *const to_abl, uint32_t const from_begin_frame,
                                            uint32_t const to_begin_frame, uint32_t const length) const {
    AudioBufferList const *const from_abl = this->audio_buffer_list();

    return copy(from_abl, to_abl, this->format().sample_byte_count(), from_begin_frame, to_begin_frame, length);
}

template <typename T>
pcm_buffer::copy_result pcm_buffer::copy_from(T const *const from_data, uint32_t const from_stride,
                                              uint32_t const from_begin_frame, uint32_t const to_ch_idx,
                                              uint32_t const to_begin_frame, uint32_t const copy_length) {
    if (!validate_pcm_format<T>(this->format().pcm_format())) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
    }

    uint32_t const sample_byte_count = this->format().sample_byte_count();
    AudioBufferList *const to_abl = this->audio_buffer_list();

    get_abl_info_result_t to_result = get_abl_info(to_abl, sample_byte_count);
    if (!to_result) {
        return pcm_buffer::copy_result(to_result.error());
    }

    abl_info to_info = to_result.value();

    if ((to_begin_frame + copy_length) > to_info.frame_length) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_t::out_of_range_frame);
    }

    if (to_info.channel_count <= to_ch_idx) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_t::out_of_range_frame);
    }

    uint32_t const &to_stride = to_info.strides[to_ch_idx];
    void *const to_data = &(to_info.datas[to_ch_idx][to_begin_frame * sample_byte_count * to_stride]);
    void const *const from_data_at_begin = &(from_data[from_begin_frame * sample_byte_count * from_stride]);

    copy(from_data_at_begin, from_stride, to_data, to_stride, copy_length, sample_byte_count);

    return pcm_buffer::copy_result(copy_length);
}

template pcm_buffer::copy_result pcm_buffer::copy_from(float const *const, uint32_t const, uint32_t const,
                                                       uint32_t const, uint32_t const, uint32_t const);
template pcm_buffer::copy_result pcm_buffer::copy_from(double const *const, uint32_t const, uint32_t const,
                                                       uint32_t const, uint32_t const, uint32_t const);
template pcm_buffer::copy_result pcm_buffer::copy_from(int32_t const *const, uint32_t const, uint32_t const,
                                                       uint32_t const, uint32_t const, uint32_t const);
template pcm_buffer::copy_result pcm_buffer::copy_from(int16_t const *const, uint32_t const, uint32_t const,
                                                       uint32_t const, uint32_t const, uint32_t const);

template <typename T>
pcm_buffer::copy_result pcm_buffer::copy_to(T *const to_data, uint32_t const to_stride, uint32_t const to_begin_frame,
                                            uint32_t const from_ch_idx, uint32_t const from_begin_frame,
                                            uint32_t const copy_length) const {
    if (!validate_pcm_format<T>(this->format().pcm_format())) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
    }

    uint32_t const sample_byte_count = this->format().sample_byte_count();
    AudioBufferList const *const from_abl = this->audio_buffer_list();

    get_abl_info_result_t const from_result = get_abl_info(from_abl, sample_byte_count);
    if (!from_result) {
        return pcm_buffer::copy_result(from_result.error());
    }

    abl_info const &from_info = from_result.value();

    if ((from_begin_frame + copy_length) > from_info.frame_length) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_t::out_of_range_frame);
    }

    uint32_t const &from_stride = from_info.strides[from_ch_idx];
    void const *from_data = &(from_info.datas[from_ch_idx][from_begin_frame * sample_byte_count * from_stride]);
    void *to_data_at_begin = &(to_data[to_begin_frame * sample_byte_count * to_stride]);

    audio::copy(from_data, from_stride, to_data_at_begin, to_stride, copy_length, sample_byte_count);

    return pcm_buffer::copy_result(copy_length);
}

template pcm_buffer::copy_result pcm_buffer::copy_to(float *const, uint32_t const, uint32_t const, uint32_t const,
                                                     uint32_t const, uint32_t const) const;
template pcm_buffer::copy_result pcm_buffer::copy_to(double *const, uint32_t const, uint32_t const, uint32_t const,
                                                     uint32_t const, uint32_t const) const;
template pcm_buffer::copy_result pcm_buffer::copy_to(int32_t *const, uint32_t const, uint32_t const, uint32_t const,
                                                     uint32_t const, uint32_t const) const;
template pcm_buffer::copy_result pcm_buffer::copy_to(int16_t *const, uint32_t const, uint32_t const, uint32_t const,
                                                     uint32_t const, uint32_t const) const;

#pragma mark - global

void audio::clear(AudioBufferList *abl) {
    for (uint32_t i = 0; i < abl->mNumberBuffers; ++i) {
        if (abl->mBuffers[i].mData) {
            memset(abl->mBuffers[i].mData, 0, abl->mBuffers[i].mDataByteSize);
        }
    }
}

void audio::copy(void const *const from_data, uint32_t const from_stride, void *const to_data, uint32_t const to_stride,
                 uint32_t const copy_length, uint32_t const sample_byte_count) {
    if (from_stride == 0 || to_stride == 0) {
        throw std::invalid_argument("invalid stride.");
    }

    if (copy_length == 0) {
        return;
    }

    if (from_stride == 1 && to_stride == 1) {
        memcpy(to_data, from_data, copy_length * sample_byte_count);
    } else {
        if (sample_byte_count == sizeof(float)) {
            float const *const from_float32_data = static_cast<float const *>(from_data);
            float *const to_float_data = static_cast<float *>(to_data);
            cblas_scopy(copy_length, from_float32_data, from_stride, to_float_data, to_stride);
        } else if (sample_byte_count == sizeof(double)) {
            double const *const from_float64_data = static_cast<double const *>(from_data);
            double *const to_float64_data = static_cast<double *>(to_data);
            cblas_dcopy(copy_length, from_float64_data, from_stride, to_float64_data, to_stride);
        } else {
            for (uint32_t frame = 0; frame < copy_length; ++frame) {
                uint32_t const sample_frame = frame * sample_byte_count;
                uint8_t const *const from_byte_data = static_cast<uint8_t const *>(from_data);
                uint8_t *const to_byte_data = static_cast<uint8_t *>(to_data);
                memcpy(&to_byte_data[sample_frame * to_stride], &from_byte_data[sample_frame * from_stride],
                       sample_byte_count);
            }
        }
    }
}

pcm_buffer::copy_result audio::copy(AudioBufferList const *const from_abl, AudioBufferList *const to_abl,
                                    uint32_t const sample_byte_count, uint32_t const from_begin_frame,
                                    uint32_t const to_begin_frame, uint32_t const length) {
    get_abl_info_result_t from_result = get_abl_info(from_abl, sample_byte_count);
    if (!from_result) {
        return pcm_buffer::copy_result(from_result.error());
    }

    get_abl_info_result_t to_result = get_abl_info(to_abl, sample_byte_count);
    if (!to_result) {
        return pcm_buffer::copy_result(to_result.error());
    }

    abl_info from_info = from_result.value();
    abl_info to_info = to_result.value();

    uint32_t const copy_length = length ?: (from_info.frame_length - from_begin_frame);

    if ((from_begin_frame + copy_length) > from_info.frame_length ||
        (to_begin_frame + copy_length) > to_info.frame_length) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_t::out_of_range_frame);
    }

    if (from_info.channel_count > to_info.channel_count) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_t::out_of_range_channel);
    }

    for (uint32_t ch_idx = 0; ch_idx < from_info.channel_count; ch_idx++) {
        uint32_t const &from_stride = from_info.strides[ch_idx];
        uint32_t const &to_stride = to_info.strides[ch_idx];
        void const *from_data = &(from_info.datas[ch_idx][from_begin_frame * sample_byte_count * from_stride]);
        void *to_data = &(to_info.datas[ch_idx][to_begin_frame * sample_byte_count * to_stride]);

        copy(from_data, from_stride, to_data, to_stride, copy_length, sample_byte_count);
    }

    return pcm_buffer::copy_result(copy_length);
}

uint32_t audio::frame_length(AudioBufferList const *const abl, uint32_t const sample_byte_count) {
    if (sample_byte_count > 0) {
        uint32_t out_frame_length = 0;
        for (uint32_t buf = 0; buf < abl->mNumberBuffers; buf++) {
            AudioBuffer const *const ab = &abl->mBuffers[buf];
            uint32_t const stride = ab->mNumberChannels;
            uint32_t const frame_length = ab->mDataByteSize / stride / sample_byte_count;
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

    for (uint32_t i = 0; i < abl1.mNumberBuffers; i++) {
        if (abl1.mBuffers[i].mData != abl2.mBuffers[i].mData) {
            return false;
        } else if (abl1.mBuffers[i].mNumberChannels != abl2.mBuffers[i].mNumberChannels) {
            return false;
        }
    }

    return true;
}

std::string yas::to_string(pcm_buffer::copy_error_t const &error) {
    switch (error) {
        case pcm_buffer::copy_error_t::invalid_argument:
            return "invalid_argument";
        case pcm_buffer::copy_error_t::invalid_abl:
            return "invalid_abl";
        case pcm_buffer::copy_error_t::invalid_format:
            return "invalid_format";
        case pcm_buffer::copy_error_t::out_of_range_frame:
            return "out_of_range_frame";
        case pcm_buffer::copy_error_t::out_of_range_channel:
            return "out_of_range_channel";
    }
}

std::ostream &operator<<(std::ostream &os, yas::audio::pcm_buffer::copy_error_t const &value) {
    os << to_string(value);
    return os;
}
