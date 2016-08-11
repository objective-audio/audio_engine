//
//  yas_audio_engine.h
//

#pragma once

#include "yas_audio_connection.h"
#include "yas_audio_offline_output_extension_protocol.h"
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
    class offline_output_extension;
    class device_io_extension;
    class testable_engine;

    class engine : public base {
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
        using subject_t = subject<engine, method>;
        using observer_t = observer<engine, method>;

        engine();
        engine(std::nullptr_t);

        virtual ~engine() final;

        audio::connection connect(audio::node &source_node, audio::node &destination_node, audio::format const &format);
        audio::connection connect(audio::node &source_node, audio::node &destination_node,
                                  uint32_t const source_bus_idx, uint32_t const destination_bus_idx,
                                  audio::format const &format);

        void disconnect(audio::connection &);
        void disconnect(audio::node &);
        void disconnect_input(audio::node const &);
        void disconnect_input(audio::node const &, uint32_t const bus_idx);
        void disconnect_output(audio::node const &);
        void disconnect_output(audio::node const &, uint32_t const bus_idx);

        add_result_t add_offline_output_extension();
        remove_result_t remove_offline_output_extension();
        audio::offline_output_extension const &offline_output_extension() const;
        audio::offline_output_extension &offline_output_extension();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        add_result_t add_device_io_extension();
        remove_result_t remove_device_io_extension();
        audio::device_io_extension const &device_io_extension() const;
        audio::device_io_extension &device_io_extension();
#endif

        start_result_t start_render();
        start_result_t start_offline_render(offline_render_f, offline_completion_f);
        void stop();

        subject_t &subject() const;

#if YAS_TEST
        std::unordered_set<node> &nodes() const;
        audio::connection_set &connections() const;
#endif
    };
}

std::string to_string(audio::engine::method const &);
std::string to_string(audio::engine::start_error_t const &);
}

std::ostream &operator<<(std::ostream &, yas::audio::engine::method const &);
std::ostream &operator<<(std::ostream &, yas::audio::engine::start_error_t const &);
