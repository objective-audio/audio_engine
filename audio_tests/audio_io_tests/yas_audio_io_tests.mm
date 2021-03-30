//
//  yas_audio_io_tests.mm
//

#import "yas_audio_test_io_device.h"
#import "yas_audio_test_utils.h"

using namespace yas;
using namespace yas::audio;

@interface yas_audio_io_tests : XCTestCase

@end

@implementation yas_audio_io_tests

- (void)setUp {
}

- (void)tearDown {
}

- (void)test_device_chain {
    auto const device = std::make_shared<test::test_io_device>();
    auto const io = audio::io::make_shared(device);

    std::vector<audio::io::device_observing_pair_t> received;

    auto canceller = io->observe_device([&received](auto const &pair) { received.push_back(pair); }).sync();

    XCTAssertEqual(received.size(), 1);
    XCTAssertEqual(received.at(0).first, audio::io::device_method::initial);

    device->notifier->notify(audio::io_device::method::updated);

    XCTAssertEqual(received.size(), 2);
    XCTAssertEqual(received.at(1).first, audio::io::device_method::updated);

    device->notifier->notify(audio::io_device::method::lost);

    XCTAssertEqual(received.size(), 3);
    XCTAssertEqual(received.at(2).first, audio::io::device_method::changed);

    device->notifier->notify(audio::io_device::method::updated);

    XCTAssertEqual(received.size(), 3);

    canceller->cancel();
}

- (void)test_io_core_method_called {
    enum method {
        set_render_handler,
        set_maximum_frames,
        start,
        stop,
    };

    auto const device = std::make_shared<test::test_io_device>();

    auto const core = std::make_shared<test::test_io_core>();
    device->make_io_core_handler = [core]() { return core; };

    std::vector<method> called_methods;

    core->set_render_handler_handler = [&called_methods](std::optional<io_render_f> const &) {
        called_methods.emplace_back(method::set_render_handler);
    };
    core->set_maximum_frames_handler = [&called_methods](uint32_t const) {
        called_methods.emplace_back(method::set_maximum_frames);
    };
    core->start_handler = [&called_methods]() {
        called_methods.emplace_back(method::start);
        return true;
    };
    core->stop_handler = [&called_methods]() { called_methods.emplace_back(method::stop); };

    {
        auto const io = audio::io::make_shared(device);

        XCTAssertEqual(called_methods.size(), 2);
        XCTAssertEqual(called_methods.at(0), method::set_render_handler);
        XCTAssertEqual(called_methods.at(1), method::set_maximum_frames);

        io->start();

        XCTAssertEqual(called_methods.size(), 3);
        XCTAssertEqual(called_methods.at(2), method::start);

        io->stop();

        XCTAssertEqual(called_methods.size(), 4);
        XCTAssertEqual(called_methods.at(3), method::stop);
    }

    XCTAssertEqual(called_methods.size(), 4, @"");

    {
        auto const io = audio::io::make_shared(device);

        XCTAssertEqual(called_methods.size(), 6);
        XCTAssertEqual(called_methods.at(4), method::set_render_handler);
        XCTAssertEqual(called_methods.at(5), method::set_maximum_frames);

        io->start();

        XCTAssertEqual(called_methods.size(), 7);
        XCTAssertEqual(called_methods.at(6), method::start);
    }

    XCTAssertEqual(called_methods.size(), 8);
    XCTAssertEqual(called_methods.at(7), method::stop);
}

@end
