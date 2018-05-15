//
//  yas_audio_file.mm
//

#include "yas_audio_file.h"
#include <AudioToolbox/AudioToolbox.h>
#include "yas_audio_file_utils.h"
#include "yas_audio_format.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_cf_utils.h"
#include "yas_exception.h"
#include "yas_result.h"

using namespace yas;

#pragma mark -

struct audio::file::impl : base::impl {
    format _file_format = nullptr;
    format _processing_format = nullptr;
    SInt64 _file_frame_position = 0;
    ExtAudioFileRef _ext_audio_file = nullptr;

    impl() : _url(nullptr), _file_type(nullptr) {
    }

    ~impl() {
        set_url(nullptr);
        set_file_type(nullptr);
        close();
    }

    void set_url(CFURLRef const url) {
        set_cf_property(_url, url);
    }

    CFURLRef url() const {
        return _url;
    }

    void set_file_type(CFStringRef const file_type) {
        set_cf_property(_file_type, file_type);
    }

    CFStringRef file_type() const {
        return _file_type;
    }

    void set_processing_format(audio::format &&format) {
        _processing_format = std::move(format);
        if (_ext_audio_file) {
            ext_audio_file_utils::set_client_format(_processing_format.stream_description(), _ext_audio_file);
        }
    }

    int64_t file_length() {
        if (_ext_audio_file) {
            return ext_audio_file_utils::get_file_length_frames(_ext_audio_file);
        }
        return 0;
    }

    int64_t processing_length() {
        auto const fileLength = file_length();
        auto const rate =
            _processing_format.stream_description().mSampleRate / _file_format.stream_description().mSampleRate;
        return fileLength * rate;
    }

    void set_file_frame_position(uint32_t const position) {
        if (_file_frame_position != position) {
            OSStatus err = ExtAudioFileSeek(_ext_audio_file, position);
            if (err == noErr) {
                _file_frame_position = position;
            }
        }
    }

    open_result_t open(open_args &&args) {
        if (_ext_audio_file) {
            return open_result_t(open_error_t::opened);
        }

        if (!args.file_url || args.pcm_format == audio::pcm_format::other) {
            return open_result_t(open_error_t::invalid_argument);
        }

        set_url(args.file_url);

        if (!_open_ext_audio_file(args.pcm_format, args.interleaved)) {
            return open_result_t(open_error_t::open_failed);
        }

        return open_result_t(nullptr);
    }

    create_result_t create(create_args &&args) {
        if (_ext_audio_file) {
            return create_result_t(create_error_t::created);
        }

        if (!args.file_url || !args.file_type || !args.settings) {
            return create_result_t(create_error_t::invalid_argument);
        }

        set_url(args.file_url);
        set_file_type(args.file_type);

        if (!_create_ext_audio_file(args.settings, args.pcm_format, args.interleaved)) {
            return create_result_t(create_error_t::create_failed);
        }

        return create_result_t(nullptr);
    }

    void close() {
        if (_ext_audio_file) {
            ext_audio_file_utils::dispose(_ext_audio_file);
            _ext_audio_file = nullptr;
        }
    }

    bool is_opened() const {
        return _ext_audio_file != nullptr;
    }

