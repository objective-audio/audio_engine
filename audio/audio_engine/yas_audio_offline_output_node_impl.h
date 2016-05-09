//
//  yas_audio_offline_output_node_impl.h
//

#pragma once

namespace yas {
namespace audio {
    struct offline_output_node::impl : node::impl, manageable_offline_output_unit::impl {
        impl();
        ~impl();

        offline_start_result_t start(offline_render_f &&render_func, offline_completion_f &&completion_func) override;
        void stop() override;

        virtual void reset() override;

        virtual uint32_t output_bus_count() const override;
        virtual uint32_t input_bus_count() const override;

        bool is_running() const;

       private:
        class core;
        std::unique_ptr<core> _core;
    };
}
}
