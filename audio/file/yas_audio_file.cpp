//
//  yas_audio_file.mm
//

#include "yas_audio_file.h"

#include <AudioToolbox/AudioToolbox.h>
#include <cpp_utils/yas_cf_utils.h>
#include <cpp_utils/yas_exception.h>
#include <cpp_utils/yas_fast_each.h>
#include <cpp_utils/yas_result.h>

#include "yas_audio_pcm_buffer.h"

using namespace yas;
using namespace yas::audio;

#pragma mark -

file::file() {
}

file::~file() {
    this->close();
}

file::open_result_t file::open(open_args args) {
    if (this->_ext_audio_file) {
        return open_result_t(open_error_t::opened);
    }

    if (args.pcm_format == pcm_format::other) {
        return open_result_t(open_error_t::invalid_argument);
    }

    this->_path = args.file_path;

    if (!this->_open_ext_audio_file(args.pcm_format, args.interleaved)) {
        return open_result_t(open_error_t::open_failed);
    }

    return open_result_t(nullptr);
}

file::create_result_t file::create(create_args args) {
    if (this->_ext_audio_file) {
        return create_result_t(create_error_t::created);
    }

    if (!args.settings) {
        return create_result_t(create_error_t::invalid_argument);
    }

    this->_path = args.file_path;
    this->_file_type = args.file_type;

    if (!this->_create_ext_audio_file(args.settings, args.pcm_format, args.interleaved)) {
        return create_result_t(create_error_t::create_failed);
    }

    return create_result_t(nullptr);
}

void file::close() {
    if (this->_ext_audio_file) {
        ext_audio_file_utils::dispose(this->_ext_audio_file.value());
        this->_ext_audio_file = std::nullopt;
    }
}

bool file::is_opened() const {
    return this->_ext_audio_file != nullptr;
}

std::filesystem::path const &file::path() const {
    return *this->_path;
}

audio::file_type file::file_type() const {
    return this->_file_type;
}

format const &file::file_format() const {
    return *this->_file_format;
}

format const &file::processing_format() const {
    return *this->_processing_format;
}

int64_t file::file_length() const {
    if (this->_ext_audio_file) {
        return ext_audio_file_utils::get_file_length_frames(this->_ext_audio_file.value());
    }
    return 0;
}

int64_t file::processing_length() const {
    if (!this->_processing_format || !this->_file_format) {
        return 0;
    }

    auto const fileLength = file_length();
    auto const rate = this->_processing_format->stream_description().mSampleRate /
                      this->_file_format->stream_description().mSampleRate;
    return fileLength * rate;
}

int64_t file::file_frame_position() const {
    return this->_file_frame_position;
}

void file::set_processing_format(format format) {
    this->_processing_format = std::move(format);
    if (this->_ext_audio_file) {
        ext_audio_file_utils::set_client_format(this->_processing_format->stream_description(),
                                                this->_ext_audio_file.value());
    }
}

void file::set_file_frame_position(uint32_t const position) {
    if (this->_ext_audio_file && this->_file_frame_position != position) {
        OSStatus err = ExtAudioFileSeek(this->_ext_audio_file.value(), position);
        if (err == noErr) {
            this->_file_frame_position = position;
        }
    }
}

