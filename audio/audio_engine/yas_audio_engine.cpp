//
//  yas_audio_engine.cpp
//

#include "yas_audio_device_io_node.h"
#include "yas_audio_engine.h"
#include "yas_audio_engine_impl.h"
#include "yas_audio_node.h"
#include "yas_audio_offline_output_node.h"
#include "yas_observing.h"
#include "yas_result.h"

using namespace yas;

audio::engine::engine() : base(std::make_shared<impl>()) {
    impl_ptr<impl>()->prepare(*this);
}

audio::engine::engine(std::nullptr_t) : base(nullptr) {
}

audio::engine::~engine() = default;

audio::connection audio::engine::connect(node &source_node, node &destination_node, audio::format const &format) {
    if (!source_node || !destination_node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    auto source_bus_result = source_node.next_available_output_bus();
    auto destination_bus_result = destination_node.next_available_input_bus();

    if (!source_bus_result || !destination_bus_result) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : bus is not available.");
    }

    return connect(source_node, destination_node, *source_bus_result, *destination_bus_result, format);
}

audio::connection audio::engine::connect(node &source_node, node &destination_node, uint32_t const src_bus_idx,
                                         uint32_t const dst_bus_idx, audio::format const &format) {
    return impl_ptr<impl>()->connect(source_node, destination_node, src_bus_idx, dst_bus_idx, format);
}

void audio::engine::disconnect(connection &connection) {
    impl_ptr<impl>()->disconnect(connection);
}

void audio::engine::disconnect(node &node) {
    impl_ptr<impl>()->disconnect(node);
}

void audio::engine::disconnect_input(node const &node) {
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    impl_ptr<impl>()->disconnect_node_with_predicate(
        [node](connection const &connection) { return (connection.destination_node() == node); });
}

void audio::engine::disconnect_input(node const &node, uint32_t const bus_idx) {
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    impl_ptr<impl>()->disconnect_node_with_predicate([node, bus_idx](auto const &connection) {
        return (connection.destination_node() == node && connection.destination_bus() == bus_idx);
    });
}

void audio::engine::disconnect_output(node const &node) {
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    impl_ptr<impl>()->disconnect_node_with_predicate(
        [node](connection const &connection) { return (connection.source_node() == node); });
}

void audio::engine::disconnect_output(node const &node, uint32_t const bus_idx) {
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    impl_ptr<impl>()->disconnect_node_with_predicate([node, bus_idx](auto const &connection) {
        return (connection.source_node() == node && connection.source_bus() == bus_idx);
    });
}

audio::engine::add_result_t audio::engine::add_offline_output_node() {
    if (impl_ptr<impl>()->offline_output_node()) {
        return add_result_t{add_error_t::already_added};
    } else {
        impl_ptr<impl>()->set_offline_output_node(audio::offline_output_node{});
        return add_result_t{nullptr};
    }
}

audio::engine::remove_result_t audio::engine::remove_offline_output_node() {
    if (impl_ptr<impl>()->offline_output_node()) {
        impl_ptr<impl>()->set_offline_output_node(nullptr);
        return remove_result_t{nullptr};
    } else {
        return remove_result_t{remove_error_t::already_removed};
    }
}

audio::offline_output_node const &audio::engine::offline_output_node() const {
    return impl_ptr<impl>()->offline_output_node();
}

audio::offline_output_node &audio::engine::offline_output_node() {
    return impl_ptr<impl>()->offline_output_node();
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

audio::engine::add_result_t audio::engine::add_device_io_node() {
    if (impl_ptr<impl>()->device_io_node()) {
        return add_result_t{add_error_t::already_added};
    } else {
        impl_ptr<impl>()->set_device_io_node(audio::device_io_node{});
        return add_result_t{nullptr};
    }
}

audio::engine::remove_result_t audio::engine::remove_device_io_node() {
    if (impl_ptr<impl>()->device_io_node()) {
        impl_ptr<impl>()->set_device_io_node(nullptr);
        return remove_result_t{nullptr};
    } else {
        return remove_result_t{remove_error_t::already_removed};
    }
}

audio::device_io_node const &audio::engine::device_io_node() const {
    return impl_ptr<impl>()->device_io_node();
}

audio::device_io_node &audio::engine::device_io_node() {
    return impl_ptr<impl>()->device_io_node();
}

#endif

audio::engine::start_result_t audio::engine::start_render() {
    return impl_ptr<impl>()->start_render();
}

audio::engine::start_result_t audio::engine::start_offline_render(offline_render_f render_handler,
                                                                  offline_completion_f completion_handler) {
    return impl_ptr<impl>()->start_offline_render(std::move(render_handler), std::move(completion_handler));
}

void audio::engine::stop() {
    impl_ptr<impl>()->stop();
}

audio::engine::subject_t &audio::engine::subject() const {
    return impl_ptr<impl>()->subject();
}

#if YAS_TEST
audio::testable_engine audio::engine::testable() {
    return audio::testable_engine{impl_ptr<audio::testable_engine::impl>()};
}
#endif

std::string yas::to_string(audio::engine::method const &method) {
    switch (method) {
        case audio::engine::method::configuration_change:
            return "configuration_change";
    }
}

std::string yas::to_string(audio::engine::start_error_t const &error) {
    switch (error) {
        case audio::engine::start_error_t::already_running:
            return "already_running";
        case audio::engine::start_error_t::prepare_failure:
            return "prepare_failure";
        case audio::engine::start_error_t::connection_not_found:
            return "connection_not_found";
        case audio::engine::start_error_t::offline_output_not_found:
            return "offline_output_not_found";
        case audio::engine::start_error_t::offline_output_starting_failure:
            return "offline_output_starting_failure";
    }
}

std::ostream &operator<<(std::ostream &os, yas::audio::engine::method const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::audio::engine::start_error_t const &value) {
    os << to_string(value);
    return os;
}
