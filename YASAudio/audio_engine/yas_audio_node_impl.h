//
//  yas_audio_node_impl.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

class yas::audio_node::impl : public base::impl
{
   public:
    impl();
    virtual ~impl();

    impl(const impl &) = delete;
    impl(impl &&) = delete;
    impl &operator=(const impl &) = delete;
    impl &operator=(impl &&) = delete;

    virtual void reset();  // requires super

    audio::format input_format(const UInt32 bus_idx);
    audio::format output_format(const UInt32 bus_idx);
    virtual bus_result_t next_available_input_bus() const;
    virtual bus_result_t next_available_output_bus() const;
    virtual bool is_available_input_bus(const UInt32 bus_idx) const;
    virtual bool is_available_output_bus(const UInt32 bus_idx) const;

    virtual UInt32 input_bus_count() const;
    virtual UInt32 output_bus_count() const;

    audio::connection input_connection(const UInt32 bus_idx) const;
    audio::connection output_connection(const UInt32 bus_idx) const;
    audio::connection_wmap &input_connections() const;
    audio::connection_wmap &output_connections() const;

    void add_connection(const audio::connection &connection);
    void remove_connection(const audio::connection &connection);

    virtual void update_connections();
    virtual std::shared_ptr<kernel> make_kernel();
    virtual void prepare_kernel(const std::shared_ptr<kernel> &kernel);  // requires super
    void update_kernel();

    template <typename T = audio_node::kernel>
    std::shared_ptr<T> kernel_cast() const
    {
        return std::static_pointer_cast<T>(_kernel());
    }

    audio::engine engine() const;
    void set_engine(const audio::engine &);

    virtual void render(audio::pcm_buffer &buffer, const UInt32 bus_idx, const audio::time &when);
    audio::time render_time() const;
    void set_render_time_on_render(const audio::time &time);

   private:
    class core;
    std::unique_ptr<core> _core;
    std::shared_ptr<kernel> _kernel() const;
};
