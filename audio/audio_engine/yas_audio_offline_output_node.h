//
//  yas_audio_offline_output_node.h
//

#pragma once

#include "yas_audio_node.h"
#include "yas_audio_offline_output_node_protocol.h"

namespace yas {
namespace audio {
    class offline_output_node : public node, public offline_output_unit_from_engine {
        using super_class = node;

       public:
        class impl;

        offline_output_node();
        offline_output_node(std::nullptr_t);

        ~offline_output_node();

        bool is_running() const;

       private:
        offline_output_node(std::shared_ptr<impl> const &);

        // from engine

        offline_start_result_t _start(offline_render_f &&callback_func,
                                      offline_completion_f &&completion_func) const override;
        void _stop() const override;

#if YAS_TEST
       public:
        class private_access;
        friend private_access;
#endif
    };
}

std::string to_string(audio::offline_start_error_t const &error);
}

#include "yas_audio_offline_output_node_impl.h"

#if YAS_TEST
#include "yas_audio_offline_output_node_private_access.h"
#endif
