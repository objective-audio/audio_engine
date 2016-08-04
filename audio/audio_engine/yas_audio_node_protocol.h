//
//  yas_audio_node_protocol.h
//

#pragma once

#include "yas_audio_connection_protocol.h"

namespace yas {
namespace audio {
    class engine;
    class graph;

    struct connectable_node : protocol {
        struct impl : protocol::impl {
            virtual void add_connection(audio::connection const &) = 0;
            virtual void remove_connection(audio::connection const &) = 0;
        };

        explicit connectable_node(std::shared_ptr<impl>);
        connectable_node(std::nullptr_t);

        void add_connection(audio::connection const &);
        void remove_connection(audio::connection const &);
    };

    struct manageable_node : protocol {
        struct impl : protocol::impl {
            virtual audio::connection input_connection(uint32_t const bus_idx) const = 0;
            virtual audio::connection output_connection(uint32_t const bus_idx) const = 0;
            virtual audio::connection_wmap const &input_connections() const = 0;
            virtual audio::connection_wmap const &output_connections() const = 0;
            virtual void set_engine(audio::engine const &engine) = 0;
            virtual audio::engine engine() const = 0;
            virtual void update_kernel() = 0;
            virtual void update_connections() = 0;
            virtual void set_add_to_graph_handler(std::function<void(audio::graph &)> &&) = 0;
            virtual void set_remove_from_graph_handler(std::function<void(audio::graph &)> &&) = 0;
            virtual std::function<void(audio::graph &)> const &add_to_graph_handler() const = 0;
            virtual std::function<void(audio::graph &)> const &remove_from_graph_handler() const = 0;
        };

        explicit manageable_node(std::shared_ptr<impl>);
        manageable_node(std::nullptr_t);

        audio::connection input_connection(uint32_t const bus_idx) const;
        audio::connection output_connection(uint32_t const bus_idx) const;
        audio::connection_wmap const &input_connections() const;
        audio::connection_wmap const &output_connections() const;

        void set_engine(audio::engine const &);
        audio::engine engine() const;

        void update_kernel();
        void update_connections();

        void set_add_to_graph_handler(std::function<void(audio::graph &)>);
        void set_remove_from_graph_handler(std::function<void(audio::graph &)>);
        std::function<void(audio::graph &)> const &add_to_graph_handler() const;
        std::function<void(audio::graph &)> const &remove_from_graph_handler() const;
    };
}
}
