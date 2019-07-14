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

struct audio::engine::au::impl : base::impl {
    explicit impl(engine::node_args &&args) : _node(std::move(args)) {
    }

    ~impl() = default;

    void set_prepare_unit_handler(prepare_unit_f &&handler) {
        this->_prepare_unit_handler = std::move(handler);
    }

    void prepare(audio::engine::au const &au, AudioComponentDescription const &acd) {
        this->_acd = acd;

        auto unit = audio::make_unit(acd);
        this->_parameters.clear();
        this->_parameters.insert(
            std::make_pair(kAudioUnitScope_Global, unit->create_parameters(kAudioUnitScope_Global)));
        this->_parameters.insert(std::make_pair(kAudioUnitScope_Input, unit->create_parameters(kAudioUnitScope_Input)));
        this->_parameters.insert(
            std::make_pair(kAudioUnitScope_Output, unit->create_parameters(kAudioUnitScope_Output)));
        this->_core.set_unit(unit);

        auto weak_au = to_weak(au);

        this->_node.set_render_handler([weak_au](auto args) {
            auto &buffer = args.buffer;

            if (auto au = weak_au.lock()) {
                if (auto unit = au.impl_ptr<impl>()->core_unit()) {
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

        this->_reset_observer = this->_node.chain(node::method::will_reset)
                                    .perform([weak_au](auto const &) {
                                        if (auto au = weak_au.lock()) {
                                            au.impl_ptr<audio::engine::au::impl>()->will_reset();
                                        }
                                    })
                                    .end();

        this->_connections_observer = this->_node.chain(node::method::update_connections)
                                          .perform([weak_au](auto const &) {
                                              if (auto au = weak_au.lock()) {
                                                  au.impl_ptr<audio::engine::au::impl>()->update_unit_connections();
                                              }
                                          })
                                          .end();

        this->_node.manageable().set_add_to_graph_handler([weak_au](audio::graph &graph) {
            if (auto au = weak_au.lock()) {
                au.prepare_unit();
                if (auto unit = au.unit()) {
                    graph.add_unit(unit);
                }
                au.prepare_parameters();
            }
        });

        this->_node.manageable().set_remove_from_graph_handler([weak_au](audio::graph &graph) {
            if (auto au = weak_au.lock()) {
                if (auto unit = au.unit()) {
                    graph.remove_unit(unit);
                }
            }
        });
    }

    std::shared_ptr<audio::unit> core_unit() {
        return this->_core.unit();
    }

    std::unordered_map<AudioUnitParameterID, audio::unit::parameter_map_t> const &parameters() {
        return this->_parameters;
    }

    audio::unit::parameter_map_t const &global_parameters() {
        return this->_parameters.at(kAudioUnitScope_Global);
    }

    audio::unit::parameter_map_t const &input_parameters() {
        return this->_parameters.at(kAudioUnitScope_Input);
    }

    audio::unit::parameter_map_t const &output_parameters() {
        return this->_parameters.at(kAudioUnitScope_Output);
    }

    uint32_t input_element_count() {
        return this->core_unit()->element_count(kAudioUnitScope_Input);
    }

    uint32_t output_element_count() {
        return this->core_unit()->element_count(kAudioUnitScope_Output);
    }

    void set_global_parameter_value(AudioUnitParameterID const parameter_id, float const value) {
        auto &global_parameters = this->_parameters.at(kAudioUnitScope_Global);
        if (global_parameters.count(parameter_id) > 0) {
            auto &parameter = global_parameters.at(parameter_id);
            parameter.set_value(value, 0);
            if (auto unit = this->core_unit()) {
                unit->set_parameter_value(value, parameter_id, kAudioUnitScope_Global, 0);
            }
        }
    }

    float global_parameter_value(AudioUnitParameterID const parameter_id) {
        if (auto const unit = this->core_unit()) {
            return unit->parameter_value(parameter_id, kAudioUnitScope_Global, 0);
        }
        return 0;
    }

    void set_input_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                   AudioUnitElement const element) {
        auto &input_parameters = this->_parameters.at(kAudioUnitScope_Input);
        if (input_parameters.count(parameter_id) > 0) {
            auto &parameter = input_parameters.at(parameter_id);
            parameter.set_value(value, element);
            if (auto unit = this->core_unit()) {
                unit->set_parameter_value(value, parameter_id, kAudioUnitScope_Input, element);
            }
        }
    }

    float input_parameter_value(AudioUnitParameterID const parameter_id, AudioUnitElement const element) {
        if (auto const unit = this->core_unit()) {
            return unit->parameter_value(parameter_id, kAudioUnitScope_Input, element);
        }
        return 0;
    }

    void set_output_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                    AudioUnitElement const element) {
        auto &output_parameters = this->_parameters.at(kAudioUnitScope_Output);
        if (output_parameters.count(parameter_id) > 0) {
            auto &parameter = output_parameters.at(parameter_id);
            parameter.set_value(value, element);
            if (auto unit = this->core_unit()) {
                unit->set_parameter_value(value, parameter_id, kAudioUnitScope_Output, element);
            }
        }
    }

    float output_parameter_value(AudioUnitParameterID const parameter_id, AudioUnitElement const element) {
        if (auto const unit = this->core_unit()) {
            return unit->parameter_value(parameter_id, kAudioUnitScope_Output, element);
        }
        return 0;
    }

    void update_unit_connections() {
        this->_notifier.notify(std::make_pair(au::method::will_update_connections, cast<audio::engine::au>()));

        if (auto unit = this->core_unit()) {
            auto input_bus_count = this->input_element_count();
            if (input_bus_count > 0) {
                auto weak_au = to_weak(cast<engine::au>());
                unit->set_render_handler([weak_au](audio::render_parameters &render_parameters) {
                    if (auto au = weak_au.lock()) {
                        if (auto kernel = au.node().kernel()) {
                            if (auto connection = kernel->input_connection(render_parameters.in_bus_number)) {
                                if (auto src_node = connection.source_node()) {
                                    pcm_buffer buffer{connection.format(), render_parameters.io_data};
                                    time when(*render_parameters.io_time_stamp, connection.format().sample_rate());
                                    src_node.render(
                                        {.buffer = buffer, .bus_idx = connection.source_bus(), .when = when});
                                }
                            }
                        }
                    }
                });

                for (uint32_t bus_idx = 0; bus_idx < input_bus_count; ++bus_idx) {
                    if (auto connection = this->_node.input_connection(bus_idx)) {
                        unit->set_input_format(connection.format().stream_description(), bus_idx);
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
                    if (auto connection = this->_node.output_connection(bus_idx)) {
                        unit->set_output_format(connection.format().stream_description(), bus_idx);
                    }
                }
            }
        }

        this->_notifier.notify(std::make_pair(au::method::did_update_connections, cast<audio::engine::au>()));
    }

    void prepare_unit() {
        if (auto unit = this->core_unit()) {
            if (auto const &handler = this->_prepare_unit_handler) {
                handler(*unit);
            } else {
                unit->set_maximum_frames_per_slice(4096);
            }
        }
    }

    void prepare_parameters() {
        if (auto unit = this->core_unit()) {
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

    void reload_unit() {
        this->_core.set_unit(audio::make_unit(this->_acd));
    }

    audio::engine::node _node;
    AudioComponentDescription _acd;
    std::unordered_map<AudioUnitScope, unit::parameter_map_t> _parameters;
    chaining::notifier<chaining_pair_t> _notifier;
    chaining::any_observer_ptr _reset_observer = nullptr;
    chaining::any_observer_ptr _connections_observer = nullptr;
    prepare_unit_f _prepare_unit_handler;

   private:
    void will_reset() {
        auto unit = this->core_unit();
        unit->reset();

        auto prev_parameters = std::move(this->_parameters);

        this->_parameters.insert(
            std::make_pair(kAudioUnitScope_Global, unit->create_parameters(kAudioUnitScope_Global)));
        this->_parameters.insert(std::make_pair(kAudioUnitScope_Input, unit->create_parameters(kAudioUnitScope_Input)));
        this->_parameters.insert(
            std::make_pair(kAudioUnitScope_Output, unit->create_parameters(kAudioUnitScope_Output)));

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

   private:
    struct core {
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

    core _core;
};

#pragma mark - audio::engine::au

audio::engine::au::au(OSType const type, OSType const sub_type)
    : au(AudioComponentDescription{
          .componentType = type,
          .componentSubType = sub_type,
          .componentManufacturer = kAudioUnitManufacturer_Apple,
          .componentFlags = 0,
          .componentFlagsMask = 0,
      }) {
}

audio::engine::au::au(AudioComponentDescription const &acd)
    : au({.acd = acd, .node_args = {.input_bus_count = 1, .output_bus_count = 1}}) {
}

audio::engine::au::au(args &&args) : base(std::make_shared<impl>(std::move(args.node_args))) {
    impl_ptr<impl>()->prepare(*this, args.acd);
}

audio::engine::au::au(std::nullptr_t) : base(nullptr) {
}

audio::engine::au::~au() = default;

void audio::engine::au::set_prepare_unit_handler(prepare_unit_f handler) {
    impl_ptr<impl>()->set_prepare_unit_handler(std::move(handler));
}

std::shared_ptr<audio::unit> audio::engine::au::unit() const {
    return impl_ptr<impl>()->core_unit();
}

std::unordered_map<AudioUnitParameterID, audio::unit::parameter_map_t> const &audio::engine::au::parameters() const {
    return impl_ptr<impl>()->parameters();
}

audio::unit::parameter_map_t const &audio::engine::au::global_parameters() const {
    return impl_ptr<impl>()->global_parameters();
}

audio::unit::parameter_map_t const &audio::engine::au::input_parameters() const {
    return impl_ptr<impl>()->input_parameters();
}

audio::unit::parameter_map_t const &audio::engine::au::output_parameters() const {
    return impl_ptr<impl>()->output_parameters();
}

uint32_t audio::engine::au::input_element_count() const {
    return impl_ptr<impl>()->input_element_count();
}

uint32_t audio::engine::au::output_element_count() const {
    return impl_ptr<impl>()->output_element_count();
}

void audio::engine::au::set_global_parameter_value(AudioUnitParameterID const parameter_id, float const value) {
    impl_ptr<impl>()->set_global_parameter_value(parameter_id, value);
}

float audio::engine::au::global_parameter_value(AudioUnitParameterID const parameter_id) const {
    return impl_ptr<impl>()->global_parameter_value(parameter_id);
}

void audio::engine::au::set_input_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                                  AudioUnitElement const element) {
    impl_ptr<impl>()->set_input_parameter_value(parameter_id, value, element);
}

float audio::engine::au::input_parameter_value(AudioUnitParameterID const parameter_id,
                                               AudioUnitElement const element) const {
    return impl_ptr<impl>()->input_parameter_value(parameter_id, element);
}

void audio::engine::au::set_output_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                                   AudioUnitElement const element) {
    impl_ptr<impl>()->set_output_parameter_value(parameter_id, value, element);
}

float audio::engine::au::output_parameter_value(AudioUnitParameterID const parameter_id,
                                                AudioUnitElement const element) const {
    return impl_ptr<impl>()->output_parameter_value(parameter_id, element);
}

chaining::chain_unsync_t<audio::engine::au::chaining_pair_t> audio::engine::au::chain() const {
    return impl_ptr<impl>()->_notifier.chain();
}

chaining::chain_relayed_unsync_t<audio::engine::au, audio::engine::au::chaining_pair_t> audio::engine::au::chain(
    method const method) const {
    return impl_ptr<impl>()
        ->_notifier.chain()
        .guard([method](auto const &pair) { return pair.first == method; })
        .to([](chaining_pair_t const &pair) { return pair.second; });
}

audio::engine::node const &audio::engine::au::node() const {
    return impl_ptr<impl>()->_node;
}

audio::engine::node &audio::engine::au::node() {
    return impl_ptr<impl>()->_node;
}

void audio::engine::au::prepare_unit() {
    impl_ptr<impl>()->prepare_unit();
}

void audio::engine::au::prepare_parameters() {
    impl_ptr<impl>()->prepare_parameters();
}

void audio::engine::au::reload_unit() {
    impl_ptr<impl>()->reload_unit();
}
