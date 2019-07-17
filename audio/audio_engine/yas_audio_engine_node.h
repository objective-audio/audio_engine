//
//  yas_audio_engine_node.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>
#include <cpp_utils/yas_base.h>
#include <cpp_utils/yas_protocol.h>
#include <optional>
#include <ostream>
#include "yas_audio_engine_connection.h"
#include "yas_audio_engine_node_protocol.h"
#include "yas_audio_format.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_types.h"

namespace yas {
template <typename T, typename U>
class result;
}

namespace yas::audio {
class time;
}

namespace yas::audio::engine {
class manager;
class kernel;

struct node : base, std::enable_shared_from_this<node>, connectable_node {
    class impl;

    enum class method {
        will_reset,
        update_connections,
    };

    using chaining_pair_t = std::pair<method, node>;

    struct render_args {
        audio::pcm_buffer &buffer;
        uint32_t const bus_idx;
        audio::time const &when;
    };

    using prepare_kernel_f = std::function<void(kernel &)>;
    using render_f = std::function<void(render_args)>;

    node(std::nullptr_t);

    //        node(node &&) = default;
    //        node &operator=(node &&) = default;

    virtual ~node();

    void reset();

    std::shared_ptr<audio::engine::connection> input_connection(uint32_t const bus_idx) const;
    std::shared_ptr<audio::engine::connection> output_connection(uint32_t const bus_idx) const;
    audio::engine::connection_wmap const &input_connections() const;
    audio::engine::connection_wmap const &output_connections() const;

    std::optional<audio::format> input_format(uint32_t const bus_idx) const;
    std::optional<audio::format> output_format(uint32_t const bus_idx) const;
    bus_result_t next_available_input_bus() const;
    bus_result_t next_available_output_bus() const;
    bool is_available_input_bus(uint32_t const bus_idx) const;
    bool is_available_output_bus(uint32_t const bus_idx) const;
    audio::engine::manager manager() const;
    std::optional<audio::time> last_render_time() const;

    uint32_t input_bus_count() const;
    uint32_t output_bus_count() const;
    bool is_input_renderable() const;

    void set_prepare_kernel_handler(prepare_kernel_f);
    void set_render_handler(render_f);

    std::shared_ptr<audio::engine::kernel> kernel() const;

    void render(render_args);
    void set_render_time_on_render(audio::time const &time);

    [[nodiscard]] chaining::chain_unsync_t<chaining_pair_t> chain() const;
    [[nodiscard]] chaining::chain_relayed_unsync_t<node, chaining_pair_t> chain(method const) const;

    std::shared_ptr<connectable_node> connectable();
    audio::engine::manageable_node const &manageable() const;
    audio::engine::manageable_node &manageable();

   protected:
    node(node_args &&);

    virtual void add_connection(audio::engine::connection &) override;
    virtual void remove_connection(audio::engine::connection const &) override;

   private:
    mutable audio::engine::manageable_node _manageable = nullptr;

    //        node(node const &) = delete;
    //        node &operator=(node const &) = delete;
};

std::shared_ptr<node> make_node(node_args);
}  // namespace yas::audio::engine

namespace yas {
std::string to_string(audio::engine::node::method const &);
}

std::ostream &operator<<(std::ostream &, yas::audio::engine::node::method const &);

template <>
struct std::hash<yas::audio::engine::node> {
    std::size_t operator()(yas::audio::engine::node const &key) const {
        return std::hash<uintptr_t>()(key.identifier());
    }
};

#include "yas_audio_engine_kernel.h"
