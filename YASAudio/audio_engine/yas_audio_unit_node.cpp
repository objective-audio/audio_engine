//
//  yas_audio_unit_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_unit_node.h"

using namespace yas;

#pragma mark - main

audio_unit_node::audio_unit_node(std::nullptr_t) : super_class(nullptr)
{
}

audio_unit_node::audio_unit_node(const AudioComponentDescription &acd) : audio_unit_node(std::make_shared<impl>(), acd)
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

audio_unit_node::audio_unit_node(std::shared_ptr<impl> &&imp, const AudioComponentDescription &acd)
    : audio_node(std::move(imp))
{
    impl_ptr<impl>()->prepare(*this, acd);
}

audio_unit_node::audio_unit_node(const std::shared_ptr<impl> &impl) : super_class(impl)
{
}

audio_unit_node::~audio_unit_node() = default;

audio::audio_unit audio_unit_node::audio_unit() const
{
    return impl_ptr<impl>()->au();
}

const std::unordered_map<AudioUnitParameterID, audio::audio_unit::parameter_map_t> &audio_unit_node::parameters() const
{
    return impl_ptr<impl>()->parameters();
}

const audio::audio_unit::parameter_map_t &audio_unit_node::global_parameters() const
{
    return impl_ptr<impl>()->global_parameters();
}

const audio::audio_unit::parameter_map_t &audio_unit_node::input_parameters() const
{
    return impl_ptr<impl>()->input_parameters();
}

const audio::audio_unit::parameter_map_t &audio_unit_node::output_parameters() const
{
    return impl_ptr<impl>()->output_parameters();
}

UInt32 audio_unit_node::input_element_count() const
{
    return impl_ptr<impl>()->input_element_count();
}

UInt32 audio_unit_node::output_element_count() const
{
    return impl_ptr<impl>()->output_element_count();
}

void audio_unit_node::set_global_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value)
{
    impl_ptr<impl>()->set_global_parameter_value(parameter_id, value);
}

Float32 audio_unit_node::global_parameter_value(const AudioUnitParameterID parameter_id) const
{
    return impl_ptr<impl>()->global_parameter_value(parameter_id);
}

void audio_unit_node::set_input_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value,
                                                const AudioUnitElement element)
{
    impl_ptr<impl>()->set_input_parameter_value(parameter_id, value, element);
}

Float32 audio_unit_node::input_parameter_value(const AudioUnitParameterID parameter_id,
                                               const AudioUnitElement element) const
{
    return impl_ptr<impl>()->input_parameter_value(parameter_id, element);
}

void audio_unit_node::set_output_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value,
                                                 const AudioUnitElement element)
{
    impl_ptr<impl>()->set_output_parameter_value(parameter_id, value, element);
}

Float32 audio_unit_node::output_parameter_value(const AudioUnitParameterID parameter_id,
                                                const AudioUnitElement element) const
{
    return impl_ptr<impl>()->output_parameter_value(parameter_id, element);
}

void audio_unit_node::_prepare_audio_unit()
{
    impl_ptr<impl>()->prepare_audio_unit();
}

void audio_unit_node::_prepare_parameters()
{
    impl_ptr<impl>()->prepare_parameters();
}

void audio_unit_node::_reload_audio_unit()
{
    impl_ptr<impl>()->reload_audio_unit();
}
