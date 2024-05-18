//
//  track_utils_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/module/module.h>
#import <audio-processing/track/track_types.h>
#import <audio-processing/track/track_utils.h>

using namespace yas;
using namespace yas::proc;

@interface track_utils_tests : XCTestCase

@end

@implementation track_utils_tests

- (void)test_to_track_event_type {
    XCTAssertEqual(to_track_event_type(observing::map::event_type::any), track_event_type::any);
    XCTAssertEqual(to_track_event_type(observing::map::event_type::inserted), track_event_type::inserted);
    XCTAssertEqual(to_track_event_type(observing::map::event_type::replaced), track_event_type::replaced);
    XCTAssertEqual(to_track_event_type(observing::map::event_type::erased), track_event_type::erased);
}

- (void)test_copy_modules {
    enum called_type {
        one,
        two,
        three,
        four,
    };

    std::vector<called_type> called;

    auto const module1 = module::make_shared([&called] {
        called.emplace_back(called_type::one);
        return module::processors_t{};
    });
    auto const module2 = module::make_shared([&called] {
        called.emplace_back(called_type::two);
        return module::processors_t{};
    });
    auto const module3 = module::make_shared([&called] {
        called.emplace_back(called_type::three);
        return module::processors_t{};
    });
    auto const module4 = module::make_shared([&called] {
        called.emplace_back(called_type::four);
        return module::processors_t{};
    });

    track_module_set_map_t src_modules;
    src_modules.emplace(time::range{0, 1}, module_set::make_shared({module1, module2}));
    src_modules.emplace(time::range{1, 1}, module_set::make_shared({module3, module4}));

    XCTAssertEqual(called.size(), 4);
    XCTAssertEqual(called.at(0), called_type::one);
    XCTAssertEqual(called.at(1), called_type::two);
    XCTAssertEqual(called.at(2), called_type::three);
    XCTAssertEqual(called.at(3), called_type::four);

    auto const dst_modules = copy_module_sets(src_modules);

    XCTAssertEqual(called.size(), 8);
    XCTAssertEqual(called.at(4), called_type::one);
    XCTAssertEqual(called.at(5), called_type::two);
    XCTAssertEqual(called.at(6), called_type::three);
    XCTAssertEqual(called.at(7), called_type::four);

    XCTAssertEqual(dst_modules.size(), 2);
    XCTAssertEqual(dst_modules.count(time::range{0, 1}), 1);
    XCTAssertEqual(dst_modules.at(time::range{0, 1})->size(), 2);
    XCTAssertEqual(dst_modules.count(time::range{1, 1}), 1);
    XCTAssertEqual(dst_modules.at(time::range{1, 1})->size(), 2);
}

@end
