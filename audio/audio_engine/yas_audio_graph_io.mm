//
//  yas_audio_graph_io.cpp
//

#include "yas_audio_graph_io.h"

#include <cpp_utils/yas_result.h>
#include <sstream>
#include "yas_audio_debug.h"
#include "yas_audio_graph_tap.h"
#include "yas_audio_io.h"
#include "yas_audio_time.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#include <cpp_utils/yas_objc_ptr.h>
#endif

using namespace yas;

#pragma mark - audio::io

audio::graph_io::graph_io(audio::io_ptr const &raw_io)
    : _node(graph_node::make_shared({.input_bus_count = 1, .output_bus_count = 1})), _raw_io(raw_io) {
    this->_connections_observer = this->_node->chain(graph_node::method::update_connections)
                                      .perform([this](auto const &) { this->_update_io_connections(); })
                                      .end();
}

audio::graph_io::~graph_io() = default;

audio::graph_node_ptr const &audio::graph_io::node() const {
    return this->_node;
}

audio::io_ptr const &audio::graph_io::raw_io() {
    return this->_raw_io;
}

void audio::graph_io::_prepare(graph_io_ptr const &shared) {
    this->_weak_graph_io = to_weak(shared);

    this->_node->set_render_handler([weak_graph_io = this->_weak_graph_io](graph_node::render_args args) {
        auto const &buffer = args.buffer;

        if (auto graph_io = weak_graph_io.lock()) {
            auto const &input_buffer_opt = graph_io->_raw_io->input_buffer_on_render();
            if (input_buffer_opt) {
                auto const &input_buffer = *input_buffer_opt;
                if (input_buffer->format() == buffer->format()) {
                    buffer->copy_from(*input_buffer);
                }
            }
        }
    });
}

void audio::graph_io::_update_io_connections() {
    auto const &raw_io = this->_raw_io;

    if (!this->_validate_connections()) {
        raw_io->set_render_handler(std::nullopt);
        return;
    }

    auto weak_io = to_weak(raw_io);

    auto render_handler = [weak_graph_io = this->_weak_graph_io, weak_io](io_render_args args) {
        if (auto graph_io = weak_graph_io.lock()) {
            if (auto const kernel_opt = graph_io->node()->kernel()) {
                auto const &kernel = kernel_opt.value();
                auto const connections = kernel->input_connections();
                if (connections.count(0) > 0) {
                    auto const &connection = connections.at(0);
                    if (auto src_node = connection->source_node();
                        src_node && connection->format == src_node->output_format(connection->source_bus)) {
                        if (auto const time = args.output_time) {
                            src_node->render({.buffer = *args.output_buffer,
                                              .bus_idx = connection->source_bus,
                                              .time = time.value()});
                        }
                    }
                }

                if (auto io = weak_io.lock()) {
                    auto const connections = kernel->output_connections();
                    if (connections.count(0) > 0) {
                        auto const &connection = connections.at(0);
                        if (auto dst_node = connection->destination_node();
                            dst_node && dst_node->is_input_renderable()) {
                            auto const &input_buffer = args.input_buffer;
                            auto const &input_time = args.input_time;
                            if (input_buffer && input_time) {
                                if (connection->format == dst_node->input_format(connection->destination_bus)) {
                                    dst_node->render({.buffer = *input_buffer, .bus_idx = 0, .time = *input_time});
                                }
                            }
                        }
                    }
                }
            }
        }
    };

    raw_io->set_render_handler(std::move(render_handler));
}

bool audio::graph_io::_validate_connections() {
    auto const &raw_io = this->_raw_io;

    auto &input_connections = manageable_graph_node::cast(this->_node)->input_connections();
    if (input_connections.size() > 0) {
        auto const connections = lock_values(input_connections);
        if (connections.count(0) > 0) {
            auto const &connection = connections.at(0);
            auto const &connection_format = connection->format;
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

    auto &output_connections = manageable_graph_node::cast(this->_node)->output_connections();
    if (output_connections.size() > 0) {
        auto const connections = lock_values(output_connections);
        if (connections.count(0) > 0) {
            auto const &connection = connections.at(0);
            auto const &connection_format = connection->format;
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

audio::graph_io_ptr audio::graph_io::make_shared(audio::io_ptr const &raw_io) {
    auto shared = graph_io_ptr(new audio::graph_io{raw_io});
    shared->_prepare(shared);
    return shared;
}
