//
//  yas_audio_engine_kernel.h
//

#pragma once

#include <cpp_utils/yas_base.h>
#include <any>
#include "yas_audio_engine_kernel_protocol.h"

namespace yas::audio::engine {
struct kernel : manageable_kernel {
    virtual ~kernel() = default;

    audio::engine::connection_smap input_connections() const;
    audio::engine::connection_smap output_connections() const;
    audio::engine::connection input_connection(uint32_t const bus_idx) const;
    audio::engine::connection output_connection(uint32_t const bus_idx) const;

    std::any decorator = nullptr;

   protected:
    kernel();

    virtual void set_input_connections(audio::engine::connection_wmap connections) override;
    virtual void set_output_connections(audio::engine::connection_wmap connections) override;

    engine::connection_wmap _input_connections;
    engine::connection_wmap _output_connections;
};

std::shared_ptr<audio::engine::kernel> make_kernel();
}  // namespace yas::audio::engine
