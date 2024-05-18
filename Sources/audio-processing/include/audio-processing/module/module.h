//
//  module.h
//

#pragma once

#include <audio-processing/connector/connector.h>
#include <audio-processing/processor/processor.h>
#include <audio-processing/stream/stream.h>
#include <audio-processing/time/time.h>

#include <observing/umbrella.hpp>
#include <vector>

namespace yas::proc {
struct module final {
    using processors_t = std::vector<processor_f>;
    using make_processors_t = std::function<std::vector<processor_f>()>;

    void process(time::range const &, stream &);

    [[nodiscard]] connector_map_t const &input_connectors() const;
    [[nodiscard]] connector_map_t const &output_connectors() const;
    void connect_input(connector_index_t const, channel_index_t const);
    void connect_output(connector_index_t const, channel_index_t const);
    void disconnect_input(connector_index_t const);
    void disconnect_output(connector_index_t const);

    [[nodiscard]] processors_t const &processors() const;

    [[nodiscard]] module_ptr copy() const;

    [[nodiscard]] static module_ptr make_shared(make_processors_t);
    [[nodiscard]] static module_ptr make_shared(make_processors_t, connector_map_t input_connectors,
                                                connector_map_t output_connectors);

   private:
    make_processors_t const _make_handler;
    processors_t const _processors;
    connector_map_t _input_connectors;
    connector_map_t _output_connectors;

    module(make_processors_t &&, connector_map_t &&input_connectors, connector_map_t &&output_connectors);
};

using module_vector_t = std::vector<module_ptr>;

module_vector_t copy(module_vector_t const &);
}  // namespace yas::proc
