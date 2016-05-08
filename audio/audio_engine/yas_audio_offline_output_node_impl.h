//
//  yas_audio_offline_output_node_impl.h
//

#pragma once

class yas::audio::offline_output_node::impl : public node::impl, public manageable_offline_output_unit::impl {
   public:
    impl();
    ~impl();

    offline_start_result_t start(offline_render_f &&render_func, offline_completion_f &&completion_func) override;
    void stop() override;

    virtual void reset() override;

    virtual UInt32 output_bus_count() const override;
    virtual UInt32 input_bus_count() const override;

    bool is_running() const;

   private:
    class core;
    std::unique_ptr<core> _core;
};
