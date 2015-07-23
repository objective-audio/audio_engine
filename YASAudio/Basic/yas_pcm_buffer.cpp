//
//  yas_pcm_buffer.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_pcm_buffer.h"
#include "yas_audio_format.h"
#include "yas_audio_channel_route.h"
#include <string>
#include <exception>
#include <functional>
#include <iostream>
#include <Accelerate/Accelerate.h>

using namespace yas;

#pragma mark - private

class pcm_buffer::impl
{
   public:
    const audio_format_ptr format;
    const AudioBufferList *abl_ptr;
    const UInt32 frame_capacity;
    UInt32 frame_length;

    impl(const audio_format_ptr &format, AudioBufferList *ptr, const UInt32 frame_capacity)
        : format(format),
          abl_ptr(ptr),
          frame_capacity(frame_capacity),
          frame_length(frame_capacity),
          _abl(nullptr),
          _data(nullptr)
    {
    }

    impl(const audio_format_ptr &format, abl_unique_ptr &&abl, abl_data_unique_ptr &&data, const UInt32 frame_capacity)
        : format(format),
          frame_capacity(frame_capacity),
          frame_length(frame_capacity),
          abl_ptr(abl.get()),
          _abl(std::move(abl)),
          _data(std::move(data))
    {
    }

    impl(const audio_format_ptr &format, abl_unique_ptr &&abl, const UInt32 frame_capacity)
        : format(format),
          frame_capacity(frame_capacity),
          frame_length(frame_capacity),
          abl_ptr(abl.get()),
          _abl(std::move(abl)),
          _data(nullptr)
    {
    }

   private:
    const abl_unique_ptr _abl;
    const abl_data_unique_ptr _data;
};

std::pair<abl_unique_ptr, abl_data_unique_ptr> yas::allocate_audio_buffer_list(const UInt32 buffer_count,
                                                                               const UInt32 channel_count,
                                                                               const UInt32 size)
{
    abl_unique_ptr abl_ptr((AudioBufferList *)calloc(1, sizeof(AudioBufferList) + buffer_count * sizeof(AudioBuffer)),
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
        }
    }

    return std::make_pair(std::move(abl_ptr), std::move(data_ptr));
}

static void set_data_byte_size(pcm_buffer &data, const UInt32 data_byte_size)
{
    AudioBufferList *abl = data.audio_buffer_list();
    for (UInt32 i = 0; i < abl->mNumberBuffers; i++) {
        abl->mBuffers[i].mDataByteSize = data_byte_size;
    }
}

static void reset_data_byte_size(pcm_buffer &data)
{
    const UInt32 data_byte_size =
        (const UInt32)(data.frame_capacity() * data.format()->stream_description().mBytesPerFrame);
    set_data_byte_size(data, data_byte_size);
}

template <typename T>
static bool validate_pcm_format(const yas::pcm_format &pcm_format)
{
    switch (pcm_format) {
        case yas::pcm_format::float32:
            return typeid(T) == typeid(Float32);
        case yas::pcm_format::float64:
            return typeid(T) == typeid(Float64);
        case yas::pcm_format::fixed824:
            return typeid(T) == typeid(SInt32);
        case yas::pcm_format::int16:
            return typeid(T) == typeid(SInt16);
        default:
            return false;
    }
}

namespace yas
{
    struct abl_info {
        UInt32 channel_count;
        UInt32 frame_length;
        std::vector<UInt8 *> datas;
        std::vector<UInt32> strides;

        abl_info() : channel_count(0), frame_length(0), datas(0), strides(0)
        {
        }
    };

    using get_abl_info_result = result<yas::abl_info, pcm_buffer::copy_error_type>;
}

