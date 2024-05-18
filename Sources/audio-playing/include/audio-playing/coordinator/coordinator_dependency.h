//
//  coordinator_dependency.h
//

#pragma once

#include <audio-playing/common/channel_mapping.h>
#include <audio-playing/exporter/exporter_types.h>
#include <audio-playing/renderer/renderer_types.h>

#include <observing/umbrella.hpp>

namespace yas::playing {
struct renderer_for_coordinator {
    virtual ~renderer_for_coordinator() = default;

    virtual void set_rendering_sample_rate(sample_rate_t const) = 0;
    virtual void set_rendering_pcm_format(audio::pcm_format const) = 0;
    virtual void set_is_rendering(bool const) = 0;

    [[nodiscard]] virtual renderer_format const &format() const = 0;

    using renderer_format_observing_handler_f = std::function<void(renderer_format const &)>;

    [[nodiscard]] virtual observing::syncable observe_format(renderer_format_observing_handler_f &&) = 0;
};

struct player_for_coordinator {
    virtual ~player_for_coordinator() = default;

    virtual void set_identifier(std::string const &) = 0;
    virtual void set_channel_mapping(playing::channel_mapping const &) = 0;
    virtual void set_playing(bool const) = 0;
    virtual void seek(frame_index_t const) = 0;
    virtual void overwrite(std::optional<channel_index_t> const, fragment_range const) = 0;

    [[nodiscard]] virtual std::string const &identifier() const = 0;
    [[nodiscard]] virtual playing::channel_mapping channel_mapping() const = 0;
    [[nodiscard]] virtual bool is_playing() const = 0;
    [[nodiscard]] virtual bool is_seeking() const = 0;
    [[nodiscard]] virtual frame_index_t current_frame() const = 0;

    [[nodiscard]] virtual observing::syncable observe_is_playing(std::function<void(bool const &)> &&) = 0;
};

struct exporter_for_coordinator {
    virtual ~exporter_for_coordinator() = default;

    virtual void set_timeline_container(timeline_container_ptr const &) = 0;

    using event_observing_handler_f = std::function<void(exporter_event const &)>;
    [[nodiscard]] virtual observing::endable observe_event(event_observing_handler_f &&) = 0;
};
}  // namespace yas::playing
