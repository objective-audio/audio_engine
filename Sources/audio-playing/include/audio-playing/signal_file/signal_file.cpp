//
//  signal_file.cpp
//

#include "signal_file.h"

#include <audio-engine/common/types.h>
#include <audio-engine/format/format.h>
#include <audio-playing/timeline/timeline_utils.h>

#include <fstream>

using namespace yas;
using namespace yas::playing;

signal_file::write_result_t signal_file::write(std::string const &path, proc::signal_event const &event) {
    std::ofstream stream{path, std::ios_base::out | std::ios_base::binary};
    if (!stream) {
        return write_result_t{write_error::open_stream_failed};
    }

    if (char const *data = timeline_utils::char_data(event)) {
        stream.write(data, event.byte_size());

        if (stream.fail()) {
            return write_result_t{write_error::write_to_stream_failed};
        }
    }

    stream.close();

    if (stream.fail()) {
        return write_result_t{write_error::close_stream_failed};
    }

    return write_result_t{nullptr};
}

signal_file::read_result_t signal_file::read(std::string const &path, void *data_ptr, std::size_t const length) {
    auto stream = std::fstream{path, std::ios_base::in | std::ios_base::binary};
    if (!stream) {
        return read_result_t{read_error::open_stream_failed};
    }

    stream.read(reinterpret_cast<char *>(data_ptr), length);
    if (stream.fail()) {
        return read_result_t{read_error::read_from_stream_failed};
    }

    if (stream.gcount() != length) {
        return read_result_t{read_error::read_count_not_match};
    }

    stream.close();
    if (stream.fail()) {
        return read_result_t{read_error::close_stream_failed};
    }

    return read_result_t{nullptr};
}

signal_file::read_result_t signal_file::read(signal_file_info const &info, audio::pcm_buffer &buffer,
                                             frame_index_t const buf_top_frame) {
    if (info.sample_type != yas::to_sample_type(buffer.format().pcm_format())) {
        return read_result_t{read_error::invalid_sample_type};
    }

    frame_index_t const buf_next_frame = buf_top_frame + buffer.frame_length();

    if (info.range.frame < buf_top_frame || buf_next_frame < info.range.next_frame()) {
        return read_result_t{read_error::out_of_range};
    }

    std::size_t const sample_byte_count = buffer.format().sample_byte_count();
    frame_index_t const frame = (info.range.frame - buf_top_frame) * sample_byte_count;
    length_t const length = info.range.length * sample_byte_count;
    char *data_ptr = timeline_utils::char_data(buffer);

    return read(info.path, &data_ptr[frame], length);
}

std::string yas::to_string(signal_file::write_error const &error) {
    switch (error) {
        case signal_file::write_error::open_stream_failed:
            return "open_stream_failed";
        case signal_file::write_error::write_to_stream_failed:
            return "write_to_stream_failed";
        case signal_file::write_error::close_stream_failed:
            return "close_stream_failed";
    }
}

std::string yas::to_string(signal_file::read_error const &error) {
    switch (error) {
        case signal_file::read_error::invalid_sample_type:
            return "invalid_sample_type";
        case signal_file::read_error::out_of_range:
            return "out_of_range";
        case signal_file::read_error::open_stream_failed:
            return "open_stream_failed";
        case signal_file::read_error::read_from_stream_failed:
            return "read_from_stream_failed";
        case signal_file::read_error::read_count_not_match:
            return "read_count_not_match";
        case signal_file::read_error::close_stream_failed:
            return "close_stream_failed";
    }
}

std::ostream &operator<<(std::ostream &os, yas::playing::signal_file::write_error const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::playing::signal_file::read_error const &value) {
    os << to_string(value);
    return os;
}
