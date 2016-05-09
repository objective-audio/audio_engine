//
//  yas_audio_device_io_node_impl.h
//

#pragma once

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

struct yas::audio::device_io_node::impl : node::impl, manageable_device_io_node::impl {
    impl();
    virtual ~impl();

    void prepare(device_io_node const &, audio::device const &);

    virtual uint32_t input_bus_count() const override;
    virtual uint32_t output_bus_count() const override;

    virtual void update_connections() override;

    void add_device_io() override;
    void remove_device_io() override;
    audio::device_io &device_io() const override;

    void set_device(audio::device const &device);
    audio::device device() const;

    virtual void render(pcm_buffer &buffer, uint32_t const bus_idx, time const &when) override;

   private:
    class core;
    std::unique_ptr<core> _core;

    bool _validate_connections() const;
};

#endif