//
//  yas_audio_unit_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_unit_node.h"
#include "yas_audio_unit.h"
#include "yas_audio_unit_parameter.h"

using namespace yas;

#pragma mark - main

audio_unit_node::audio_unit_node(std::nullptr_t) : super_class(nullptr)
{
}

audio_unit_node::audio_unit_node(const AudioComponentDescription &acd)
    : audio_unit_node(std::make_unique<impl>(), acd, create_tag)
{
}

audio_unit_node::audio_unit_node(const OSType type, const OSType sub_type)
    : audio_unit_node(AudioComponentDescription{
          .componentType = type,
          .componentSubType = sub_type,
          .componentManufacturer = kAudioUnitManufacturer_Apple,
          .componentFlags = 0,
          .componentFlagsMask = 0,
      })
{
}

audio_unit_node::audio_unit_node(const audio_node &node, audio_node::cast_tag_t)
    : super_class(std::dynamic_pointer_cast<audio_unit_node::impl>(audio_node::private_access::impl(node)))
{
}

audio_unit_node::audio_unit_node(std::shared_ptr<impl> &&impl, const AudioComponentDescription &acd, create_tag_t)
    : audio_node(std::move(impl), create_tag)
{
    _impl_ptr()->prepare(*this, acd);
}

audio_unit_node::audio_unit_node(const std::shared_ptr<impl> &impl) : super_class(impl)
{
}

audio_unit_node::~audio_unit_node() = default;

audio_unit audio_unit_node::audio_unit() const
{
    return _impl_ptr()->au();
}

const std::map<AudioUnitParameterID, audio_unit_parameter_map_t> &audio_unit_node::parameters() const
{
    return _impl_ptr()->parameters();
}

const audio_unit_parameter_map_t &audio_unit_node::global_parameters() const
{
    return _impl_ptr()->global_parameters();
}

const audio_unit_parameter_map_t &audio_unit_node::input_parameters() const
{
    return _impl_ptr()->input_parameters();
}

const audio_unit_parameter_map_t &audio_unit_node::output_parameters() const
{
    return _impl_ptr()->output_parameters();
}

UInt32 audio_unit_node::input_element_count() const
{
    return _impl_ptr()->input_element_count();
}

UInt32 audio_unit_node::output_element_count() const
{
    return _impl_ptr()->output_element_count();
}

void audio_unit_node::set_global_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value)
{
    _impl_ptr()->set_global_parameter_value(parameter_id, value);
}

Float32 audio_unit_node::global_parameter_value(const AudioUnitParameterID parameter_id) const
{
    return _impl_ptr()->global_parameter_value(parameter_id);
}

void audio_unit_node::set_input_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value,
                                                const AudioUnitElement element)
{
    _impl_ptr()->set_input_parameter_value(parameter_id, value, element);
}

Float32 audio_unit_node::input_parameter_value(const AudioUnitParameterID parameter_id,
                                               const AudioUnitElement element) const
{
    return _impl_ptr()->input_parameter_value(parameter_id, element);
}

void audio_unit_node::set_output_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value,
                                                 const AudioUnitElement element)
{
    _impl_ptr()->set_output_parameter_value(parameter_id, value, element);
}

Float32 audio_unit_node::output_parameter_value(const AudioUnitParameterID parameter_id,
                                                const AudioUnitElement element) const
{
    return _impl_ptr()->output_parameter_value(parameter_id, element);
}

std::shared_ptr<audio_unit_node::impl> audio_unit_node::_impl_ptr() const
{
    return std::dynamic_pointer_cast<audio_unit_node::impl>(_impl);
}
