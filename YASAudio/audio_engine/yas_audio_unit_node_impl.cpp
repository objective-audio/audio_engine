//
//  yas_audio_unit_node_impl.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_unit_node.h"
#include "yas_audio_graph.h"
#include "yas_audio_unit.h"
#include "yas_audio_unit_parameter.h"
#include "yas_audio_time.h"

using namespace yas;

class audio_unit_node::impl::core
{
   public:
    AudioComponentDescription acd;
    std::unordered_map<AudioUnitScope, audio_unit_parameter_map_t> parameters;
    yas::audio_unit _au;

    core() : acd(), parameters(), _au(nullptr), _mutex()
    {
    }

    void set_au(const yas::audio_unit &au)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _au = au;
    }

    yas::audio_unit au() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _au;
    }

   private:
    mutable std::recursive_mutex _mutex;
};

#pragma mark - impl

audio_unit_node::impl::impl() : audio_node::impl(), _core(std::make_unique<audio_unit_node::impl::core>())
{
}

audio_unit_node::impl::~impl() = default;

void audio_unit_node::impl::prepare(const audio_unit_node &node, const AudioComponentDescription &acd)
{
    _core->acd = acd;

    yas::audio_unit unit(acd);
    _core->set_au(unit);

    _core->parameters.clear();
    _core->parameters.insert(std::make_pair(kAudioUnitScope_Global, unit.create_parameters(kAudioUnitScope_Global)));
    _core->parameters.insert(std::make_pair(kAudioUnitScope_Input, unit.create_parameters(kAudioUnitScope_Input)));
    _core->parameters.insert(std::make_pair(kAudioUnitScope_Output, unit.create_parameters(kAudioUnitScope_Output)));
}

void audio_unit_node::impl::reset()
{
    auto unit = au();
    unit.reset();

    _core->parameters.clear();
    _core->parameters.insert(std::make_pair(kAudioUnitScope_Global, unit.create_parameters(kAudioUnitScope_Global)));
    _core->parameters.insert(std::make_pair(kAudioUnitScope_Input, unit.create_parameters(kAudioUnitScope_Input)));
    _core->parameters.insert(std::make_pair(kAudioUnitScope_Output, unit.create_parameters(kAudioUnitScope_Output)));

    super_class::reset();
}

audio_unit audio_unit_node::impl::au() const
{
    return _core->au();
}

const std::unordered_map<AudioUnitParameterID, audio_unit_parameter_map_t> &audio_unit_node::impl::parameters() const
{
    return _core->parameters;
}

const audio_unit_parameter_map_t &audio_unit_node::impl::global_parameters() const
{
    return _core->parameters.at(kAudioUnitScope_Global);
}

const audio_unit_parameter_map_t &audio_unit_node::impl::input_parameters() const
{
    return _core->parameters.at(kAudioUnitScope_Input);
}

const audio_unit_parameter_map_t &audio_unit_node::impl::output_parameters() const
{
    return _core->parameters.at(kAudioUnitScope_Output);
}

UInt32 audio_unit_node::impl::input_element_count() const
{
    return _core->au().element_count(kAudioUnitScope_Input);
}

UInt32 audio_unit_node::impl::output_element_count() const
{
    return _core->au().element_count(kAudioUnitScope_Output);
}

void audio_unit_node::impl::set_global_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value)
{
    auto &global_parameters = _core->parameters.at(kAudioUnitScope_Global);
    if (global_parameters.count(parameter_id) > 0) {
        auto &parameter = global_parameters.at(parameter_id);
        parameter.set_value(value, 0);
        if (auto &audio_unit = _core->_au) {
            audio_unit.set_parameter_value(value, parameter_id, kAudioUnitScope_Global, 0);
        }
    }
}

Float32 audio_unit_node::impl::global_parameter_value(const AudioUnitParameterID parameter_id) const
{
    if (auto &audio_unit = _core->_au) {
        return audio_unit.parameter_value(parameter_id, kAudioUnitScope_Global, 0);
    }
    return 0;
}

void audio_unit_node::impl::set_input_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value,
                                                      const AudioUnitElement element)
{
    auto &input_parameters = _core->parameters.at(kAudioUnitScope_Input);
    if (input_parameters.count(parameter_id) > 0) {
        auto &parameter = input_parameters.at(parameter_id);
        parameter.set_value(value, element);
        if (auto &audio_unit = _core->_au) {
            audio_unit.set_parameter_value(value, parameter_id, kAudioUnitScope_Input, element);
        }
    }
}

