//
//  yas_audio_graph_route.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>
#include "yas_audio_ptr.h"
#include "yas_audio_route.h"

namespace yas::audio {
struct graph_route final {
    virtual ~graph_route();

    audio::route_set_t const &routes() const;
    void add_route(audio::route);
    void remove_route(audio::route const &);
    void remove_route_for_source(audio::route::point const &);
    void remove_route_for_destination(audio::route::point const &);
    void set_routes(audio::route_set_t routes);
    void clear_routes();

    audio::graph_node_ptr const &node() const;

    static graph_route_ptr make_shared();

   private:
    class kernel;

    graph_node_ptr _node;
    route_set_t _routes;
    std::optional<chaining::any_observer_ptr> _reset_observer = std::nullopt;

    graph_route();

    void _prepare(graph_route_ptr const &);

    void _will_reset();
    void _erase_route_if_either_matched(audio::route const &route);
    void _erase_route_if(std::function<bool(audio::route const &)> pred);

    using kernel_ptr = std::shared_ptr<kernel>;
};
}  // namespace yas::audio
