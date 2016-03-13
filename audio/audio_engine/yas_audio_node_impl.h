//
//  yas_audio_node_impl.h
//

#pragma once

#include "yas_audio_node_protocol.h"

class yas::audio::node::impl : public base::impl, public manageable_node::impl {
   public:
    impl();
    virtual ~impl();

    impl(impl const &) = delete;
    impl(impl &&) = delete;
    impl &operator=(impl const &) = delete;
    impl &operator=(impl &&) = delete;

    virtual void reset();  // requires super

    audio::format input_format(UInt32 const bus_idx);
    audio::format output_format(UInt32 const bus_idx);
    virtual bus_result_t next_available_input_bus() const;
    virtual bus_result_t next_available_output_bus() const;
    virtual bool is_available_input_bus(UInt32 const bus_idx) const;
    virtual bool is_available_output_bus(UInt32 const bus_idx) const;

    virtual UInt32 input_bus_count() const;
    virtual UInt32 output_bus_count() const;

    audio::connection input_connection(UInt32 const bus_idx) const;
    audio::connection output_connection(UInt32 const bus_idx) const;
    audio::connection_wmap &input_connections() const;
    audio::connection_wmap &output_connections() const;

    void add_connection(audio::connection const &connection);
    void remove_connection(audio::connection const &connection);

    virtual void update_connections();
    virtual std::shared_ptr<kernel> make_kernel();
    virtual void prepare_kernel(std::shared_ptr<kernel> const &kernel);  // requires super
    void update_kernel();

    template <typename T = audio::node::kernel>
    std::shared_ptr<T> kernel_cast() const {
        return std::static_pointer_cast<T>(_kernel());
    }

    audio::engine engine() const;
    void set_engine(audio::engine const &);

    virtual void render(audio::pcm_buffer &buffer, UInt32 const bus_idx, audio::time const &when);
    audio::time render_time() const;
    void set_render_time_on_render(audio::time const &time);

   private:
    class core;
    std::unique_ptr<core> _core;
    std::shared_ptr<kernel> _kernel() const;
};
