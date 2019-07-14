//
//  yas_audio_engine_kernel.h
//

#pragma once

#include <cpp_utils/yas_base.h>
#include "yas_audio_engine_kernel_protocol.h"

namespace yas::audio::engine {
struct kernel final : base, manageable_kernel {
    kernel();
    kernel(std::nullptr_t);

    virtual ~kernel();

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
    struct impl;
};
}  // namespace yas::audio::engine
