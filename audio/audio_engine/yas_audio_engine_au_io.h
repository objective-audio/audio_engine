//
//  yas_audio_au_io.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_types.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
namespace yas::audio {
class device;
}
#endif

namespace yas::audio::engine {
class au;

struct au_io : std::enable_shared_from_this<au_io> {
    enum class method {
        did_update_connection,
    };

    using chaining_pair_t = std::pair<method, std::shared_ptr<au_io>>;

    struct args {
        bool enable_input = true;
        bool enable_output = true;
    };

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
    [[nodiscard]] chaining::chain_relayed_unsync_t<std::shared_ptr<au_io>, chaining_pair_t> chain(method const) const;

    audio::engine::au const &au() const;
    audio::engine::au &au();

   private:
    std::shared_ptr<audio::engine::au> _au;
    channel_map_t _channel_map[2];
    chaining::any_observer_ptr _connections_observer = nullptr;
    chaining::notifier_ptr<chaining_pair_t> _notifier = chaining::notifier<chaining_pair_t>::make_shared();

    explicit au_io(args);

    void _prepare();

    void _update_unit_io_connections();

   public:
    static std::shared_ptr<au_io> make_shared();
    static std::shared_ptr<au_io> make_shared(au_io::args);
};

struct au_output : std::enable_shared_from_this<au_output> {
    virtual ~au_output() = default;

    void set_channel_map(channel_map_t const &);
    channel_map_t const &channel_map() const;

    audio::engine::au_io const &au_io() const;
    audio::engine::au_io &au_io();

   private:
    std::shared_ptr<audio::engine::au_io> _au_io;

    au_output();

   public:
    static std::shared_ptr<au_output> make_shared();
};

struct au_input : std::enable_shared_from_this<au_input> {
    virtual ~au_input() = default;

    void set_channel_map(channel_map_t const &);
    channel_map_t const &channel_map() const;

    audio::engine::au_io const &au_io() const;
    audio::engine::au_io &au_io();

   private:
    std::shared_ptr<audio::engine::au_io> _au_io;

    std::shared_ptr<audio::pcm_buffer> _input_buffer = nullptr;
    chaining::any_observer_ptr _connections_observer = nullptr;

    au_input();

    void _prepare();

    void _update_unit_input_connections();

   public:
    static std::shared_ptr<au_input> make_shared();
};
}  // namespace yas::audio::engine
