//
//  yas_audio_file.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_file_utils.h"
#include "yas_audio_pcm_buffer.h"
#include <memory>
#include <Foundation/Foundation.h>

namespace yas
{
    class audio_file
    {
       public:
        virtual ~audio_file();

        CFURLRef url() const;
        audio_format_sptr file_format() const;
        void set_processing_format(const audio_format_sptr &format);
        audio_format_sptr processing_format() const;
        SInt64 file_length() const;
        SInt64 processing_length() const;
        void set_file_frame_position(const UInt32 position);
        SInt64 file_frame_position() const;

        void close();

       protected:
        class impl;
        std::unique_ptr<impl> _impl;

        audio_file();

       private:
        audio_file(const audio_file &) = delete;
        audio_file(audio_file &&) = delete;
        audio_file &operator=(const audio_file &) = delete;
        audio_file &operator=(audio_file &&) = delete;
    };

    class audio_file_reader : public audio_file
    {
       public:
        enum class create_error_type : UInt32 {
            invalid_argument,
            open_failed,
        };

        enum class read_error_type : UInt32 {
            closed,
            invalid_argument,
            invalid_format,
            read_failed,
            tell_failed,
        };

        using create_result = result<audio_file_reader_sptr, create_error_type>;
        using read_result = result<std::nullptr_t, read_error_type>;

        static create_result create(const CFURLRef file_url, const pcm_format pcm_format = pcm_format::float32,
                                    const bool interleaved = false);

        ~audio_file_reader();

        read_result read_into_buffer(audio_pcm_buffer_sptr &buffer, const UInt32 frame_length = 0);

       private:
        audio_file_reader();
        audio_file_reader(const audio_file_reader &) = delete;
        audio_file_reader(audio_file_reader &&) = delete;
        audio_file_reader &operator=(const audio_file_reader &) = delete;
        audio_file_reader &operator=(audio_file_reader &&) = delete;
    };

    std::string to_string(const audio_file_reader::create_error_type &);
    std::string to_string(const audio_file_reader::read_error_type &);

    class audio_file_writer : public audio_file
    {
       public:
        enum class create_error_type : UInt32 {
            invalid_argument,
            create_failed,
        };

        enum class write_error_type : UInt32 {
            closed,
            invalid_argument,
            invalid_format,
            write_failed,
            tell_failed,
        };

        using create_result = result<audio_file_writer_sptr, create_error_type>;
        using write_result = result<std::nullptr_t, write_error_type>;

        static create_result create(const CFURLRef file_url, const CFStringRef file_type,
                                    const CFDictionaryRef settings, const pcm_format pcm_format = pcm_format::float32,
                                    const bool interleaved = false);

        ~audio_file_writer();

        write_result write_from_buffer(const audio_pcm_buffer_sptr &buffer, const bool async = false);

       private:
        audio_file_writer();
        audio_file_writer(const audio_file_writer &) = delete;
        audio_file_writer(audio_file_writer &&) = delete;
        audio_file_writer &operator=(const audio_file_writer &) = delete;
        audio_file_writer &operator=(audio_file_writer &&) = delete;
    };

    std::string to_string(const audio_file_writer::create_error_type &);
    std::string to_string(const audio_file_writer::write_error_type &);
}
