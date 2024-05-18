//
//  module.cpp
//

#include "module.h"

#include <audio-processing/connector/connector.h>
#include <cpp-utils/stl_utils.h>

using namespace yas;
using namespace yas::proc;

#pragma mark - utility

namespace yas::proc {
static void connect(connector_map_t &connectors, connector_index_t const idx, channel_index_t const ch_idx) {
    if (connectors.count(idx) == 0) {
        connectors.erase(idx);
    }
    connectors.emplace(idx, connector{.channel_index = ch_idx});
}

static void disconnect(connector_map_t &connectors, connector_index_t const idx) {
    if (connectors.count(idx) > 0) {
        connectors.erase(idx);
    }
}
}  // namespace yas::proc

#pragma mark - module

proc::module::module(make_processors_t &&handler, connector_map_t &&input_connectors,
                     connector_map_t &&output_connectors)
    : _make_handler(std::move(handler)),
      _processors(_make_handler()),
      _input_connectors(std::move(input_connectors)),
      _output_connectors(std::move(output_connectors)) {
}

void proc::module::process(time::range const &time_range, stream &stream) {
    for (auto &processor : this->_processors) {
        if (processor) {
            processor(time_range, this->_input_connectors, this->_output_connectors, stream);
        }
    }
}

proc::connector_map_t const &proc::module::input_connectors() const {
    return this->_input_connectors;
}

proc::connector_map_t const &proc::module::output_connectors() const {
    return this->_output_connectors;
}

void proc::module::connect_input(connector_index_t const co_idx, channel_index_t const ch_idx) {
    connect(this->_input_connectors, co_idx, ch_idx);
}

void proc::module::connect_output(connector_index_t const co_idx, channel_index_t const ch_idx) {
    connect(this->_output_connectors, co_idx, ch_idx);
}

void proc::module::disconnect_input(connector_index_t const idx) {
    disconnect(this->_input_connectors, idx);
}

void proc::module::disconnect_output(connector_index_t const idx) {
    disconnect(this->_output_connectors, idx);
}

proc::module::processors_t const &proc::module::processors() const {
    return this->_processors;
}

proc::module_ptr proc::module::copy() const {
    if (!this->_make_handler) {
        throw std::runtime_error("make_handler is null.");
    }
    return module::make_shared(this->_make_handler, this->_input_connectors, this->_output_connectors);
}

proc::module_ptr proc::module::make_shared(make_processors_t handler) {
    return make_shared(std::move(handler), {}, {});
}

proc::module_ptr proc::module::make_shared(make_processors_t handler, connector_map_t inputs, connector_map_t outputs) {
    return module_ptr(new module{std::move(handler), std::move(inputs), std::move(outputs)});
}

std::vector<proc::module_ptr> proc::copy(std::vector<proc::module_ptr> const &modules) {
    return to_vector<proc::module_ptr>(modules, [](proc::module_ptr const &module) { return module->copy(); });
}
