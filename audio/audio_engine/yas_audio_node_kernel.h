//
//  yas_audio_node_kernel.h
//

#pragma once

#include "yas_base.h"
#include "yas_protocol.h"

namespace yas {
namespace audio {
    struct yas::audio::node::kernel : base {
        kernel();

        audio::connection_smap input_connections() const;
        audio::connection_smap output_connections() const;
        audio::connection input_connection(uint32_t const bus_idx);
        audio::connection output_connection(uint32_t const bus_idx);

        manageable_kernel manageable();

       private:
        class impl;

#if YAS_TEST
       public:
        class private_access;
        friend private_access;
#endif
    };
}
}
