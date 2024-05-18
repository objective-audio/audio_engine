//
//  numbers_file.cpp
//

#include "numbers_file.h"

#include <audio-playing/timeline/timeline_utils.h>
#include <cpp-utils/boolean.h>

#include <fstream>

using namespace yas;
using namespace yas::playing;

numbers_file::write_result_t numbers_file::write(std::string const &path, event_map_t const &events) {
    std::ofstream stream{path, std::ios_base::out | std::ios_base::binary};
    if (stream.fail()) {
        return write_result_t{write_error::open_stream_failed};
    }

    for (auto const &event_pair : events) {
        proc::time::frame::type const &frame = event_pair.first;

        if (char const *data = timeline_utils::char_data(frame)) {
            stream.write(data, sizeof(proc::time::frame::type));
            if (stream.fail()) {
                return write_result_t{write_error::write_to_stream_failed};
            }
        }

        proc::number_event_ptr const &event = event_pair.second;

        auto const store_type = timeline_utils::to_sample_store_type(event->sample_type());
        if (char const *data = timeline_utils::char_data(store_type)) {
            stream.write(data, sizeof(sample_store_type));
            if (stream.fail()) {
                return write_result_t{write_error::write_to_stream_failed};
            }
        }

        if (char const *data = timeline_utils::char_data(*event)) {
            stream.write(data, event->sample_byte_count());
            if (stream.fail()) {
                return write_result_t{write_error::write_to_stream_failed};
            }
        }
    }

    stream.close();
    if (stream.fail()) {
        return write_result_t{write_error::close_stream_failed};
    }

    return write_result_t{nullptr};
}

namespace yas::playing::numbers_file {
using read_value_result_t = result<proc::number_event_ptr, std::nullptr_t>;

template <typename T>
read_value_result_t read_value(std::ifstream &stream) {
    T value;
    stream.read(reinterpret_cast<char *>(&value), sizeof(T));
    if (stream.fail() || stream.gcount() != sizeof(T)) {
        return read_value_result_t{nullptr};
    }
    return read_value_result_t{proc::number_event::make_shared(value)};
}
}  // namespace yas::playing::numbers_file

numbers_file::read_result_t numbers_file::read(std::string const &path) {
    std::ifstream stream{path, std::ios_base::in | std::ios_base::binary};
    if (stream.fail()) {
        return read_result_t{read_error::open_stream_failed};
    }

    event_map_t result;

    while (true) {
        proc::time::frame::type frame;
        stream.read((char *)&frame, sizeof(proc::time::frame::type));
        if (stream.eof()) {
            break;
        }
        if (stream.fail() || stream.gcount() != sizeof(proc::time::frame::type)) {
            return read_result_t{read_error::read_frame_failed};
        }

        sample_store_type store_type;
        stream.read((char *)&store_type, sizeof(sample_store_type));
        if (stream.fail() || stream.gcount() != sizeof(sample_store_type)) {
            return read_result_t{read_error::read_sample_store_type_failed};
        }

        switch (store_type) {
            case sample_store_type::float64: {
                if (auto read_result = read_value<double>(stream)) {
                    result.emplace(frame, std::move(read_result.value()));
                } else {
                    return read_result_t{read_error::read_value_failed};
                }
            } break;
            case sample_store_type::float32: {
                if (auto read_result = read_value<float>(stream)) {
                    result.emplace(frame, std::move(read_result.value()));
                } else {
                    return read_result_t{read_error::read_value_failed};
                }
            } break;
            case sample_store_type::int64: {
                if (auto read_result = read_value<int64_t>(stream)) {
                    result.emplace(frame, std::move(read_result.value()));
                } else {
                    return read_result_t{read_error::read_value_failed};
                }
            } break;
            case sample_store_type::uint64: {
                if (auto read_result = read_value<uint64_t>(stream)) {
                    result.emplace(frame, std::move(read_result.value()));
                } else {
                    return read_result_t{read_error::read_value_failed};
                }
            } break;
            case sample_store_type::int32:
                if (auto read_result = read_value<int32_t>(stream)) {
                    result.emplace(frame, std::move(read_result.value()));
                } else {
                    return read_result_t{read_error::read_value_failed};
                }
                break;
            case sample_store_type::uint32:
                if (auto read_result = read_value<uint32_t>(stream)) {
                    result.emplace(frame, std::move(read_result.value()));
                } else {
                    return read_result_t{read_error::read_value_failed};
                }
                break;
            case sample_store_type::int16:
                if (auto read_result = read_value<int16_t>(stream)) {
                    result.emplace(frame, std::move(read_result.value()));
                } else {
                    return read_result_t{read_error::read_value_failed};
                }
                break;
            case sample_store_type::uint16:
                if (auto read_result = read_value<uint16_t>(stream)) {
                    result.emplace(frame, std::move(read_result.value()));
                } else {
                    return read_result_t{read_error::read_value_failed};
                }
                break;
            case sample_store_type::int8:
                if (auto read_result = read_value<int8_t>(stream)) {
                    result.emplace(frame, std::move(read_result.value()));
                } else {
                    return read_result_t{read_error::read_value_failed};
                }
                break;
            case sample_store_type::uint8:
                if (auto read_result = read_value<uint8_t>(stream)) {
                    result.emplace(frame, std::move(read_result.value()));
                } else {
                    return read_result_t{read_error::read_value_failed};
                }
                break;
            case sample_store_type::boolean:
                bool value;
                stream.read(reinterpret_cast<char *>(&value), sizeof(bool));
                if (stream.fail() || stream.gcount() != sizeof(bool)) {
                    return read_result_t{read_error::read_value_failed};
                }
                result.emplace(frame, proc::number_event::make_shared(yas::boolean{value}));
                break;
            case sample_store_type::unknown:
                return read_result_t{read_error::sample_store_type_not_found};
        }
    }

    return read_result_t{std::move(result)};
}

std::string yas::to_string(numbers_file::write_error const &error) {
    switch (error) {
        case numbers_file::write_error::open_stream_failed:
            return "open_stream_failed";
        case numbers_file::write_error::write_to_stream_failed:
            return "write_to_stream_failed";
        case numbers_file::write_error::close_stream_failed:
            return "close_stream_failed";
    }
}

std::string yas::to_string(numbers_file::read_error const &error) {
    switch (error) {
        case numbers_file::read_error::open_stream_failed:
            return "open_stream_failed";
        case numbers_file::read_error::read_frame_failed:
            return "read_frame_failed";
        case numbers_file::read_error::read_sample_store_type_failed:
            return "read_sample_store_type_failed";
        case numbers_file::read_error::read_value_failed:
            return "read_value_failed";
        case numbers_file::read_error::sample_store_type_not_found:
            return "sample_store_type_not_found";
    }
}

std::ostream &operator<<(std::ostream &stream, numbers_file::write_error const &value) {
    stream << to_string(value);
    return stream;
}

std::ostream &operator<<(std::ostream &stream, numbers_file::read_error const &value) {
    stream << to_string(value);
    return stream;
}
