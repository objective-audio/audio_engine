//
//  yas_audio_au_io.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>
#include <cpp_utils/yas_base.h>
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_types.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
namespace yas::audio {
class device;
}
#endif

namespace yas::audio::engine {
class au;

struct au_io final : base {
   public:
    class impl;

    enum class method {
        did_update_connection,
    };

    using chaining_pair_t = std::pair<method, au_io>;

    struct args {
        bool enable_input = true;
        bool enable_output = true;
    };

    au_io();
    au_io(args);
    au_io(std::nullptr_t);

    virtual ~au_io();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    void set_device(audio::device const &);
    std::shared_ptr<audio::device> device() const;
#endif

    void set_channel_map(channel_map_t const &, audio::direction const);
    channel_map_t const &channel_map(audio::direction const) const;

    double device_sample_rate() const;
    uint32_t output_device_channel_count() const;
    uint32_t input_device_channel_count() const;

    [[nodiscard]] chaining::chain_unsync_t<chaining_pair_t> chain() const;
    [[nodiscard]] chaining::chain_relayed_unsync_t<au_io, chaining_pair_t> chain(method const) const;

    audio::engine::au const &au() const;
    audio::engine::au &au();
};

struct au_output : std::enable_shared_from_this<au_output> {
    virtual ~au_output() = default;

    void set_channel_map(channel_map_t const &);
    channel_map_t const &channel_map() const;

    audio::engine::au_io const &au_io() const;
    audio::engine::au_io &au_io();

   protected:
    au_output();

   private:
    audio::engine::au_io _au_io;
};

std::shared_ptr<au_output> make_au_output();

struct au_input : std::enable_shared_from_this<au_input> {
    virtual ~au_input() = default;

    void set_channel_map(channel_map_t const &);
    channel_map_t const &channel_map() const;

    audio::engine::au_io const &au_io() const;
    audio::engine::au_io &au_io();

   protected:
    au_input();

    void prepare();

   private:
    audio::engine::au_io _au_io;

    std::shared_ptr<audio::pcm_buffer> _input_buffer = nullptr;
    chaining::any_observer_ptr _connections_observer = nullptr;

    void update_unit_input_connections();
};

std::shared_ptr<au_input> make_au_input();
}  // namespace yas::audio::engine
