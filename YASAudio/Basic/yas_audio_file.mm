//
//  yas_audio_file.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_file.h"
#include "yas_pcm_buffer.h"
#include "yas_audio_format.h"
#include "yas_cf_utils.h"
#include "yas_exception.h"
#include <AudioToolbox/AudioToolbox.h>

#include <iostream>

using namespace yas;

#pragma mark -

class audio_file::impl
{
   public:
    audio_format_ptr file_format;
    audio_format_ptr processing_format;
    SInt64 file_frame_position;
    ExtAudioFileRef ext_audio_file;

    impl()
        : file_format(nullptr),
          processing_format(nullptr),
          file_frame_position(0),
          ext_audio_file(nullptr),
          _url(nullptr),
          _file_type(nullptr)
    {
    }

    ~impl()
    {
        set_url(nullptr);
        set_file_type(nullptr);
    }

    void set_url(const CFURLRef url)
    {
        yas::set_cf_property(_url, url);
    }

    CFURLRef url() const
    {
        return _url;
    }

    void set_file_type(const CFStringRef file_type)
    {
        yas::set_cf_property(_file_type, file_type);
    }

    CFStringRef file_type() const
    {
        return _file_type;
    }

   private:
    CFURLRef _url;
    CFStringRef _file_type;
};

audio_file::audio_file() : _impl(std::make_unique<impl>())
{
}

audio_file::~audio_file()
{
    close();
}

CFURLRef audio_file::url() const
{
    return _impl->url();
}

audio_format_ptr audio_file::file_format() const
{
    return _impl->file_format;
}

void audio_file::set_processing_format(const audio_format_ptr &format)
{
    _impl->processing_format = format;
    if (_impl->ext_audio_file) {
        ext_audio_file_utils::set_client_format(format->stream_description(), _impl->ext_audio_file);
    }
}

audio_format_ptr audio_file::processing_format() const
{
    return _impl->processing_format;
}

SInt64 audio_file::file_length() const
{
    if (_impl->ext_audio_file) {
        return ext_audio_file_utils::get_file_length_frames(_impl->ext_audio_file);
    }
    return 0;
}

SInt64 audio_file::processing_length() const
{
    const SInt64 fileLength = file_length();
    const Float64 rate = _impl->processing_format->stream_description().mSampleRate /
                         _impl->file_format->stream_description().mSampleRate;
    return fileLength * rate;
}

void audio_file::set_file_frame_position(const UInt32 position)
{
    if (_impl->file_frame_position != position) {
        OSStatus err = ExtAudioFileSeek(_impl->ext_audio_file, position);
        if (err == noErr) {
            _impl->file_frame_position = position;
        }
    }
}

SInt64 audio_file::file_frame_position() const
{
    return _impl->file_frame_position;
}

void audio_file::close()
{
    if (_impl->ext_audio_file) {
        ext_audio_file_utils::dispose(_impl->ext_audio_file);
        _impl->ext_audio_file = nullptr;
    }
}

bool audio_file::_open(const pcm_format pcm_format, const bool interleaved)
{
    const CFURLRef url = _impl->url();
    ExtAudioFileRef &ext_audio_file = _impl->ext_audio_file;

    if (!ext_audio_file_utils::can_open(url)) {
        return false;
    }

    if (!ext_audio_file_utils::open(&ext_audio_file, url)) {
        ext_audio_file = nullptr;
        return false;
    };

    AudioStreamBasicDescription asbd;
    if (!ext_audio_file_utils::get_audio_file_format(&asbd, ext_audio_file)) {
        close();
        return false;
    }

    AudioFileTypeID file_type_id = ext_audio_file_utils::get_audio_file_type_id(ext_audio_file);
    _impl->set_file_type(to_audio_file_type(file_type_id));
    if (!_impl->file_type()) {
        close();
        return false;
    }

    auto file_format = audio_format::create(asbd);
    _impl->file_format = file_format;

    auto processing_format =
        audio_format::create(file_format->sample_rate(), file_format->channel_count(), pcm_format, interleaved);
    _impl->processing_format = processing_format;

    if (!ext_audio_file_utils::set_client_format(processing_format->stream_description(), ext_audio_file)) {
        close();
        return false;
    }

    return true;
}

bool audio_file::_create(const CFDictionaryRef &settings, const pcm_format pcm_format, const bool interleaved)
{
    auto file_format = audio_format::create(settings);
    _impl->file_format = file_format;

    AudioFileTypeID file_type_id = to_audio_file_type_id(_impl->file_type());
    if (!file_type_id) {
        return false;
    }

    ExtAudioFileRef &ext_audio_file = _impl->ext_audio_file;

    if (!ext_audio_file_utils::create(&ext_audio_file, _impl->url(), file_type_id, file_format->stream_description())) {
        ext_audio_file = nullptr;
        return false;
    }

    auto processing_format =
        audio_format::create(file_format->sample_rate(), file_format->channel_count(), pcm_format, interleaved);
    _impl->processing_format = processing_format;

    if (!ext_audio_file_utils::set_client_format(processing_format->stream_description(), ext_audio_file)) {
        close();
        return false;
    }

    return true;
}

#pragma mark - audio file reader

audio_file_reader::create_result audio_file_reader::create(const CFURLRef file_url, const pcm_format pcm_format,
                                                           const bool interleaved)
{
    if (!file_url) {
        return create_result(create_error_type::invalid_argument);
    }

    auto reader = std::make_shared<audio_file_reader>();

    reader->_impl->set_url(file_url);

    if (!reader->_open(pcm_format, interleaved)) {
        return create_result(create_error_type::open_failed);
    }

    return create_result(std::move(reader));
}

audio_file_reader::audio_file_reader()
{
}

audio_file_reader::~audio_file_reader()
{
}

