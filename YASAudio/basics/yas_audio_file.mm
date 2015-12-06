//
//  yas_audio_file.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_file.h"
#include "yas_audio_file_utils.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_format.h"
#include "yas_cf_utils.h"
#include "yas_exception.h"
#include <AudioToolbox/AudioToolbox.h>

using namespace yas;

#pragma mark -

class audio::file::impl
{
   public:
    format file_format;
    format processing_format;
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
        close();
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

    bool open(const pcm_format pcm_format, const bool interleaved)
    {
        if (!ext_audio_file_utils::can_open(url())) {
            return false;
        }

        if (!ext_audio_file_utils::open(&ext_audio_file, url())) {
            ext_audio_file = nullptr;
            return false;
        };

        AudioStreamBasicDescription asbd;
        if (!ext_audio_file_utils::get_audio_file_format(&asbd, ext_audio_file)) {
            close();
            return false;
        }

        AudioFileTypeID file_type_id = ext_audio_file_utils::get_audio_file_type_id(ext_audio_file);
        set_file_type(to_file_type(file_type_id));
        if (!file_type()) {
            close();
            return false;
        }

        file_format = format{asbd};

        processing_format = format{file_format.sample_rate(), file_format.channel_count(), pcm_format, interleaved};

        if (!ext_audio_file_utils::set_client_format(processing_format.stream_description(), ext_audio_file)) {
            close();
            return false;
        }

        return true;
    }

    bool create(const CFDictionaryRef &settings, const pcm_format pcm_format, const bool interleaved)
    {
        file_format = format{settings};

        AudioFileTypeID file_type_id = to_audio_file_type_id(file_type());
        if (!file_type_id) {
            return false;
        }

        if (!ext_audio_file_utils::create(&ext_audio_file, url(), file_type_id, file_format.stream_description())) {
            ext_audio_file = nullptr;
            return false;
        }

        processing_format = format{file_format.sample_rate(), file_format.channel_count(), pcm_format, interleaved};

        if (!ext_audio_file_utils::set_client_format(processing_format.stream_description(), ext_audio_file)) {
            close();
            return false;
        }

        return true;
    }

    void close()
    {
        if (ext_audio_file) {
            ext_audio_file_utils::dispose(ext_audio_file);
            ext_audio_file = nullptr;
        }
    }

    bool is_open() const
    {
        return ext_audio_file != nullptr;
    }

   private:
    CFURLRef _url;
    CFStringRef _file_type;
};

audio::file::file() : _impl(std::make_shared<impl>())
{
}

audio::file::operator bool() const
{
    if (_impl) {
        return _impl->is_open();
    }
    return false;
}

CFURLRef audio::file::url() const
{
    return _impl->url();
}

const audio::format &audio::file::file_format() const
{
    return _impl->file_format;
}

void audio::file::set_processing_format(const audio::format &format)
{
    _impl->processing_format = format;
    if (_impl->ext_audio_file) {
        ext_audio_file_utils::set_client_format(format.stream_description(), _impl->ext_audio_file);
    }
}

const audio::format &audio::file::processing_format() const
{
    return _impl->processing_format;
}

SInt64 audio::file::file_length() const
{
    if (_impl->ext_audio_file) {
        return ext_audio_file_utils::get_file_length_frames(_impl->ext_audio_file);
    }
    return 0;
}

SInt64 audio::file::processing_length() const
{
    const SInt64 fileLength = file_length();
    const Float64 rate =
        _impl->processing_format.stream_description().mSampleRate / _impl->file_format.stream_description().mSampleRate;
    return fileLength * rate;
}

void audio::file::set_file_frame_position(const UInt32 position)
{
    if (_impl->file_frame_position != position) {
        OSStatus err = ExtAudioFileSeek(_impl->ext_audio_file, position);
        if (err == noErr) {
            _impl->file_frame_position = position;
        }
    }
}

SInt64 audio::file::file_frame_position() const
{
    return _impl->file_frame_position;
}

audio::file::open_result_t audio::file::open(const CFURLRef file_url, const pcm_format pcm_format,
                                             const bool interleaved)
{
    if (_impl->ext_audio_file) {
        return open_result_t(open_error_t::opened);
    }

    if (!file_url || pcm_format == yas::pcm_format::other) {
        return open_result_t(open_error_t::invalid_argument);
    }

    _impl->set_url(file_url);

    if (!_impl->open(pcm_format, interleaved)) {
        return open_result_t(open_error_t::open_failed);
    }

    return open_result_t(nullptr);
}

audio::file::create_result_t audio::file::create(const CFURLRef file_url, const CFStringRef file_type,
                                                 const CFDictionaryRef settings, const pcm_format pcm_format,
                                                 const bool interleaved)
{
    if (_impl->ext_audio_file) {
        return create_result_t(create_error_t::created);
    }

    if (!file_url || !file_type || !settings) {
        return create_result_t(create_error_t::invalid_argument);
    }

    _impl->set_url(file_url);
    _impl->set_file_type(file_type);

    if (!_impl->create(settings, pcm_format, interleaved)) {
        return create_result_t(create_error_t::create_failed);
    }

    return create_result_t(nullptr);
}

