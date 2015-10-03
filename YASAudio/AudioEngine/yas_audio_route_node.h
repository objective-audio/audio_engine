//
//  yas_audio_route_node.hpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_node.h"
#include <set>

namespace yas
{
    class audio_route_node : public audio_node
    {
       public:
        static audio_route_node_sptr create();

        virtual UInt32 input_bus_count() const override;
        virtual UInt32 output_bus_count() const override;

        const std::set<audio_route> &routes() const;
        void add_route(const audio_route &);
        void add_route(audio_route &&);
        void remove_route(const audio_route &);
        void remove_route_for_source(const audio_route::point &);
        void remove_route_for_destination(const audio_route::point &);
        void set_routes(const std::set<audio_route> &routes);
        void set_routes(std::set<audio_route> &&routes);
        void clear_routes();

        virtual void render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when) override;

       protected:
        virtual audio_node_core_sptr make_node_core() override;
        virtual void prepare_node_core(const audio_node_core_sptr &node_core) override;

       private:
        using super_class = audio_node;

        class impl;
        std::unique_ptr<impl> _impl;

        audio_route_node();

        void render_source(const audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when);
    };
}