static get_abl_info_result get_abl_info(const AudioBufferList *abl, const UInt32 sample_byte_count)
{
    if (!abl || sample_byte_count == 0 || sample_byte_count > 8) {
        return get_abl_info_result(pcm_buffer::copy_error_type::invalid_argument);
    }

    const UInt32 buffer_count = abl->mNumberBuffers;

    abl_info data_info;

    for (UInt32 buf_idx = 0; buf_idx < buffer_count; ++buf_idx) {
        const UInt32 stride = abl->mBuffers[buf_idx].mNumberChannels;
        const UInt32 frame_length = abl->mBuffers[buf_idx].mDataByteSize / stride / sample_byte_count;
        if (data_info.frame_length == 0) {
            data_info.frame_length = frame_length;
        } else if (data_info.frame_length != frame_length) {
            return get_abl_info_result(pcm_buffer::copy_error_type::invalid_abl);
        }
        data_info.channel_count += stride;
    }

    if (data_info.channel_count > 0) {
        for (UInt32 buf_idx = 0; buf_idx < buffer_count; buf_idx++) {
            const UInt32 stride = abl->mBuffers[buf_idx].mNumberChannels;
            UInt8 *data = static_cast<UInt8 *>(abl->mBuffers[buf_idx].mData);
            for (UInt32 ch_idx = 0; ch_idx < stride; ++ch_idx) {
                data_info.datas.push_back(&data[ch_idx * sample_byte_count]);
                data_info.strides.push_back(stride);
            }
        }
    }

    return get_abl_info_result(std::move(data_info));
}

#pragma mark - public

pcm_buffer_ptr pcm_buffer::create(const audio_format_ptr &format, AudioBufferList *abl)
{
    return pcm_buffer_ptr(new pcm_buffer(format, abl));
}

pcm_buffer_ptr pcm_buffer::create(const audio_format_ptr &format, const UInt32 frame_capacity)
{
    return pcm_buffer_ptr(new pcm_buffer(format, frame_capacity));
}

pcm_buffer_ptr pcm_buffer::create(const audio_format_ptr &format, const pcm_buffer &data,
                                  const std::vector<channel_route_ptr> &channel_routes, const bool is_output)
{
    return pcm_buffer_ptr(new pcm_buffer(format, data, channel_routes, is_output));
}

pcm_buffer::pcm_buffer(const audio_format_ptr &format, AudioBufferList *abl)
{
    if (!format || !abl) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    _impl = std::make_unique<impl>(format, abl,
                                   abl->mBuffers[0].mDataByteSize / format->stream_description().mBytesPerFrame);
}

pcm_buffer::pcm_buffer(const audio_format_ptr &format, const UInt32 frame_capacity)
{
    if (!format || frame_capacity == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    auto pair = allocate_audio_buffer_list(format->buffer_count(), format->stride(),
                                           frame_capacity * format->stream_description().mBytesPerFrame);
    _impl = std::make_unique<impl>(format, std::move(pair.first), std::move(pair.second), frame_capacity);
}

pcm_buffer::pcm_buffer(const audio_format_ptr &format, const pcm_buffer &data,
                       const std::vector<channel_route_ptr> channel_routes, const bool is_output)
{
    if (!format || channel_routes.size() == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    if (format->channel_count() != channel_routes.size() || format->is_interleaved()) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid format. format.channel_count(" +
                                    std::to_string(format->channel_count()) + ") channel_routes.size(" +
                                    std::to_string(channel_routes.size()) + ") is_interleaved(" +
                                    std::to_string(format->is_interleaved()) + ")");
    }

    auto pair = allocate_audio_buffer_list(format->buffer_count(), format->stride(), 0);
    abl_unique_ptr &to_abl = pair.first;

    const AudioBufferList *from_abl = data.audio_buffer_list();
    UInt32 bytesPerFrame = format->stream_description().mBytesPerFrame;
    UInt32 frame_capacity = 0;

    for (UInt32 i = 0; i < format->channel_count(); i++) {
        const channel_route_ptr &route = channel_routes.at(i);
        UInt32 from_channel = is_output ? route->destination_channel() : route->source_channel();
        UInt32 to_channel = is_output ? route->source_channel() : route->destination_channel();
        to_abl->mBuffers[to_channel].mData = from_abl->mBuffers[from_channel].mData;
        to_abl->mBuffers[to_channel].mDataByteSize = from_abl->mBuffers[from_channel].mDataByteSize;
        UInt32 frame_length = from_abl->mBuffers[0].mDataByteSize / bytesPerFrame;
        if (frame_capacity == 0) {
            frame_capacity = frame_length;
        } else if (frame_capacity != frame_length) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid frame length. frame_capacity(" +
                                        std::to_string(frame_capacity) + ") frame_length(" +
                                        std::to_string(frame_length) + ")");
        }
    }

    _impl = std::make_unique<impl>(format, std::move(to_abl), frame_capacity);
}

