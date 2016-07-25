//
//  yas_audio_node_impl.h
//

#pragma once

#include "yas_audio_node_kernel.h"
#include "yas_audio_node_protocol.h"

namespace yas {
namespace audio {
    struct node::impl : base::impl, manageable_node::impl, connectable_node::impl {
        impl();
        virtual ~impl();

        impl(impl const &) = delete;
        impl(impl &&) = delete;
        impl &operator=(impl const &) = delete;
        impl &operator=(impl &&) = delete;

        virtual void reset() final;

        audio::format input_format(uint32_t const bus_idx);
        audio::format output_format(uint32_t const bus_idx);
        virtual bus_result_t next_available_input_bus() const;
        virtual bus_result_t next_available_output_bus() const;
        virtual bool is_available_input_bus(uint32_t const bus_idx) const;
        virtual bool is_available_output_bus(uint32_t const bus_idx) const;

        virtual uint32_t input_bus_count() const;
        virtual uint32_t output_bus_count() const;

        audio::connection input_connection(uint32_t const bus_idx) const override;
        audio::connection output_connection(uint32_t const bus_idx) const override;
        audio::connection_wmap &input_connections() const override;
        audio::connection_wmap &output_connections() const override;

        void add_connection(audio::connection const &connection) override;
        void remove_connection(audio::connection const &connection) override;

        virtual void update_connections() override final;
        virtual node::kernel make_kernel();
        virtual void prepare_kernel(node::kernel &kernel);  // requires super
        void update_kernel() override final;

        template <typename T = audio::node::kernel>
        T kernel_cast() const {
            return yas::cast<T>(_kernel());
        }

        audio::engine engine() const override;
        void set_engine(audio::engine const &) override;

        subject_t &subject();

        virtual void render(audio::pcm_buffer &buffer, uint32_t const bus_idx, audio::time const &when);
        audio::time render_time() const;
        void set_render_time_on_render(audio::time const &);

       private:
        class core;
        std::unique_ptr<core> _core;
        node::kernel _kernel() const;
    };
}
}
