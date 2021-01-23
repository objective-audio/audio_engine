//
//  yas_audio_renewable_device_tests.mm
//

#import "yas_audio_test_io_device.h"

using namespace yas;
using namespace yas::audio;

@interface yas_audio_renewable_device_tests : XCTestCase

@end

@implementation yas_audio_renewable_device_tests

- (void)setUp {
}

- (void)tearDown {
}

- (void)test_renewal {
    auto const output_device = test::test_io_device::make_shared();
    output_device->output_format_handler = []() { return audio::format{{.sample_rate = 44100.0, .channel_count = 1}}; };

    auto const input_device = test::test_io_device::make_shared();
    input_device->input_format_handler = []() { return audio::format{{.sample_rate = 44100.0, .channel_count = 1}}; };

    auto const update_notifier = observing::notifier<std::nullptr_t>::make_shared();

    bool is_input = false;

    auto const renewable_device = audio::renewable_device::make_shared(
        [output_device, input_device, &is_input]() mutable {
            if (is_input) {
                return input_device;
            } else {
                return output_device;
            }
        },
        [update_notifier](io_device_ptr const &device, auto const &handler) {
            auto canceller1 = device->observe_io_device([handler](auto const &method) {
                if (method == io_device::method::updated) {
                    handler(renewable_device::method::notify);
                }
            });

            auto canceller2 =
                update_notifier->observe([handler](auto const &) { handler(renewable_device::method::renewal); });

            return std::vector<observing::invalidatable_ptr>{std::move(canceller1), std::move(canceller2)};
        });

    std::vector<io_device::method> received;

    auto canceller =
        renewable_device->observe_io_device([&received](auto const &method) { received.push_back(method); });

    // 最初はoutput_device
    XCTAssertTrue(renewable_device->output_format().has_value());
    XCTAssertFalse(renewable_device->input_format().has_value());

    // output_deviceからlostを送信
    output_device->notifier->notify(io_device::method::lost);

    // lostは無視されている
    XCTAssertEqual(received.size(), 0);

    // デバイスを変更せず通知する
    update_notifier->notify(nullptr);

    // デバイスは変わっていないので無視されている
    XCTAssertEqual(received.size(), 0);

    // デバイスを変更して通知する
    is_input = true;
    update_notifier->notify(nullptr);

    // renewable_deviceからはupdateで送信される
    XCTAssertEqual(received.size(), 1);
    XCTAssertEqual(received.at(0), io_device::method::updated);
    // input_deviceに変わっている
    XCTAssertTrue(renewable_device->input_format().has_value());
    XCTAssertFalse(renewable_device->output_format().has_value());

    // output_deviceからupdatedを送信
    output_device->notifier->notify(io_device::method::updated);

    // renewable_deviceのdeviceはoutput_deviceではないので何も送信されない
    XCTAssertEqual(received.size(), 1);

    // input_deviceからupdateを送信
    input_device->notifier->notify(io_device::method::updated);

    // renewable_deviceからupdatedが送信される
    XCTAssertEqual(received.size(), 2);
    XCTAssertEqual(received.at(1), io_device::method::updated);
}

@end