void audio::file::close()
{
    _impl->close();
}

audio::file::read_result_t audio::file::read_into_buffer(audio::pcm_buffer &buffer, const UInt32 frame_length)
{
    if (!_impl->ext_audio_file) {
        return read_result_t(read_error_t::closed);
    }

    if (!buffer) {
        return read_result_t(read_error_t::invalid_argument);
    }

    if (buffer.format() != processing_format()) {
        return read_result_t(read_error_t::invalid_format);
    }

    OSStatus err = noErr;
    UInt32 out_frame_length = 0;
    UInt32 remain_frames = frame_length > 0 ?: buffer.frame_capacity();

    const auto &format = buffer.format();
    const UInt32 buffer_count = format.buffer_count();
    const UInt32 stride = format.stride();

    if (auto abl_ptr = allocate_audio_buffer_list(buffer_count, 0, 0).first) {
        AudioBufferList *io_abl = abl_ptr.get();

        while (remain_frames) {
            UInt32 bytesPerFrame = format.stream_description().mBytesPerFrame;
            UInt32 dataByteSize = remain_frames * bytesPerFrame;
            UInt32 dataIndex = out_frame_length * bytesPerFrame;

            for (NSInteger i = 0; i < buffer_count; i++) {
                AudioBuffer *ab = &io_abl->mBuffers[i];
                ab->mNumberChannels = stride;
                ab->mDataByteSize = dataByteSize;
                UInt8 *byte_data = static_cast<UInt8 *>(buffer.audio_buffer_list()->mBuffers[i].mData);
                ab->mData = &byte_data[dataIndex];
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

    buffer.set_frame_length(out_frame_length);

    if (err != noErr) {
        return read_result_t(read_error_t::read_failed);
    } else {
        err = ExtAudioFileTell(_impl->ext_audio_file, &_impl->file_frame_position);
        if (err != noErr) {
            return read_result_t(read_error_t::tell_failed);
        }
    }

    return read_result_t(nullptr);
}

audio::file::write_result_t audio::file::write_from_buffer(const audio::pcm_buffer &buffer, const bool async)
{
    if (!_impl->ext_audio_file) {
        return write_result_t(write_error_t::closed);
    }

    if (!buffer) {
        return write_result_t(write_error_t::invalid_argument);
    }

    if (buffer.format() != processing_format()) {
        return write_result_t(write_error_t::invalid_format);
    }

    OSStatus err = noErr;

    if (async) {
        err = ExtAudioFileWriteAsync(_impl->ext_audio_file, buffer.frame_length(), buffer.audio_buffer_list());
    } else {
        err = ExtAudioFileWrite(_impl->ext_audio_file, buffer.frame_length(), buffer.audio_buffer_list());
    }

    if (err != noErr) {
        return write_result_t(write_error_t::write_failed);
    } else {
        err = ExtAudioFileTell(_impl->ext_audio_file, &_impl->file_frame_position);
        if (err != noErr) {
            return write_result_t(write_error_t::tell_failed);
        }
    }

    return write_result_t(nullptr);
}

std::string yas::to_string(const audio::file::open_error_t &error_t)
{
    switch (error_t) {
        case audio::file::open_error_t::opened:
            return "opened";
        case audio::file::open_error_t::invalid_argument:
            return "invalid_argument";
        case audio::file::open_error_t::open_failed:
            return "open_failed";
    }
}

std::string yas::to_string(const audio::file::read_error_t &error_t)
{
    switch (error_t) {
        case audio::file::read_error_t::closed:
            return "closed";
        case audio::file::read_error_t::invalid_argument:
            return "invalid_argument";
        case audio::file::read_error_t::invalid_format:
            return "invalid_format";
        case audio::file::read_error_t::read_failed:
            return "read_failed";
        case audio::file::read_error_t::tell_failed:
            return "tell_failed";
    }
}

std::string yas::to_string(const audio::file::create_error_t &error_t)
{
    switch (error_t) {
        case audio::file::create_error_t::created:
            return "created";
        case audio::file::create_error_t::invalid_argument:
            return "invalid_argument";
        case audio::file::create_error_t::create_failed:
            return "open_failed";
    }
}

std::string yas::to_string(const audio::file::write_error_t &error_t)
{
    switch (error_t) {
        case audio::file::write_error_t::closed:
            return "closed";
        case audio::file::write_error_t::invalid_argument:
            return "invalid_argument";
        case audio::file::write_error_t::invalid_format:
            return "invalid_format";
        case audio::file::write_error_t::write_failed:
            return "read_failed";
        case audio::file::write_error_t::tell_failed:
            return "tell_failed";
    }
}