audio_format_ptr pcm_buffer::format() const
{
    return _impl->format;
}

AudioBufferList *pcm_buffer::audio_buffer_list()
{
    return const_cast<AudioBufferList *>(_impl->abl_ptr);
}

const AudioBufferList *pcm_buffer::audio_buffer_list() const
{
    return _impl->abl_ptr;
}

flex_pointer pcm_buffer::audio_ptr_at_index(const UInt32 buf_idx) const
{
    if (buf_idx >= _impl->abl_ptr->mNumberBuffers) {
        throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. buf_idx(" +
                                std::to_string(buf_idx) + ") _impl->abl_ptr.mNumberBuffers(" +
                                std::to_string(_impl->abl_ptr->mNumberBuffers) + ")");
    }

    return flex_pointer{.v = _impl->abl_ptr->mBuffers[buf_idx].mData};
}

flex_pointer pcm_buffer::audio_ptr_at_channel(const UInt32 ch_idx) const
{
    flex_pointer pointer{.v = nullptr};

    const UInt32 stride = format()->stride();
    const AudioBufferList *abl_ptr = _impl->abl_ptr;

    if (stride > 1) {
        if (ch_idx < abl_ptr->mBuffers[0].mNumberChannels) {
            pointer.v = abl_ptr->mBuffers[0].mData;
            if (ch_idx > 0) {
                pointer.u8 += ch_idx * format()->sample_byte_count();
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

template <typename T>
T *yas::pcm_buffer::audio_ptr_at_index(const UInt32 buf_idx) const
{
    if (!validate_pcm_format<T>(format()->pcm_format())) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
        return nullptr;
    }

    return static_cast<T *>(audio_ptr_at_index(buf_idx).v);
}

template Float32 *yas::pcm_buffer::audio_ptr_at_index(const UInt32 buf_idx) const;
template Float64 *yas::pcm_buffer::audio_ptr_at_index(const UInt32 buf_idx) const;
template SInt32 *yas::pcm_buffer::audio_ptr_at_index(const UInt32 buf_idx) const;
template SInt16 *yas::pcm_buffer::audio_ptr_at_index(const UInt32 buf_idx) const;

template <typename T>
T *yas::pcm_buffer::audio_ptr_at_channel(const UInt32 ch_idx) const
{
    if (!validate_pcm_format<T>(format()->pcm_format())) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : invalid pcm_format.");
        return nullptr;
    }

    return static_cast<T *>(audio_ptr_at_channel(ch_idx).v);
}

template Float32 *yas::pcm_buffer::audio_ptr_at_channel(const UInt32 ch_idx) const;
template Float64 *yas::pcm_buffer::audio_ptr_at_channel(const UInt32 ch_idx) const;
template SInt32 *yas::pcm_buffer::audio_ptr_at_channel(const UInt32 ch_idx) const;
template SInt16 *yas::pcm_buffer::audio_ptr_at_channel(const UInt32 ch_idx) const;

const UInt32 pcm_buffer::frame_capacity() const
{
    return _impl->frame_capacity;
}

const UInt32 pcm_buffer::frame_length() const
{
    return _impl->frame_length;
}

void pcm_buffer::set_frame_length(const UInt32 length)
{
    if (length > frame_capacity()) {
        throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. frame_length(" +
                                std::to_string(length) + ") frame_capacity(" + std::to_string(frame_capacity()) + ")");
        return;
    }

    _impl->frame_length = length;

    const UInt32 data_byte_size = format()->stream_description().mBytesPerFrame * length;
    set_data_byte_size(*this, data_byte_size);
}

void pcm_buffer::clear()
{
    set_frame_length(frame_capacity());
    yas::clear(audio_buffer_list());
}

void pcm_buffer::clear(const UInt32 start_frame, const UInt32 length)
{
    if ((start_frame + length) > frame_length()) {
        throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. frame(" +
                                std::to_string(start_frame) + " length(" + std::to_string(length) + " frame_length(" +
                                std::to_string(frame_length()) + ")");
    }

    const UInt32 bytes_per_frame = format()->stream_description().mBytesPerFrame;
    for (UInt32 i = 0; i < format()->buffer_count(); i++) {
        UInt8 *byte_data = static_cast<UInt8 *>(audio_buffer_list()->mBuffers[i].mData);
        memset(&byte_data[start_frame * bytes_per_frame], 0, length * bytes_per_frame);
    }
}

pcm_buffer::copy_result pcm_buffer::copy_from(const pcm_buffer_ptr &from_buffer, const UInt32 from_start_frame,
                                              const UInt32 to_start_frame, const UInt32 length)
{
    auto from_format = from_buffer->format();

    if ((from_format->pcm_format() != format()->pcm_format()) ||
        (from_format->channel_count() != format()->channel_count())) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_type::invalid_format);
    }

    const AudioBufferList *from_abl = from_buffer->audio_buffer_list();
    AudioBufferList *to_abl = audio_buffer_list();

    auto result = copy(from_abl, to_abl, from_format->sample_byte_count(), from_start_frame, to_start_frame, length);

    if (result && from_start_frame == 0 && to_start_frame == 0 && length == 0) {
        set_frame_length(result.value());
    }

    return result;
}

