//
//  yas_audio_route_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_node.h"

namespace yas
{
    class audio_route_node : public audio_node
    {
        using super_class = audio_node;
        class kernel;
        class impl;

       public:
        audio_route_node();
        audio_route_node(std::nullptr_t);

        const audio_route_set &routes() const;
        void add_route(const audio_route &);
        void add_route(audio_route &&);
        void remove_route(const audio_route &);
        void remove_route_for_source(const audio_route::point &);
        void remove_route_for_destination(const audio_route::point &);
        void set_routes(const std::set<audio_route> &routes);
        void set_routes(std::set<audio_route> &&routes);
        void clear_routes();
    };
}