//
//  yas_audio_graph_route.h
//

#pragma once

#include <audio/yas_audio_ptr.h>
#include <audio/yas_audio_route.h>
#include <chaining/yas_chaining_umbrella.h>

namespace yas::audio {
struct graph_route final {
    virtual ~graph_route();

    [[nodiscard]] audio::route_set_t const &routes() const;
    void add_route(audio::route);
    void remove_route(audio::route const &);
    void remove_route_for_source(audio::route::point const &);
    void remove_route_for_destination(audio::route::point const &);
    void set_routes(audio::route_set_t routes);
    void clear_routes();

    graph_node_ptr const node;

    [[nodiscard]] static graph_route_ptr make_shared();

   private:
    route_set_t _routes;

    graph_route();

    void _will_reset();
    void _erase_route_if_either_matched(audio::route const &route);
    void _erase_route_if(std::function<bool(audio::route const &)> pred);
    void _update_rendering();
};
}  // namespace yas::audio
