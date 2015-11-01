//
//  yas_audio_unit_io_node_impl.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

class yas::audio_unit_io_node::impl : public super_class::impl
{
    using super_class = audio_unit_node::impl;

   public:
    impl();
    virtual ~impl();

    virtual void reset() override;

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    void set_device(const audio_device &device);
    audio_device device() const;
#endif
    Float64 device_sample_rate() const;
    UInt32 output_device_channel_count() const;
    UInt32 input_device_channel_count() const;

    void set_channel_map(const channel_map_t &map, const yas::direction dir);
    const channel_map_t &channel_map(const yas::direction dir) const;

    virtual bus_result_t next_available_output_bus() const override;
    virtual bool is_available_output_bus(const UInt32 bus_idx) const override;

    virtual void update_connections() override;
    virtual void prepare_audio_unit() override;

   private:
    class core;
    std::unique_ptr<core> _core;
};

class yas::audio_unit_output_node::impl : public super_class::impl
{
    virtual UInt32 input_bus_count() const override;
    virtual UInt32 output_bus_count() const override;
    virtual void prepare_audio_unit() override;
};

class yas::audio_unit_input_node::impl : public super_class::impl
{
    using super_class = audio_unit_io_node::impl;

   public:
    impl();
    virtual ~impl();

    virtual UInt32 input_bus_count() const override;
    virtual UInt32 output_bus_count() const override;

    virtual void update_connections() override;
    virtual void prepare_audio_unit() override;

    weak<audio_unit_input_node> weak_node() const;

   private:
    class core;
    std::unique_ptr<core> _core;
};
