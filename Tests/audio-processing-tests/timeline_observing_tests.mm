//
//  timeline_observing_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/timeline/timeline.h>

using namespace yas;
using namespace yas::proc;

@interface timeline_observing_tests : XCTestCase

@end

@implementation timeline_observing_tests

- (void)setUp {
}

- (void)tearDown {
}

- (void)test_fetched {
    auto timeline = timeline::make_shared();

    auto track0 = track::make_shared();
    auto track1 = track::make_shared();

    timeline->insert_track(0, track0);
    timeline->insert_track(1, track1);

    std::vector<timeline_event> events;

    auto canceller = timeline->observe([&events](auto const &event) { events.push_back(event); }).sync();

    XCTAssertEqual(events.size(), 1);
    XCTAssertEqual(events.at(0).type, timeline_event_type::any);
    auto const &tracks = events.at(0).tracks;
    XCTAssertEqual(tracks.at(0), track0);
    XCTAssertEqual(tracks.at(1), track1);
    XCTAssertEqual(events.at(0).index, std::nullopt);
    XCTAssertEqual(events.at(0).inserted, nullptr);
    XCTAssertEqual(events.at(0).erased, nullptr);
    XCTAssertEqual(events.at(0).relayed, nullptr);
}

- (void)test_inserted {
    auto timeline = timeline::make_shared();

    auto track = track::make_shared();

    std::vector<timeline_event> events;
    std::vector<std::pair<track_index_t, track_ptr>> inserted;

    auto canceller = timeline
                         ->observe([&events, &inserted](auto const &event) {
                             events.push_back(event);
                             if (event.type == timeline_event_type::inserted) {
                                 inserted.push_back({*event.index, *event.inserted});
                             }
                         })
                         .end();

    timeline->insert_track(0, track);

    XCTAssertEqual(events.size(), 1);
    XCTAssertEqual(events.at(0).type, timeline_event_type::inserted);
    XCTAssertEqual(inserted.size(), 1);
    XCTAssertEqual(inserted.at(0).first, 0);
    XCTAssertEqual(inserted.at(0).second, track);
}

- (void)test_erased {
    auto timeline = timeline::make_shared();

    auto track = track::make_shared();
    timeline->insert_track(0, track);

    std::vector<timeline_event> events;
    std::vector<std::pair<track_index_t, track_ptr>> erased;

    auto canceller = timeline
                         ->observe([&events, &erased](auto const &event) {
                             events.push_back(event);
                             if (event.type == timeline_event_type::erased) {
                                 erased.push_back({*event.index, *event.erased});
                             }
                         })
                         .end();

    timeline->erase_track(0);

    XCTAssertEqual(events.size(), 1);
    XCTAssertEqual(events.at(0).type, timeline_event_type::erased);
    XCTAssertEqual(erased.size(), 1);
    XCTAssertEqual(erased.at(0).first, 0);
    XCTAssertEqual(erased.at(0).second, track);
}

- (void)test_relayed {
    auto timeline = timeline::make_shared();

    auto track = track::make_shared();
    timeline->insert_track(0, track);

    std::vector<timeline_event> events;
    std::vector<std::tuple<track_index_t, track_event_type>> relayed;

    auto canceller = timeline
                         ->observe([&events, &relayed](timeline_event const &event) {
                             events.push_back(event);
                             if (event.type == timeline_event_type::relayed) {
                                 relayed.push_back({*event.index, event.track_event->type});
                             }
                         })
                         .end();

    auto module = proc::module::make_shared([] { return module::processors_t{}; });
    track->push_back_module(module, {0, 1});

    XCTAssertEqual(events.size(), 1);
    XCTAssertEqual(events.at(0).type, timeline_event_type::relayed);
    XCTAssertEqual(relayed.size(), 1);
    XCTAssertEqual(std::get<0>(relayed.at(0)), 0);
    XCTAssertEqual(std::get<1>(relayed.at(0)), track_event_type::inserted);
}

@end
