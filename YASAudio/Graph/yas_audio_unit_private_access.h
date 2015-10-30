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
        static void initialize(audio_unit &unit)
        {
            unit._impl_ptr()->initialize();
        }

        static void uninitialize(audio_unit &unit)
        {
            unit._impl_ptr()->uninitialize();
        }

        static void set_graph_key(audio_unit &unit, const std::experimental::optional<UInt8> &key)
        {
            unit._impl_ptr()->graph_key = key;
        }

        static const std::experimental::optional<UInt8> &graph_key(const audio_unit &unit)
        {
            return unit._impl_ptr()->graph_key;
        }

        static void set_key(audio_unit &unit, const std::experimental::optional<UInt16> &key)
        {
            unit._impl_ptr()->key = key;
        }

        static const std::experimental::optional<UInt16> &key(const audio_unit &unit)
        {
            return unit._impl_ptr()->key;
        }

        template <typename T>
        static void set_property_data(const audio_unit &unit, const std::vector<T> &data,
                                      const AudioUnitPropertyID property_id, const AudioUnitScope scope,
                                      const AudioUnitElement element)
        {
            unit._impl_ptr()->set_property_data(data, property_id, scope, element);
        }

        template <typename T>
        static std::vector<T> property_data(const audio_unit &unit, const AudioUnitPropertyID property_id,
                                            const AudioUnitScope scope, const AudioUnitElement element)
        {
            return unit._impl_ptr()->property_data<T>(property_id, scope, element);
        }
    };
}
