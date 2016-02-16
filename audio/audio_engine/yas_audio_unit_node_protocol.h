//
//  yas_audio_unit_node_protocol.h
//

#pragma once

namespace yas {
namespace audio {
    class unit_node_from_engine {
       public:
        virtual ~unit_node_from_engine() = default;

        virtual void _prepare_audio_unit() = 0;
        virtual void _prepare_parameters() = 0;
        virtual void _reload_audio_unit() = 0;
    };
}
}