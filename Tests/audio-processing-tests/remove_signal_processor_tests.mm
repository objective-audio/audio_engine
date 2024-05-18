//
//  remove_signal_processor_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/processor/maker/remove_signal_processor.h>

using namespace yas;
using namespace yas::proc;

@interface remove_signal_processor_tests : XCTestCase

@end

@implementation remove_signal_processor_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_process {
    stream stream{sync_source{1, 1}};

    auto &channel = stream.add_channel(0);
    channel.insert_event(make_range_time(0, 1), signal_event::make_shared<int16_t>(1));

    auto module = module::make_shared([] { return module::processors_t{make_remove_signal_processor<int16_t>({0})}; });
    module->connect_input(0, 0);

    module->process({0, 1}, stream);

    XCTAssertEqual(channel.events().size(), 0);
}

- (void)test_range {
    stream stream{sync_source{1, 1}};

    auto &channel = stream.add_channel(0);
    auto signal = signal_event::make_shared<int16_t>(3);
    signal->data<int16_t>()[0] = 100;
    signal->data<int16_t>()[1] = 101;
    signal->data<int16_t>()[2] = 102;
    channel.insert_event(make_range_time(0, 3), signal);

    auto module = module::make_shared([] { return module::processors_t{make_remove_signal_processor<int16_t>({0})}; });
    module->connect_input(0, 0);

    module->process({1, 1}, stream);

    XCTAssertEqual(channel.events().size(), 2);

    auto iterator = channel.events().cbegin();
    XCTAssertEqual(iterator->first.get<time::range>().frame, 0);
    XCTAssertEqual(iterator->first.get<time::range>().length, 1);
    XCTAssertEqual(iterator->second.get<signal_event>()->data<int16_t>()[0], 100);

    ++iterator;
    XCTAssertEqual(iterator->first.get<time::range>().frame, 2);
    XCTAssertEqual(iterator->first.get<time::range>().length, 1);
    XCTAssertEqual(iterator->second.get<signal_event>()->data<int16_t>()[0], 102);
}

- (void)test_type {
    stream stream{sync_source{1, 1}};

    auto &channel = stream.add_channel(0);
    channel.insert_event(make_range_time(0, 1), signal_event::make_shared<int8_t>(1));
    channel.insert_event(make_range_time(0, 1), signal_event::make_shared<int16_t>(1));
    channel.insert_event(make_range_time(0, 1), signal_event::make_shared<int32_t>(1));

    auto module = module::make_shared([] { return module::processors_t{make_remove_signal_processor<int16_t>({0})}; });
    module->connect_input(0, 0);

    module->process({0, 1}, stream);

    XCTAssertEqual(channel.events().size(), 2);

    auto iterator = channel.events().cbegin();
    XCTAssertTrue(iterator->second.get<signal_event>()->sample_type() != typeid(int16_t));
    ++iterator;
    XCTAssertTrue(iterator->second.get<signal_event>()->sample_type() != typeid(int16_t));
}

- (void)test_key {
    stream stream{sync_source{1, 1}};

    {
        auto &channel0 = stream.add_channel(0);
        channel0.insert_event(make_range_time(0, 1), signal_event::make_shared<int16_t>(1));

        auto &channel1 = stream.add_channel(1);
        channel1.insert_event(make_range_time(0, 1), signal_event::make_shared<int16_t>(1));

        auto &channel2 = stream.add_channel(2);
        channel2.insert_event(make_range_time(0, 1), signal_event::make_shared<int16_t>(1));
    }

    auto module =
        module::make_shared([] { return module::processors_t{make_remove_signal_processor<int16_t>({0, 2})}; });
    module->connect_input(0, 0);
    module->connect_input(1, 1);
    module->connect_input(2, 2);

    module->process({0, 1}, stream);

    {
        auto const &channel0 = stream.channel(0);
        XCTAssertEqual(channel0.events().size(), 0);

        auto const &channel1 = stream.channel(1);
        XCTAssertEqual(channel1.events().size(), 1);

        auto const &channel2 = stream.channel(2);
        XCTAssertEqual(channel2.events().size(), 0);
    }
}

@end
