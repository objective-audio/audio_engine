//
//  player_task_tests.mm
//

#import <XCTest/XCTest.h>
#import "player_test_utils.h"

using namespace yas;
using namespace yas::playing;

@interface player_task_tests : XCTestCase

@end

@implementation player_task_tests {
    player_test::cpp _cpp;
}

- (void)test_reading {
    self->_cpp.setup_initial();

    auto const reading = self->_cpp.reading;
    auto const buffering = self->_cpp.buffering;
    auto const worker = self->_cpp.worker;

    buffering->setup_state_handler = [] { return buffering_resource::setup_state_t::initial; };
    buffering->rendering_state_handler = [] { return buffering_resource::rendering_state_t::waiting; };

    auto state = reading_resource::state_t::initial;
    reading->state_handler = [&state] { return state; };

    std::size_t called_create_buffer = 0;
    reading->create_buffer_handler = [&called_create_buffer] { ++called_create_buffer; };

    worker->start();

    worker->process();
    XCTAssertEqual(called_create_buffer, 0);

    state = reading_resource::state_t::rendering;

    worker->process();
    XCTAssertEqual(called_create_buffer, 0);

    state = reading_resource::state_t::creating;

    worker->process();
    XCTAssertEqual(called_create_buffer, 1);
}

- (void)test_buffering_setup {
    self->_cpp.setup_initial();

    auto const reading = self->_cpp.reading;
    auto const buffering = self->_cpp.buffering;
    auto const worker = self->_cpp.worker;

    reading->state_handler = [] { return reading_resource::state_t::initial; };
    buffering->rendering_state_handler = [] { return buffering_resource::rendering_state_t::waiting; };

    auto state = buffering_resource::setup_state_t::initial;
    buffering->setup_state_handler = [&state] { return state; };

    std::size_t called_create_buffer;
    buffering->create_buffer_handler = [&called_create_buffer] { ++called_create_buffer; };

    worker->start();

    worker->process();
    XCTAssertEqual(called_create_buffer, 0);

    state = buffering_resource::setup_state_t::rendering;

    worker->process();
    XCTAssertEqual(called_create_buffer, 0);

    state = buffering_resource::setup_state_t::creating;

    worker->process();
    XCTAssertEqual(called_create_buffer, 1);
}

- (void)test_buffering_rendering {
    self->_cpp.setup_initial();

    auto const reading = self->_cpp.reading;
    auto const buffering = self->_cpp.buffering;
    auto const worker = self->_cpp.worker;

    reading->state_handler = [] { return reading_resource::state_t::initial; };
    buffering->setup_state_handler = [] { return buffering_resource::setup_state_t::initial; };

    auto state = buffering_resource::rendering_state_t::waiting;
    buffering->rendering_state_handler = [&state] { return state; };

    std::size_t called_write_all = 0;
    std::size_t called_write_if_needed = 0;
    bool write_if_needed_result = false;

    buffering->write_all_elements_handler = [&called_write_all] { ++called_write_all; };
    buffering->write_elements_if_needed_handler = [&called_write_if_needed, &write_if_needed_result] {
        ++called_write_if_needed;
        return write_if_needed_result;
    };

    worker->start();

    worker->process();
    XCTAssertEqual(called_write_all, 0);
    XCTAssertEqual(called_write_if_needed, 0);

    state = buffering_resource::rendering_state_t::all_writing;

    worker->process();
    XCTAssertEqual(called_write_all, 1);
    XCTAssertEqual(called_write_if_needed, 0);

    state = buffering_resource::rendering_state_t::advancing;

    worker->process();
    XCTAssertEqual(called_write_all, 1);
    XCTAssertEqual(called_write_if_needed, 1);

    write_if_needed_result = true;

    worker->process();
    XCTAssertEqual(called_write_all, 1);
    XCTAssertEqual(called_write_if_needed, 2);
}

@end
