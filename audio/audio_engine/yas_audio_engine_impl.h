//
//  yas_audio_engine_impl.h
//

#pragma once

#include <unordered_set>
#include "yas_audio_engine_protocol.h"
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
#include "yas_audio_device.h"
#endif

namespace yas {
namespace audio {
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    class device_io_node;
#endif

    struct engine::impl : base::impl {
        impl();
        virtual ~impl();

        void prepare(engine const &);

        weak<engine> &weak_engine() const;
        subject_t &subject() const;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        audio::device::observer_t &device_observer();
#endif

        bool node_exists(audio::node const &node);

        void attach_node(audio::node &node);
        void detach_node(audio::node &node);
        void detach_node_if_unused(node &node);

        bool prepare();

        audio::connection connect(audio::node &source_node, audio::node &destination_node,
                                  uint32_t const source_bus_idx, uint32_t const destination_bus_idx,
                                  audio::format const &format);
        void disconnect(audio::connection &connection);
        void disconnect(audio::node &node);
        void disconnect_node_with_predicate(std::function<bool(audio::connection const &)> predicate);

        void add_node_to_graph(audio::node const &node);
        void remove_node_from_graph(audio::node const &node);

        bool add_connection(audio::connection const &connection);
        void remove_connection_from_nodes(audio::connection const &connection);
        void update_node_connections(audio::node &node);
        void update_all_node_connections();

        audio::connection_set input_connections_for_destination_node(audio::node const &node) const;
        audio::connection_set output_connections_for_source_node(audio::node const &node) const;

        void set_graph(audio::graph const &graph);
        audio::graph graph() const;
        void reload_graph();

        std::unordered_set<audio::node> &nodes();
        audio::connection_set &connections();

        void set_offline_output_node(audio::offline_output_node &&);
        audio::offline_output_node &offline_output_node();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void set_device_io_node(audio::device_io_node &&);
        audio::device_io_node &device_io_node();
#endif

        engine::start_result_t start_render();
        engine::start_result_t start_offline_render(offline_render_f &&, offline_completion_f &&);
        void stop();

        void post_configuration_change() const;

       private:
        class core;
        std::unique_ptr<core> _core;
    };
}
}
