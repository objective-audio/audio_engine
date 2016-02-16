//
//  yas_audio_unit_node_impl.h
//

#pragma once

class yas::audio::unit_node::impl : public node::impl {
    using super_class = node::impl;

   public:
    impl();
    virtual ~impl();

    void prepare(unit_node const &node, AudioComponentDescription const &acd);
    virtual void reset() override;

    yas::audio::unit au() const;

    std::unordered_map<AudioUnitScope, std::unordered_map<AudioUnitParameterID, audio::unit::parameter>> const &
    parameters() const;
    std::unordered_map<AudioUnitParameterID, audio::unit::parameter> const &global_parameters() const;
    std::unordered_map<AudioUnitParameterID, audio::unit::parameter> const &input_parameters() const;
    std::unordered_map<AudioUnitParameterID, audio::unit::parameter> const &output_parameters() const;

    UInt32 input_element_count() const;
    UInt32 output_element_count() const;

    void set_global_parameter_value(AudioUnitParameterID const parameter_id, Float32 const value);
    Float32 global_parameter_value(AudioUnitParameterID const parameter_id) const;
    void set_input_parameter_value(AudioUnitParameterID const parameter_id, Float32 const value,
                                   AudioUnitElement const element);
    Float32 input_parameter_value(AudioUnitParameterID const parameter_id, AudioUnitElement const element) const;
    void set_output_parameter_value(AudioUnitParameterID const parameter_id, Float32 const value,
                                    AudioUnitElement const element);
    Float32 output_parameter_value(AudioUnitParameterID const parameter_id, AudioUnitElement const element) const;

    virtual UInt32 input_bus_count() const override;
    virtual UInt32 output_bus_count() const override;

    virtual void update_connections() override;
    virtual void prepare_audio_unit();
    virtual void prepare_parameters();  // NS_REQUIRES_SUPER

    void reload_audio_unit();
    void set_graph(audio::graph const &);

    virtual void render(audio::pcm_buffer &buffer, UInt32 const bus_idx, audio::time const &when) override;

   private:
    class core;
    std::unique_ptr<core> _core;
};
