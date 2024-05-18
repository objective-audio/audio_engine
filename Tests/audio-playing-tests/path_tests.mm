//
//  yas_playing_path_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-playing/umbrella.hpp>
#import <cpp-utils/umbrella.hpp>

using namespace yas;
using namespace yas::playing;

@interface path_tests : XCTestCase

@end

@implementation path_tests

- (void)test_timeline {
    path::timeline tl_path{"/root", "0", 48000};

    XCTAssertEqual(tl_path.identifier, "0");
    XCTAssertEqual(tl_path.sample_rate, 48000);
    XCTAssertEqual(tl_path.value().string(), "/root/0_48000");
}

- (void)test_timeline_equal {
    XCTAssertTrue((path::timeline{"/root", "0", 48000}) == (path::timeline{"/root", "0", 48000}));
    XCTAssertFalse((path::timeline{"/root", "0", 48000}) == (path::timeline{"/other", "0", 48000}));
    XCTAssertFalse((path::timeline{"/root", "0", 48000}) == (path::timeline{"/root", "1", 48000}));
    XCTAssertFalse((path::timeline{"/root", "0", 48000}) == (path::timeline{"/root", "0", 48001}));

    XCTAssertFalse((path::timeline{"/root", "0", 48000}) != (path::timeline{"/root", "0", 48000}));
    XCTAssertTrue((path::timeline{"/root", "0", 48000}) != (path::timeline{"/other", "0", 48000}));
    XCTAssertTrue((path::timeline{"/root", "0", 48000}) != (path::timeline{"/root", "1", 48000}));
    XCTAssertTrue((path::timeline{"/root", "0", 48000}) != (path::timeline{"/root", "0", 48001}));
}

- (void)test_channel {
    path::timeline tl_path{"/root", "0", 48000};
    path::channel ch_path{tl_path, 1};

    XCTAssertEqual(ch_path.channel_index, 1);
    XCTAssertEqual(ch_path.value().string(), "/root/0_48000/1");
}

- (void)test_channel_equal {
    XCTAssertTrue((path::channel{path::timeline{"/root", "0", 48000}, 1}) ==
                  (path::channel{path::timeline{"/root", "0", 48000}, 1}));
    XCTAssertFalse((path::channel{path::timeline{"/root", "1", 48000}, 1}) ==
                   (path::channel{path::timeline{"/root", "0", 48000}, 1}));
    XCTAssertFalse((path::channel{path::timeline{"/root", "0", 48000}, 1}) ==
                   (path::channel{path::timeline{"/root", "0", 48000}, 2}));

    XCTAssertFalse((path::channel{path::timeline{"/root", "0", 48000}, 1}) !=
                   (path::channel{path::timeline{"/root", "0", 48000}, 1}));
    XCTAssertTrue((path::channel{path::timeline{"/root", "0", 48000}, 1}) !=
                  (path::channel{path::timeline{"/root", "1", 48000}, 1}));
    XCTAssertTrue((path::channel{path::timeline{"/root", "0", 48000}, 1}) !=
                  (path::channel{path::timeline{"/root", "0", 48000}, 2}));
}

- (void)test_fragment {
    path::timeline tl_path{"/root", "0", 48000};
    path::fragment frag_path{path::channel{tl_path, 1}, 2};

    XCTAssertEqual(frag_path.fragment_index, 2);
    XCTAssertEqual(frag_path.value().string(), "/root/0_48000/1/2");
}

- (void)test_fragment_equal {
    XCTAssertTrue((path::fragment{path::channel{path::timeline{"/root", "0", 48000}, 1}, 2}) ==
                  (path::fragment{path::channel{path::timeline{"/root", "0", 48000}, 1}, 2}));
    XCTAssertFalse((path::fragment{path::channel{path::timeline{"/root", "0", 48000}, 1}, 2}) ==
                   (path::fragment{path::channel{path::timeline{"/root", "0", 48000}, 3}, 2}));
    XCTAssertFalse((path::fragment{path::channel{path::timeline{"/root", "0", 48000}, 1}, 2}) ==
                   (path::fragment{path::channel{path::timeline{"/root", "0", 48000}, 1}, 4}));

    XCTAssertFalse((path::fragment{path::channel{path::timeline{"/root", "0", 48000}, 1}, 2}) !=
                   (path::fragment{path::channel{path::timeline{"/root", "0", 48000}, 1}, 2}));
    XCTAssertTrue((path::fragment{path::channel{path::timeline{"/root", "0", 48000}, 1}, 2}) !=
                  (path::fragment{path::channel{path::timeline{"/root", "0", 48000}, 3}, 2}));
    XCTAssertTrue((path::fragment{path::channel{path::timeline{"/root", "0", 48000}, 1}, 2}) !=
                  (path::fragment{path::channel{path::timeline{"/root", "0", 48000}, 1}, 4}));
}

