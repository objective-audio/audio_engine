//
//  yas_audio_enumerator.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_enumerator.h"
#include "yas_pcm_buffer.h"
#include "yas_audio_format.h"
#include <string>

using namespace yas;

#pragma mark - enumerator

audio_enumerator::audio_enumerator(const flex_pointer &pointer, const UInt32 byte_stride, const UInt32 length)
{
    if (!pointer.v || byte_stride == 0 || length == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid argument.");
    }

    _pointer = _top_pointer = pointer;
    _byte_stride = byte_stride;
    _length = length;
    _index = 0;
}

audio_enumerator::audio_enumerator(const pcm_buffer_ptr &buffer, const UInt32 channel)
    : audio_enumerator(buffer->audio_ptr_at_channel(channel), buffer->format()->buffer_frame_byte_count(),
                       buffer->frame_length())
{
}

const flex_pointer *audio_enumerator::pointer() const
{
    return &_pointer;
}

const UInt32 *audio_enumerator::index() const
{
    return &_index;
}

const UInt32 audio_enumerator::length() const
{
    return _length;
}

void audio_enumerator::move()
{
    yas_audio_enumerator_move(*this);
}

void audio_enumerator::stop()
{
    yas_audio_enumerator_stop(*this);
}

void audio_enumerator::set_position(const UInt32 index)
{
    if (index >= _length) {
        throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. position(" +
                                std::to_string(index) + ") length(" + std::to_string(_length) + ")");
        return;
    }
    _index = index;
    _pointer.v = _top_pointer.u8 + (_byte_stride * index);
}

void audio_enumerator::reset()
{
    yas_audio_enumerator_reset(*this);
}

audio_enumerator &audio_enumerator::operator++()
{
    yas_audio_enumerator_move(*this);
    return *this;
}

#pragma mark - frame enumerator

audio_frame_enumerator::audio_frame_enumerator(const pcm_buffer_ptr &buffer)
    : _frame(0),
      _channel(0),
      _frame_length(buffer->frame_length()),
      _channel_count(buffer->format()->channel_count()),
      _frame_byte_stride(buffer->format()->buffer_frame_byte_count()),
      _pointers(std::vector<flex_pointer>(buffer->format()->channel_count())),
      _top_pointers(std::vector<flex_pointer>(buffer->format()->channel_count())),
      _pointers_size(buffer->format()->channel_count() * sizeof(flex_pointer *))
{
    const auto &format = buffer->format();
    const UInt32 bufferCount = format->buffer_count();
    const UInt32 stride = format->stride();
    const UInt32 sampleByteCount = format->sample_byte_count();

    UInt32 channel = 0;
    for (UInt32 buf_idx = 0; buf_idx < bufferCount; buf_idx++) {
        flex_pointer pointer = buffer->audio_ptr_at_index(buf_idx);
        for (UInt32 ch = 0; ch < stride; ch++) {
            _pointers[channel].v = _top_pointers[channel].v = pointer.v;
            pointer.u8 += sampleByteCount;
            channel++;
        }
    }

    _pointer.v = _pointers[0].v;
}

const flex_pointer *audio_frame_enumerator::pointer() const
{
    return &_pointer;
}

const UInt32 *audio_frame_enumerator::frame() const
{
    return &_frame;
}

const UInt32 *audio_frame_enumerator::channel() const
{
    return &_channel;
}

const UInt32 audio_frame_enumerator::frame_length() const
{
    return _frame_length;
}

const UInt32 audio_frame_enumerator::channel_count() const
{
    return _channel_count;
}

void audio_frame_enumerator::move_frame()
{
    yas_audio_frame_enumerator_move_frame(*this);
}

void audio_frame_enumerator::move_channel()
{
    yas_audio_frame_enumerator_move_channel(*this);
}

void audio_frame_enumerator::move()
{
    yas_audio_frame_enumerator_move(*this);
}

void audio_frame_enumerator::stop()
{
    yas_audio_frame_enumerator_stop(*this);
}

void audio_frame_enumerator::set_frame_position(const UInt32 frame)
{
    if (frame >= _frame_length) {
        throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. frame(" + std::to_string(frame) +
                                ")");
    }

    _frame = frame;

    const UInt32 stride = _frame_byte_stride * frame;
    UInt32 index = _channel_count;
    while (index--) {
        _pointers[index].v = _top_pointers[index].u8 + stride;
    }

    if (_pointer.v) {
        _pointer.v = _pointers[_channel].v;
    }
}

void audio_frame_enumerator::set_channel_position(const UInt32 channel)
{
    if (channel >= _channel_count) {
        throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. channel(" +
                                std::to_string(channel) + ") count(" + std::to_string(_channel_count) + ")");
    }

    _channel = channel;
    _pointer.v = _pointers[_channel].v;
}

void audio_frame_enumerator::reset()
{
    yas_audio_frame_enumerator_reset(*this);
}

audio_frame_enumerator &audio_frame_enumerator::operator++()
{
    yas_audio_frame_enumerator_move(*this);
    return *this;
}
