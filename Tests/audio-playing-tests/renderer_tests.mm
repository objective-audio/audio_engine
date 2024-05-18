//
//  renderer_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-engine/umbrella.h>
#import <audio-playing/umbrella.hpp>

using namespace yas;
using namespace yas::playing;

namespace yas::playing::renderer_test {
struct io_core : audio::io_core {
    void set_render_handler(std::optional<audio::io_render_f>) {
    }

    void set_maximum_frames_per_slice(uint32_t const) {
    }

    bool start() {
        return true;
    }

    void stop() {
    }
};

struct device : audio::io_device {
    std::function<std::optional<audio::format>(void)> input_format_handler;
    std::function<std::optional<audio::format>(void)> output_format_handler;
    observing::notifier_ptr<io_device::method> const notifier = observing::notifier<io_device::method>::make_shared();

    std::optional<audio::format> input_format() const override {
        return this->input_format_handler();
    }

    std::optional<audio::format> output_format() const override {
        return this->output_format_handler();
    }

    audio::io_core_ptr make_io_core() const override {
        return std::make_shared<io_core>();
    }

    std::optional<audio::interruptor_ptr> const &interruptor() const override {
        static std::optional<audio::interruptor_ptr> _interruptor = std::nullopt;
        return _interruptor;
    }

    observing::endable observe_io_device(observing::caller<method>::handler_f &&handler) override {
        return this->notifier->observe(std::move(handler));
    }
};
}  // namespace yas::playing::renderer_test

@interface renderer_tests : XCTestCase

@end

@implementation renderer_tests {
}

- (void)test_constructor_with_format {
    auto const device = std::make_shared<renderer_test::device>();

    std::optional<audio::format> output_format =
        audio::format{{.sample_rate = 1000, .channel_count = 2, .pcm_format = audio::pcm_format::float32}};

    device->output_format_handler = [&output_format] { return output_format; };

    auto const renderer = playing::renderer::make_shared(device);

    auto const &format = renderer->format();
    XCTAssertEqual(format.sample_rate, 1000);
    XCTAssertEqual(format.channel_count, 2);
    XCTAssertEqual(format.pcm_format, audio::pcm_format::float32);
}

- (void)test_constructor_null_format {
    auto const device = std::make_shared<renderer_test::device>();

    std::optional<audio::format> output_format = std::nullopt;

    device->output_format_handler = [&output_format] { return output_format; };

    auto const renderer = playing::renderer::make_shared(device);

    auto const &format = renderer->format();
    XCTAssertEqual(format.sample_rate, 0);
    XCTAssertEqual(format.channel_count, 0);
    XCTAssertEqual(format.pcm_format, audio::pcm_format::other);
}

@end
