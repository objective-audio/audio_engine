//
//  yas_audio_node_kernel.h
//

#pragma once

#include "yas_audio_node_kernel_protocol.h"
#include "yas_base.h"

namespace yas {
namespace audio {
    struct node::kernel : base {
        struct impl : base::impl, manageable_kernel::impl {
            audio::connection input_connection(uint32_t const bus_idx);
            audio::connection output_connection(uint32_t const bus_idx);

            audio::connection_smap input_connections();
            audio::connection_smap output_connections();

            void set_input_connections(audio::connection_wmap &&connections) override;
            void set_output_connections(audio::connection_wmap &&connections) override;

           private:
            connection_wmap _input_connections;
            connection_wmap _output_connections;
        };

        kernel();
        kernel(std::nullptr_t);

        audio::connection_smap input_connections() const;
        audio::connection_smap output_connections() const;
        audio::connection input_connection(uint32_t const bus_idx) const;
        audio::connection output_connection(uint32_t const bus_idx) const;

        manageable_kernel &manageable();

       protected:
        kernel(std::shared_ptr<impl> &&);

       private:
        manageable_kernel _manageable = nullptr;
    };
}
}
