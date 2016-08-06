//
//  yas_audio_unit_node.h
//

#pragma once

#include <unordered_map>
#include "yas_audio_node_protocol.h"
#include "yas_audio_unit.h"
#include "yas_audio_unit_node_protocol.h"
#include "yas_base.h"
#include "yas_observing.h"

namespace yas {
namespace audio {
    class graph;
    class node;

    class unit_node : public base {
       public:
        class impl;

        enum class method {
            will_update_connections,
            did_update_connections,
        };

        using subject_t = yas::subject<unit_node, method>;
        using observer_t = yas::observer<unit_node, method>;
        using prepare_au_f = std::function<void(audio::unit &)>;

        struct args {
            audio::node_args node_args;
            AudioComponentDescription acd;
        };

        unit_node(OSType const type, OSType const sub_type);
        explicit unit_node(AudioComponentDescription const &);
        unit_node(args &&);
        unit_node(std::nullptr_t);

        virtual ~unit_node();

        void set_prepare_audio_unit_handler(prepare_au_f);

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

        subject_t &subject();

        audio::node const &node() const;
        audio::node &node();

        manageable_unit_node &manageable();

       private:
        manageable_unit_node _manageable = nullptr;
    };
}
}

#include "yas_audio_unit_node_impl.h"
