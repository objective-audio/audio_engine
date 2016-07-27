//
//  yas_audio_offline_output_node_impl.h
//

#pragma once

namespace yas {
namespace audio {
    struct offline_output_node::impl : node::impl, manageable_offline_output_unit::impl {
        impl();
        ~impl();

        void prepare(offline_output_node const &);

        offline_start_result_t start(offline_render_f &&render_func, offline_completion_f &&completion_func) override;
        void stop() override;

        void _will_reset();

        bool is_running() const;

       private:
        class core;
        std::unique_ptr<core> _core;
    };
}
}
