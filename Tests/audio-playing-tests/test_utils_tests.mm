//
//  yas_playing_test_utils_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-playing/umbrella.hpp>
#import "test_utils.h"

using namespace yas;
using namespace yas::playing;

@interface test_utils_tests : XCTestCase

@end

@implementation test_utils_tests

- (void)setUp {
}

- (void)tearDown {
}

- (void)test_test_timeline {
    auto timeline = test_utils::test_timeline(0, 2);

    auto expectation = [self expectationWithDescription:@""];
    expectation.expectedFulfillmentCount = 5;

    timeline->process({-5, 25}, proc::sync_source{5, 5},
                      [&expectation, self](proc::time::range const &range, proc::stream const &stream) {
                          if (range == proc::time::range{-5, 5}) {
                              if (auto const events = stream.channel(0).filtered_events<int16_t, proc::signal_event>();
                                  events.size() == 1) {
                                  auto const &event = *events.begin();
                                  XCTAssertEqual(event.first, (proc::time::range{-3, 3}));
                                  auto const *data_ptr = event.second->data<int16_t>();
                                  XCTAssertEqual(data_ptr[0], -3);
                                  XCTAssertEqual(data_ptr[1], -2);
                                  XCTAssertEqual(data_ptr[2], -1);
                              } else {
                                  XCTFail(@"");
                              }
                              if (auto const events = stream.channel(1).filtered_events<int16_t, proc::signal_event>();
                                  events.size() == 1) {
                                  auto const &event = *events.begin();
                                  XCTAssertEqual(event.first, (proc::time::range{-3, 3}));
                                  auto const *data_ptr = event.second->data<int16_t>();
                                  XCTAssertEqual(data_ptr[0], 997);
                                  XCTAssertEqual(data_ptr[1], 998);
                                  XCTAssertEqual(data_ptr[2], 999);
                              } else {
                                  XCTFail(@"");
                              }
                          } else if (range == proc::time::range{0, 5}) {
                              if (auto const events = stream.channel(0).filtered_events<int16_t, proc::signal_event>();
                                  events.size() == 1) {
                                  auto const &event = *events.begin();
                                  XCTAssertEqual(event.first, (proc::time::range{0, 5}));
                                  auto const *data_ptr = event.second->data<int16_t>();
                                  XCTAssertEqual(data_ptr[0], 0);
                                  XCTAssertEqual(data_ptr[1], 1);
                                  XCTAssertEqual(data_ptr[2], 2);
                                  XCTAssertEqual(data_ptr[3], 3);
                                  XCTAssertEqual(data_ptr[4], 4);
                              } else {
                                  XCTFail(@"");
                              }
                              if (auto const events = stream.channel(1).filtered_events<int16_t, proc::signal_event>();
                                  events.size() == 1) {
                                  auto const &event = *events.begin();
                                  XCTAssertEqual(event.first, (proc::time::range{0, 5}));
                                  auto const *data_ptr = event.second->data<int16_t>();
                                  XCTAssertEqual(data_ptr[0], 1000);
                                  XCTAssertEqual(data_ptr[1], 1001);
                                  XCTAssertEqual(data_ptr[2], 1002);
                                  XCTAssertEqual(data_ptr[3], 1003);
                                  XCTAssertEqual(data_ptr[4], 1004);
                              } else {
                                  XCTFail(@"");
                              }
                          } else if (range == proc::time::range{5, 5}) {
                              if (auto const events = stream.channel(0).filtered_events<int16_t, proc::signal_event>();
                                  events.size() == 1) {
                                  auto const &event = *events.begin();
                                  XCTAssertEqual(event.first, (proc::time::range{5, 5}));
                                  auto const *data_ptr = event.second->data<int16_t>();
                                  XCTAssertEqual(data_ptr[0], 5);
                                  XCTAssertEqual(data_ptr[1], 6);
                                  XCTAssertEqual(data_ptr[2], 7);
                                  XCTAssertEqual(data_ptr[3], 8);
                                  XCTAssertEqual(data_ptr[4], 9);
                              } else {
                                  XCTFail(@"");
                              }
                              if (auto const events = stream.channel(1).filtered_events<int16_t, proc::signal_event>();
                                  events.size() == 1) {
                                  auto const &event = *events.begin();
                                  XCTAssertEqual(event.first, (proc::time::range{5, 5}));
                                  auto const *data_ptr = event.second->data<int16_t>();
                                  XCTAssertEqual(data_ptr[0], 1005);
                                  XCTAssertEqual(data_ptr[1], 1006);
                                  XCTAssertEqual(data_ptr[2], 1007);
                                  XCTAssertEqual(data_ptr[3], 1008);
                                  XCTAssertEqual(data_ptr[4], 1009);
                              } else {
                                  XCTFail(@"");
                              }
                          } else if (range == proc::time::range{10, 5}) {
                              if (auto const events = stream.channel(0).filtered_events<int16_t, proc::signal_event>();
                                  events.size() == 1) {
                                  auto const &event = *events.begin();
                                  XCTAssertEqual(event.first, (proc::time::range{10, 5}));
                                  auto const *data_ptr = event.second->data<int16_t>();
                                  XCTAssertEqual(data_ptr[0], 10);
                                  XCTAssertEqual(data_ptr[1], 11);
                                  XCTAssertEqual(data_ptr[2], 12);
                                  XCTAssertEqual(data_ptr[3], 13);
                                  XCTAssertEqual(data_ptr[4], 14);
                              } else {
                                  XCTFail(@"");
                              }
                              if (auto const events = stream.channel(1).filtered_events<int16_t, proc::signal_event>();
                                  events.size() == 1) {
                                  auto const &event = *events.begin();
                                  XCTAssertEqual(event.first, (proc::time::range{10, 5}));
                                  auto const *data_ptr = event.second->data<int16_t>();
                                  XCTAssertEqual(data_ptr[0], 1010);
                                  XCTAssertEqual(data_ptr[1], 1011);
                                  XCTAssertEqual(data_ptr[2], 1012);
                                  XCTAssertEqual(data_ptr[3], 1013);
                                  XCTAssertEqual(data_ptr[4], 1014);
                              } else {
                                  XCTFail(@"");
                              }
                          } else if (range == proc::time::range{15, 5}) {
                              XCTAssertEqual(stream.channel_count(), 0);
                          } else {
                              XCTFail(@"");
                          }

                          [expectation fulfill];

                          return proc::continuation::keep;
                      });

    [self waitForExpectations:@[expectation] timeout:10.0];
}

@end