    read_result_t read_into_buffer(audio::pcm_buffer &buffer, uint32_t const frame_length) {
        if (!_ext_audio_file) {
            return read_result_t(read_error_t::closed);
        }

        if (!buffer) {
            return read_result_t(read_error_t::invalid_argument);
        }

        if (buffer.format() != _processing_format) {
            return read_result_t(read_error_t::invalid_format);
        }

        OSStatus err = noErr;
        uint32_t out_frame_length = 0;
        uint32_t remain_frames = frame_length > 0 ?: buffer.frame_capacity();

        auto const &format = buffer.format();
        uint32_t const buffer_count = format.buffer_count();
        uint32_t const stride = format.stride();

        if (auto abl_ptr = allocate_audio_buffer_list(buffer_count, 0, 0).first) {
            AudioBufferList *io_abl = abl_ptr.get();

            while (remain_frames) {
                uint32_t bytesPerFrame = format.stream_description().mBytesPerFrame;
                uint32_t dataByteSize = remain_frames * bytesPerFrame;
                uint32_t dataIndex = out_frame_length * bytesPerFrame;

                for (NSInteger i = 0; i < buffer_count; i++) {
                    AudioBuffer *ab = &io_abl->mBuffers[i];
                    ab->mNumberChannels = stride;
                    ab->mDataByteSize = dataByteSize;
                    uint8_t *byte_data = static_cast<uint8_t *>(buffer.audio_buffer_list()->mBuffers[i].mData);
                    ab->mData = &byte_data[dataIndex];
                }

                UInt32 io_frames = remain_frames;

                err = ExtAudioFileRead(_ext_audio_file, &io_frames, io_abl);
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
            err = ExtAudioFileTell(_ext_audio_file, &_file_frame_position);
            if (err != noErr) {
                return read_result_t(read_error_t::tell_failed);
            }
        }

        return read_result_t(nullptr);
    }

    write_result_t write_from_buffer(audio::pcm_buffer const &buffer, bool const async) {
        if (!_ext_audio_file) {
            return write_result_t(write_error_t::closed);
        }

        if (!buffer) {
            return write_result_t(write_error_t::invalid_argument);
        }

        if (buffer.format() != _processing_format) {
            return write_result_t(write_error_t::invalid_format);
        }

        OSStatus err = noErr;

        if (async) {
            err = ExtAudioFileWriteAsync(_ext_audio_file, buffer.frame_length(), buffer.audio_buffer_list());
        } else {
            err = ExtAudioFileWrite(_ext_audio_file, buffer.frame_length(), buffer.audio_buffer_list());
        }

        if (err != noErr) {
            return write_result_t(write_error_t::write_failed);
        } else {
            err = ExtAudioFileTell(_ext_audio_file, &_file_frame_position);
            if (err != noErr) {
                return write_result_t(write_error_t::tell_failed);
            }
        }

        return write_result_t(nullptr);
    }

   private:
    bool _open_ext_audio_file(pcm_format const pcm_format, bool const interleaved) {
        if (!ext_audio_file_utils::can_open(url())) {
            return false;
        }

        if (!ext_audio_file_utils::open(&_ext_audio_file, url())) {
            _ext_audio_file = nullptr;
            return false;
        };

        AudioStreamBasicDescription asbd;
        if (!ext_audio_file_utils::get_audio_file_format(&asbd, _ext_audio_file)) {
            close();
            return false;
        }

        AudioFileTypeID file_type_id = ext_audio_file_utils::get_audio_file_type_id(_ext_audio_file);
        set_file_type(to_file_type(file_type_id));
        if (!file_type()) {
            close();
            return false;
        }

        _file_format = format{asbd};

        _processing_format = format{{.sample_rate = _file_format.sample_rate(),
                                     .channel_count = _file_format.channel_count(),
                                     .pcm_format = pcm_format,
                                     .interleaved = interleaved}};

        if (!ext_audio_file_utils::set_client_format(_processing_format.stream_description(), _ext_audio_file)) {
            close();
            return false;
        }

        return true;
    }

    bool _create_ext_audio_file(CFDictionaryRef const &settings, pcm_format const pcm_format, bool const interleaved) {
        _file_format = format{settings};

        AudioFileTypeID file_type_id = to_audio_file_type_id(file_type());
        if (!file_type_id) {
            return false;
        }

        if (!ext_audio_file_utils::create(&_ext_audio_file, url(), file_type_id, _file_format.stream_description())) {
            _ext_audio_file = nullptr;
            return false;
        }

        _processing_format = format{{.sample_rate = _file_format.sample_rate(),
                                     .channel_count = _file_format.channel_count(),
                                     .pcm_format = pcm_format,
                                     .interleaved = interleaved}};

        if (!ext_audio_file_utils::set_client_format(_processing_format.stream_description(), _ext_audio_file)) {
            close();
            return false;
        }

        return true;
    }

    CFURLRef _url = nullptr;
    CFStringRef _file_type = nullptr;
};

audio::file::file() : base(std::make_shared<impl>()) {
}

audio::file::file(std::nullptr_t) : base(nullptr) {
}

audio::file::~file() = default;

audio::file::open_result_t audio::file::open(open_args args) {
    return impl_ptr<impl>()->open(std::move(args));
}

audio::file::create_result_t audio::file::create(create_args args) {
    return impl_ptr<impl>()->create(std::move(args));
}

void audio::file::close() {
    impl_ptr<impl>()->close();
}

bool audio::file::is_opened() const {
    return impl_ptr<impl>()->is_opened();
}

CFURLRef audio::file::url() const {
    return impl_ptr<impl>()->url();
}

CFStringRef audio::file::file_type() const {
    return impl_ptr<impl>()->file_type();
}

audio::format const &audio::file::file_format() const {
    return impl_ptr<impl>()->_file_format;
}

audio::format const &audio::file::processing_format() const {
    return impl_ptr<impl>()->_processing_format;
}

int64_t audio::file::file_length() const {
    return impl_ptr<impl>()->file_length();
}

int64_t audio::file::processing_length() const {
    return impl_ptr<impl>()->processing_length();
}

int64_t audio::file::file_frame_position() const {
    return impl_ptr<impl>()->_file_frame_position;
}

void audio::file::set_processing_format(audio::format format) {
    impl_ptr<impl>()->set_processing_format(std::move(format));
}

void audio::file::set_file_frame_position(uint32_t const position) {
    return impl_ptr<impl>()->set_file_frame_position(position);
}

audio::file::read_result_t audio::file::read_into_buffer(audio::pcm_buffer &buffer, uint32_t const frame_length) {
    return impl_ptr<impl>()->read_into_buffer(buffer, frame_length);
}

audio::file::write_result_t audio::file::write_from_buffer(audio::pcm_buffer const &buffer, bool const async) {
    return impl_ptr<impl>()->write_from_buffer(buffer, async);
}

audio::file::make_opened_result_t audio::make_opened_file(file::open_args args) {
    audio::file file;
    if (auto result = file.open(std::move(args))) {
        return file::make_opened_result_t{std::move(file)};
    } else {
        return file::make_opened_result_t{std::move(result.error())};
    }
}

audio::file::make_created_result_t audio::make_created_file(file::create_args args) {
    audio::file file;
    if (auto result = file.create(std::move(args))) {
        return file::make_created_result_t{std::move(file)};
    } else {
        return file::make_created_result_t{std::move(result.error())};
    }
}

std::string yas::to_string(audio::file::open_error_t const &error_t) {
    switch (error_t) {
        case audio::file::open_error_t::opened:
            return "opened";
        case audio::file::open_error_t::invalid_argument:
            return "invalid_argument";
        case audio::file::open_error_t::open_failed:
            return "open_failed";
    }
}

std::string yas::to_string(audio::file::read_error_t const &error_t) {
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

std::string yas::to_string(audio::file::create_error_t const &error_t) {
    switch (error_t) {
        case audio::file::create_error_t::created:
            return "created";
        case audio::file::create_error_t::invalid_argument:
            return "invalid_argument";
        case audio::file::create_error_t::create_failed:
            return "create_failed";
    }
}

std::string yas::to_string(audio::file::write_error_t const &error_t) {
    switch (error_t) {
        case audio::file::write_error_t::closed:
            return "closed";
        case audio::file::write_error_t::invalid_argument:
            return "invalid_argument";
        case audio::file::write_error_t::invalid_format:
            return "invalid_format";
        case audio::file::write_error_t::write_failed:
            return "write_failed";
        case audio::file::write_error_t::tell_failed:
            return "tell_failed";
    }
}

std::ostream &operator<<(std::ostream &os, yas::audio::file::open_error_t const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::audio::file::read_error_t const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::audio::file::create_error_t const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::audio::file::write_error_t const &value) {
    os << to_string(value);
    return os;
}
