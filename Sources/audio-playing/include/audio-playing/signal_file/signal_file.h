//
//  signal_file.h
//

#pragma once

#include <audio-engine/pcm_buffer/pcm_buffer.h>
#include <audio-playing/common/types.h>
#include <audio-playing/signal_file/signal_file_info.h>
#include <audio-processing/event/signal_event.h>
#include <audio-processing/time/time.h>
#include <cpp-utils/result.h>

#include <ostream>
#include <string>

namespace yas::playing::signal_file {
enum class write_error {
    open_stream_failed,
    write_to_stream_failed,
    close_stream_failed,
};

enum class read_error {
    invalid_sample_type,
    out_of_range,
    open_stream_failed,
    read_from_stream_failed,
    read_count_not_match,
    close_stream_failed,
};

using write_result_t = result<std::nullptr_t, write_error>;
using read_result_t = result<std::nullptr_t, read_error>;

write_result_t write(std::string const &path, proc::signal_event const &event);
read_result_t read(std::string const &path, void *data_ptr, std::size_t const byte_length);
read_result_t read(signal_file_info const &, audio::pcm_buffer &, frame_index_t const buf_top_frame);
}  // namespace yas::playing::signal_file

namespace yas {
std::string to_string(playing::signal_file::write_error const &);
std::string to_string(playing::signal_file::read_error const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::playing::signal_file::write_error const &);
std::ostream &operator<<(std::ostream &, yas::playing::signal_file::read_error const &);
