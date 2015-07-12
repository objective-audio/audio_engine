//
//  yas_audio_data.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_data.h"
#include "yas_audio_format.h"
#include "yas_audio_channel_route.h"
#include "YASAudioUtility.h"
#include <string>
#include <exception>
#include <functional>
#include <iostream>

using namespace yas;

#pragma mark - private

class audio_data::impl
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
                                                                           const UInt32 channels, const UInt32 size)
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
        abl_ptr->mBuffers[i].mNumberChannels = channels;
        abl_ptr->mBuffers[i].mDataByteSize = size;
        if (size > 0) {
            data_ptr->push_back(std::vector<UInt8>(size));
            abl_ptr->mBuffers[i].mData = data_ptr->at(i).data();
        }
    }

    return std::make_pair(std::move(abl_ptr), std::move(data_ptr));
}

static void set_data_byte_size(audio_data &data, const UInt32 data_byte_size)
{
    AudioBufferList *abl = data.audio_buffer_list();
    for (UInt32 i = 0; i < abl->mNumberBuffers; i++) {
        abl->mBuffers[i].mDataByteSize = data_byte_size;
    }
}

static void reset_data_byte_size(audio_data &data)
{
    const UInt32 data_byte_size =
        (const UInt32)(data.frame_capacity() * data.format()->stream_description().mBytesPerFrame);
    set_data_byte_size(data, data_byte_size);
}

#pragma mark - public

audio_data_ptr audio_data::create(const audio_format_ptr &format, AudioBufferList *abl)
{
    return audio_data_ptr(new audio_data(format, abl));
}

audio_data_ptr audio_data::create(const audio_format_ptr &format, const UInt32 frame_capacity)
{
    return audio_data_ptr(new audio_data(format, frame_capacity));
}

audio_data_ptr audio_data::create(const audio_format_ptr &format, const audio_data &data,
                                  const std::vector<channel_route_ptr> &channel_routes, const bool is_output)
{
    return audio_data_ptr(new audio_data(format, data, channel_routes, is_output));
}

audio_data::audio_data(const audio_format_ptr &format, AudioBufferList *abl)
{
    if (!format || !abl) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    _impl = std::make_unique<impl>(format, abl,
                                   abl->mBuffers[0].mDataByteSize / format->stream_description().mBytesPerFrame);
}

