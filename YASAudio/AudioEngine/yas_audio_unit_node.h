//
//  yas_audio_unit_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_node.h"
#include "yas_audio_unit.h"

namespace yas
{
    class audio_unit_node;
    class audio_graph;

    using audio_unit_node_ptr = std::shared_ptr<audio_unit_node>;
    using audio_unit_node_weak_ptr = std::weak_ptr<audio_unit_node>;
    using audio_graph_ptr = std::shared_ptr<audio_graph>;

    class audio_unit_node : public audio_node
    {
       public:
        static audio_unit_node_ptr create(const AudioComponentDescription &acd);
        static audio_unit_node_ptr create(const OSType type, const OSType sub_type);

        virtual ~audio_unit_node();

        audio_unit_ptr audio_unit() const;
        const std::map<AudioUnitScope, audio_unit_parameter_map> &parameters() const;
        const audio_unit_parameter_map &global_parameters() const;
        const audio_unit_parameter_map &input_parameters() const;
        const audio_unit_parameter_map &output_parameters() const;

        virtual uint32_t input_bus_count() const override;
        virtual uint32_t output_bus_count() const override;
        uint32_t input_element_count() const;
        uint32_t output_element_count() const;

        void set_global_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value);
        Float32 global_parameter_value(const AudioUnitParameterID parameter_id) const;
        void set_input_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value,
                                       const AudioUnitElement element);
        Float32 input_parameter_value(const AudioUnitParameterID parameter_id, const AudioUnitElement element) const;
        void set_output_parameter_value(const AudioUnitParameterID parameter_id, const Float32 value,
                                        const AudioUnitElement element);
        Float32 output_parameter_value(const AudioUnitParameterID parameter_id, const AudioUnitElement element) const;

        virtual void update_connections() override;

        void render(const pcm_buffer_ptr &buffer, const uint32_t bus_idx, const audio_time_ptr &when) override;

       protected:
        static void prepare_for_create(const audio_unit_node_ptr &node);

        audio_unit_node(const AudioComponentDescription &acd);

        virtual void prepare_audio_unit();
        virtual void prepare_parameters();  // NS_REQUIRES_SUPER

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        using super_class = audio_node;

        void reload_audio_unit();
        void add_audio_unit_to_graph(const audio_graph_ptr &graph);
        void remove_audio_unit_from_graph();

       public:
        class private_access;
        friend private_access;
    };
}

#include "yas_audio_unit_node_private_access.h"