Float32 audio_unit_node::impl::input_parameter_value(const AudioUnitParameterID parameter_id,
                                                     const AudioUnitElement element) const
{
    if (auto &audio_unit = _core->_au) {
        return audio_unit.parameter_value(parameter_id, kAudioUnitScope_Input, element);
    }
    return 0;
}

void audio_unit_node::impl::set_output_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value,
                                                       const AudioUnitElement element)
{
    auto &output_parameters = _core->parameters.at(kAudioUnitScope_Output);
    if (output_parameters.count(parameter_id) > 0) {
        auto &parameter = output_parameters.at(parameter_id);
        parameter.set_value(value, element);
        if (auto &audio_unit = _core->_au) {
            audio_unit.set_parameter_value(value, parameter_id, kAudioUnitScope_Output, element);
        }
    }
}

Float32 audio_unit_node::impl::output_parameter_value(const AudioUnitParameterID parameter_id,
                                                      const AudioUnitElement element) const
{
    if (auto &audio_unit = _core->_au) {
        return audio_unit.parameter_value(parameter_id, kAudioUnitScope_Output, element);
    }
    return 0;
}

UInt32 audio_unit_node::impl::input_bus_count() const
{
    return 1;
}

UInt32 audio_unit_node::impl::output_bus_count() const
{
    return 1;
}

void audio_unit_node::impl::update_connections()
{
    if (auto audio_unit = _core->au()) {
        auto input_bus_count = input_element_count();
        if (input_bus_count > 0) {
            auto weak_node = to_weak(cast<audio_unit_node>());
            audio_unit.set_render_callback([weak_node](yas::render_parameters &render_parameters) {
                if (auto node = weak_node.lock()) {
                    if (auto kernel = node.impl_ptr<impl>()->kernel_cast()) {
                        if (auto connection = kernel->input_connection(render_parameters.in_bus_number)) {
                            if (auto source_node = connection.source_node()) {
                                auto buffer = yas::audio_pcm_buffer(connection.format(), render_parameters.io_data);
                                audio_time when(*render_parameters.io_time_stamp, connection.format().sample_rate());
                                source_node.render(buffer, connection.source_bus(), when);
                            }
                        }
                    }
                }
            });

            for (UInt32 bus_idx = 0; bus_idx < input_bus_count; ++bus_idx) {
                if (auto connection = input_connection(bus_idx)) {
                    audio_unit.set_input_format(connection.format().stream_description(), bus_idx);
                    audio_unit.attach_render_callback(bus_idx);
                } else {
                    audio_unit.detach_render_callback(bus_idx);
                }
            }
        } else {
            audio_unit.set_render_callback(nullptr);
        }

        auto output_bus_count = output_element_count();
        if (output_bus_count > 0) {
            for (UInt32 bus_idx = 0; bus_idx < output_bus_count; ++bus_idx) {
                if (auto connection = output_connection(bus_idx)) {
                    audio_unit.set_output_format(connection.format().stream_description(), bus_idx);
                }
            }
        }
    }
}

void audio_unit_node::impl::prepare_audio_unit()
{
    if (auto &audio_unit = _core->_au) {
        audio_unit.set_maximum_frames_per_slice(4096);
    }
}

void audio_unit_node::impl::prepare_parameters()
{
    if (auto audio_unit = _core->_au) {
        for (auto &parameters_pair : _core->parameters) {
            auto &scope = parameters_pair.first;
            for (auto &parameter_pair : _core->parameters.at(scope)) {
                auto &parameter = parameter_pair.second;
                for (auto &value_pair : parameter.values()) {
                    auto &element = value_pair.first;
                    auto &value = value_pair.second;
                    audio_unit.set_parameter_value(value, parameter.parameter_id(), scope, element);
                }
            }
        }
    }
}

void audio_unit_node::impl::reload_audio_unit()
{
    _core->set_au(yas::audio_unit(_core->acd));
}

void audio_unit_node::impl::render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when)
{
    super_class::render(buffer, bus_idx, when);

    if (auto audio_unit = _core->au()) {
        AudioUnitRenderActionFlags action_flags = 0;
        const AudioTimeStamp time_stamp = when.audio_time_stamp();

        render_parameters render_parameters{.in_render_type = render_type::normal,
                                            .io_action_flags = &action_flags,
                                            .io_time_stamp = &time_stamp,
                                            .in_bus_number = bus_idx,
                                            .in_number_frames = buffer.frame_length(),
                                            .io_data = buffer.audio_buffer_list()};

        if (auto err = audio_unit.audio_unit_render(render_parameters).error_opt()) {
            std::cout << "audio unit render error : " << std::to_string(*err) << " - " << yas::to_string(*err)
                      << std::endl;
        }
    }
}
