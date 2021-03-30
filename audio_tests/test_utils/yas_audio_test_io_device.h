//
//  yas_audio_test_io_device.h
//

#pragma once

#import "yas_audio_test_utils.h"

namespace yas::test {
struct test_io_core : audio::io_core {
    std::optional<std::function<void(std::optional<audio::io_render_f> const &)>> set_render_handler_handler =
        std::nullopt;
    std::optional<std::function<void(uint32_t const)>> set_maximum_frames_handler = std::nullopt;

    std::optional<std::function<bool(void)>> start_handler = std::nullopt;
    std::optional<std::function<void(void)>> stop_handler = std::nullopt;

    void set_render_handler(std::optional<audio::io_render_f> handler) override {
        if (auto const &set_handler = this->set_render_handler_handler) {
            set_handler.value()(handler);
        }
    }

    void set_maximum_frames_per_slice(uint32_t const frames) override {
        if (auto const &handler = this->set_maximum_frames_handler) {
            handler.value()(frames);
        }
    }

    bool start() override {
        if (auto const &handler = this->start_handler) {
            return handler.value()();
        } else {
            return false;
        }
    }

    void stop() override {
        if (auto const &handler = this->stop_handler) {
            return handler.value()();
        }
    }
};

using test_io_core_ptr = std::shared_ptr<test_io_core>;

struct test_io_device : audio::io_device {
    observing::notifier_ptr<io_device::method> const notifier = observing::notifier<io_device::method>::make_shared();

    std::optional<std::function<test_io_core_ptr(void)>> make_io_core_handler = std::nullopt;
    std::optional<std::function<std::optional<audio::format>(void)>> input_format_handler = std::nullopt;
    std::optional<std::function<std::optional<audio::format>(void)>> output_format_handler = std::nullopt;

    std::optional<audio::format> input_format() const override {
        if (auto const &handler = this->input_format_handler) {
            return handler.value()();
        } else {
            return std::nullopt;
        }
    }
    std::optional<audio::format> output_format() const override {
        if (auto const &handler = this->output_format_handler) {
            return handler.value()();
        } else {
            return std::nullopt;
        }
    }

    audio::io_core_ptr make_io_core() const override {
        if (auto const &handler = this->make_io_core_handler) {
            return handler.value()();
        } else {
            return std::make_shared<test_io_core>();
        }
    }

    std::optional<audio::interruptor_ptr> const &interruptor() const override {
        static std::optional<audio::interruptor_ptr> const _nullopt = std::nullopt;
        return _nullopt;
    }

    observing::endable observe_io_device(observing::caller<method>::handler_f &&handler) override {
        return this->notifier->observe(std::move(handler));
    }

    static std::shared_ptr<test_io_device> make_shared() {
        return std::make_shared<test_io_device>();
    }
};

using test_io_device_ptr = std::shared_ptr<test_io_device>;
}  // namespace yas::test
