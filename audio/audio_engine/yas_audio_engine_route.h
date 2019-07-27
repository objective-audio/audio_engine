//
//  yas_audio_engine_route.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>
#include "yas_audio_route.h"

namespace yas::audio::engine {
class node;

struct route : std::enable_shared_from_this<route> {
    virtual ~route();

    audio::route_set_t const &routes() const;
    void add_route(audio::route);
    void remove_route(audio::route const &);
    void remove_route_for_source(audio::route::point const &);
    void remove_route_for_destination(audio::route::point const &);
    void set_routes(audio::route_set_t routes);
    void clear_routes();

    audio::engine::node const &node() const;
    audio::engine::node &node();

   private:
    class kernel;

    std::shared_ptr<audio::engine::node> _node;
    route_set_t _routes;
    chaining::any_observer_ptr _reset_observer = nullptr;

    route();

    void _prepare();

    void _will_reset();
    void _erase_route_if_either_matched(audio::route const &route);
    void _erase_route_if(std::function<bool(audio::route const &)> pred);

   public:
    static std::shared_ptr<route> make_shared();
};
}  // namespace yas::audio::engine
