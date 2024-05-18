//
//  signal_file_info.cpp
//

#include "signal_file_info.h"

#include <audio-playing/common/path.h>
#include <cpp-utils/boolean.h>
#include <cpp-utils/stl_utils.h>
#include <cpp-utils/to_integer.h>

using namespace yas;
using namespace yas::playing;

signal_file_info::signal_file_info(std::string const &path, proc::time::range const &range,
                                   std::type_info const &sample_type)
    : path(path), range(range), sample_type(sample_type) {
}

std::string signal_file_info::file_name() const {
    return to_signal_file_name(this->range, this->sample_type);
}

std::string playing::to_signal_file_name(proc::time::range const &range, std::type_info const &sample_type) {
    return "signal_" + std::to_string(range.frame) + "_" + std::to_string(range.length) + "_" +
           to_sample_type_name(sample_type);
}

std::string playing::to_sample_type_name(std::type_info const &type_info) {
    if (type_info == typeid(double)) {
        return "f64";
    } else if (type_info == typeid(float)) {
        return "f32";
    } else if (type_info == typeid(int64_t)) {
        return "i64";
    } else if (type_info == typeid(uint64_t)) {
        return "u64";
    } else if (type_info == typeid(int32_t)) {
        return "i32";
    } else if (type_info == typeid(uint32_t)) {
        return "u32";
    } else if (type_info == typeid(int16_t)) {
        return "i16";
    } else if (type_info == typeid(uint16_t)) {
        return "u16";
    } else if (type_info == typeid(int8_t)) {
        return "i8";
    } else if (type_info == typeid(uint8_t)) {
        return "u8";
    } else if (type_info == typeid(boolean)) {
        return "b";
    } else {
        return "";
    }
}

std::type_info const &playing::to_sample_type(std::string const &name) {
    if (name == "f64") {
        return typeid(double);
    } else if (name == "f32") {
        return typeid(float);
    } else if (name == "i64") {
        return typeid(int64_t);
    } else if (name == "u64") {
        return typeid(uint64_t);
    } else if (name == "i32") {
        return typeid(int32_t);
    } else if (name == "u32") {
        return typeid(uint32_t);
    } else if (name == "i16") {
        return typeid(int16_t);
    } else if (name == "u16") {
        return typeid(uint16_t);
    } else if (name == "i8") {
        return typeid(int8_t);
    } else if (name == "u8") {
        return typeid(uint8_t);
    } else if (name == "b") {
        return typeid(boolean);
    } else {
        return typeid(std::nullptr_t);
    }
}

std::optional<signal_file_info> playing::to_signal_file_info(std::filesystem::path const &path) {
    std::string const file_name = path.filename();

    std::vector<std::string> splited = split(file_name, '_');
    if (splited.size() != 4) {
        return std::nullopt;
    }

    if (splited.at(0) != "signal") {
        return std::nullopt;
    }

    std::type_info const &sample_type = to_sample_type(splited.at(3));

    if (sample_type == typeid(std::nullptr_t)) {
        return std::nullopt;
    }

    auto const frame = to_integer<frame_index_t>(splited.at(1));
    auto const length = to_integer<length_t>(splited.at(2));

    return signal_file_info{path, proc::time::range{frame, length}, sample_type};
}
