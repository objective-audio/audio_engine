
//
//  yas_audio_unit_protocol.h
//

#pragma once

#include <optional>

namespace yas::audio {
struct manageable_unit {
    virtual void initialize() = 0;
    virtual void uninitialize() = 0;
    virtual void set_graph_key(std::optional<uint8_t> const &) = 0;
    virtual std::optional<uint8_t> const &graph_key() const = 0;
    virtual void set_key(std::optional<uint16_t> const &) = 0;
    virtual std::optional<uint16_t> const &key() const = 0;
};
}  // namespace yas::audio
