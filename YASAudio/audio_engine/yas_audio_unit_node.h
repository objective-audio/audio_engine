//
//  yas_audio_unit_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_node.h"
#include "yas_audio_unit.h"
#include "yas_audio_unit_node_protocol.h"
#include <unordered_map>

namespace yas {
namespace audio {
    class graph;

    class unit_node : public node, public unit_node_from_engine {
        using super_class = node;

       public:
        class impl;

        unit_node(std::nullptr_t);
        unit_node(const AudioComponentDescription &);
        unit_node(const OSType type, const OSType sub_type);

        virtual ~unit_node();

        audio::unit audio_unit() const;
        const std::unordered_map<AudioUnitScope, std::unordered_map<AudioUnitParameterID, audio::unit::parameter>>
            &parameters() const;
        const std::unordered_map<AudioUnitParameterID, audio::unit::parameter> &global_parameters() const;
        const std::unordered_map<AudioUnitParameterID, audio::unit::parameter> &input_parameters() const;
        const std::unordered_map<AudioUnitParameterID, audio::unit::parameter> &output_parameters() const;

        UInt32 input_element_count() const;
        UInt32 output_element_count() const;

        void set_global_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value);
        Float32 global_parameter_value(const AudioUnitParameterID parameter_id) const;
        void set_input_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value,
                                       const AudioUnitElement element);
        Float32 input_parameter_value(const AudioUnitParameterID parameter_id, const AudioUnitElement element) const;
        void set_output_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value,
                                        const AudioUnitElement element);
        Float32 output_parameter_value(const AudioUnitParameterID parameter_id, const AudioUnitElement element) const;

       protected:
        unit_node(std::shared_ptr<impl> &&, const AudioComponentDescription &);
        explicit unit_node(const std::shared_ptr<impl> &);

       private:
        // from engine

        void _prepare_audio_unit() override;
        void _prepare_parameters() override;
        void _reload_audio_unit() override;

#if YAS_TEST
       public:
        class private_access;
        friend private_access;
#endif
    };
}
}

#include "yas_audio_unit_node_impl.h"

#if YAS_TEST
#include "yas_audio_unit_node_private_access.h"
#endif
