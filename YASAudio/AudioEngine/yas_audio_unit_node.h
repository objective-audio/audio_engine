//
//  yas_audio_unit_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_node.h"
#include "yas_audio_unit.h"

namespace yas
{
    class audio_unit_node : public audio_node
    {
       public:
        static audio_unit_node_sptr create(const AudioComponentDescription &acd);
        static audio_unit_node_sptr create(const OSType type, const OSType sub_type);

        virtual ~audio_unit_node();

        audio_unit_sptr audio_unit() const;
        const std::map<AudioUnitScope, audio_unit_parameter_map> &parameters() const;
        const audio_unit_parameter_map &global_parameters() const;
        const audio_unit_parameter_map &input_parameters() const;
        const audio_unit_parameter_map &output_parameters() const;

        virtual UInt32 input_bus_count() const override;
        virtual UInt32 output_bus_count() const override;
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

        virtual void update_connections() override;

        void render(const audio_pcm_buffer_sptr &buffer, const UInt32 bus_idx, const audio_time_sptr &when) override;

       protected:
        static void prepare_for_create(const audio_unit_node_sptr &node);

        audio_unit_node(const AudioComponentDescription &acd);

        virtual void prepare_audio_unit();
        virtual void prepare_parameters();  // NS_REQUIRES_SUPER

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        using super_class = audio_node;

        void _reload_audio_unit();
        void _add_audio_unit_to_graph(const audio_graph_sptr &graph);
        void _remove_audio_unit_from_graph();

       public:
        class private_access;
        friend private_access;
    };
}

#include "yas_audio_unit_node_private_access.h"
