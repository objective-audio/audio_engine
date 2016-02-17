//
//  yas_audio_unit_impl.h
//

#pragma once

class yas::audio::unit::impl : public base::impl {
   public:
    std::experimental::optional<UInt8> graph_key;
    std::experimental::optional<UInt16> key;
    bool initialized;

    impl();
    ~impl();

    void create_audio_unit(AudioComponentDescription const &acd);
    void dispose_audio_unit();

    void initialize();
    void uninitialize();
    bool is_initialized() const;

    void reset();

    AudioComponentDescription const &acd() const;
    std::string const &name() const;

    void attach_render_callback(UInt32 const bus_idx);
    void detach_render_callback(UInt32 const bus_idx);
    void attach_render_notify();
    void detach_render_notify();
    void attach_input_callback();  // for io
    void detach_input_callback();  // for io

    void set_render_callback(render_f &&callback);
    void set_notify_callback(render_f &&callback);
    void set_input_callback(render_f &&callback);  // for io

    void set_input_format(AudioStreamBasicDescription const &asbd, UInt32 const bus_idx);
    void set_output_format(AudioStreamBasicDescription const &asbd, UInt32 const bus_idx);
    AudioStreamBasicDescription input_format(UInt32 const bus_idx) const;
    AudioStreamBasicDescription output_format(UInt32 const bus_idx) const;

    void set_maximum_frames_per_slice(UInt32 const frames);
    UInt32 maximum_frames_per_slice() const;

    void set_parameter_value(AudioUnitParameterValue const value, AudioUnitParameterID const parameter_id,
                             AudioUnitScope const scope, AudioUnitElement const element);
    AudioUnitParameterValue parameter_value(AudioUnitParameterID const parameter_id, AudioUnitScope const scope,
                                            AudioUnitElement const element);

    void set_element_count(UInt32 const count, AudioUnitScope const scope);  // for mixer
    UInt32 element_count(AudioUnitScope const scope) const;                  // for mixer

    void set_enable_output(const bool enable_output);  // for io
    bool is_enable_output() const;                     // for io
    void set_enable_input(const bool enable_input);    // for io
    bool is_enable_input() const;                      // for io
    bool has_output() const;                           // for io
    bool has_input() const;                            // for io
    bool is_running() const;                           // for io

    void set_channel_map(const channel_map_t &map, AudioUnitScope const scope,
                         AudioUnitElement const element);                                         // for io
    channel_map_t channel_map(AudioUnitScope const scope, AudioUnitElement const element) const;  // for io
    UInt32 channel_map_count(AudioUnitScope const scope, AudioUnitElement const element) const;   // for io

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    void set_current_device(AudioDeviceID const device);  // for io
    AudioDeviceID current_device() const;                 // for io
#endif

    void start();  // for io
    void stop();   // for io

    unit::render_f render_callback() const;  // atomic
    unit::render_f notify_callback() const;  // atomic
    unit::render_f input_callback() const;   // atomic

    void set_audio_unit_instance(AudioUnit const);  // atomic
    AudioUnit audio_unit_instance() const;          // atomic

    void callback_render(render_parameters &render_parameters);           // render thread
    au_result_t audio_unit_render(render_parameters &render_parameters);  // render thread

    template <typename T>
    void set_property_data(std::vector<T> const &data, AudioUnitPropertyID const property_id,
                           AudioUnitScope const scope, AudioUnitElement const element);
    template <typename T>
    std::vector<T> property_data(AudioUnitPropertyID const property_id, AudioUnitScope const scope,
                                 AudioUnitElement const element) const;

   private:
    class core;
    std::unique_ptr<core> _core;
};

#include "yas_audio_unit_impl_private.h"
