//
//  yas_audio_au.cpp
//

#include "yas_audio_engine_au.h"
#include <cpp_utils/yas_result.h>
#include <iostream>
#include "yas_audio_engine_node.h"
#include "yas_audio_graph.h"
#include "yas_audio_time.h"
#include "yas_audio_unit.h"
#include "yas_audio_unit_parameter.h"

using namespace yas;

#pragma mark - core

struct audio::engine::au::core {
    void set_unit(std::shared_ptr<audio::unit> const &au) {
        std::lock_guard<std::recursive_mutex> lock(this->_mutex);
        this->_unit = au;
    }

    std::shared_ptr<audio::unit> unit() const {
        std::lock_guard<std::recursive_mutex> lock(this->_mutex);
        return this->_unit;
    }

   private:
    std::shared_ptr<audio::unit> _unit = nullptr;
    mutable std::recursive_mutex _mutex;
};

#pragma mark - audio::engine::au

audio::engine::au::au(node_args &&args) : _node(make_node(std::move(args))), _core(std::make_unique<core>()) {
}

audio::engine::au::~au() = default;

void audio::engine::au::set_prepare_unit_handler(prepare_unit_f handler) {
    this->_prepare_unit_handler = std::move(handler);
}

std::shared_ptr<audio::unit> audio::engine::au::unit() const {
    return this->_core->unit();
}

std::unordered_map<AudioUnitParameterID, audio::unit::parameter_map_t> const &audio::engine::au::parameters() const {
    return this->_parameters;
}

audio::unit::parameter_map_t const &audio::engine::au::global_parameters() const {
    return this->_parameters.at(kAudioUnitScope_Global);
}

audio::unit::parameter_map_t const &audio::engine::au::input_parameters() const {
    return this->_parameters.at(kAudioUnitScope_Input);
}

audio::unit::parameter_map_t const &audio::engine::au::output_parameters() const {
    return this->_parameters.at(kAudioUnitScope_Output);
}

uint32_t audio::engine::au::input_element_count() const {
    return this->_core->unit()->element_count(kAudioUnitScope_Input);
}

uint32_t audio::engine::au::output_element_count() const {
    return this->_core->unit()->element_count(kAudioUnitScope_Output);
}

void audio::engine::au::set_global_parameter_value(AudioUnitParameterID const parameter_id, float const value) {
    auto &global_parameters = this->_parameters.at(kAudioUnitScope_Global);
    if (global_parameters.count(parameter_id) > 0) {
        auto &parameter = global_parameters.at(parameter_id);
        parameter.set_value(value, 0);
        if (auto unit = this->_core->unit()) {
            unit->set_parameter_value(value, parameter_id, kAudioUnitScope_Global, 0);
        }
    }
}

float audio::engine::au::global_parameter_value(AudioUnitParameterID const parameter_id) const {
    if (auto const unit = this->_core->unit()) {
        return unit->parameter_value(parameter_id, kAudioUnitScope_Global, 0);
    }
    return 0;
}

void audio::engine::au::set_input_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                                  AudioUnitElement const element) {
    auto &input_parameters = this->_parameters.at(kAudioUnitScope_Input);
    if (input_parameters.count(parameter_id) > 0) {
        auto &parameter = input_parameters.at(parameter_id);
        parameter.set_value(value, element);
        if (auto unit = this->_core->unit()) {
            unit->set_parameter_value(value, parameter_id, kAudioUnitScope_Input, element);
        }
    }
}

float audio::engine::au::input_parameter_value(AudioUnitParameterID const parameter_id,
                                               AudioUnitElement const element) const {
    if (auto const unit = this->_core->unit()) {
        return unit->parameter_value(parameter_id, kAudioUnitScope_Input, element);
    }
    return 0;
}

void audio::engine::au::set_output_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                                   AudioUnitElement const element) {
    auto &output_parameters = this->_parameters.at(kAudioUnitScope_Output);
    if (output_parameters.count(parameter_id) > 0) {
        auto &parameter = output_parameters.at(parameter_id);
        parameter.set_value(value, element);
        if (auto unit = this->_core->unit()) {
            unit->set_parameter_value(value, parameter_id, kAudioUnitScope_Output, element);
        }
    }
}

