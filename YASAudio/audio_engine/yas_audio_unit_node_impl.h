//
//  yas_audio_unit_node_impl.h
//  YASAudio_Tests
//
//  Created by Yuki Yasoshima on 2015/10/24.
//
//

#pragma once

class yas::audio_unit_node::impl : public audio_node::impl
{
    using super_class = audio_node::impl;

   public:
    impl();
    virtual ~impl();

    void prepare(const audio_unit_node &node, const AudioComponentDescription &acd);
    virtual void reset() override;

    yas::audio_unit au() const;

    const std::unordered_map<AudioUnitScope, std::unordered_map<AudioUnitParameterID, audio_unit_parameter>>
        &parameters() const;
    const std::unordered_map<AudioUnitParameterID, audio_unit_parameter> &global_parameters() const;
    const std::unordered_map<AudioUnitParameterID, audio_unit_parameter> &input_parameters() const;
    const std::unordered_map<AudioUnitParameterID, audio_unit_parameter> &output_parameters() const;

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

    virtual UInt32 input_bus_count() const override;
    virtual UInt32 output_bus_count() const override;

    virtual void update_connections() override;
    virtual void prepare_audio_unit();
    virtual void prepare_parameters();  // NS_REQUIRES_SUPER

    void reload_audio_unit();
    void set_graph(const audio_graph &);

    virtual void render(audio::pcm_buffer &buffer, const UInt32 bus_idx, const audio::time &when) override;

   private:
    class core;
    std::unique_ptr<core> _core;
};
