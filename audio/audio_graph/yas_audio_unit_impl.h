//
//  yas_audio_unit_impl.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

class yas::audio::unit::impl : public base::impl {
   public:
    std::experimental::optional<UInt8> graph_key;
    std::experimental::optional<UInt16> key;
    bool initialized;

    impl();
    ~impl();

    void create_audio_unit(const AudioComponentDescription &acd);
    void dispose_audio_unit();

    void initialize();
    void uninitialize();
    bool is_initialized() const;

    void reset();

    const AudioComponentDescription &acd() const;
    const std::string &name() const;

    void attach_render_callback(const UInt32 &bus_idx);
    void detach_render_callback(const UInt32 &bus_idx);
    void attach_render_notify();
    void detach_render_notify();
    void attach_input_callback();  // for io
    void detach_input_callback();  // for io

    void set_render_callback(const render_f &callback);
    void set_notify_callback(const render_f &callback);
    void set_input_callback(const render_f &callback);  // for io

    void set_input_format(const AudioStreamBasicDescription &asbd, const UInt32 bus_idx);
    void set_output_format(const AudioStreamBasicDescription &asbd, const UInt32 bus_idx);
    AudioStreamBasicDescription input_format(const UInt32 bus_idx) const;
    AudioStreamBasicDescription output_format(const UInt32 bus_idx) const;

    void set_maximum_frames_per_slice(const UInt32 frames);
    UInt32 maximum_frames_per_slice() const;

    void set_parameter_value(const AudioUnitParameterValue value, const AudioUnitParameterID parameter_id,
                             const AudioUnitScope scope, const AudioUnitElement element);
    AudioUnitParameterValue parameter_value(const AudioUnitParameterID parameter_id, const AudioUnitScope scope,
                                            const AudioUnitElement element);

    void set_element_count(const UInt32 &count, const AudioUnitScope &scope);  // for mixer
    UInt32 element_count(const AudioUnitScope &scope) const;                   // for mixer

    void set_enable_output(const bool enable_output);  // for io
    bool is_enable_output() const;                     // for io
    void set_enable_input(const bool enable_input);    // for io
    bool is_enable_input() const;                      // for io
    bool has_output() const;                           // for io
    bool has_input() const;                            // for io
    bool is_running() const;                           // for io

    void set_channel_map(const channel_map_t &map, const AudioUnitScope scope,
                         const AudioUnitElement element);                                         // for io
    channel_map_t channel_map(const AudioUnitScope scope, const AudioUnitElement element) const;  // for io
    UInt32 channel_map_count(const AudioUnitScope scope, const AudioUnitElement element) const;   // for io

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    void set_current_device(const AudioDeviceID &device);  // for io
    const AudioDeviceID current_device() const;            // for io
#endif

    void start();  // for io
    void stop();   // for io

    unit::render_f render_callback() const;  // atomic
    unit::render_f notify_callback() const;  // atomic
    unit::render_f input_callback() const;   // atomic

    void set_audio_unit_instance(const AudioUnit);  // atomic
    const AudioUnit audio_unit_instance() const;    // atomic

    void callback_render(render_parameters &render_parameters);           // render thread
    au_result_t audio_unit_render(render_parameters &render_parameters);  // render thread

    template <typename T>
    void set_property_data(const std::vector<T> &data, const AudioUnitPropertyID property_id,
                           const AudioUnitScope scope, const AudioUnitElement element);
    template <typename T>
    std::vector<T> property_data(const AudioUnitPropertyID property_id, const AudioUnitScope scope,
                                 const AudioUnitElement element) const;

   private:
    class core;
    std::unique_ptr<core> _core;
};

#include "yas_audio_unit_impl_private.h"