pcm_buffer::copy_result pcm_buffer::copy_from(const AudioBufferList *from_abl, const UInt32 from_start_frame,
                                              const UInt32 to_start_frame, const UInt32 length)
{
    set_frame_length(0);
    reset_data_byte_size(*this);

    AudioBufferList *to_abl = audio_buffer_list();

    auto result = copy(from_abl, to_abl, format()->sample_byte_count(), from_start_frame, to_start_frame, length);

    if (result) {
        set_frame_length(result.value());
    }

    return result;
}

pcm_buffer::copy_result pcm_buffer::copy_to(AudioBufferList *to_abl, const UInt32 from_start_frame,
                                            const UInt32 to_start_frame, const UInt32 length)
{
    const AudioBufferList *from_abl = audio_buffer_list();

    return copy(from_abl, to_abl, format()->sample_byte_count(), from_start_frame, to_start_frame, length);
}

#pragma mark - global

void yas::clear(AudioBufferList *abl)
{
    for (UInt32 i = 0; i < abl->mNumberBuffers; ++i) {
        if (abl->mBuffers[i].mData) {
            memset(abl->mBuffers[i].mData, 0, abl->mBuffers[i].mDataByteSize);
        }
    }
}

pcm_buffer::copy_result yas::copy(const AudioBufferList *from_abl, AudioBufferList *to_abl,
                                  const UInt32 sample_byte_count, const UInt32 from_start_frame,
                                  const UInt32 to_start_frame, const UInt32 length)
{
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

    const UInt32 copy_length = length ?: (from_info.frame_length - from_start_frame);

    if ((from_start_frame + copy_length) > from_info.frame_length ||
        (to_start_frame + copy_length) > to_info.frame_length || from_info.channel_count > to_info.channel_count) {
        return pcm_buffer::copy_result(pcm_buffer::copy_error_type::out_of_range);
    }

    for (UInt32 ch_idx = 0; ch_idx < from_info.channel_count; ch_idx++) {
        const UInt32 &from_stride = from_info.strides[ch_idx];
        const UInt32 &to_stride = to_info.strides[ch_idx];
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
                auto from_double_data = static_cast<const Float64 *>(from_data);
                auto to_double_data = static_cast<Float64 *>(to_data);
                cblas_dcopy(copy_length, from_double_data, from_stride, to_double_data, to_stride);
            } else {
                for (UInt32 frame = 0; frame < copy_length; ++frame) {
                    const UInt32 sample_frame = frame * sample_byte_count;
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

UInt32 yas::frame_length(const AudioBufferList *abl, const UInt32 sample_byte_count)
{
    if (sample_byte_count > 0) {
        UInt32 out_frame_length = 0;
        for (UInt32 buf = 0; buf < abl->mNumberBuffers; buf++) {
            const AudioBuffer *ab = &abl->mBuffers[buf];
            const UInt32 stride = ab->mNumberChannels;
            const UInt32 frame_length = ab->mDataByteSize / stride / sample_byte_count;
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
