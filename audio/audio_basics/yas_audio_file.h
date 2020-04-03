//
//  yas_audio_file.h
//

#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <cpp_utils/yas_url.h>

#include <ostream>

#include "yas_audio_file_utils.h"
#include "yas_audio_format.h"
#include "yas_audio_ptr.h"
#include "yas_audio_types.h"

namespace yas {
template <typename T, typename U>
class result;
}

namespace yas::audio {
class pcm_buffer;

struct file final {
    struct open_args {
        url file_url;
        audio::pcm_format pcm_format = pcm_format::float32;
        bool interleaved = false;
    };

    struct create_args {
        url file_url;
        audio::file_type file_type = audio::file_type::wave;
        CFDictionaryRef settings = nullptr;
        audio::pcm_format pcm_format = pcm_format::float32;
        bool interleaved = false;
    };

    enum class open_error_t : uint32_t {
        opened,
        invalid_argument,
        open_failed,
    };

    enum class read_error_t : uint32_t {
        closed,
        invalid_format,
        read_failed,
        tell_failed,
        frame_length_out_of_range,
    };

    enum class create_error_t : uint32_t {
        created,
        invalid_argument,
        create_failed,
    };

    enum class write_error_t : uint32_t {
        closed,
        invalid_format,
        write_failed,
        tell_failed,
    };

    using open_result_t = result<std::nullptr_t, open_error_t>;
    using read_result_t = result<std::nullptr_t, read_error_t>;
    using create_result_t = result<std::nullptr_t, create_error_t>;
    using write_result_t = result<std::nullptr_t, write_error_t>;
    using make_opened_result_t = result<audio::file_ptr, open_error_t>;
    using make_created_result_t = result<audio::file_ptr, create_error_t>;

    ~file();

    open_result_t open(open_args);
    create_result_t create(create_args);
    void close();

    bool is_opened() const;
    yas::url const &url() const;
    audio::file_type file_type() const;
    audio::format const &file_format() const;
    audio::format const &processing_format() const;
    int64_t file_length() const;
    int64_t processing_length() const;
    int64_t file_frame_position() const;

    void set_processing_format(audio::format format);
    void set_file_frame_position(uint32_t const position);

    read_result_t read_into_buffer(audio::pcm_buffer &buffer, uint32_t const frame_length = 0);
    write_result_t write_from_buffer(audio::pcm_buffer const &buffer, bool const async = false);

    static file_ptr make_shared();
    static file::make_opened_result_t make_opened(file::open_args);
    static file::make_created_result_t make_created(file::create_args);

   private:
    std::optional<format> _file_format = std::nullopt;
    std::optional<format> _processing_format = std::nullopt;
    int64_t _file_frame_position = 0;
    std::optional<ExtAudioFileRef> _ext_audio_file = std::nullopt;
    std::optional<yas::url> _url = std::nullopt;
    audio::file_type _file_type;

    bool _open_ext_audio_file(pcm_format const pcm_format, bool const interleaved);
    bool _create_ext_audio_file(CFDictionaryRef const &settings, pcm_format const pcm_format, bool const interleaved);

    file();

    file(file const &) = delete;
    file(file &&) = delete;
    file &operator=(file const &) = delete;
    file &operator=(file &&) = delete;
};
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::file::open_error_t const &);
std::string to_string(audio::file::read_error_t const &);
std::string to_string(audio::file::create_error_t const &);
std::string to_string(audio::file::write_error_t const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::audio::file::open_error_t const &);
std::ostream &operator<<(std::ostream &, yas::audio::file::read_error_t const &);
std::ostream &operator<<(std::ostream &, yas::audio::file::create_error_t const &);
std::ostream &operator<<(std::ostream &, yas::audio::file::write_error_t const &);
