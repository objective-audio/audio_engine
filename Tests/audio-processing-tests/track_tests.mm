//
//  track_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/track/track.h>

using namespace yas;
using namespace yas::proc;

@interface track_tests : XCTestCase

@end

@implementation track_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_make_track {
    auto track = track::make_shared();

    XCTAssertEqual(track->module_sets().size(), 0);
}

- (void)test_push_back_module {
    auto track = track::make_shared();

    auto module1 = module::make_shared([] { return module::processors_t{}; });
    auto module2 = module::make_shared([] { return module::processors_t{}; });

    track->push_back_module(std::move(module1), {0, 1});
    track->push_back_module(std::move(module2), {1, 1});

    XCTAssertEqual(track->module_sets().size(), 2);

    auto const &const_track = track;

    std::size_t idx = 0;
    for (auto const &pair : const_track->module_sets()) {
        auto const &time_range = pair.first;
        auto const &module_vec = pair.second;

        XCTAssertEqual(module_vec->size(), 1);

        if (idx == 0) {
            XCTAssertTrue((time_range == time::range{0, 1}));
        } else if (idx == 1) {
            XCTAssertTrue((time_range == time::range{1, 1}));
        } else {
            XCTFail();
        }

        ++idx;
    }
}

- (void)test_insert_module {
    auto track = track::make_shared();

    auto module1 = module::make_shared([] { return module::processors_t{}; });
    auto module2 = module::make_shared([] { return module::processors_t{}; });
    auto module3 = module::make_shared([] { return module::processors_t{}; });

    track->insert_module(module1, 0, {0, 1});
    track->insert_module(module2, 0, {0, 1});
    track->insert_module(module3, 1, {0, 1});

    XCTAssertEqual(track->module_sets().at({0, 1})->size(), 3);
    XCTAssertEqual(track->module_sets().at({0, 1})->at(0), module2);
    XCTAssertEqual(track->module_sets().at({0, 1})->at(1), module3);
    XCTAssertEqual(track->module_sets().at({0, 1})->at(2), module1);
}

- (void)test_remove_module {
    auto track = track::make_shared();

    auto module1 = module::make_shared([] { return module::processors_t{}; });
    auto module2 = module::make_shared([] { return module::processors_t{}; });

    track->push_back_module(module1, {0, 1});
    track->push_back_module(module2, {1, 1});

    XCTAssertEqual(track->module_sets().size(), 2);

    track->erase_module(module1);

    XCTAssertEqual(track->module_sets().size(), 1);
    XCTAssertEqual(track->module_sets().begin()->second->size(), 1);
    XCTAssertEqual(track->module_sets().begin()->second->at(0), module2);
}

- (void)test_push_back_and_erase_modules_same_range {
    auto track = track::make_shared();

    auto module1 = module::make_shared([] { return module::processors_t{}; });
    auto module2 = module::make_shared([] { return module::processors_t{}; });

    track->push_back_module(module1, {0, 1});

    XCTAssertEqual(track->module_sets().size(), 1);
    XCTAssertEqual(track->module_sets().begin()->first, (time::range{0, 1}));
    XCTAssertEqual(track->module_sets().begin()->second->size(), 1);
    XCTAssertEqual(track->module_sets().begin()->second->at(0), module1);

    track->push_back_module(module2, {0, 1});

    XCTAssertEqual(track->module_sets().size(), 1);
    XCTAssertEqual(track->module_sets().begin()->second->size(), 2);
    XCTAssertEqual(track->module_sets().begin()->second->at(0), module1);
    XCTAssertEqual(track->module_sets().begin()->second->at(1), module2);

    track->erase_module(module1);

    XCTAssertEqual(track->module_sets().size(), 1);
    XCTAssertEqual(track->module_sets().begin()->second->size(), 1);
    XCTAssertEqual(track->module_sets().begin()->second->at(0), module2);

    track->erase_module(module2);

    XCTAssertEqual(track->module_sets().size(), 0);
}

