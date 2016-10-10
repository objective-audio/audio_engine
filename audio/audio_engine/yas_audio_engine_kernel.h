//
//  yas_audio_engine_kernel.h
//

#pragma once

#include "yas_audio_engine_kernel_protocol.h"
#include "yas_base.h"

namespace yas {
namespace audio {
    namespace engine {
        struct kernel : base {
            kernel();
            kernel(std::nullptr_t);

            virtual ~kernel() final;

            audio::engine::connection_smap input_connections() const;
            audio::engine::connection_smap output_connections() const;
            audio::engine::connection input_connection(uint32_t const bus_idx) const;
            audio::engine::connection output_connection(uint32_t const bus_idx) const;

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
}
