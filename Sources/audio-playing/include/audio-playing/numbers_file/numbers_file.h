//
//  numbers_file.h
//

#pragma once

#include <audio-playing/common/types.h>
#include <audio-processing/event/number_event.h>
#include <cpp-utils/result.h>

#include <ostream>
#include <string>

namespace yas::playing::numbers_file {
enum class write_error {
    open_stream_failed,
    write_to_stream_failed,
    close_stream_failed,
};

enum class read_error {
    open_stream_failed,
    read_frame_failed,
    read_sample_store_type_failed,
    read_value_failed,
    sample_store_type_not_found,
};

using event_map_t = std::multimap<playing::frame_index_t, proc::number_event_ptr>;
using write_result_t = result<std::nullptr_t, write_error>;
using read_result_t = result<event_map_t, read_error>;

write_result_t write(std::string const &path, event_map_t const &);
read_result_t read(std::string const &path);
}  // namespace yas::playing::numbers_file

namespace yas {
std::string to_string(playing::numbers_file::write_error const &);
std::string to_string(playing::numbers_file::read_error const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::playing::numbers_file::write_error const &);
std::ostream &operator<<(std::ostream &, yas::playing::numbers_file::read_error const &);
