//
//  yas_playing_path.cpp
//

#include "path.h"

#include <audio-playing/common/math.h>
#include <audio-playing/signal_file/signal_file_info.h>
#include <cpp-utils/boolean.h>

using namespace yas;
using namespace yas::playing;
using namespace yas::playing::path;

#pragma mark - path::timeline

std::filesystem::path timeline::value() const {
    auto path = this->root_path;
    return path.append(timeline_name(this->identifier, this->sample_rate));
}

bool timeline::operator==(timeline const &rhs) const {
    return this->root_path == rhs.root_path && this->identifier == rhs.identifier &&
           this->sample_rate == rhs.sample_rate;
}

bool timeline::operator!=(timeline const &rhs) const {
    return !(*this == rhs);
}

#pragma mark - path::channel

std::filesystem::path channel::value() const {
    return this->timeline_path.value().append(channel_name(this->channel_index));
}

bool channel::operator==(channel const &rhs) const {
    return this->timeline_path == rhs.timeline_path && this->channel_index == rhs.channel_index;
}

bool channel::operator!=(channel const &rhs) const {
    return !(*this == rhs);
}

#pragma mark - path::fragment

std::filesystem::path fragment::value() const {
    return this->channel_path.value().append(fragment_name(this->fragment_index));
}

bool fragment::operator==(fragment const &rhs) const {
    return this->channel_path == rhs.channel_path && this->fragment_index == rhs.fragment_index;
}

bool fragment::operator!=(fragment const &rhs) const {
    return !(*this == rhs);
}

#pragma mark - path::signal_event

std::filesystem::path signal_event::value() const {
    return this->fragment_path.value().append(to_signal_file_name(this->range, this->sample_type));
}

bool signal_event::operator==(signal_event const &rhs) const {
    return this->fragment_path == rhs.fragment_path && this->range == rhs.range && this->sample_type == rhs.sample_type;
}

bool signal_event::operator!=(signal_event const &rhs) const {
    return !(*this == rhs);
}

#pragma mark - path::number_events

std::filesystem::path number_events::value() const {
    return this->fragment_path.value().append("numbers");
}

bool number_events::operator==(number_events const &rhs) const {
    return this->fragment_path == rhs.fragment_path;
}

bool number_events::operator!=(number_events const &rhs) const {
    return !(*this == rhs);
}

#pragma mark - name

std::string path::timeline_name(std::string const &identifier, sample_rate_t const sr) {
    return identifier + "_" + std::to_string(sr);
}

std::string path::channel_name(channel_index_t const ch_idx) {
    return std::to_string(ch_idx);
}

std::string path::fragment_name(fragment_index_t const frag_idx) {
    return std::to_string(frag_idx);
}
