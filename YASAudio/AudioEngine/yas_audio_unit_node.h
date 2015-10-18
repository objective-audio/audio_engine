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
        static audio_unit_node_sptr create(const AudioComponentDescription &);
        static audio_unit_node_sptr create(const OSType type, const OSType sub_type);

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

        void render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when) override;

       protected:
        class impl : public audio_node::impl
        {
           public:
            impl();
            virtual ~impl();

            yas::audio_unit au() const;

            UInt32 input_element_count() const;
            UInt32 output_element_count() const;

            virtual UInt32 input_bus_count() const override;
            virtual UInt32 output_bus_count() const override;

            virtual void update_connections() override;

            class core;
            std::unique_ptr<core> _core;
        };

        static void prepare_for_create(const audio_unit_node_sptr &);

        audio_unit_node(std::shared_ptr<impl> &&, const AudioComponentDescription &);

        virtual void prepare_audio_unit();
        virtual void prepare_parameters();  // NS_REQUIRES_SUPER

       private:
        audio_unit_node(const std::shared_ptr<impl> &);

        impl *_impl_ptr() const;

        using super_class = audio_node;

        void _reload_audio_unit();
        void _add_audio_unit_to_graph(audio_graph &graph);
        void _remove_audio_unit_from_graph();

       public:
        class private_access;
        friend private_access;

        using weak = yas::weak<audio_unit_node, audio_unit_node::impl>;
        friend weak;
    };
}

#include "yas_audio_unit_node_private_access.h"