audio_file_reader::read_result audio_file_reader::read_into_buffer(pcm_buffer_ptr &buffer, const UInt32 frame_length)
{
    if (!_impl->ext_audio_file) {
        return read_result(read_error_type::closed);
    }

    if (!buffer) {
        return read_result(read_error_type::invalid_argument);
    }

    if (*buffer->format() != *processing_format()) {
        return read_result(read_error_type::invalid_format);
    }

    OSStatus err = noErr;
    UInt32 out_frame_length = 0;
    UInt32 remain_frames = frame_length > 0 ?: buffer->frame_capacity();

    const audio_format_ptr &format = buffer->format();
    const UInt32 buffer_count = format->buffer_count();
    const UInt32 stride = format->stride();

    if (auto abl_ptr = yas::allocate_audio_buffer_list(buffer_count, 0, 0).first) {
        AudioBufferList *io_abl = abl_ptr.get();

        while (remain_frames) {
            UInt32 bytesPerFrame = format->stream_description().mBytesPerFrame;
            UInt32 dataByteSize = remain_frames * bytesPerFrame;
            UInt32 dataIndex = out_frame_length * bytesPerFrame;

            for (NSInteger i = 0; i < buffer_count; i++) {
                AudioBuffer *audioBuffer = &io_abl->mBuffers[i];
                audioBuffer->mNumberChannels = stride;
                audioBuffer->mDataByteSize = dataByteSize;
                UInt8 *byte_data = static_cast<UInt8 *>(buffer->audio_buffer_list()->mBuffers[i].mData);
                audioBuffer->mData = &byte_data[dataIndex];
            }

            UInt32 io_frames = remain_frames;

            err = ExtAudioFileRead(_impl->ext_audio_file, &io_frames, io_abl);
            if (err != noErr) {
                break;
            }

            if (!io_frames) {
                break;
            }
            remain_frames -= io_frames;
            out_frame_length += io_frames;
        }
    }

    buffer->set_frame_length(out_frame_length);

    if (err != noErr) {
        return read_result(read_error_type::read_failed);
    } else {
        err = ExtAudioFileTell(_impl->ext_audio_file, &_impl->file_frame_position);
        if (err != noErr) {
            return read_result(read_error_type::tell_failed);
        }
    }

    return read_result(nullptr);
}

std::string yas::to_string(const audio_file_reader::create_error_type &error_type)
{
    switch (error_type) {
        case audio_file_reader::create_error_type::invalid_argument:
            return "invalid_argument";
        case audio_file_reader::create_error_type::open_failed:
            return "open_failed";
    }
}

std::string yas::to_string(const audio_file_reader::read_error_type &error_type)
{
    switch (error_type) {
        case audio_file_reader::read_error_type::closed:
            return "closed";
        case audio_file_reader::read_error_type::invalid_argument:
            return "invalid_argument";
        case audio_file_reader::read_error_type::invalid_format:
            return "invalid_format";
        case audio_file_reader::read_error_type::read_failed:
            return "read_failed";
        case audio_file_reader::read_error_type::tell_failed:
            return "tell_failed";
    }
}

#pragma mark - audio file writer

audio_file_writer::create_result audio_file_writer::create(const CFURLRef file_url, const CFStringRef file_type,
                                                           const CFDictionaryRef settings, const pcm_format pcm_format,
                                                           const bool interleaved)
{
    if (!file_url || !file_type || !settings) {
        return create_result(create_error_type::invalid_argument);
    }

    auto writer = std::make_shared<audio_file_writer>();

    writer->_impl->set_url(file_url);
    writer->_impl->set_file_type(file_type);

    if (!writer->_create(settings, pcm_format, interleaved)) {
        return create_result(create_error_type::create_failed);
    }

    return create_result(std::move(writer));
}

audio_file_writer::audio_file_writer()
{
}

audio_file_writer::~audio_file_writer()
{
}

audio_file_writer::write_result audio_file_writer::write_from_buffer(const pcm_buffer_ptr &buffer, const bool async)
{
    if (!_impl->ext_audio_file) {
        return write_result(write_error_type::closed);
    }

    if (!buffer) {
        return write_result(write_error_type::invalid_argument);
    }

    if (*buffer->format() != *processing_format()) {
        return write_result(write_error_type::invalid_format);
    }

    OSStatus err = noErr;

    if (async) {
        err = ExtAudioFileWriteAsync(_impl->ext_audio_file, buffer->frame_length(), buffer->audio_buffer_list());
    } else {
        err = ExtAudioFileWrite(_impl->ext_audio_file, buffer->frame_length(), buffer->audio_buffer_list());
    }

    if (err != noErr) {
        return write_result(write_error_type::write_failed);
    } else {
        err = ExtAudioFileTell(_impl->ext_audio_file, &_impl->file_frame_position);
        if (err != noErr) {
            return write_result(write_error_type::tell_failed);
        }
    }

    return write_result(nullptr);
}

std::string yas::to_string(const audio_file_writer::create_error_type &error_type)
{
    switch (error_type) {
        case audio_file_writer::create_error_type::invalid_argument:
            return "invalid_argument";
        case audio_file_writer::create_error_type::create_failed:
            return "open_failed";
    }
}

std::string yas::to_string(const audio_file_writer::write_error_type &error_type)
{
    switch (error_type) {
        case audio_file_writer::write_error_type::closed:
            return "closed";
        case audio_file_writer::write_error_type::invalid_argument:
            return "invalid_argument";
        case audio_file_writer::write_error_type::invalid_format:
            return "invalid_format";
        case audio_file_writer::write_error_type::write_failed:
            return "read_failed";
        case audio_file_writer::write_error_type::tell_failed:
            return "tell_failed";
    }
}
