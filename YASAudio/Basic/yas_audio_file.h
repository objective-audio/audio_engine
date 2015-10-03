//
//  yas_audio_file.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_pcm_buffer.h"
#include <memory>
#include <CoreFoundation/CoreFoundation.h>

namespace yas
{
    class audio_file
    {
       public:
        virtual ~audio_file();

        CFURLRef url() const;
        audio_format &file_format() const;
        void set_processing_format(const audio_format &format);
        audio_format &processing_format() const;
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
        enum class create_error_t : UInt32 {
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

        using create_result_t = result<audio_file_reader_sptr, create_error_t>;
        using read_result_t = result<std::nullptr_t, read_error_t>;

        static create_result_t create(const CFURLRef file_url, const pcm_format pcm_format = pcm_format::float32,
                                      const bool interleaved = false);

        ~audio_file_reader();

        read_result_t read_into_buffer(audio_pcm_buffer &buffer, const UInt32 frame_length = 0);

       private:
        audio_file_reader();
        audio_file_reader(const audio_file_reader &) = delete;
        audio_file_reader(audio_file_reader &&) = delete;
        audio_file_reader &operator=(const audio_file_reader &) = delete;
        audio_file_reader &operator=(audio_file_reader &&) = delete;
    };

    std::string to_string(const audio_file_reader::create_error_t &);
    std::string to_string(const audio_file_reader::read_error_t &);

    class audio_file_writer : public audio_file
    {
       public:
        enum class create_error_t : UInt32 {
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

        using create_result_t = result<audio_file_writer_sptr, create_error_t>;
        using write_result_t = result<std::nullptr_t, write_error_t>;

        static create_result_t create(const CFURLRef file_url, const CFStringRef file_type,
                                      const CFDictionaryRef settings, const pcm_format pcm_format = pcm_format::float32,
                                      const bool interleaved = false);

        ~audio_file_writer();

        write_result_t write_from_buffer(const audio_pcm_buffer &buffer, const bool async = false);

       private:
        audio_file_writer();
        audio_file_writer(const audio_file_writer &) = delete;
        audio_file_writer(audio_file_writer &&) = delete;
        audio_file_writer &operator=(const audio_file_writer &) = delete;
        audio_file_writer &operator=(audio_file_writer &&) = delete;
    };

    std::string to_string(const audio_file_writer::create_error_t &);
    std::string to_string(const audio_file_writer::write_error_t &);
}
