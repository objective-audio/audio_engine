//
//  yas_playing_channel_mapping.cpp
//

#include "channel_mapping.h"

#include <cpp-utils/fast_each.h>

using namespace yas;
using namespace yas::playing;

std::optional<channel_index_t> channel_mapping::file_index(channel_index_t const out_idx,
                                                           std::size_t const ch_count) const {
    if (out_idx < ch_count) {
        if (out_idx < this->indices.size()) {
            return this->indices.at(out_idx);
        } else {
            return out_idx;
        }
    } else {
        return std::nullopt;
    }
}

std::optional<channel_index_t> channel_mapping::out_index(channel_index_t const ch_idx,
                                                          std::size_t const ch_count) const {
    auto const count = std::min(this->indices.size(), ch_count);
    auto each = make_fast_each(count);
    while (yas_each_next(each)) {
        auto const &idx = yas_each_index(each);
        if (this->indices.at(idx) == ch_idx) {
            return idx;
        }
    }

    if (count <= ch_idx && ch_idx < ch_count) {
        return ch_idx;
    }

    return std::nullopt;
}

bool channel_mapping::operator==(channel_mapping const &rhs) const {
    return this->indices == rhs.indices;
}

bool channel_mapping::operator!=(channel_mapping const &rhs) const {
    return !(*this == rhs);
}
