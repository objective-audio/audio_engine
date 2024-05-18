//
//  track_observing_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/track/track.h>

using namespace yas;
using namespace yas::proc;

@interface track_observing_tests : XCTestCase

@end

@implementation track_observing_tests

- (void)test_fetched {
    auto track = track::make_shared();

    auto module1 = module::make_shared([] { return module::processors_t{}; });
    auto module2 = module::make_shared([] { return module::processors_t{}; });
    track->push_back_module(module1, {0, 1});
    track->push_back_module(module2, {1, 1});

    std::vector<track_event> events;

    auto canceller = track->observe([&events](auto const &event) { events.push_back(event); }).sync();

    XCTAssertEqual(events.size(), 1);
    XCTAssertEqual(events.at(0).type, track_event_type::any);

    auto const &elements = events.at(0).module_sets;
    XCTAssertEqual(elements.size(), 2);
    auto const &module_set0_1 = elements.at(time::range{0, 1});
    XCTAssertEqual(module_set0_1->size(), 1);
    XCTAssertEqual(module_set0_1->at(0), module1);
    auto const &modules1_1 = elements.at(time::range{1, 1});
    XCTAssertEqual(modules1_1->size(), 1);
    XCTAssertEqual(modules1_1->at(0), module2);

    XCTAssertEqual(events.at(0).range, std::nullopt);
    XCTAssertEqual(events.at(0).inserted, nullptr);
    XCTAssertEqual(events.at(0).erased, nullptr);
}

- (void)test_inserted {
    auto track = track::make_shared();

    std::vector<track_event> events;
    std::vector<std::pair<time::range, module_set_ptr>> inserted;

    auto canceller = track
                         ->observe([&events, &inserted](track_event const &event) {
                             events.push_back(event);
                             inserted.push_back({*event.range, *event.inserted});
                         })
                         .end();

    auto module1 = module::make_shared([] { return module::processors_t{}; });
    auto module2 = module::make_shared([] { return module::processors_t{}; });

    track->push_back_module(module1, {0, 1});

    XCTAssertEqual(events.size(), 1);
    XCTAssertEqual(events.at(0).type, track_event_type::inserted);
    XCTAssertEqual(inserted.size(), 1);
    XCTAssertEqual(inserted.at(0).first, (time::range{0, 1}));
    XCTAssertEqual(inserted.at(0).second->size(), 1);
    XCTAssertEqual(inserted.at(0).second->at(0), module1);

    track->push_back_module(module2, {1, 1});

    XCTAssertEqual(events.size(), 2);
    XCTAssertEqual(events.at(1).type, track_event_type::inserted);
    XCTAssertEqual(inserted.size(), 2);
    XCTAssertEqual(inserted.at(1).first, (time::range{1, 1}));
    XCTAssertEqual(inserted.at(1).second->size(), 1);
    XCTAssertEqual(inserted.at(1).second->at(0), module2);
}

- (void)test_erased {
    auto track = track::make_shared();

    auto module1 = module::make_shared([] { return module::processors_t{}; });
    auto module2 = module::make_shared([] { return module::processors_t{}; });
    track->push_back_module(module1, {0, 1});
    track->push_back_module(module2, {1, 1});

    std::vector<track_event_type> event_types;
    std::vector<std::pair<time::range, module_set_ptr>> erased;

    auto canceller = track
                         ->observe([&event_types, &erased](auto const &event) {
                             event_types.push_back(event.type);

                             if (event.type == track_event_type::erased) {
                                 erased.push_back({*event.range, *event.erased});
                             } else {
                                 XCTFail();
                             }
                         })
                         .end();

    track->erase_module(module1);

    XCTAssertEqual(event_types.size(), 1);
    XCTAssertEqual(event_types.at(0), track_event_type::erased);

    XCTAssertEqual(erased.size(), 1);
    XCTAssertEqual(erased.at(0).first, (time::range{0, 1}));
    XCTAssertEqual(erased.at(0).second->size(), 1);
}

