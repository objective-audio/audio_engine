//
//  yas_audio_file.h
//

#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <memory>
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_types.h"

namespace yas {
namespace audio {
    class file {
       public:
        struct open_args {
            CFURLRef file_url = nullptr;
            pcm_format pcm_format = pcm_format::float32;
            bool interleaved = false;
        };

        struct create_args {
            CFURLRef file_url = nullptr;
            CFStringRef file_type = nullptr;
            CFDictionaryRef settings = nullptr;
            pcm_format pcm_format = pcm_format::float32;
            bool interleaved = false;
        };

        enum class open_error_t : UInt32 {
            opened,
            invalid_argument,
            open_failed,
        };

        enum class read_error_t : UInt32 {
            closed,
            invalid_argument,
            invalid_format,
            read_failed,
            tell_failed,
        };

        enum class create_error_t : UInt32 {
            created,
            invalid_argument,
            create_failed,
        };

        enum class write_error_t : UInt32 {
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

        file();
        virtual ~file() = default;

        file(file const &) = default;
        file(file &&) = default;
        file &operator=(file const &) = default;
        file &operator=(file &&) = default;

        explicit operator bool() const;

        CFURLRef url() const;
        audio::format const &file_format() const;
        void set_processing_format(audio::format const &format);
        audio::format const &processing_format() const;
        SInt64 file_length() const;
        SInt64 processing_length() const;
        void set_file_frame_position(UInt32 const position);
        SInt64 file_frame_position() const;

        open_result_t open(open_args);
        create_result_t create(create_args);
        void close();

        read_result_t read_into_buffer(audio::pcm_buffer &buffer, UInt32 const frame_length = 0);
        write_result_t write_from_buffer(audio::pcm_buffer const &buffer, bool const async = false);

       protected:
        class impl;
        std::shared_ptr<impl> _impl;
    };
}

std::string to_string(audio::file::open_error_t const &);
std::string to_string(audio::file::read_error_t const &);
std::string to_string(audio::file::create_error_t const &);
std::string to_string(audio::file::write_error_t const &);
}
