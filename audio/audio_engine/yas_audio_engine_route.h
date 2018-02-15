//
//  yas_audio_engine_route.h
//

#pragma once

#include "yas_audio_route.h"
#include "yas_base.h"

namespace yas::audio::engine {
class node;

class route : public base {
    class kernel;
    class impl;

   public:
    route();
    route(std::nullptr_t);

    virtual ~route() final;

    audio::route_set_t const &routes() const;
    void add_route(audio::route);
    void remove_route(audio::route const &);
    void remove_route_for_source(audio::route::point const &);
    void remove_route_for_destination(audio::route::point const &);
    void set_routes(audio::route_set_t routes);
    void clear_routes();

    audio::engine::node const &node() const;
    audio::engine::node &node();
};
}
