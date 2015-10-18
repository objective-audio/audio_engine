//
//  yas_audio_unit_mixer_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_unit_node.h"

namespace yas
{
    class audio_unit_mixer_node : public audio_unit_node
    {
       public:
        static audio_unit_mixer_node_sptr create();

        void set_output_volume(const Float32 volume, const UInt32 bus_idx);
        Float32 output_volume(const UInt32 bus_idx);
        void set_output_pan(const Float32 pan, const UInt32 bus_idx);
        Float32 output_pan(const UInt32 bus_idx);

        void set_input_volume(const Float32 volume, const UInt32 bus_idx);
        Float32 input_volume(const UInt32 bus_idx);
        void set_input_pan(const Float32 pan, const UInt32 bus_idx);
        Float32 input_pan(const UInt32 bus_idx);

        void set_input_enabled(const bool enabled, UInt32 bus_idx);
        bool input_enabled(UInt32 bus_idx);

       protected:
        audio_unit_mixer_node();

       private:
        using super_class = audio_unit_node;
        class impl;
    };
}