float audio::engine::au::output_parameter_value(AudioUnitParameterID const parameter_id,
                                                AudioUnitElement const element) const {
    if (auto const unit = this->_core->unit()) {
        return unit->parameter_value(parameter_id, kAudioUnitScope_Output, element);
    }
    return 0;
}

chaining::chain_unsync_t<audio::engine::au::chaining_pair_t> audio::engine::au::chain() const {
    return this->_notifier.chain();
}

chaining::chain_relayed_unsync_t<std::shared_ptr<audio::engine::au>, audio::engine::au::chaining_pair_t>
audio::engine::au::chain(method const method) const {
    return this->_notifier.chain()
        .guard([method](auto const &pair) { return pair.first == method; })
        .to([](chaining_pair_t const &pair) { return pair.second; });
}

audio::engine::node const &audio::engine::au::node() const {
    return *this->_node;
}

audio::engine::node &audio::engine::au::node() {
    return *this->_node;
}

std::shared_ptr<audio::engine::manageable_au> audio::engine::au::manageable() {
    return std::dynamic_pointer_cast<manageable_au>(shared_from_this());
}

#pragma mark - private

void audio::engine::au::_prepare(AudioComponentDescription const &acd) {
    this->_acd = acd;

    auto unit = audio::make_unit(acd);
    this->_parameters.clear();
    this->_parameters.insert(std::make_pair(kAudioUnitScope_Global, unit->create_parameters(kAudioUnitScope_Global)));
    this->_parameters.insert(std::make_pair(kAudioUnitScope_Input, unit->create_parameters(kAudioUnitScope_Input)));
    this->_parameters.insert(std::make_pair(kAudioUnitScope_Output, unit->create_parameters(kAudioUnitScope_Output)));
    this->_core->set_unit(unit);

    auto weak_au = to_weak(shared_from_this());

    this->_node->set_render_handler([weak_au](auto args) {
        auto &buffer = args.buffer;

        if (auto au = weak_au.lock()) {
            if (auto unit = au->_core->unit()) {
                AudioUnitRenderActionFlags action_flags = 0;
                AudioTimeStamp const time_stamp = args.when.audio_time_stamp();

                render_parameters render_parameters{.in_render_type = render_type::normal,
                                                    .io_action_flags = &action_flags,
                                                    .io_time_stamp = &time_stamp,
                                                    .in_bus_number = args.bus_idx,
                                                    .in_number_frames = buffer.frame_length(),
                                                    .io_data = buffer.audio_buffer_list()};

                if (auto err = unit->raw_unit_render(render_parameters).error_opt()) {
                    std::cout << "audio unit render error : " << std::to_string(*err) << " - " << to_string(*err)
                              << std::endl;
                }
            }
        }
    });

    this->_reset_observer = this->_node->chain(node::method::will_reset)
                                .perform([weak_au](auto const &) {
                                    if (auto au = weak_au.lock()) {
                                        au->_will_reset();
                                    }
                                })
                                .end();

    this->_connections_observer = this->_node->chain(node::method::update_connections)
                                      .perform([weak_au](auto const &) {
                                          if (auto au = weak_au.lock()) {
                                              au->_update_unit_connections();
                                          }
                                      })
                                      .end();

    this->_node->manageable()->set_add_to_graph_handler([weak_au](audio::graph &graph) {
        if (auto au = weak_au.lock()) {
            au->prepare_unit();
            if (auto unit = au->unit()) {
                graph.add_unit(unit);
            }
            au->prepare_parameters();
        }
    });

    this->_node->manageable()->set_remove_from_graph_handler([weak_au](audio::graph &graph) {
        if (auto au = weak_au.lock()) {
            if (auto unit = au->unit()) {
                graph.remove_unit(unit);
            }
        }
    });
}

