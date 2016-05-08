//
//  yas_audio_route_node.h
//

#pragma once

#include "yas_audio_node.h"

namespace yas {
namespace audio {
    class route_node : public node {
        class kernel;
        class impl;

       public:
        route_node();
        route_node(std::nullptr_t);

        audio::route_set_t const &routes() const;
        void add_route(audio::route);
        void remove_route(audio::route const &);
        void remove_route_for_source(audio::route::point const &);
        void remove_route_for_destination(audio::route::point const &);
        void set_routes(audio::route_set_t routes);
        void clear_routes();
    };
}
}
