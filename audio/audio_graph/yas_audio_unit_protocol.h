
//
//  yas_audio_unit_protocol.h
//

#pragma once

#include <cpp_utils/yas_protocol.h>
#include <optional>

namespace yas::audio {
struct manageable_unit : protocol {
    struct impl : protocol::impl {
        virtual void initialize() = 0;
        virtual void uninitialize() = 0;
        virtual void set_graph_key(std::optional<uint8_t> const &) = 0;
        virtual std::optional<uint8_t> const &graph_key() const = 0;
        virtual void set_key(std::optional<uint16_t> const &) = 0;
        virtual std::optional<uint16_t> const &key() const = 0;
    };

    explicit manageable_unit(std::shared_ptr<impl> impl);
    manageable_unit(std::nullptr_t);

    void initialize();
    void uninitialize();
    void set_graph_key(std::optional<uint8_t> const &key);
    std::optional<uint8_t> const &graph_key() const;
    void set_key(std::optional<uint16_t> const &key);
    std::optional<uint16_t> const &key() const;
};
}  // namespace yas::audio
