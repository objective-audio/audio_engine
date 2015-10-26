//
//  yas_audio_unit_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_node.h"

namespace yas
{
    class audio_graph;
    class audio_unit;
    class audio_unit_parameter;

    class audio_unit_node : public audio_node
    {
       public:
        audio_unit_node(std::nullptr_t);
        audio_unit_node(const AudioComponentDescription &);
        audio_unit_node(const OSType type, const OSType sub_type);

        audio_unit_node(const audio_node &, audio_node::cast_tag_t);

        virtual ~audio_unit_node();

        audio_unit audio_unit() const;
        const std::map<AudioUnitScope, std::map<AudioUnitParameterID, audio_unit_parameter>> &parameters() const;
        const std::map<AudioUnitParameterID, audio_unit_parameter> &global_parameters() const;
        const std::map<AudioUnitParameterID, audio_unit_parameter> &input_parameters() const;
        const std::map<AudioUnitParameterID, audio_unit_parameter> &output_parameters() const;

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
        class impl;

        audio_unit_node(std::shared_ptr<impl> &&, const AudioComponentDescription &, create_tag_t);
        explicit audio_unit_node(const std::shared_ptr<impl> &);

       private:
        using super_class = audio_node;

        std::shared_ptr<impl> _impl_ptr() const;

       public:
        class private_access;
        friend private_access;

        friend weak<audio_unit_node>;
    };
}

#include "yas_audio_unit_node_impl.h"
#include "yas_audio_unit_node_private_access.h"
