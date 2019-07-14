//
//  yas_audio_engine_kernel.h
//

#pragma once

#include <cpp_utils/yas_base.h>
#include "yas_audio_engine_kernel_protocol.h"

namespace yas::audio::engine {
struct kernel final : manageable_kernel {
    kernel();

    audio::engine::connection_smap input_connections() const;
    audio::engine::connection_smap output_connections() const;
    audio::engine::connection input_connection(uint32_t const bus_idx) const;
    audio::engine::connection output_connection(uint32_t const bus_idx) const;

    void set_decorator(base);
    base const &decorator() const;
    base &decorator();

    void set_input_connections(audio::engine::connection_wmap connections) override;
    void set_output_connections(audio::engine::connection_wmap connections) override;

   private:
    engine::connection_wmap _input_connections;
    engine::connection_wmap _output_connections;
    base _decorator = nullptr;
};
}  // namespace yas::audio::engine
