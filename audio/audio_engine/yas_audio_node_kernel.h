//
//  yas_audio_node_kernel.h
//

#pragma once

#include "yas_audio_node_kernel_protocol.h"
#include "yas_base.h"

namespace yas {
namespace audio {
    struct node::kernel : base {
        kernel();
        kernel(std::nullptr_t);

        virtual ~kernel() final;

        audio::connection_smap input_connections() const;
        audio::connection_smap output_connections() const;
        audio::connection input_connection(uint32_t const bus_idx) const;
        audio::connection output_connection(uint32_t const bus_idx) const;

        void set_decorator(base);
        base const &decorator() const;
        base &decorator();

        manageable_kernel &manageable();

       private:
        struct impl;

        manageable_kernel _manageable = nullptr;
    };
}
}
