//
//  yas_audio_graph_avf_au.mm
//

#include "yas_audio_graph_avf_au.h"
#import <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_cf_utils.h>
#include <cpp_utils/yas_fast_each.h>
#include <cpp_utils/yas_objc_ptr.h>
#include <cpp_utils/yas_thread.h>
#include "yas_audio_avf_au_parameter.h"
#include "yas_audio_avf_au_parameter_core.h"
#include "yas_audio_time.h"

using namespace yas;

audio::graph_avf_au::graph_avf_au(graph_node_args &&args, AudioComponentDescription const &acd)
    : _node(graph_node::make_shared(std::move(args))), _raw_au(audio::avf_au::make_shared(acd)) {
}

audio::graph_avf_au::~graph_avf_au() = default;

audio::graph_avf_au::load_state audio::graph_avf_au::state() const {
    return this->_load_state->raw();
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
    return this->_load_state->chain();
}

chaining::chain_unsync_t<audio::graph_avf_au::connection_method> audio::graph_avf_au::connection_chain() const {
    return this->_connection_notifier->chain();
}

void audio::graph_avf_au::_prepare(graph_avf_au_ptr const &shared, AudioComponentDescription const &acd) {
    this->_weak_au = shared;

    auto weak_au = to_weak(shared);

    this->_node->set_render_handler([weak_au](graph_node::render_args args) {
        if (auto shared_au = weak_au.lock()) {
            auto const &raw_au = shared_au->_raw_au;

            raw_au->render(
                {.output_buffer = args.output_buffer, .bus_idx = args.bus_idx, .output_time = args.output_time},
                [weak_au](auto input_args) {
                    if (auto shared_au = weak_au.lock()) {
                        if (auto kernel = shared_au->node()->kernel()) {
                            if (auto connection = kernel.value()->input_connection(input_args.bus_idx)) {
                                if (auto src_node = connection->source_node()) {
                                    src_node->render({.output_buffer = input_args.output_buffer,
                                                      .bus_idx = input_args.bus_idx,
                                                      .output_time = input_args.output_time});
                                }
                            }
                        }
                    }
                });
        }
    });

    this->_node->chain(graph_node::method::will_reset)
        .perform([weak_au](auto const &) {
            if (auto au = weak_au.lock()) {
                au->_will_reset();
            }
        })
        .end()
        ->add_to(this->_pool);

    this->_node->chain(graph_node::method::update_connections)
        .perform([weak_au](auto const &) {
            if (auto au = weak_au.lock()) {
                au->_update_unit_connections();
            }
        })
        .end()
        ->add_to(this->_pool);

    manageable_graph_node::cast(this->_node)->set_setup_handler([weak_au]() {
        if (auto au = weak_au.lock()) {
            au->_initialize_raw_au();
        }
    });

    manageable_graph_node::cast(this->_node)->set_teardown_handler([weak_au]() {
        if (auto au = weak_au.lock()) {
            au->_uninitialize_raw_au();
        }
    });

    this->_raw_au->load_state_chain().send_to(shared->_load_state).sync()->add_to(this->_pool);
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
                raw_au->set_input_format(connection->format, bus_idx);
            }
        }
    }

    auto const output_bus_count = raw_au->output_bus_count();
    if (output_bus_count > 0) {
        auto each = make_fast_each(output_bus_count);
        while (yas_each_next(each)) {
            uint32_t const bus_idx = yas_each_index(each);
            if (auto connection = manageable_graph_node::cast(this->_node)->output_connection(bus_idx)) {
                raw_au->set_output_format(connection->format, bus_idx);
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
    auto shared = graph_avf_au_ptr(new graph_avf_au{std::move(args.node_args), args.acd});
    shared->_prepare(shared, args.acd);
    return shared;
}

#pragma mark -

std::string yas::to_string(audio::graph_avf_au::load_state const &state) {
    switch (state) {
        case audio::graph_avf_au::load_state::unload:
            return "unload";
        case audio::graph_avf_au::load_state::loaded:
            return "loaded";
        case audio::graph_avf_au::load_state::failed:
            return "failed";
    }
}
