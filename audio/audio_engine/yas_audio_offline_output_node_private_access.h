//
//  yas_audio_offline_output_node_private_access.h
//

#pragma once

#if YAS_TEST

namespace yas {
namespace audio {
    class offline_output_node::private_access {
       public:
        static offline_start_result_t start(offline_output_node &node, offline_render_f callback_func,
                                            offline_completion_f completion_func) {
            return node._start(std::move(callback_func), std::move(completion_func));
        }

        static void stop(offline_output_node &node) {
            node._stop();
        }
    };
}
}

#endif