- (void)test_erase_modules_for_range {
    auto track = track::make_shared();

    auto module1 = module::make_shared([] { return module::processors_t{}; });
    auto module1b = module::make_shared([] { return module::processors_t{}; });
    auto module2 = module::make_shared([] { return module::processors_t{}; });

    track->push_back_module(module1, {0, 1});
    track->push_back_module(module1b, {0, 1});
    track->push_back_module(module2, {1, 1});

    XCTAssertEqual(track->module_sets().size(), 2);

    track->erase_modules_for_range({0, 1});

    XCTAssertEqual(track->module_sets().size(), 1);
    XCTAssertEqual(track->module_sets().count({0, 1}), 0);
    XCTAssertEqual(track->module_sets().count({1, 1}), 1);
}

- (void)test_erase_module_with_range {
    auto track = track::make_shared();

    auto module1 = module::make_shared([] { return module::processors_t{}; });
    auto module1b = module::make_shared([] { return module::processors_t{}; });

    track->push_back_module(module1, {0, 1});
    track->push_back_module(module1b, {0, 1});

    XCTAssertEqual(track->module_sets().size(), 1);
    XCTAssertEqual(track->module_sets().at({0, 1})->size(), 2);

    track->erase_module(module1, {0, 1});

    XCTAssertEqual(track->module_sets().size(), 1);
    XCTAssertEqual(track->module_sets().at({0, 1})->size(), 1);
    XCTAssertEqual(track->module_sets().at({0, 1})->at(0), module1b);
}

- (void)test_erase_module_at {
    auto track = track::make_shared();

    auto const module1 = module::make_shared([] { return module::processors_t{}; });
    auto const module2 = module::make_shared([] { return module::processors_t{}; });
    auto const module3 = module::make_shared([] { return module::processors_t{}; });

    track->push_back_module(module1, {0, 1});
    track->push_back_module(module2, {0, 1});
    track->push_back_module(module3, {0, 1});

    XCTAssertEqual(track->module_sets().at({0, 1})->size(), 3);
    XCTAssertEqual(track->module_sets().at({0, 1})->at(0), module1);
    XCTAssertEqual(track->module_sets().at({0, 1})->at(1), module2);
    XCTAssertEqual(track->module_sets().at({0, 1})->at(2), module3);

    track->erase_module_at(1, {0, 1});

    XCTAssertEqual(track->module_sets().at({0, 1})->size(), 2);
    XCTAssertEqual(track->module_sets().at({0, 1})->at(0), module1);
    XCTAssertEqual(track->module_sets().at({0, 1})->at(1), module3);
}

- (void)test_total_range {
    auto track = track::make_shared();

    XCTAssertFalse(track->total_range());

    track->push_back_module(module::make_shared([] { return module::processors_t{}; }), {0, 1});

    XCTAssertEqual(track->total_range(), (time::range{0, 1}));

    track->push_back_module(module::make_shared([] { return module::processors_t{}; }), {1, 1});

    XCTAssertEqual(track->total_range(), (time::range{0, 2}));

    track->push_back_module(module::make_shared([] { return module::processors_t{}; }), {99, 1});

    XCTAssertEqual(track->total_range(), (time::range{0, 100}));

    track->push_back_module(module::make_shared([] { return module::processors_t{}; }), {-10, 1});

    XCTAssertEqual(track->total_range(), (time::range{-10, 110}));
}

- (void)test_copy {
    std::vector<int> called;

    auto index = std::make_shared<int>(0);
    auto module = module::make_shared([index = std::move(index), &called] {
        auto processor = [index = *index, &called](time::range const &, connector_map_t const &,
                                                   connector_map_t const &, stream &) { called.push_back(index); };
        ++(*index);
        return module::processors_t{std::move(processor)};
    });

    auto track = track::make_shared();
    track->push_back_module(std::move(module), {0, 1});

    auto copied_track = track->copy();

    XCTAssertEqual(copied_track->module_sets().size(), 1);
    XCTAssertEqual(copied_track->module_sets().count({0, 1}), 1);

    proc::stream stream{sync_source{1, 1}};

    track->process({0, 1}, stream);

    XCTAssertEqual(called.size(), 1);
    XCTAssertEqual(called.at(0), 0);

    copied_track->process({0, 1}, stream);

    XCTAssertEqual(called.size(), 2);
    XCTAssertEqual(called.at(1), 1);
}

@end
