//
//  yas_audio_unit_node.h
//

#pragma once

#include <unordered_map>
#include "yas_audio_node.h"
#include "yas_audio_unit.h"
#include "yas_audio_unit_node_protocol.h"

namespace yas {
namespace audio {
    class graph;

    class unit_node : public node {
       public:
        class impl;

        unit_node(std::nullptr_t);
        unit_node(AudioComponentDescription const &);
        unit_node(OSType const type, OSType const sub_type);

        virtual ~unit_node();

        audio::unit audio_unit() const;
        std::unordered_map<AudioUnitScope, std::unordered_map<AudioUnitParameterID, audio::unit::parameter>> const &
        parameters() const;
        std::unordered_map<AudioUnitParameterID, audio::unit::parameter> const &global_parameters() const;
        std::unordered_map<AudioUnitParameterID, audio::unit::parameter> const &input_parameters() const;
        std::unordered_map<AudioUnitParameterID, audio::unit::parameter> const &output_parameters() const;

        uint32_t input_element_count() const;
        uint32_t output_element_count() const;

        void set_global_parameter_value(AudioUnitParameterID const parameter_id, float const value);
        float global_parameter_value(AudioUnitParameterID const parameter_id) const;
        void set_input_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                       AudioUnitElement const element);
        float input_parameter_value(AudioUnitParameterID const parameter_id, AudioUnitElement const element) const;
        void set_output_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                        AudioUnitElement const element);
        float output_parameter_value(AudioUnitParameterID const parameter_id, AudioUnitElement const element) const;

        manageable_unit_node manageable_unit_node();

       protected:
        unit_node(std::shared_ptr<impl> &&, AudioComponentDescription const &);
        explicit unit_node(std::shared_ptr<impl> const &);

#if YAS_TEST
       public:
        class private_access;
        friend private_access;
#endif
    };
}
}

#include "yas_audio_unit_node_impl.h"
