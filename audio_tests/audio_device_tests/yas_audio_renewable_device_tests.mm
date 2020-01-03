//
//  yas_audio_renewable_device_tests.mm
//

#import "yas_audio_test_utils.h"

using namespace yas;
using namespace yas::audio;

namespace yas::test {
struct test_io_core : io_core {
    void initialize() override {
    }

    void uninitialize() override {
    }

    void set_render_handler(std::optional<io_render_f>) override {
    }

    void set_maximum_frames_per_slice(uint32_t const) override {
    }

    bool start() override {
        return false;
    }

    void stop() override {
    }

    std::optional<pcm_buffer_ptr> const &input_buffer_on_render() const override {
        static std::optional<pcm_buffer_ptr> const _null_buffer = std::nullopt;
        return _null_buffer;
    }

    std::optional<time_ptr> const &input_time_on_render() const override {
        static std::optional<time_ptr> const _null_time = std::nullopt;
        return _null_time;
    }
};

struct test_io_device : audio::io_device {
    bool const is_input;
    chaining::notifier_ptr<io_device::method> const notifier = chaining::notifier<io_device::method>::make_shared();

    std::optional<audio::format> input_format() const override {
        if (this->is_input) {
            return audio::format{{.sample_rate = 44100.0, .channel_count = 1}};
        } else {
            return std::nullopt;
        }
    }

    std::optional<audio::format> output_format() const override {
        if (this->is_input) {
            return std::nullopt;
        } else {
            return audio::format{{.sample_rate = 44100.0, .channel_count = 1}};
        }
    }

    std::optional<interruptor_ptr> const &interruptor() const override {
        static std::optional<interruptor_ptr> const _nullopt = std::nullopt;
        return _nullopt;
    }

    io_core_ptr make_io_core() const override {
        return std::make_shared<test_io_core>();
    }

    chaining::chain_unsync_t<io_device::method> io_device_chain() override {
        return this->notifier->chain();
    }

    static std::shared_ptr<test_io_device> make_shared(bool is_input) {
        return std::shared_ptr<test_io_device>(new test_io_device{is_input});
    }

   private:
    test_io_device(bool is_input) : is_input(is_input) {
    }
};
}

@interface yas_audio_renewable_device_tests : XCTestCase

@end

@implementation yas_audio_renewable_device_tests

- (void)setUp {
}

- (void)tearDown {
}

- (void)test_renewal {
    auto const output_device = test::test_io_device::make_shared(false);
    auto const input_device = test::test_io_device::make_shared(true);

    auto const update_notifier = chaining::notifier<std::nullptr_t>::make_shared();

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
            auto pool = chaining::observer_pool::make_shared();

            *pool += device->io_device_chain()
                         .guard([](auto const &method) { return method == io_device::method::updated; })
                         .perform([handler](auto const &) { handler(renewable_device::method::notify); })
                         .end();

            *pool += update_notifier->chain()
                         .perform([handler](auto const &) { handler(renewable_device::method::renewal); })
                         .end();

            return pool;
        });

    std::vector<io_device::method> received;

    auto observer = renewable_device->io_device_chain()
                        .perform([&received](auto const &method) { received.push_back(method); })
                        .end();

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