file::read_result_t file::read_into_buffer(pcm_buffer &buffer, uint32_t const frame_length) {
    if (!this->_ext_audio_file) {
        return read_result_t(read_error_t::closed);
    }

    if (buffer.format() != this->_processing_format) {
        return read_result_t(read_error_t::invalid_format);
    }

    if (buffer.frame_capacity() < frame_length) {
        return read_result_t(read_error_t::frame_length_out_of_range);
    }

    OSStatus err = noErr;
    uint32_t out_frame_length = 0;
    uint32_t remain_frames = frame_length > 0 ? frame_length : buffer.frame_capacity();

    auto const &format = buffer.format();
    uint32_t const buffer_count = format.buffer_count();
    uint32_t const stride = format.stride();

    if (auto abl_ptr = allocate_audio_buffer_list(buffer_count, 0, 0).first) {
        AudioBufferList *io_abl = abl_ptr.get();

        while (remain_frames) {
            uint32_t bytesPerFrame = format.stream_description().mBytesPerFrame;
            uint32_t dataByteSize = remain_frames * bytesPerFrame;
            uint32_t dataIndex = out_frame_length * bytesPerFrame;

            auto each = make_fast_each(buffer_count);
            while (yas_each_next(each)) {
                auto const &idx = yas_each_index(each);
                AudioBuffer *ab = &io_abl->mBuffers[idx];
                ab->mNumberChannels = stride;
                ab->mDataByteSize = dataByteSize;
                uint8_t *byte_data = static_cast<uint8_t *>(buffer.audio_buffer_list()->mBuffers[idx].mData);
                ab->mData = &byte_data[dataIndex];
            }

            UInt32 io_frames = remain_frames;

            err = ExtAudioFileRead(this->_ext_audio_file.value(), &io_frames, io_abl);
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
        err = ExtAudioFileTell(this->_ext_audio_file.value(), &this->_file_frame_position);
        if (err != noErr) {
            return read_result_t(read_error_t::tell_failed);
        }
    }

    return read_result_t(nullptr);
}

file::write_result_t file::write_from_buffer(pcm_buffer const &buffer, bool const async) {
    if (!this->_ext_audio_file) {
        return write_result_t(write_error_t::closed);
    }

    ExtAudioFileRef const &ext_audio_file = this->_ext_audio_file.value();

    if (buffer.format() != this->_processing_format) {
        return write_result_t(write_error_t::invalid_format);
    }

    OSStatus err = noErr;

    if (async) {
        err = ExtAudioFileWriteAsync(ext_audio_file, buffer.frame_length(), buffer.audio_buffer_list());
    } else {
        err = ExtAudioFileWrite(ext_audio_file, buffer.frame_length(), buffer.audio_buffer_list());
    }

    if (err != noErr) {
        return write_result_t(write_error_t::write_failed);
    } else {
        err = ExtAudioFileTell(ext_audio_file, &this->_file_frame_position);
        if (err != noErr) {
            return write_result_t(write_error_t::tell_failed);
        }
    }

    return write_result_t(nullptr);
}

#pragma mark - private

bool file::_open_ext_audio_file(pcm_format const pcm_format, bool const interleaved) {
    if (!ext_audio_file_utils::can_open(this->_path.value())) {
        return false;
    }

    ExtAudioFileRef ext_audio_file = nullptr;
    if (!ext_audio_file_utils::open(&ext_audio_file, this->_path.value())) {
        this->_ext_audio_file = std::nullopt;
        return false;
    };
    this->_ext_audio_file = ext_audio_file;

    AudioStreamBasicDescription asbd;
    if (!ext_audio_file_utils::get_audio_file_format(&asbd, ext_audio_file)) {
        this->close();
        return false;
    }

    AudioFileTypeID file_type_id = ext_audio_file_utils::get_audio_file_type_id(ext_audio_file);

    try {
        this->_file_type = to_file_type(file_type_id);
    } catch (std::exception const &) {
        this->close();
        return false;
    }

    this->_file_format = format{asbd};

    this->_processing_format = format{{.sample_rate = _file_format->sample_rate(),
                                       .channel_count = this->_file_format->channel_count(),
                                       .pcm_format = pcm_format,
                                       .interleaved = interleaved}};

    if (!ext_audio_file_utils::set_client_format(this->_processing_format->stream_description(), ext_audio_file)) {
        this->close();
        return false;
    }

    return true;
}

bool file::_create_ext_audio_file(CFDictionaryRef const &settings, pcm_format const pcm_format,
                                  bool const interleaved) {
    this->_file_format = format{settings};

    AudioFileTypeID file_type_id = to_audio_file_type_id(this->_file_type);

    ExtAudioFileRef ext_audio_file = nullptr;
    if (!ext_audio_file_utils::create(&ext_audio_file, this->_path.value(), file_type_id,
                                      this->_file_format->stream_description())) {
        this->_ext_audio_file = std::nullopt;
        return false;
    }
    this->_ext_audio_file = ext_audio_file;

    this->_processing_format = format{{.sample_rate = this->_file_format->sample_rate(),
                                       .channel_count = this->_file_format->channel_count(),
                                       .pcm_format = pcm_format,
                                       .interleaved = interleaved}};

    if (!ext_audio_file_utils::set_client_format(this->_processing_format->stream_description(), ext_audio_file)) {
        this->close();
        return false;
    }

    return true;
}

#pragma mark -

file_ptr file::make_shared() {
    return file_ptr(new file{});
}

file::make_opened_result_t file::make_opened(file::open_args args) {
    auto file = make_shared();
    if (auto result = file->open(std::move(args))) {
        return file::make_opened_result_t{std::move(file)};
    } else {
        return file::make_opened_result_t{std::move(result.error())};
    }
}

file::make_created_result_t file::make_created(file::create_args args) {
    auto file = make_shared();
    if (auto result = file->create(std::move(args))) {
        return file::make_created_result_t{std::move(file)};
    } else {
        return file::make_created_result_t{std::move(result.error())};
    }
}

std::string yas::to_string(file::open_error_t const &error_t) {
    switch (error_t) {
        case file::open_error_t::opened:
            return "opened";
        case file::open_error_t::invalid_argument:
            return "invalid_argument";
        case file::open_error_t::open_failed:
            return "open_failed";
    }
}

std::string yas::to_string(file::read_error_t const &error_t) {
    switch (error_t) {
        case file::read_error_t::closed:
            return "closed";
        case file::read_error_t::invalid_format:
            return "invalid_format";
        case file::read_error_t::read_failed:
            return "read_failed";
        case file::read_error_t::tell_failed:
            return "tell_failed";
        case file::read_error_t::frame_length_out_of_range:
            return "frame_length_out_of_range";
    }
}

std::string yas::to_string(file::create_error_t const &error_t) {
    switch (error_t) {
        case file::create_error_t::created:
            return "created";
        case file::create_error_t::invalid_argument:
            return "invalid_argument";
        case file::create_error_t::create_failed:
            return "create_failed";
    }
}

std::string yas::to_string(file::write_error_t const &error_t) {
    switch (error_t) {
        case file::write_error_t::closed:
            return "closed";
        case file::write_error_t::invalid_format:
            return "invalid_format";
        case file::write_error_t::write_failed:
            return "write_failed";
        case file::write_error_t::tell_failed:
            return "tell_failed";
    }
}

std::ostream &operator<<(std::ostream &os, file::open_error_t const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, file::read_error_t const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, file::create_error_t const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, file::write_error_t const &value) {
    os << to_string(value);
    return os;
}
