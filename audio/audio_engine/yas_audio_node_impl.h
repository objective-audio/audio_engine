//
//  yas_audio_node_impl.h
//

#pragma once

#include "yas_audio_node_kernel.h"
#include "yas_audio_node_protocol.h"

namespace yas {
namespace audio {
    struct node::impl : base::impl, manageable_node::impl, connectable_node::impl {
        explicit impl(node_args &&);
        ~impl();

        impl(impl const &) = delete;
        impl(impl &&) = delete;
        impl &operator=(impl const &) = delete;
        impl &operator=(impl &&) = delete;

        virtual void reset() final;

        audio::format input_format(uint32_t const bus_idx);
        audio::format output_format(uint32_t const bus_idx);
        bus_result_t next_available_input_bus() const;
        bus_result_t next_available_output_bus() const;
        bool is_available_input_bus(uint32_t const bus_idx) const;
        bool is_available_output_bus(uint32_t const bus_idx) const;
        void override_output_bus_idx(std::experimental::optional<uint32_t> bus_idx);

        void set_input_bus_count(uint32_t const);
        void set_output_bus_count(uint32_t const);
        uint32_t input_bus_count() const;
        uint32_t output_bus_count() const;

        void set_input_renderable(bool const);
        bool is_input_renderable();

        audio::connection input_connection(uint32_t const bus_idx) const override final;
        audio::connection output_connection(uint32_t const bus_idx) const override final;
        audio::connection_wmap &input_connections() const override final;
        audio::connection_wmap &output_connections() const override final;

        void add_connection(audio::connection const &connection) override final;
        void remove_connection(audio::connection const &connection) override final;

        void update_connections() override final;
        void set_make_kernel_handler(std::function<node::kernel(void)> &&);
        void prepare_kernel(node::kernel &kernel);
        void update_kernel() override final;

        template <typename T = audio::node::kernel>
        T kernel_cast() const {
            return yas::cast<T>(_kernel());
        }

        audio::engine engine() const override final;
        void set_engine(audio::engine const &) override final;

        void set_add_to_graph_handler(std::function<void(audio::graph &)> &&) override final;
        void set_remove_from_graph_handler(std::function<void(audio::graph &)> &&) override final;
        std::function<void(audio::graph &)> const &add_to_graph_handler() const override final;
        std::function<void(audio::graph &)> const &remove_from_graph_handler() const override final;

        subject_t &subject();
        kernel_subject_t &kernel_subject();

        void set_render_handler(audio::node::render_f &&);
        void render(audio::pcm_buffer &buffer, uint32_t const bus_idx, audio::time const &when);
        audio::time render_time() const;
        void set_render_time_on_render(audio::time const &);

       private:
        class core;
        std::unique_ptr<core> _core;
        node::kernel _make_kernel();
        node::kernel _kernel() const;
    };
}
}
