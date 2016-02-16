//
//  yas_audio_unit_private_access.h
//

#pragma once

#if YAS_TEST

class yas::audio::unit::private_access {
   public:
    static void initialize(unit &unit) {
        unit.impl_ptr<impl>()->initialize();
    }

    static void uninitialize(unit &unit) {
        unit.impl_ptr<impl>()->uninitialize();
    }

    static void set_graph_key(unit &unit, std::experimental::optional<UInt8> const &key) {
        unit.impl_ptr<impl>()->graph_key = key;
    }

    static std::experimental::optional<UInt8> const &graph_key(unit const &unit) {
        return unit.impl_ptr<impl>()->graph_key;
    }

    static void set_key(unit &unit, std::experimental::optional<UInt16> const &key) {
        unit.impl_ptr<impl>()->key = key;
    }

    static std::experimental::optional<UInt16> const &key(unit const &unit) {
        return unit.impl_ptr<impl>()->key;
    }

    template <typename T>
    static void set_property_data(unit const &unit, std::vector<T> const &data, AudioUnitPropertyID const property_id,
                                  AudioUnitScope const scope, AudioUnitElement const element) {
        unit.impl_ptr<impl>()->set_property_data(data, property_id, scope, element);
    }

    template <typename T>
    static std::vector<T> property_data(unit const &unit, AudioUnitPropertyID const property_id,
                                        AudioUnitScope const scope, AudioUnitElement const element) {
        return unit.impl_ptr<impl>()->property_data<T>(property_id, scope, element);
    }
};

#endif
