//
//  yas_audio_unit_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
    class audio_unit::private_access
    {
       public:
        static void initialize(const audio_unit_sptr &unit)
        {
            unit->_initialize();
        }

        static void uninitialize(const audio_unit_sptr &unit)
        {
            unit->_uninitialize();
        }

        static void set_graph_key(const audio_unit_sptr &unit, const std::experimental::optional<UInt8> &key)
        {
            unit->_set_graph_key(key);
        }

        static const std::experimental::optional<UInt8> &graph_key(const audio_unit_sptr &unit)
        {
            return unit->_graph_key();
        }

        static void set_key(const audio_unit_sptr &unit, const std::experimental::optional<UInt16> &key)
        {
            unit->_set_key(key);
        }

        static const std::experimental::optional<UInt16> &key(const audio_unit_sptr &unit)
        {
            return unit->_key();
        }
    };
}