- (void)test_push_back_and_erase_same_range {
    auto track = track::make_shared();

    std::vector<std::tuple<track_event_type, module_set_ptr, module_set_ptr, module_set_ptr, std::optional<time::range>,
                           std::optional<module_set_event_type>>>
        event_types;

    auto canceller = track
                         ->observe([&event_types](auto const &event) {
                             event_types.push_back(
                                 {event.type, (event.inserted ? *event.inserted : nullptr),
                                  (event.erased ? *event.erased : nullptr), (event.relayed ? *event.relayed : nullptr),
                                  (event.range ? *event.range : std::optional<time::range>(std::nullopt)),
                                  (event.module_set_event ? event.module_set_event->type :
                                                            std::optional<module_set_event_type>(std::nullopt))});
                         })
                         .end();

    auto module1 = module::make_shared([] { return module::processors_t{}; });
    auto module2 = module::make_shared([] { return module::processors_t{}; });

    track->push_back_module(module1, {0, 1});

    XCTAssertEqual(event_types.size(), 1);
    XCTAssertEqual(std::get<0>(event_types.at(0)), track_event_type::inserted);
    XCTAssertEqual(std::get<1>(event_types.at(0))->size(), 1);
    XCTAssertEqual(std::get<1>(event_types.at(0))->at(0), module1);
    XCTAssertEqual(std::get<2>(event_types.at(0)), nullptr);
    XCTAssertEqual(std::get<3>(event_types.at(0)), nullptr);
    XCTAssertEqual(std::get<4>(event_types.at(0)), time::range(0, 1));
    XCTAssertEqual(std::get<5>(event_types.at(0)), std::nullopt);

    track->push_back_module(module2, {0, 1});

    XCTAssertEqual(event_types.size(), 2);
    XCTAssertEqual(std::get<0>(event_types.at(1)), track_event_type::relayed);
    XCTAssertEqual(std::get<1>(event_types.at(1)), nullptr);
    XCTAssertEqual(std::get<2>(event_types.at(1)), nullptr);
    XCTAssertEqual(std::get<3>(event_types.at(1))->size(), 2);
    XCTAssertEqual(std::get<3>(event_types.at(1))->at(0), module1);
    XCTAssertEqual(std::get<3>(event_types.at(1))->at(1), module2);
    XCTAssertEqual(std::get<4>(event_types.at(1)), time::range(0, 1));
    XCTAssertEqual(std::get<5>(event_types.at(1)), module_set_event_type::inserted);

    track->erase_module(module1);

    XCTAssertEqual(event_types.size(), 3);
    XCTAssertEqual(std::get<0>(event_types.at(2)), track_event_type::relayed);
    XCTAssertEqual(std::get<1>(event_types.at(2)), nullptr);
    XCTAssertEqual(std::get<2>(event_types.at(2)), nullptr);
    XCTAssertEqual(std::get<3>(event_types.at(2))->size(), 1);
    XCTAssertEqual(std::get<3>(event_types.at(2))->at(0), module2);
    XCTAssertEqual(std::get<4>(event_types.at(2)), time::range(0, 1));
    XCTAssertEqual(std::get<5>(event_types.at(2)), module_set_event_type::erased);

    track->erase_module(module2);

    XCTAssertEqual(event_types.size(), 4);
    XCTAssertEqual(std::get<0>(event_types.at(3)), track_event_type::erased);
    XCTAssertEqual(std::get<1>(event_types.at(3)), nullptr);
    XCTAssertEqual(std::get<2>(event_types.at(3))->size(), 1);
    XCTAssertEqual(std::get<2>(event_types.at(3))->at(0), module2);
    XCTAssertEqual(std::get<3>(event_types.at(3)), nullptr);
    XCTAssertEqual(std::get<4>(event_types.at(3)), time::range(0, 1));
    XCTAssertEqual(std::get<5>(event_types.at(3)), std::nullopt);
}

@end
