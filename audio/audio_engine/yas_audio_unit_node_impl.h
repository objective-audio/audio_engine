//
//  yas_audio_unit_node_impl.h
//

#pragma once

namespace yas {
namespace audio {
    struct unit_node::impl : node::impl, manageable_unit_node::impl {
        impl();
        virtual ~impl();

        void prepare(unit_node const &node, AudioComponentDescription const &acd);

        audio::unit au() const;

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

        void update_unit_connections();
        virtual void prepare_audio_unit() override;
        virtual void prepare_parameters() override;  // NS_REQUIRES_SUPER

        void reload_audio_unit() override;
        void set_graph(audio::graph const &);

        audio::unit_node::subject_t &subject();

        void unit_render(audio::pcm_buffer &buffer, uint32_t const bus_idx, audio::time const &when);

       private:
        class core;
        std::unique_ptr<core> _core;

        void will_reset();
    };
}
}
