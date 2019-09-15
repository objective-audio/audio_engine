
//
//  yas_audio_unit_protocol.h
//

#pragma once

#include <optional>

namespace yas::audio {
class manageable_unit;
using manageable_unit_ptr = std::shared_ptr<manageable_unit>;

struct manageable_unit {
    virtual ~manageable_unit() = default;

    virtual void initialize() = 0;
    virtual void uninitialize() = 0;
    virtual void set_graph_key(std::optional<uint8_t> const &) = 0;
    virtual std::optional<uint8_t> const &graph_key() const = 0;
    virtual void set_key(std::optional<uint16_t> const &) = 0;
    virtual std::optional<uint16_t> const &key() const = 0;

    static manageable_unit_ptr cast(manageable_unit_ptr const &unit) {
        return unit;
    }
};
}  // namespace yas::audio
