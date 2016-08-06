//
//  yas_audio_unit_node.cpp
//

#include "yas_audio_unit_node.h"

using namespace yas;

#pragma mark - main

audio::unit_node::unit_node(OSType const type, OSType const sub_type)
    : unit_node(AudioComponentDescription{
          .componentType = type,
          .componentSubType = sub_type,
          .componentManufacturer = kAudioUnitManufacturer_Apple,
          .componentFlags = 0,
          .componentFlagsMask = 0,
      }) {
}

audio::unit_node::unit_node(AudioComponentDescription const &acd)
    : unit_node({.acd = acd, .node_args = {.input_bus_count = 1, .output_bus_count = 1}}) {
}

audio::unit_node::unit_node(args &&args) : base(std::make_shared<impl>(std::move(args.node_args))) {
    impl_ptr<impl>()->prepare(*this, args.acd);
}

audio::unit_node::unit_node(std::nullptr_t) : base(nullptr) {
}

audio::unit_node::~unit_node() = default;

void audio::unit_node::set_prepare_audio_unit_handler(prepare_au_f handler) {
    impl_ptr<impl>()->set_prepare_audio_unit_handler(std::move(handler));
}

audio::unit audio::unit_node::audio_unit() const {
    return impl_ptr<impl>()->au();
}

std::unordered_map<AudioUnitParameterID, audio::unit::parameter_map_t> const &audio::unit_node::parameters() const {
    return impl_ptr<impl>()->parameters();
}

audio::unit::parameter_map_t const &audio::unit_node::global_parameters() const {
    return impl_ptr<impl>()->global_parameters();
}

audio::unit::parameter_map_t const &audio::unit_node::input_parameters() const {
    return impl_ptr<impl>()->input_parameters();
}

audio::unit::parameter_map_t const &audio::unit_node::output_parameters() const {
    return impl_ptr<impl>()->output_parameters();
}

uint32_t audio::unit_node::input_element_count() const {
    return impl_ptr<impl>()->input_element_count();
}

uint32_t audio::unit_node::output_element_count() const {
    return impl_ptr<impl>()->output_element_count();
}

void audio::unit_node::set_global_parameter_value(AudioUnitParameterID const parameter_id, float const value) {
    impl_ptr<impl>()->set_global_parameter_value(parameter_id, value);
}

float audio::unit_node::global_parameter_value(AudioUnitParameterID const parameter_id) const {
    return impl_ptr<impl>()->global_parameter_value(parameter_id);
}

void audio::unit_node::set_input_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                                 AudioUnitElement const element) {
    impl_ptr<impl>()->set_input_parameter_value(parameter_id, value, element);
}

float audio::unit_node::input_parameter_value(AudioUnitParameterID const parameter_id,
                                              AudioUnitElement const element) const {
    return impl_ptr<impl>()->input_parameter_value(parameter_id, element);
}

void audio::unit_node::set_output_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                                  AudioUnitElement const element) {
    impl_ptr<impl>()->set_output_parameter_value(parameter_id, value, element);
}

float audio::unit_node::output_parameter_value(AudioUnitParameterID const parameter_id,
                                               AudioUnitElement const element) const {
    return impl_ptr<impl>()->output_parameter_value(parameter_id, element);
}

audio::unit_node::subject_t &audio::unit_node::subject() {
    return impl_ptr<impl>()->subject();
}

audio::node const &audio::unit_node::node() const {
    return impl_ptr<impl>()->node();
}

audio::node &audio::unit_node::node() {
    return impl_ptr<impl>()->node();
}

audio::manageable_unit_node &audio::unit_node::manageable() {
    if (!_manageable) {
        _manageable = audio::manageable_unit_node{impl_ptr<manageable_unit_node::impl>()};
    }
    return _manageable;
}
