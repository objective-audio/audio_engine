//
//  module_set_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/module/module.h>
#import <audio-processing/module_set/module_set.h>

using namespace yas;
using namespace yas::proc;

@interface module_set_tests : XCTestCase

@end

@implementation module_set_tests

- (void)test_make {
    auto const set = module_set::make_shared();

    XCTAssertEqual(set->modules().size(), 0);
    XCTAssertEqual(set->size(), 0);
}

- (void)test_make_with_modules {
    auto const module0 = module::make_shared([] { return module::processors_t{}; });
    auto const module1 = module::make_shared([] { return module::processors_t{}; });

    auto const set = module_set::make_shared({module0, module1});

    XCTAssertEqual(set->modules().size(), 2);
    XCTAssertEqual(set->modules().at(0), module0);
    XCTAssertEqual(set->modules().at(1), module1);

    XCTAssertEqual(set->size(), 2);
    XCTAssertEqual(set->at(0), module0);
    XCTAssertEqual(set->at(1), module1);
}

- (void)test_push_back {
    auto const module0 = module::make_shared([] { return module::processors_t{}; });
    auto const module1 = module::make_shared([] { return module::processors_t{}; });

    auto const set = module_set::make_shared({module0, module1});

    XCTAssertEqual(set->size(), 2);

    auto const module2 = module::make_shared([] { return module::processors_t{}; });

    set->push_back(module2);

    XCTAssertEqual(set->size(), 3);
    XCTAssertEqual(set->at(2), module2);
}

- (void)test_insert {
    auto const module0 = module::make_shared([] { return module::processors_t{}; });
    auto const module1 = module::make_shared([] { return module::processors_t{}; });

    auto const set = module_set::make_shared({module0, module1});

    XCTAssertEqual(set->size(), 2);

    auto const module2 = module::make_shared([] { return module::processors_t{}; });

    set->insert(module2, 1);

    XCTAssertEqual(set->size(), 3);
    XCTAssertEqual(set->at(0), module0);
    XCTAssertEqual(set->at(1), module2);
    XCTAssertEqual(set->at(2), module1);
}

- (void)test_erase {
    auto const module0 = module::make_shared([] { return module::processors_t{}; });
    auto const module1 = module::make_shared([] { return module::processors_t{}; });

    auto const set = module_set::make_shared({module0, module1});

    XCTAssertEqual(set->size(), 2);

    XCTAssertTrue(set->erase(0));

    XCTAssertEqual(set->size(), 1);
    XCTAssertEqual(set->at(0), module1);

    XCTAssertFalse(set->erase(1));

    XCTAssertEqual(set->size(), 1);
}

@end
