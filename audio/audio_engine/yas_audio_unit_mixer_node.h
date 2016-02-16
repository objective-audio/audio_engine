//
//  yas_audio_unit_mixer_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_unit_node.h"

namespace yas {
namespace audio {
    class unit_mixer_node : public unit_node {
        using super_class = unit_node;

       public:
        unit_mixer_node();
        unit_mixer_node(std::nullptr_t);

        void set_output_volume(Float32 const volume, UInt32 const bus_idx);
        Float32 output_volume(UInt32 const bus_idx) const;
        void set_output_pan(Float32 const pan, UInt32 const bus_idx);
        Float32 output_pan(UInt32 const bus_idx) const;

        void set_input_volume(Float32 const volume, UInt32 const bus_idx);
        Float32 input_volume(UInt32 const bus_idx) const;
        void set_input_pan(Float32 const pan, UInt32 const bus_idx);
        Float32 input_pan(UInt32 const bus_idx) const;

        void set_input_enabled(bool const enabled, UInt32 const bus_idx);
        bool input_enabled(UInt32 const bus_idx) const;

       private:
        class impl;
    };
}
}
