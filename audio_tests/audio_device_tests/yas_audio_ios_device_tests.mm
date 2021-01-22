//
//  yas_audio_ios_device_tests.mm
//

#import <XCTest/XCTest.h>
#import "yas_audio_test_utils.h"

using namespace yas;

namespace yas::audio::test {
struct test_device_session : ios_device_session {
    std::optional<std::function<double(void)>> sample_rate_handler = std::nullopt;
    std::optional<std::function<uint32_t(void)>> output_channel_count_handler = std::nullopt;
    std::optional<std::function<uint32_t(void)>> input_channel_count_handler = std::nullopt;
    observing::notifier_ptr<device_method> notifier = observing::notifier<device_method>::make_shared();

    double sample_rate() const override {
        if (auto const &handler = this->sample_rate_handler) {
            return handler.value()();
        } else {
            return 0;
        }
    }

    uint32_t output_channel_count() const override {
        if (auto const &handler = this->output_channel_count_handler) {
            return handler.value()();
        } else {
            return 0;
        }
    }

    uint32_t input_channel_count() const override {
        if (auto const &handler = this->input_channel_count_handler) {
            return handler.value()();
        } else {
            return 0;
        }
    }

    observing::canceller_ptr observe_device(observing::caller<device_method>::handler_f &&handler) override {
        return this->notifier->observe(std::move(handler));
    }
};

struct test_interruptor : interruptor {
    void begin() {
        this->_is_interrupting = true;
        this->_notifier->notify(interruption_method::began);
    }

    void end() {
        this->_is_interrupting = false;
        this->_notifier->notify(interruption_method::ended);
    }

    bool is_interrupting() const override {
        return this->_is_interrupting;
    }

    observing::canceller_ptr observe_interruption(
        observing::caller<interruption_method>::handler_f &&handler) override {
        return this->_notifier->observe(std::move(handler));
    }

   private:
    bool _is_interrupting = false;
    observing::notifier_ptr<interruption_method> _notifier = observing::notifier<interruption_method>::make_shared();
};
}

@interface yas_audio_ios_device_tests : XCTestCase

@end

@implementation yas_audio_ios_device_tests

- (void)setUp {
}

- (void)tearDown {
}

- (void)test_format {
    auto const device_session = std::make_shared<audio::test::test_device_session>();
    auto const interruptor = std::make_shared<audio::test::test_interruptor>();
    auto const device = audio::ios_device::make_shared(device_session, interruptor);

    device_session->sample_rate_handler = []() { return 48000.0; };
    device_session->output_channel_count_handler = []() { return 2; };
    device_session->input_channel_count_handler = []() { return 1; };

    XCTAssertEqual(device->sample_rate(), 48000);
    XCTAssertTrue(device->output_format() == audio::format({.sample_rate = 48000.0, .channel_count = 2}));
    XCTAssertTrue(device->input_format() == audio::format({.sample_rate = 48000.0, .channel_count = 1}));

    device_session->sample_rate_handler = []() { return 0; };
    device_session->output_channel_count_handler = []() { return 1; };
    device_session->input_channel_count_handler = []() { return 1; };

    XCTAssertFalse(device->output_format().has_value());
    XCTAssertFalse(device->input_format().has_value());

    device_session->sample_rate_handler = []() { return 44100; };
    device_session->output_channel_count_handler = []() { return 0; };
    device_session->input_channel_count_handler = []() { return 0; };

    XCTAssertFalse(device->output_format().has_value());
    XCTAssertFalse(device->input_format().has_value());
}

- (void)test_notify {
    auto const device_session = std::make_shared<audio::test::test_device_session>();
    auto const interruptor = std::make_shared<audio::test::test_interruptor>();
    auto const device = audio::ios_device::make_shared(device_session, interruptor);

    device_session->sample_rate_handler = []() { return 44100; };
    device_session->output_channel_count_handler = []() { return 1; };
    device_session->input_channel_count_handler = []() { return 1; };

    std::vector<audio::io_device::method> received;

    auto canceller = device->observe_io_device([&received](auto const &method) { received.push_back(method); });

    device_session->notifier->notify(audio::ios_device_session::device_method::route_change);

    XCTAssertEqual(received.size(), 1);
    XCTAssertEqual(received.at(0), audio::io_device::method::updated);
    XCTAssertTrue(device->output_format().has_value());
    XCTAssertTrue(device->input_format().has_value());

    device_session->notifier->notify(audio::ios_device_session::device_method::media_service_were_lost);

    XCTAssertEqual(received.size(), 2);
    XCTAssertEqual(received.at(1), audio::io_device::method::lost);
    XCTAssertFalse(device->output_format().has_value());
    XCTAssertFalse(device->input_format().has_value());
}

- (void)test_interruptor {
    auto const device_session = std::make_shared<audio::test::test_device_session>();
    auto const interruptor = std::make_shared<audio::test::test_interruptor>();
    auto const device = audio::ios_device::make_shared(device_session, interruptor);

    XCTAssertEqual(audio::io_device::cast(device)->interruptor(), interruptor);
}

@end
