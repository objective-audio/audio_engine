//
//  yas_audio_engine_kernel.h
//

#pragma once

#include <any>
#include "yas_audio_engine_kernel_protocol.h"
#include "yas_audio_engine_ptr.h"

namespace yas::audio::engine {
struct kernel : manageable_kernel {
    virtual ~kernel();

    audio::engine::connection_smap input_connections() const;
    audio::engine::connection_smap output_connections() const;
    audio::engine::connection_ptr input_connection(uint32_t const bus_idx) const;
    audio::engine::connection_ptr output_connection(uint32_t const bus_idx) const;

    std::any decorator = nullptr;

   private:
    std::weak_ptr<kernel> _weak_kernel;

    kernel();

    void set_input_connections(audio::engine::connection_wmap connections) override;
    void set_output_connections(audio::engine::connection_wmap connections) override;

    engine::connection_wmap _input_connections;
    engine::connection_wmap _output_connections;

   public:
    static kernel_ptr make_shared();
};
}  // namespace yas::audio::engine
