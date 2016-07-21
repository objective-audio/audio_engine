//
//  yas_audio_file.h
//

#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include "yas_audio_types.h"
#include "yas_base.h"

namespace yas {
template <typename T, typename U>
class result;

namespace audio {
    class format;
    class pcm_buffer;

    class file : public base {
        class impl;

       public:
        struct open_args {
            CFURLRef file_url = nullptr;
            audio::pcm_format pcm_format = pcm_format::float32;
            bool interleaved = false;
        };

        struct create_args {
            CFURLRef file_url = nullptr;
            CFStringRef file_type = nullptr;
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
            invalid_argument,
            invalid_format,
            read_failed,
            tell_failed,
        };

        enum class create_error_t : uint32_t {
            created,
            invalid_argument,
            create_failed,
        };

        enum class write_error_t : uint32_t {
            closed,
            invalid_argument,
            invalid_format,
            write_failed,
            tell_failed,
        };

        using open_result_t = result<std::nullptr_t, open_error_t>;
        using read_result_t = result<std::nullptr_t, read_error_t>;
        using create_result_t = result<std::nullptr_t, create_error_t>;
        using write_result_t = result<std::nullptr_t, write_error_t>;
        using make_opened_result_t = result<audio::file, open_error_t>;
        using make_created_result_t = result<audio::file, create_error_t>;

        file();
        file(std::nullptr_t);

        open_result_t open(open_args);
        create_result_t create(create_args);
        void close();

        bool is_opened() const;
        CFURLRef url() const;
        CFStringRef file_type() const;
        audio::format const &file_format() const;
        audio::format const &processing_format() const;
        int64_t file_length() const;
        int64_t processing_length() const;
        int64_t file_frame_position() const;

        void set_processing_format(audio::format format);
        void set_file_frame_position(uint32_t const position);

        read_result_t read_into_buffer(audio::pcm_buffer &buffer, uint32_t const frame_length = 0);
        write_result_t write_from_buffer(audio::pcm_buffer const &buffer, bool const async = false);
    };

    file::make_opened_result_t make_opened_file(file::open_args);
    file::make_created_result_t make_created_file(file::create_args);
}

std::string to_string(audio::file::open_error_t const &);
std::string to_string(audio::file::read_error_t const &);
std::string to_string(audio::file::create_error_t const &);
std::string to_string(audio::file::write_error_t const &);
}

std::ostream &operator<<(std::ostream &, yas::audio::file::open_error_t const &);
std::ostream &operator<<(std::ostream &, yas::audio::file::read_error_t const &);
std::ostream &operator<<(std::ostream &, yas::audio::file::create_error_t const &);
std::ostream &operator<<(std::ostream &, yas::audio::file::write_error_t const &);