audio_data::audio_data(const audio_format_ptr &format, const UInt32 frame_capacity)
{
    if (!format || frame_capacity == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    auto pair = allocate_audio_buffer_list(format->buffer_count(), format->stride(),
                                           frame_capacity * format->stream_description().mBytesPerFrame);
    _impl = std::make_unique<impl>(format, std::move(pair.first), std::move(pair.second), frame_capacity);
}

audio_data::audio_data(const audio_format_ptr &format, const audio_data &data,
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

audio_format_ptr audio_data::format() const
{
    return _impl->format;
}

AudioBufferList *audio_data::audio_buffer_list()
{
    return const_cast<AudioBufferList *>(_impl->abl_ptr);
}

const AudioBufferList *audio_data::audio_buffer_list() const
{
    return _impl->abl_ptr;
}

audio_pointer audio_data::audio_ptr_at_buffer(const UInt32 buffer) const
{
    if (buffer >= _impl->abl_ptr->mNumberBuffers) {
        throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. buffer(" + std::to_string(buffer) +
                                ") _impl->abl_ptr.mNumberBuffers(" + std::to_string(_impl->abl_ptr->mNumberBuffers) +
                                ")");
    }

    return audio_pointer{.v = _impl->abl_ptr->mBuffers[buffer].mData};
}

audio_pointer audio_data::audio_ptr_at_channel(const UInt32 channel) const
{
    audio_pointer pointer{.v = nullptr};

    const UInt32 stride = format()->stride();
    const AudioBufferList *abl_ptr = _impl->abl_ptr;

    if (stride > 1) {
        if (channel < abl_ptr->mBuffers[0].mNumberChannels) {
            pointer.v = abl_ptr->mBuffers[0].mData;
            if (channel > 0) {
                pointer.u8 += channel * format()->sample_byte_count();
            }
        } else {
            throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. channel(" +
                                    std::to_string(channel) + ") mNumberChannels(" +
                                    std::to_string(abl_ptr->mBuffers[0].mNumberChannels) + ")");
        }
    } else {
        if (channel < abl_ptr->mNumberBuffers) {
            pointer.v = abl_ptr->mBuffers[channel].mData;
        } else {
            throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. channel(" +
                                    std::to_string(channel) + ") mNumberChannels(" +
                                    std::to_string(abl_ptr->mBuffers[0].mNumberChannels) + ")");
        }
    }

    return pointer;
}

const UInt32 audio_data::frame_capacity() const
{
    return _impl->frame_capacity;
}

const UInt32 audio_data::frame_length() const
{
    return _impl->frame_length;
}

void audio_data::set_frame_length(const UInt32 length)
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

void audio_data::clear()
{
    set_frame_length(frame_capacity());
    yas::clear(audio_buffer_list());
}

void audio_data::clear(const UInt32 start_frame, const UInt32 length)
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

#pragma mark - global

void yas::clear(AudioBufferList *abl)
{
    for (UInt32 i = 0; i < abl->mNumberBuffers; ++i) {
        if (abl->mBuffers[i].mData) {
            memset(abl->mBuffers[i].mData, 0, abl->mBuffers[i].mDataByteSize);
        }
    }
}

audio_data::copy_result yas::copy_data(const audio_data_ptr &from_data, audio_data_ptr &to_data)
{
    return copy_data(from_data, to_data, 0, 0, from_data->frame_length());
}

audio_data::copy_result yas::copy_data(const audio_data_ptr &from_data, audio_data_ptr &to_data,
                                       const UInt32 from_start_frame, const UInt32 to_start_frame, const UInt32 length)
{
    if (!from_data || !to_data) {
        return audio_data::copy_result(audio_data::copy_error_type::invalid_argument);
    }

    if (*from_data->format() != *to_data->format()) {
        return audio_data::copy_result(audio_data::copy_error_type::invalid_format);
    }

    if (((to_start_frame + length) > to_data->frame_length()) ||
        ((from_start_frame + length) > from_data->frame_length())) {
        return audio_data::copy_result(audio_data::copy_error_type::out_of_range_frame_length);
    }

    const UInt32 bytes_per_frame = to_data->format()->stream_description().mBytesPerFrame;
    const UInt32 buffer_count = to_data->format()->buffer_count();

    for (UInt32 i = 0; i < buffer_count; i++) {
        UInt8 *to_data_ptr = static_cast<UInt8 *>(to_data->audio_buffer_list()->mBuffers[i].mData);
        const UInt8 *from_data_ptr = static_cast<const UInt8 *>(from_data->audio_buffer_list()->mBuffers[i].mData);
        memcpy(&to_data_ptr[to_start_frame * bytes_per_frame], &from_data_ptr[from_start_frame * bytes_per_frame],
               length * bytes_per_frame);
    }

    return audio_data::copy_result(nullptr);
}

audio_data::copy_result yas::copy_data_flexibly(const AudioBufferList *&from_abl, AudioBufferList *&to_abl,
                                                const UInt32 sample_byte_count, UInt32 *out_frame_length)
{
    if (YASAudioCopyAudioBufferListFlexibly(from_abl, to_abl, sample_byte_count, out_frame_length)) {
        return audio_data::copy_result(nullptr);
    } else {
        return audio_data::copy_result(audio_data::copy_error_type::flexible_copy_failed);
    }
}

audio_data::copy_result yas::copy_data_flexibly(const audio_data_ptr &from_data, audio_data_ptr &to_data)
{
    if (!from_data || !to_data) {
        return audio_data::copy_result(audio_data::copy_error_type::invalid_argument);
    }

    if (from_data->format()->pcm_format() != to_data->format()->pcm_format()) {
        return audio_data::copy_result(audio_data::copy_error_type::invalid_pcm_format);
    }

    const auto abl = from_data->audio_buffer_list();
    return copy_data_flexibly(abl, to_data);
}

audio_data::copy_result yas::copy_data_flexibly(const audio_data_ptr &from_data, AudioBufferList *to_abl)
{
    if (!from_data || !to_abl) {
        return audio_data::copy_result(audio_data::copy_error_type::invalid_argument);
    }

    const AudioBufferList *from_abl = from_data->audio_buffer_list();
    const UInt32 sample_byte_count = from_data->format()->sample_byte_count();
    return copy_data_flexibly(from_abl, to_abl, sample_byte_count, nullptr);
}

audio_data::copy_result yas::copy_data_flexibly(const AudioBufferList *from_abl, audio_data_ptr &to_data)
{
    if (!from_abl || !to_data) {
        return audio_data::copy_result(audio_data::copy_error_type::invalid_argument);
    }

    to_data->set_frame_length(0);
    reset_data_byte_size(*to_data);

    AudioBufferList *to_abl = to_data->audio_buffer_list();
    const UInt32 sample_byte_count = to_data->format()->sample_byte_count();
    UInt32 frameLength = 0;

    auto result = copy_data_flexibly(from_abl, to_abl, sample_byte_count, &frameLength);
    if (result) {
        to_data->set_frame_length(frameLength);
    }
    return result;
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
