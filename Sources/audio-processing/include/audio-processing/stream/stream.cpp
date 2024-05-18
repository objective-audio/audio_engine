//
//  stream.cpp
//

#include "stream.h"

#include <audio-processing/channel/channel.h>

#include <map>

using namespace yas;
using namespace yas::proc;

#pragma mark - proc::stream

proc::stream::stream(proc::sync_source const &sync_src) : _sync_source(sync_src) {
}

proc::stream::stream(proc::sync_source &&sync_src) : _sync_source(std::move(sync_src)) {
}

proc::stream::stream(stream &&other) : _sync_source(std::move(other._sync_source)) {
}

proc::stream::stream(stream const &other) : _sync_source(other._sync_source) {
}

proc::sync_source const &proc::stream::sync_source() const {
    return this->_sync_source;
}

proc::channel &proc::stream::add_channel(channel_index_t const ch_idx) {
    auto &channels = this->_channels;
    if (channels.count(ch_idx) == 0) {
        channels.emplace(ch_idx, proc::channel{});
    }
    return channels.at(ch_idx);
}

proc::channel &proc::stream::add_channel(channel_index_t const ch_idx, channel::events_map_t events) {
    auto &channels = this->_channels;
    if (channels.count(ch_idx) > 0) {
        throw "channel exists.";
    }
    channels.emplace(ch_idx, proc::channel{std::move(events)});
    return channels.at(ch_idx);
}

void proc::stream::remove_channel(channel_index_t const ch_idx) {
    auto &channels = this->_channels;
    if (channels.count(ch_idx) > 0) {
        channels.erase(ch_idx);
    }
}

bool proc::stream::has_channel(channel_index_t const channel) {
    return this->_channels.count(channel) > 0;
}

proc::channel const &proc::stream::channel(channel_index_t const channel) const {
    return this->_channels.at(channel);
}

proc::channel &proc::stream::channel(channel_index_t const channel) {
    return this->_channels.at(channel);
}

std::size_t proc::stream::channel_count() const {
    return this->_channels.size();
}

std::map<proc::channel_index_t, proc::channel> const &proc::stream::channels() const {
    return this->_channels;
}
