//
//  stream.h
//

#pragma once

#include <audio-processing/channel/channel.h>
#include <audio-processing/common/common_types.h>
#include <audio-processing/sync_source/sync_source.h>
#include <audio-processing/time/time.h>

namespace yas::proc {
struct stream final {
    explicit stream(sync_source const &);
    explicit stream(sync_source &&);

    stream(stream &&);
    stream(stream const &);

    [[nodiscard]] sync_source const &sync_source() const;

    proc::channel &add_channel(channel_index_t const);
    proc::channel &add_channel(channel_index_t const, channel::events_map_t);
    void remove_channel(channel_index_t const);
    [[nodiscard]] bool has_channel(channel_index_t const);
    [[nodiscard]] proc::channel const &channel(channel_index_t const) const;
    [[nodiscard]] proc::channel &channel(channel_index_t const);
    [[nodiscard]] std::size_t channel_count() const;
    [[nodiscard]] std::map<channel_index_t, proc::channel> const &channels() const;

   private:
    proc::sync_source _sync_source;
    std::map<channel_index_t, proc::channel> _channels;

    stream &operator=(stream &&) = delete;
    stream &operator=(stream const &) = delete;
};
}  // namespace yas::proc
