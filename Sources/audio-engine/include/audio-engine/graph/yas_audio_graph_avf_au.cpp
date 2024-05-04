//
//  yas_audio_graph_avf_au.cpp
//

#include "yas_audio_graph_avf_au.h"

#include <audio-engine/common/yas_audio_time.h>
#include <audio-engine/rendering/yas_audio_rendering_connection.h>
#include <cpp-utils/yas_cf_utils.h>
#include <cpp-utils/yas_fast_each.h>

using namespace yas;
using namespace yas::audio;

graph_avf_au::graph_avf_au(graph_node_args &&args, AudioComponentDescription const &acd)
    : node(graph_node::make_shared(std::move(args))), raw_au(audio::avf_au::make_shared(acd)) {
    auto const manageable_node = manageable_graph_node::cast(this->node);

    manageable_node->set_prepare_rendering_handler([this] {
        this->_update_unit_connections();
        this->node->set_render_handler([raw_au = this->raw_au](node_render_args const &args) {
            raw_au->render({.buffer = args.buffer, .bus_idx = args.bus_idx, .time = args.time},
                           [&args](avf_au::render_args input_args) {
                               if (args.source_connections.count(input_args.bus_idx) > 0) {
                                   rendering_connection const &connection =
                                       args.source_connections.at(input_args.bus_idx);
                                   connection.render(input_args.buffer, input_args.time);
                               }
                           });
        });
    });

    manageable_node->set_will_reset_handler([this] { this->_will_reset(); });
    manageable_node->set_setup_handler([this]() { this->_initialize_raw_au(); });
    manageable_node->set_teardown_handler([this]() { this->_uninitialize_raw_au(); });
}

graph_avf_au::~graph_avf_au() = default;

graph_avf_au::load_state graph_avf_au::state() const {
    return this->raw_au->state();
}

void graph_avf_au::_initialize_raw_au() {
    this->raw_au->initialize();
}

void graph_avf_au::_uninitialize_raw_au() {
    this->raw_au->uninitialize();
}

observing::syncable graph_avf_au::observe_load_state(observing::caller<load_state>::handler_f &&handler) {
    return this->raw_au->observe_load_state(std::move(handler));
}

observing::endable graph_avf_au::observe_connection(observing::caller<connection_method>::handler_f &&handler) {
    return this->_connection_notifier->observe(std::move(handler));
}

void graph_avf_au::_will_reset() {
    this->raw_au->reset();
}

void graph_avf_au::_update_unit_connections() {
    auto const &raw_au = this->raw_au;

    bool const is_initialized = raw_au->is_initialized();

    if (is_initialized) {
        this->_uninitialize_raw_au();
    }

    this->_connection_notifier->notify(connection_method::will_update);

    auto const input_bus_count = raw_au->input_bus_count();
    if (input_bus_count > 0) {
        auto each = make_fast_each(input_bus_count);
        while (yas_each_next(each)) {
            uint32_t const bus_idx = yas_each_index(each);

            if (auto connection = manageable_graph_node::cast(this->node)->input_connection(bus_idx)) {
                raw_au->set_input_format(connection->format(), bus_idx);
            }
        }
    }

    auto const output_bus_count = raw_au->output_bus_count();
    if (output_bus_count > 0) {
        auto each = make_fast_each(output_bus_count);
        while (yas_each_next(each)) {
            uint32_t const bus_idx = yas_each_index(each);
            if (auto connection = manageable_graph_node::cast(this->node)->output_connection(bus_idx)) {
                raw_au->set_output_format(connection->format(), bus_idx);
            }
        }
    }

    this->_connection_notifier->notify(connection_method::did_update);

    if (is_initialized) {
        this->_initialize_raw_au();
    }
}

graph_avf_au_ptr graph_avf_au::make_shared(OSType const type, OSType const sub_type) {
    return graph_avf_au::make_shared(AudioComponentDescription{
        .componentType = type,
        .componentSubType = sub_type,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0,
    });
}

graph_avf_au_ptr graph_avf_au::make_shared(AudioComponentDescription const &acd) {
    return graph_avf_au::make_shared({.acd = acd, .node_args = {.input_bus_count = 1, .output_bus_count = 1}});
}

graph_avf_au_ptr graph_avf_au::make_shared(graph_avf_au::args &&args) {
    return graph_avf_au_ptr(new graph_avf_au{std::move(args.node_args), args.acd});
}
