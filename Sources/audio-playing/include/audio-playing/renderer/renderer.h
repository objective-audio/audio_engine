//
//  renderer.h
//

#pragma once

#include <audio-engine/graph/graph.h>
#include <audio-engine/graph/graph_avf_au.h>
#include <audio-engine/graph/graph_tap.h>
#include <audio-playing/common/ptr.h>
#include <audio-playing/coordinator/coordinator_dependency.h>
#include <audio-playing/player/player_dependency.h>
#include <audio-processing/common/common_types.h>

namespace yas::playing {
struct renderer final : renderer_for_coordinator, renderer_for_player {
    audio::graph_ptr const graph;

    void set_rendering_sample_rate(sample_rate_t const) override;
    void set_rendering_pcm_format(audio::pcm_format const) override;
    void set_rendering_handler(renderer_rendering_f &&) override;
    void set_is_rendering(bool const) override;

    [[nodiscard]] renderer_format const &format() const override;

    [[nodiscard]] observing::syncable observe_format(renderer_format_observing_handler_f &&) override;

    static renderer_ptr make_shared(audio::io_device_ptr const &);

   private:
    audio::io_device_ptr const _device;

    observing::value::holder_ptr<sample_rate_t> const _rendering_sample_rate;
    observing::value::holder_ptr<audio::pcm_format> const _rendering_pcm_format;

    observing::value::holder_ptr<sample_rate_t> const _output_sample_rate;
    observing::value::holder_ptr<audio::pcm_format> const _output_pcm_format;

    observing::value::holder_ptr<sample_rate_t> const _sample_rate;
    observing::value::holder_ptr<audio::pcm_format> const _pcm_format;
    observing::value::holder_ptr<std::size_t> const _channel_count;
    observing::value::holder_ptr<renderer_format> const _format;

    audio::graph_io_ptr const _io;
    audio::graph_avf_au_ptr const _converter;
    audio::graph_tap_ptr const _tap;
    std::optional<audio::graph_connection_ptr> _connection{std::nullopt};
    std::optional<audio::graph_connection_ptr> _converter_connection{std::nullopt};

    observing::canceller_pool _pool;

    observing::value::holder_ptr<bool> _is_rendering = observing::value::holder<bool>::make_shared(false);

    renderer(audio::io_device_ptr const &);

    void _update_format();
    void _update_connection();
};
}  // namespace yas::playing
