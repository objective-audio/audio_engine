//
//  yas_audio_graph_avf_au.cpp
//

#include "yas_audio_graph_avf_au.h"

#include <cpp_utils/yas_cf_utils.h>
#include <cpp_utils/yas_fast_each.h>

#include "yas_audio_rendering_connection.h"
#include "yas_audio_time.h"

using namespace yas;

audio::graph_avf_au::graph_avf_au(graph_node_args &&args, AudioComponentDescription const &acd)
    : _node(graph_node::make_shared(std::move(args))), _raw_au(audio::avf_au::make_shared(acd)) {
    auto const manageable_node = manageable_graph_node::cast(this->_node);

    manageable_node->set_prepare_rendering_handler([this] {
        this->_update_unit_connections();
        this->_node->set_render_handler([raw_au = this->_raw_au](node_render_args const &args) {
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

audio::graph_avf_au::~graph_avf_au() = default;

audio::graph_avf_au::load_state audio::graph_avf_au::state() const {
    return this->_raw_au->state();
}

audio::avf_au_ptr const &audio::graph_avf_au::raw_au() const {
    return this->_raw_au;
}

void audio::graph_avf_au::_initialize_raw_au() {
    this->_raw_au->initialize();
}

void audio::graph_avf_au::_uninitialize_raw_au() {
    this->_raw_au->uninitialize();
}

audio::graph_node_ptr const &audio::graph_avf_au::node() const {
    return this->_node;
}

chaining::chain_sync_t<audio::graph_avf_au::load_state> audio::graph_avf_au::load_state_chain() const {
    return this->_raw_au->load_state_chain();
}

chaining::chain_unsync_t<audio::graph_avf_au::connection_method> audio::graph_avf_au::connection_chain() const {
    return this->_connection_notifier->chain();
}

void audio::graph_avf_au::_will_reset() {
    this->_raw_au->reset();
}

void audio::graph_avf_au::_update_unit_connections() {
    auto const &raw_au = this->_raw_au;

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

            if (auto connection = manageable_graph_node::cast(this->_node)->input_connection(bus_idx)) {
                raw_au->set_input_format(connection->format(), bus_idx);
            }
        }
    }

    auto const output_bus_count = raw_au->output_bus_count();
    if (output_bus_count > 0) {
        auto each = make_fast_each(output_bus_count);
        while (yas_each_next(each)) {
            uint32_t const bus_idx = yas_each_index(each);
            if (auto connection = manageable_graph_node::cast(this->_node)->output_connection(bus_idx)) {
                raw_au->set_output_format(connection->format(), bus_idx);
            }
        }
    }

    this->_connection_notifier->notify(connection_method::did_update);

    if (is_initialized) {
        this->_initialize_raw_au();
    }
}

audio::graph_avf_au_ptr audio::graph_avf_au::make_shared(OSType const type, OSType const sub_type) {
    return graph_avf_au::make_shared(AudioComponentDescription{
        .componentType = type,
        .componentSubType = sub_type,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0,
    });
}

audio::graph_avf_au_ptr audio::graph_avf_au::make_shared(AudioComponentDescription const &acd) {
    return graph_avf_au::make_shared({.acd = acd, .node_args = {.input_bus_count = 1, .output_bus_count = 1}});
}

audio::graph_avf_au_ptr audio::graph_avf_au::make_shared(graph_avf_au::args &&args) {
    return graph_avf_au_ptr(new graph_avf_au{std::move(args.node_args), args.acd});
}
