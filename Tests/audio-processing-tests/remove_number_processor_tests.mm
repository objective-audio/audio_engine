//
//  remove_number_processor_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/processor/maker/remove_number_processor.h>

using namespace yas;
using namespace yas::proc;

@interface remove_number_processor_tests : XCTestCase

@end

@implementation remove_number_processor_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_process {
    stream stream{sync_source{1, 1}};

    auto &channel0 = stream.add_channel(0);
    channel0.insert_event(make_frame_time(0), number_event::make_shared(int8_t(0)));
    channel0.insert_event(make_frame_time(0), number_event::make_shared(float(1.0f)));
    channel0.insert_event(make_frame_time(10), number_event::make_shared(int8_t(10)));

    auto &channel1 = stream.add_channel(1);
    channel1.insert_event(make_frame_time(0), number_event::make_shared(int8_t(0)));

    auto module = module::make_shared([] { return module::processors_t{make_remove_number_processor<int8_t>({0})}; });

    module->connect_input(0, 0);

    module->process({0, 1}, stream);

    XCTAssertEqual(channel0.events().size(), 2);
    XCTAssertEqual(channel1.events().size(), 1);
}

- (void)test_connector_index {
    stream stream{sync_source{1, 1}};

    {
        auto &channel0 = stream.add_channel(0);
        channel0.insert_event(make_frame_time(0), number_event::make_shared<int8_t>(0));

        auto &channel1 = stream.add_channel(1);
        channel1.insert_event(make_frame_time(0), number_event::make_shared<int8_t>(1));

        auto &channel2 = stream.add_channel(2);
        channel2.insert_event(make_frame_time(0), number_event::make_shared<int8_t>(2));
    }

    auto module =
        module::make_shared([] { return module::processors_t{make_remove_number_processor<int8_t>({0, 2})}; });
    module->connect_input(0, 0);
    module->connect_input(1, 1);
    module->connect_input(2, 2);

    module->process({0, 1}, stream);

    {
        auto &channel0 = stream.channel(0);
        XCTAssertEqual(channel0.events().size(), 0);

        auto &channel1 = stream.channel(1);
        XCTAssertEqual(channel1.events().size(), 1);

        auto &channel2 = stream.channel(2);
        XCTAssertEqual(channel2.events().size(), 0);
    }
}

@end
