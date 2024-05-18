//
//  renderer.cpp
//

#include "renderer.h"

#include <audio-engine/graph/graph_io.h>
#include <audio-engine/io/io.h>
#include <audio-playing/common/types.h>

using namespace yas;
using namespace yas::playing;

renderer::renderer(audio::io_device_ptr const &device)
    : graph(audio::graph::make_shared()),
      _device(device),
      _rendering_sample_rate(observing::value::holder<sample_rate_t>::make_shared(sample_rate_t{0})),
      _rendering_pcm_format(observing::value::holder<audio::pcm_format>::make_shared(audio::pcm_format::other)),
      _output_sample_rate(observing::value::holder<sample_rate_t>::make_shared(sample_rate_t{0})),
      _output_pcm_format(observing::value::holder<audio::pcm_format>::make_shared(audio::pcm_format::other)),
      _sample_rate(observing::value::holder<sample_rate_t>::make_shared(sample_rate_t{0})),
      _pcm_format(observing::value::holder<audio::pcm_format>::make_shared(audio::pcm_format::other)),
      _channel_count(observing::value::holder<std::size_t>::make_shared(std::size_t(0))),
      _format(observing::value::holder<renderer_format>::make_shared(
          {.sample_rate = 0, .pcm_format = audio::pcm_format::float32, .channel_count = 0})),
      _io(this->graph->add_io(this->_device)),
      _converter(audio::graph_avf_au::make_shared(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter)),
      _tap(audio::graph_tap::make_shared()) {
    this->_update_format();

    this->_rendering_sample_rate->observe([this](auto const &) { this->_update_format(); }).end()->add_to(this->_pool);
    this->_rendering_pcm_format->observe([this](auto const &) { this->_update_format(); }).end()->add_to(this->_pool);
    this->_device->observe_io_device([this](auto const &) { this->_update_format(); }).end()->add_to(this->_pool);

    auto set_config_handler = [this] {
        this->_format->set_value(renderer_format{.sample_rate = this->_sample_rate->value(),
                                                 .pcm_format = this->_pcm_format->value(),
                                                 .channel_count = this->_channel_count->value()});
    };

    this->_sample_rate->observe([set_config_handler](auto const &) { set_config_handler(); })
        .end()
        ->add_to(this->_pool);
    this->_pcm_format->observe([set_config_handler](auto const &) { set_config_handler(); }).end()->add_to(this->_pool);
    this->_channel_count->observe([set_config_handler](auto const &) { set_config_handler(); })
        .sync()
        ->add_to(this->_pool);

    this->_output_sample_rate->observe([this](auto const &) { this->_update_connection(); }).end()->add_to(this->_pool);
    this->_output_pcm_format->observe([this](auto const &) { this->_update_connection(); }).end()->add_to(this->_pool);
    this->_format->observe([this](auto const &) { this->_update_connection(); }).sync()->add_to(this->_pool);

    this->_is_rendering
        ->observe([this](bool const &is_rendering) {
            if (is_rendering) {
                this->graph->start_render();
            } else {
                this->graph->stop();
            }
        })
        .sync()
        ->add_to(this->_pool);
}

renderer_format const &renderer::format() const {
    return this->_format->value();
}

observing::syncable renderer::observe_format(renderer_format_observing_handler_f &&handler) {
    return this->_format->observe(std::move(handler));
}

void renderer::set_rendering_sample_rate(sample_rate_t const sample_rate) {
    this->_rendering_sample_rate->set_value(sample_rate);
}

void renderer::set_rendering_pcm_format(audio::pcm_format const pcm_format) {
    this->_rendering_pcm_format->set_value(pcm_format);
}

void renderer::set_rendering_handler(renderer_rendering_f &&handler) {
    this->_tap->set_render_handler([handler = std::move(handler)](audio::node_render_args const &args) {
        if (args.bus_idx != 0) {
            return;
        }

        auto const &buffer = args.buffer;

        if (buffer->format().is_interleaved()) {
            return;
        }

        if (handler) {
            handler(buffer);
        }
    });
}

void renderer::set_is_rendering(bool const is_rendering) {
    this->_is_rendering->set_value(is_rendering);
}

void renderer::_update_format() {
    if (auto const &output_format = this->_device->output_format()) {
        this->_output_sample_rate->set_value(output_format->sample_rate());
        if (auto const &rendering_pcm_format = this->_rendering_pcm_format->value();
            rendering_pcm_format != audio::pcm_format::other) {
            this->_output_pcm_format->set_value(rendering_pcm_format);
        } else {
            this->_output_pcm_format->set_value(output_format->pcm_format());
        }
        this->_sample_rate->set_value(this->_rendering_sample_rate->value() ?: output_format->sample_rate());
        this->_channel_count->set_value(output_format->channel_count());
        this->_pcm_format->set_value(output_format->pcm_format());
    } else {
        this->_output_sample_rate->set_value(0);
        this->_output_pcm_format->set_value(audio::pcm_format::other);
        this->_sample_rate->set_value(0);
        this->_channel_count->set_value(0);
        this->_pcm_format->set_value(audio::pcm_format::other);
    }
}

void renderer::_update_connection() {
    if (this->_connection) {
        this->graph->disconnect(*this->_connection);
        this->_connection = std::nullopt;
    }

    if (this->_converter_connection) {
        this->graph->disconnect(*this->_converter_connection);
        this->_converter_connection = std::nullopt;
    }

    auto const &output_format = this->_device->output_format();
    auto const output_sample_rate = output_format.has_value() ? output_format.value().sample_rate() : 0;
    auto const output_pcm_format =
        output_format.has_value() ? output_format.value().pcm_format() : audio::pcm_format::other;

    sample_rate_t const &config_sample_rate = this->_sample_rate->value();
    audio::pcm_format const &config_pcm_format = this->_pcm_format->value();
    std::size_t const ch_count = this->_channel_count->value();
    audio::pcm_format const pcm_format = this->_pcm_format->value();

    if (output_sample_rate > 0 && config_sample_rate > 0 && ch_count > 0 && pcm_format != audio::pcm_format::other &&
        config_pcm_format != audio::pcm_format::other) {
        if (output_sample_rate != config_sample_rate || output_pcm_format != config_pcm_format) {
            audio::format const input_format{{.sample_rate = static_cast<double>(config_sample_rate),
                                              .channel_count = static_cast<uint32_t>(ch_count),
                                              .pcm_format = config_pcm_format}};
            audio::format const output_format{{.sample_rate = static_cast<double>(output_sample_rate),
                                               .channel_count = static_cast<uint32_t>(ch_count),
                                               .pcm_format = pcm_format}};
            this->_converter->raw_au->set_input_format(input_format, 0);
            this->_converter->raw_au->set_output_format(output_format, 0);

            this->_converter_connection = this->graph->connect(this->_tap->node, this->_converter->node, input_format);
            this->_connection = this->graph->connect(this->_converter->node, this->_io->output_node, output_format);
        } else {
            audio::format const format{{.sample_rate = static_cast<double>(config_sample_rate),
                                        .channel_count = static_cast<uint32_t>(ch_count),
                                        .pcm_format = pcm_format}};
            this->_connection = this->graph->connect(this->_tap->node, this->_io->output_node, format);
        }
    }
}

renderer_ptr renderer::make_shared(audio::io_device_ptr const &device) {
    return renderer_ptr(new renderer{device});
}
