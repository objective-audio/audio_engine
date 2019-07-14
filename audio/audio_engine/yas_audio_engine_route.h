//
//  yas_audio_engine_route.h
//

#pragma once

#include <cpp_utils/yas_base.h>
#include "yas_audio_route.h"

namespace yas::audio::engine {
class node;

class route final : public base {
    class kernel;
    class impl;

   public:
    route();
    route(std::nullptr_t);

    virtual ~route();

    audio::route_set_t const &routes() const;
    void add_route(audio::route);
    void remove_route(audio::route const &);
    void remove_route_for_source(audio::route::point const &);
    void remove_route_for_destination(audio::route::point const &);
    void set_routes(audio::route_set_t routes);
    void clear_routes();

    std::shared_ptr<audio::engine::node> const &node() const;
    std::shared_ptr<audio::engine::node> &node();
};
}  // namespace yas::audio::engine
