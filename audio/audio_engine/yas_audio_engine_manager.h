//
//  yas_audio_engine_manager.h
//

#pragma once

#include "yas_audio_connection.h"
#include "yas_audio_offline_output_node_protocol.h"
#include "yas_audio_types.h"
#include "yas_base.h"

namespace yas {
template <typename T, typename U>
class result;
template <typename T, typename K>
class subject;
template <typename T, typename K>
class observer;

namespace audio {
    class graph;

    namespace engine {
        class device_io_node;
        class offline_output_node;
        
        class manager : public base {
            class impl;

           public:
            enum class method { configuration_change };

            enum class start_error_t {
                already_running,
                prepare_failure,
                connection_not_found,
                offline_output_not_found,
                offline_output_starting_failure,
            };

            enum class add_error_t { already_added };
            enum class remove_error_t { already_removed };

            using start_result_t = result<std::nullptr_t, start_error_t>;
            using add_result_t = result<std::nullptr_t, add_error_t>;
            using remove_result_t = result<std::nullptr_t, remove_error_t>;
            using subject_t = subject<manager, method>;
            using observer_t = observer<manager, method>;

            manager();
            manager(std::nullptr_t);

            virtual ~manager() final;

            audio::engine::connection connect(audio::engine::node &source_node, audio::engine::node &destination_node,
                                              audio::format const &format);
            audio::engine::connection connect(audio::engine::node &source_node, audio::engine::node &destination_node,
                                              uint32_t const source_bus_idx, uint32_t const destination_bus_idx,
                                              audio::format const &format);

            void disconnect(audio::engine::connection &);
            void disconnect(audio::engine::node &);
            void disconnect_input(audio::engine::node const &);
            void disconnect_input(audio::engine::node const &, uint32_t const bus_idx);
            void disconnect_output(audio::engine::node const &);
            void disconnect_output(audio::engine::node const &, uint32_t const bus_idx);

            add_result_t add_offline_output_node();
            remove_result_t remove_offline_output_node();
            audio::engine::offline_output_node const &offline_output_node() const;
            audio::engine::offline_output_node &offline_output_node();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
            add_result_t add_device_io_node();
            remove_result_t remove_device_io_node();
            audio::engine::device_io_node const &device_io_node() const;
            audio::engine::device_io_node &device_io_node();
#endif

            start_result_t start_render();
            start_result_t start_offline_render(offline_render_f, offline_completion_f);
            void stop();

            subject_t &subject() const;

#if YAS_TEST
            std::unordered_set<node> &nodes() const;
            audio::engine::connection_set &connections() const;
#endif
        };
    }
}

std::string to_string(audio::engine::manager::method const &);
std::string to_string(audio::engine::manager::start_error_t const &);
}

std::ostream &operator<<(std::ostream &, yas::audio::engine::manager::method const &);
std::ostream &operator<<(std::ostream &, yas::audio::engine::manager::start_error_t const &);
