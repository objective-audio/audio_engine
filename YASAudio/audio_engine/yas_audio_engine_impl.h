//
//  yas_audio_engine_impl.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_objc_container.h"
#include <unordered_set>

class yas::audio_engine::impl : public yas::base::impl
{
   public:
    impl();
    virtual ~impl();

    void prepare(const audio_engine &);

    weak<audio_engine> &weak_engine() const;
    objc::container<> &reset_observer() const;
    objc::container<> &route_change_observer() const;
    yas::subject &subject() const;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    observer &device_observer();
#endif

    bool node_exists(const audio_node &node);

    void attach_node(audio_node &node);
    void detach_node(audio_node &node);
    void detach_node_if_unused(audio_node &node);

    bool prepare();

    audio_connection connect(audio_node &source_node, audio_node &destination_node, const UInt32 source_bus_idx,
                             const UInt32 destination_bus_idx, const audio_format &format);
    void disconnect(audio_connection &connection);
    void disconnect(audio_node &node);
    void disconnect_node_with_predicate(std::function<bool(const audio_connection &)> predicate);

    void add_node_to_graph(audio_node &node);
    void remove_node_from_graph(const audio_node &node);

    bool add_connection(const audio_connection &connection);
    void remove_connection_from_nodes(const audio_connection &connection);
    void update_node_connections(audio_node &node);
    void update_all_node_connections();

    audio_connection_map input_connections_for_destination_node(const audio_node &node) const;
    audio_connection_map output_connections_for_source_node(const audio_node &node) const;

    void set_graph(const audio_graph &graph);
    audio_graph graph() const;
    void reload_graph();

    std::unordered_set<audio_node> &nodes() const;
    audio_connection_map &connections() const;
    audio_offline_output_node &offline_output_node() const;

    audio_engine::start_result_t start_render();
    audio_engine::start_result_t start_offline_render(const offline_render_f &, const offline_completion_f &);
    void stop();

    void post_configuration_change() const;

   private:
    class core;
    std::unique_ptr<core> _core;
};
