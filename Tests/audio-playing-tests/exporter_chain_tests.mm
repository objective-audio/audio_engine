//
//  exporter_chain_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-playing/umbrella.hpp>
#import <audio-processing/umbrella.hpp>
#import <cpp-utils/umbrella.hpp>
#import "test_utils.h"

using namespace yas;
using namespace yas::playing;

namespace yas::playing::exporter_chain_test {
struct cpp {
    std::string const root_path = test_utils::root_path();
    std::shared_ptr<exporter_task_queue> const queue = exporter_task_queue::make_shared(2);
    exporter::task_priority_t const priority{.timeline = 0, .fragment = 1};
};
}  // namespace yas::playing::exporter_chain_test

@interface exporter_chain_tests : XCTestCase

@end

@implementation exporter_chain_tests {
    exporter_chain_test::cpp _cpp;
}

- (void)setUp {
}

- (void)tearDown {
}

- (void)test_chain {
    std::string const &root_path = self->_cpp.root_path;
    auto const &queue = self->_cpp.queue;
    sample_rate_t const sample_rate = 2;
    std::string const identifier = "0";

    auto exporter = exporter::make_shared(root_path, queue, self->_cpp.priority);

    queue->wait_until_all_tasks_are_finished();

    auto timeline = proc::timeline::make_shared();

    {
        std::vector<exporter::event_t> received;

        auto expectation = [self expectationWithDescription:@"set timeline"];

        auto canceller = exporter
                             ->observe_event([&received, &expectation](auto const &event) {
                                 received.push_back(event);
                                 [expectation fulfill];
                             })
                             .end();

        exporter->set_timeline_container(timeline_container::make_shared(identifier, sample_rate, timeline));

        [self waitForExpectations:@[expectation] timeout:10.0];

        XCTAssertEqual(received.size(), 1);
        XCTAssertEqual(received.at(0).result.value(), exporter::method_t::reset);

        canceller->cancel();
    }

    auto track = proc::track::make_shared();

    {
        std::vector<exporter::event_t> received;

        auto expectation = [self expectationWithDescription:@"insert track"];
        expectation.expectedFulfillmentCount = 2;

        auto canceller = exporter
                             ->observe_event([&received, &expectation](auto const &event) {
                                 received.push_back(event);
                                 [expectation fulfill];
                             })
                             .end();

        auto module = proc::make_number_module<int64_t>(100);
        module->connect_output(proc::to_connector_index(proc::constant::output::value), 0);
        track->push_back_module(module, {0, 1});

        timeline->insert_track(0, track);

        [self waitForExpectations:@[expectation] timeout:10.0];

        XCTAssertEqual(received.size(), 2);
        XCTAssertEqual(received.at(0).result.value(), exporter::method_t::export_began);
        XCTAssertEqual(received.at(0).range, (proc::time::range{0, 2}));
        XCTAssertEqual(received.at(1).result.value(), exporter::method_t::export_ended);
        XCTAssertEqual(received.at(1).range, (proc::time::range{0, 2}));

        canceller->cancel();
    }

    {
        std::vector<exporter::event_t> received;

        auto expectation = [self expectationWithDescription:@"insert module same range"];
        expectation.expectedFulfillmentCount = 2;

        auto canceller = exporter
                             ->observe_event([&received, &expectation](auto const &event) {
                                 received.push_back(event);
                                 [expectation fulfill];
                             })
                             .end();

        auto module = proc::make_number_module<int64_t>(200);
        module->connect_output(proc::to_connector_index(proc::constant::output::value), 0);
        track->push_back_module(module, {0, 1});

        [self waitForExpectations:@[expectation] timeout:10.0];

        XCTAssertEqual(received.size(), 2);

        XCTAssertEqual(received.at(0).result.value(), exporter::method_t::export_began);
        XCTAssertEqual(received.at(0).range, (proc::time::range{0, 2}));
        XCTAssertEqual(received.at(1).result.value(), exporter::method_t::export_ended);
        XCTAssertEqual(received.at(1).range, (proc::time::range{0, 2}));

        canceller->cancel();
    }

    {
        std::vector<exporter::event_t> received;

        auto expectation = [self expectationWithDescription:@"insert module diff range"];
        expectation.expectedFulfillmentCount = 3;

        auto canceller = exporter
                             ->observe_event([&received, &expectation](auto const &event) {
                                 received.push_back(event);
                                 [expectation fulfill];
                             })
                             .end();

        auto module = proc::make_number_module<Float64>(1.0);
        module->connect_output(proc::to_connector_index(proc::constant::output::value), 1);
        track->push_back_module(module, {2, 3});

        [self waitForExpectations:@[expectation] timeout:10.0];

        XCTAssertEqual(received.size(), 3);

        XCTAssertEqual(received.at(0).result.value(), exporter::method_t::export_began);
        XCTAssertEqual(received.at(0).range, (proc::time::range{2, 4}));
        XCTAssertEqual(received.at(1).result.value(), exporter::method_t::export_ended);
        XCTAssertEqual(received.at(1).range, (proc::time::range{2, 2}));
        XCTAssertEqual(received.at(2).result.value(), exporter::method_t::export_ended);
        XCTAssertEqual(received.at(2).range, (proc::time::range{4, 2}));

        canceller->cancel();
    }

    {
        std::vector<exporter::event_t> received;

        auto expectation = [self expectationWithDescription:@"erase module"];
        expectation.expectedFulfillmentCount = 2;

        auto canceller = exporter
                             ->observe_event([&received, &expectation](auto const &event) {
                                 received.push_back(event);
                                 [expectation fulfill];
                             })
                             .end();

        track->erase_modules_for_range({0, 1});

        [self waitForExpectations:@[expectation] timeout:10.0];

        XCTAssertEqual(received.size(), 2);

        XCTAssertEqual(received.at(0).result.value(), exporter::method_t::export_began);
        XCTAssertEqual(received.at(0).range, (proc::time::range{0, 2}));
        XCTAssertEqual(received.at(1).result.value(), exporter::method_t::export_ended);
        XCTAssertEqual(received.at(1).range, (proc::time::range{0, 2}));

        canceller->cancel();
    }

    {
        std::vector<exporter::event_t> received;

        auto expectation = [self expectationWithDescription:@"erase track"];
        expectation.expectedFulfillmentCount = 3;

        auto canceller = exporter
                             ->observe_event([&received, &expectation](auto const &event) {
                                 received.push_back(event);
                                 [expectation fulfill];
                             })
                             .end();

        timeline->erase_track(0);

        [self waitForExpectations:@[expectation] timeout:10.0];

        XCTAssertEqual(received.size(), 3);

        XCTAssertEqual(received.at(0).result.value(), exporter::method_t::export_began);
        XCTAssertEqual(received.at(0).range, (proc::time::range{2, 4}));
        XCTAssertEqual(received.at(1).result.value(), exporter::method_t::export_ended);
        XCTAssertEqual(received.at(1).range, (proc::time::range{2, 2}));
        XCTAssertEqual(received.at(2).result.value(), exporter::method_t::export_ended);
        XCTAssertEqual(received.at(2).range, (proc::time::range{4, 2}));

        canceller->cancel();
    }
}

@end