void audio::engine::au::_update_unit_connections() {
    auto shared_au = shared_from_this();

    this->_notifier.notify(std::make_pair(au::method::will_update_connections, shared_au));

    if (auto unit = this->_core->unit()) {
        auto input_bus_count = this->input_element_count();
        if (input_bus_count > 0) {
            auto weak_au = to_weak(shared_au);
            unit->set_render_handler([weak_au](audio::render_parameters &render_parameters) {
                if (auto au = weak_au.lock()) {
                    if (auto kernel = au->node().kernel()) {
                        if (auto connection = kernel->input_connection(render_parameters.in_bus_number)) {
                            if (auto src_node = connection->source_node()) {
                                pcm_buffer buffer{connection->format, render_parameters.io_data};
                                time when(*render_parameters.io_time_stamp, connection->format.sample_rate());
                                src_node->render({.buffer = buffer, .bus_idx = connection->source_bus, .when = when});
                            }
                        }
                    }
                }
            });

            for (uint32_t bus_idx = 0; bus_idx < input_bus_count; ++bus_idx) {
                if (auto connection = this->_node->manageable()->input_connection(bus_idx)) {
                    unit->set_input_format(connection->format.stream_description(), bus_idx);
                    unit->attach_render_callback(bus_idx);
                } else {
                    unit->detach_render_callback(bus_idx);
                }
            }
        } else {
            unit->set_render_handler(nullptr);
        }

        auto output_bus_count = this->output_element_count();
        if (output_bus_count > 0) {
            for (uint32_t bus_idx = 0; bus_idx < output_bus_count; ++bus_idx) {
                if (auto connection = this->_node->manageable()->output_connection(bus_idx)) {
                    unit->set_output_format(connection->format.stream_description(), bus_idx);
                }
            }
        }
    }

    this->_notifier.notify(std::make_pair(au::method::did_update_connections, shared_au));
}

void audio::engine::au::prepare_unit() {
    if (auto unit = this->_core->unit()) {
        if (auto const &handler = this->_prepare_unit_handler) {
            handler(*unit);
        } else {
            unit->set_maximum_frames_per_slice(4096);
        }
    }
}

void audio::engine::au::prepare_parameters() {
    if (auto unit = this->_core->unit()) {
        for (auto &parameters_pair : this->_parameters) {
            auto &scope = parameters_pair.first;
            for (auto &parameter_pair : this->_parameters.at(scope)) {
                auto &parameter = parameter_pair.second;
                for (auto &value_pair : parameter.values()) {
                    auto &element = value_pair.first;
                    auto &value = value_pair.second;
                    unit->set_parameter_value(value, parameter.parameter_id, scope, element);
                }
            }
        }
    }
}

void audio::engine::au::reload_unit() {
    this->_core->set_unit(audio::make_unit(this->_acd));
}

void audio::engine::au::_will_reset() {
    auto unit = this->_core->unit();
    unit->reset();

    auto prev_parameters = std::move(this->_parameters);

    this->_parameters.insert(std::make_pair(kAudioUnitScope_Global, unit->create_parameters(kAudioUnitScope_Global)));
    this->_parameters.insert(std::make_pair(kAudioUnitScope_Input, unit->create_parameters(kAudioUnitScope_Input)));
    this->_parameters.insert(std::make_pair(kAudioUnitScope_Output, unit->create_parameters(kAudioUnitScope_Output)));

    for (AudioUnitScope const scope : {kAudioUnitScope_Global, kAudioUnitScope_Input, kAudioUnitScope_Output}) {
        for (auto const &param_pair : prev_parameters.at(scope)) {
            auto const &parameter_id = param_pair.first;
            auto const &parameter = param_pair.second;
            auto const &default_value = parameter.default_value;
            for (auto &value_pair : parameter.values()) {
                auto const &element = value_pair.first;
                unit->set_parameter_value(default_value, parameter_id, scope, element);
            }
        }
    }
}

#pragma mark - factory

std::shared_ptr<audio::engine::au> audio::engine::au::make_shared(OSType const type, OSType const sub_type) {
    return au::make_shared(AudioComponentDescription{
        .componentType = type,
        .componentSubType = sub_type,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0,
    });
}

std::shared_ptr<audio::engine::au> audio::engine::au::make_shared(AudioComponentDescription const &acd) {
    return au::make_shared({.acd = acd, .node_args = {.input_bus_count = 1, .output_bus_count = 1}});
}

std::shared_ptr<audio::engine::au> audio::engine::au::make_shared(au::args &&args) {
    auto shared = std::shared_ptr<au>(new au{std::move(args.node_args)});
    shared->_prepare(args.acd);
    return shared;
}
