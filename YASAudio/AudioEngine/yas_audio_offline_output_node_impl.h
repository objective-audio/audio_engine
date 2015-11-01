//
//  yas_audio_offline_output_node_impl.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

class yas::audio_offline_output_node::impl : public super_class::impl
{
    using super_class = super_class::impl;

   public:
    impl();
    ~impl();

    offline_start_result_t start(const offline_render_f &render_func, const offline_completion_f &completion_func);
    void stop();

    virtual void reset() override;

    virtual UInt32 output_bus_count() const override;
    virtual UInt32 input_bus_count() const override;

    base_weak<audio_offline_output_node> weak_node() const;

    bool is_running() const;

   private:
    class core;
    std::unique_ptr<core> _core;
};
