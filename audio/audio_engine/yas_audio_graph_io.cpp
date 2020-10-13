//
//  yas_audio_graph_io.cpp
//

#include "yas_audio_graph_io.h"

#include <sstream>

#include "yas_audio_debug.h"
#include "yas_audio_graph_tap.h"
#include "yas_audio_io.h"
#include "yas_audio_rendering_connection.h"
#include "yas_audio_rendering_graph.h"
#include "yas_audio_time.h"

using namespace yas;

#pragma mark - audio::graph_input_context

namespace yas::audio {
struct graph_input_context {
    audio::pcm_buffer *input_buffer = nullptr;
};
}  // namespace yas::audio

#pragma mark - audio::graph_io

audio::graph_io::graph_io(audio::io_ptr const &raw_io)
    : _output_node(graph_node::make_shared({.input_bus_count = 1, .output_bus_count = 0})),
      _input_node(graph_node::make_shared({.input_bus_count = 0, .output_bus_count = 1})),
      _raw_io(raw_io),
      _input_context(std::make_shared<graph_input_context>()) {
    this->_input_node->set_render_handler([input_context = this->_input_context](node_render_args const &args) {
        auto const &buffer = args.buffer;
        auto const *input_buffer = input_context->input_buffer;
        if (input_buffer) {
            if (input_buffer->format() == buffer->format()) {
                buffer->copy_from(*input_buffer);
            }
        }
    });
}

audio::graph_io::~graph_io() = default;

audio::graph_node_ptr const &audio::graph_io::output_node() const {
    return this->_output_node;
}

audio::graph_node_ptr const &audio::graph_io::input_node() const {
    return this->_input_node;
}

audio::io_ptr const &audio::graph_io::raw_io() {
    return this->_raw_io;
}

bool audio::graph_io::_validate_connections() {
    auto const &raw_io = this->_raw_io;

    auto &input_connections = manageable_graph_node::cast(this->_output_node)->input_connections();
    if (input_connections.size() > 0) {
        auto const connections = lock_values(input_connections);
        if (connections.count(0) > 0) {
            auto const &connection = connections.at(0);
            auto const &connection_format = connection->format();
            auto const &device_opt = raw_io->device();
            if (!device_opt) {
                yas_audio_log(("graph_io validate_connections failed - output device is null."));
                return false;
            }
            auto const &device = *device_opt;
            if (connection_format != device->output_format()) {
                std::ostringstream stream;
                stream << "graph_io validate_connections failed - output device io format is not match.\n";
                if (device->output_format().has_value()) {
                    stream << "device output format : " << to_string(*device->output_format()) << "\n";
                } else {
                    stream << "device output format : null"
                           << "\n";
                }
                stream << "connection format : " << to_string(connection_format);
                yas_audio_log(stream.str());
                return false;
            }
        }
    }

    auto &output_connections = manageable_graph_node::cast(this->_input_node)->output_connections();
    if (output_connections.size() > 0) {
        auto const connections = lock_values(output_connections);
        if (connections.count(0) > 0) {
            auto const &connection = connections.at(0);
            auto const &connection_format = connection->format();
            auto const &device_opt = raw_io->device();
            if (!device_opt) {
                yas_audio_log("graph_io validate_connections failed - output device is null.");
                return false;
            }
            auto const &device = *device_opt;
            if (connection_format != device->input_format()) {
                std::ostringstream stream;
                stream << "graph_io validate_connections failed - input device io format is not match.\n";
                if (device->input_format().has_value()) {
                    stream << "device input format : " << to_string(*device->input_format()) << "\n";
                } else {
                    stream << "device input format : null"
                           << "\n";
                }
                stream << "connection format : " << to_string(connection_format);
                yas_audio_log(stream.str());
                return false;
            }
        }
    }

    yas_audio_log("graph_io validate_connections succeeded");

    return true;
}

void audio::graph_io::update_rendering() {
    auto const &raw_io = this->_raw_io;

    if (!this->_validate_connections()) {
        raw_io->set_render_handler(std::nullopt);
        return;
    }

    auto graph = std::make_shared<rendering_graph>(this->output_node(), this->input_node());

    auto render_handler = [input_context = this->_input_context, graph](io_render_args args) {
        input_context->input_buffer = args.input_buffer;

        if (pcm_buffer *const buffer = args.output_buffer) {
            if (rendering_output_node const *node = graph->output_node()) {
                if (auto const &time = args.output_time) {
                    node->render(buffer, time.value());
                }
            }
        }

        if (pcm_buffer *const buffer = args.input_buffer) {
            if (rendering_input_node const *const node = graph->input_node()) {
                if (auto const &time = args.input_time) {
                    graph->input_node()->render(buffer, time.value());
                }
            }
        }

        input_context->input_buffer = nullptr;
    };

    raw_io->set_render_handler(std::move(render_handler));
}

void audio::graph_io::clear_rendering() {
    auto const &raw_io = this->_raw_io;
    raw_io->set_render_handler(std::nullopt);
}

audio::graph_io_ptr audio::graph_io::make_shared(audio::io_ptr const &raw_io) {
    return graph_io_ptr(new audio::graph_io{raw_io});
}