//
//  yas_audio_tap_node_impl.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

class yas::audio_tap_node::impl : public super_class::impl
{
    using super_class = super_class::impl;

   public:
    impl();
    virtual ~impl();

    virtual void reset() override;

    virtual UInt32 input_bus_count() const override;
    virtual UInt32 output_bus_count() const override;

    virtual std::shared_ptr<audio_node::kernel> make_kernel() override;
    virtual void prepare_kernel(const std::shared_ptr<audio_node::kernel> &kernel) override;

    void set_render_function(const render_f &);

    audio_connection input_connection_on_render(const UInt32 bus_idx) const;
    audio_connection output_connection_on_render(const UInt32 bus_idx) const;
    audio_connection_smap input_connections_on_render() const;
    audio_connection_smap output_connections_on_render() const;

    virtual void render(audio::pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when) override;
    void render_source(audio::pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when);

   private:
    class core;
    std::unique_ptr<core> _core;
};

class yas::audio_input_tap_node::impl : public super_class::impl
{
    virtual UInt32 input_bus_count() const override;
    virtual UInt32 output_bus_count() const override;
};