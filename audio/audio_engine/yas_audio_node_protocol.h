//
//  yas_audio_node_protocol.h
//

#pragma once

#include "yas_audio_connection_protocol.h"
#include "yas_types.h"

namespace yas {
namespace audio {
    class engine;
    class graph;

    using edit_graph_f = std::function<void(audio::graph &)>;

    struct node_args {
        uint32_t input_bus_count = 0;
        uint32_t output_bus_count = 0;
        std::experimental::optional<uint32_t> override_output_bus_idx;
        bool input_renderable = false;
    };

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
            virtual audio::connection input_connection(uint32_t const bus_idx) = 0;
            virtual audio::connection output_connection(uint32_t const bus_idx) = 0;
            virtual audio::connection_wmap const &input_connections() = 0;
            virtual audio::connection_wmap const &output_connections() = 0;
            virtual void set_engine(audio::engine const &engine) = 0;
            virtual audio::engine engine() const = 0;
            virtual void update_kernel() = 0;
            virtual void update_connections() = 0;
            virtual void set_add_to_graph_handler(edit_graph_f &&) = 0;
            virtual void set_remove_from_graph_handler(edit_graph_f &&) = 0;
            virtual edit_graph_f const &add_to_graph_handler() const = 0;
            virtual edit_graph_f const &remove_from_graph_handler() const = 0;
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

        void set_add_to_graph_handler(edit_graph_f);
        void set_remove_from_graph_handler(edit_graph_f);
        edit_graph_f const &add_to_graph_handler() const;
        edit_graph_f const &remove_from_graph_handler() const;
    };
}
}
