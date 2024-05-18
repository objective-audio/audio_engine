//
//  timeline_utils.cpp
//

#include "timeline_utils.h"

#include <audio-engine/format/format.h>
#include <audio-playing/common/math.h>
#include <cpp-utils/boolean.h>

#include <fstream>

using namespace yas;
using namespace yas::playing;

proc::time::range timeline_utils::fragments_range(proc::time::range const &range, sample_rate_t const sample_rate) {
    auto const frame = math::floor_int(range.frame, sample_rate);
    auto const next_frame = math::ceil_int(range.next_frame(), sample_rate);
    return proc::time::range{frame, static_cast<length_t>(next_frame - frame)};
}

char const *timeline_utils::char_data(proc::signal_event const &event) {
    auto const &type = event.sample_type();

    if (type == typeid(double)) {
        return reinterpret_cast<char const *>(event.data<double>());
    } else if (type == typeid(float)) {
        return reinterpret_cast<char const *>(event.data<float>());
    } else if (type == typeid(int64_t)) {
        return reinterpret_cast<char const *>(event.data<int64_t>());
    } else if (type == typeid(uint64_t)) {
        return reinterpret_cast<char const *>(event.data<uint64_t>());
    } else if (type == typeid(int32_t)) {
        return reinterpret_cast<char const *>(event.data<int32_t>());
    } else if (type == typeid(uint32_t)) {
        return reinterpret_cast<char const *>(event.data<uint32_t>());
    } else if (type == typeid(int16_t)) {
        return reinterpret_cast<char const *>(event.data<int16_t>());
    } else if (type == typeid(uint16_t)) {
        return reinterpret_cast<char const *>(event.data<uint16_t>());
    } else if (type == typeid(int8_t)) {
        return reinterpret_cast<char const *>(event.data<int8_t>());
    } else if (type == typeid(uint8_t)) {
        return reinterpret_cast<char const *>(event.data<uint8_t>());
    } else if (type == typeid(boolean)) {
        return reinterpret_cast<char const *>(event.data<boolean>());
    } else {
        return nullptr;
    }
}

char const *timeline_utils::char_data(proc::time::frame::type const &frame) {
    return reinterpret_cast<char const *>(&frame);
}

char const *timeline_utils::char_data(sample_store_type const &store_type) {
    return reinterpret_cast<char const *>(&store_type);
}

char const *timeline_utils::char_data(proc::number_event const &event) {
    auto const &type = event.sample_type();

    if (type == typeid(double)) {
        return reinterpret_cast<char const *>(&event.get<double>());
    } else if (type == typeid(float)) {
        return reinterpret_cast<char const *>(&event.get<float>());
    } else if (type == typeid(int64_t)) {
        return reinterpret_cast<char const *>(&event.get<int64_t>());
    } else if (type == typeid(uint64_t)) {
        return reinterpret_cast<char const *>(&event.get<uint64_t>());
    } else if (type == typeid(int32_t)) {
        return reinterpret_cast<char const *>(&event.get<int32_t>());
    } else if (type == typeid(uint32_t)) {
        return reinterpret_cast<char const *>(&event.get<uint32_t>());
    } else if (type == typeid(int16_t)) {
        return reinterpret_cast<char const *>(&event.get<int16_t>());
    } else if (type == typeid(uint16_t)) {
        return reinterpret_cast<char const *>(&event.get<uint16_t>());
    } else if (type == typeid(int8_t)) {
        return reinterpret_cast<char const *>(&event.get<int8_t>());
    } else if (type == typeid(uint8_t)) {
        return reinterpret_cast<char const *>(&event.get<uint8_t>());
    } else if (type == typeid(boolean)) {
        return reinterpret_cast<char const *>(&event.get<boolean>().raw());
    } else {
        return nullptr;
    }
}

char *timeline_utils::char_data(audio::pcm_buffer &buffer) {
    switch (buffer.format().pcm_format()) {
        case audio::pcm_format::float32:
            return reinterpret_cast<char *>(buffer.data_ptr_at_index<float>(0));
        case audio::pcm_format::float64:
            return reinterpret_cast<char *>(buffer.data_ptr_at_index<double>(0));
        case audio::pcm_format::int16:
            return reinterpret_cast<char *>(buffer.data_ptr_at_index<int16_t>(0));
        case audio::pcm_format::fixed824:
            return reinterpret_cast<char *>(buffer.data_ptr_at_index<int32_t>(0));
        case audio::pcm_format::other:
            return nullptr;
    }
}

sample_store_type timeline_utils::to_sample_store_type(std::type_info const &type) {
    if (type == typeid(double)) {
        return sample_store_type::float64;
    } else if (type == typeid(float)) {
        return sample_store_type::float32;
    } else if (type == typeid(int64_t)) {
        return sample_store_type::int64;
    } else if (type == typeid(uint64_t)) {
        return sample_store_type::uint64;
    } else if (type == typeid(int32_t)) {
        return sample_store_type::int32;
    } else if (type == typeid(uint32_t)) {
        return sample_store_type::uint32;
    } else if (type == typeid(int16_t)) {
        return sample_store_type::int16;
    } else if (type == typeid(uint16_t)) {
        return sample_store_type::uint16;
    } else if (type == typeid(int8_t)) {
        return sample_store_type::int8;
    } else if (type == typeid(uint8_t)) {
        return sample_store_type::uint8;
    } else if (type == typeid(boolean)) {
        return sample_store_type::boolean;
    } else {
        return sample_store_type::unknown;
    }
}

std::type_info const &timeline_utils::to_sample_type(sample_store_type const &store_type) {
    switch (store_type) {
        case sample_store_type::float64:
            return typeid(double);
        case sample_store_type::float32:
            return typeid(float);
        case sample_store_type::int64:
            return typeid(int64_t);
        case sample_store_type::uint64:
            return typeid(uint64_t);
        case sample_store_type::int32:
            return typeid(int32_t);
        case sample_store_type::uint32:
            return typeid(uint32_t);
        case sample_store_type::int16:
            return typeid(int16_t);
        case sample_store_type::uint16:
            return typeid(uint16_t);
        case sample_store_type::int8:
            return typeid(int8_t);
        case sample_store_type::uint8:
            return typeid(uint8_t);
        case sample_store_type::boolean:
            return typeid(boolean);
        default:
            return typeid(std::nullptr_t);
    }
}