- (void)test_signal_event {
    path::timeline tl_path{"/root", "0", 48000};
    path::channel ch_path{tl_path, 1};
    path::fragment frag_path{ch_path, 2};
    path::signal_event signal_event_path{frag_path, {3, 4}, typeid(int64_t)};

    XCTAssertEqual(signal_event_path.range, (proc::time::range{3, 4}));
    XCTAssertTrue(signal_event_path.sample_type == typeid(int64_t));
    XCTAssertEqual(signal_event_path.value().string(), "/root/0_48000/1/2/signal_3_4_i64");
}

- (void)test_signal_event_equal {
    path::fragment const frag_path_1a{path::channel{path::timeline{"/root", "0", 48000}, 1}, 2};
    path::fragment const frag_path_1b{path::channel{path::timeline{"/root", "0", 48000}, 1}, 2};
    path::fragment const frag_path_2{path::channel{path::timeline{"/root", "0", 48000}, 1}, 3};

    XCTAssertTrue((path::signal_event{frag_path_1a, {3, 4}, typeid(int64_t)}) ==
                  (path::signal_event{frag_path_1b, {3, 4}, typeid(int64_t)}));
    XCTAssertFalse((path::signal_event{frag_path_1a, {3, 4}, typeid(int64_t)}) ==
                   (path::signal_event{frag_path_2, {3, 4}, typeid(int64_t)}));
    XCTAssertFalse((path::signal_event{frag_path_1a, {3, 4}, typeid(int64_t)}) ==
                   (path::signal_event{frag_path_1b, {3, 5}, typeid(int64_t)}));
    XCTAssertFalse((path::signal_event{frag_path_1a, {3, 4}, typeid(int64_t)}) ==
                   (path::signal_event{frag_path_1b, {3, 4}, typeid(float)}));

    XCTAssertFalse((path::signal_event{frag_path_1a, {3, 4}, typeid(int64_t)}) !=
                   (path::signal_event{frag_path_1b, {3, 4}, typeid(int64_t)}));
    XCTAssertTrue((path::signal_event{frag_path_1a, {3, 4}, typeid(int64_t)}) !=
                  (path::signal_event{frag_path_2, {3, 4}, typeid(int64_t)}));
    XCTAssertTrue((path::signal_event{frag_path_1a, {3, 4}, typeid(int64_t)}) !=
                  (path::signal_event{frag_path_1b, {3, 5}, typeid(int64_t)}));
    XCTAssertTrue((path::signal_event{frag_path_1a, {3, 4}, typeid(int64_t)}) !=
                  (path::signal_event{frag_path_1b, {3, 4}, typeid(float)}));
}

- (void)test_number_events {
    path::timeline tl_path{"/root", "0", 48000};
    path::channel ch_path{tl_path, 1};
    path::fragment frag_path{ch_path, 2};
    path::number_events number_events_path{frag_path};

    XCTAssertEqual(number_events_path.value().string(), "/root/0_48000/1/2/numbers");
}

- (void)test_number_events_equal {
    path::fragment const frag_path_1a{path::channel{path::timeline{"/root", "0", 48000}, 1}, 2};
    path::fragment const frag_path_1b{path::channel{path::timeline{"/root", "0", 48000}, 1}, 2};
    path::fragment const frag_path_2{path::channel{path::timeline{"/root", "0", 48000}, 1}, 3};

    XCTAssertTrue((path::number_events{frag_path_1a}) == (path::number_events{frag_path_1b}));
    XCTAssertFalse((path::number_events{frag_path_1a}) == (path::number_events{frag_path_2}));

    XCTAssertFalse((path::number_events{frag_path_1a}) != (path::number_events{frag_path_1b}));
    XCTAssertTrue((path::number_events{frag_path_1a}) != (path::number_events{frag_path_2}));
}

- (void)test_timeline_name {
    XCTAssertEqual(path::timeline_name("testid", 48000), "testid_48000");
}

- (void)test_channel_name {
    XCTAssertEqual(path::channel_name(0), "0");
    XCTAssertEqual(path::channel_name(1), "1");
    XCTAssertEqual(path::channel_name(1000), "1000");
    XCTAssertEqual(path::channel_name(-1), "-1");
}

- (void)test_fragment_name {
    XCTAssertEqual(path::fragment_name(0), "0");
    XCTAssertEqual(path::fragment_name(1), "1");
    XCTAssertEqual(path::fragment_name(1000), "1000");
    XCTAssertEqual(path::fragment_name(-1), "-1");
}

@end
