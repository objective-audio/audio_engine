//
//  player_reading_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-playing/umbrella.hpp>
#import "player_test_utils.h"

using namespace yas;
using namespace yas::playing;

@interface player_reading_tests : XCTestCase

@end

@implementation player_reading_tests {
    player_test::cpp _cpp;
}

- (void)tearDown {
    self->_cpp.reset();
}

- (void)test_state_initial {
    audio::pcm_buffer buffer = player_test::cpp::make_out_buffer();

    self->_cpp.setup_initial();

    std::vector<std::tuple<double, audio::pcm_format, uint32_t>> called_set_create;

    auto const &reading = self->_cpp.reading;

    reading->state_handler = [] { return playing::reading_resource_state::initial; };
    reading->set_creating_handler = [&called_set_create](sample_rate_t sample_rate, audio::pcm_format pcm_format,
                                                         uint32_t ch_count) {
        called_set_create.emplace_back(sample_rate, pcm_format, ch_count);
    };

    self->_cpp.rendering_handler(&buffer);

    // initialならreadingのバッファを生成する
    XCTAssertEqual(called_set_create.size(), 1);
    XCTAssertEqual(std::get<0>(called_set_create.at(0)), 4);
    XCTAssertEqual(std::get<1>(called_set_create.at(0)), audio::pcm_format::int16);
    XCTAssertEqual(std::get<2>(called_set_create.at(0)), 2);
}

- (void)test_state_creating {
    audio::pcm_buffer buffer = player_test::cpp::make_out_buffer();

    self->_cpp.setup_initial();

    std::vector<std::tuple<double, audio::pcm_format, uint32_t>> called_set_create;

    auto const &reading = self->_cpp.reading;

    reading->state_handler = [] { return playing::reading_resource_state::creating; };
    reading->set_creating_handler = [&called_set_create](sample_rate_t sample_rate, audio::pcm_format pcm_format,
                                                         uint32_t ch_count) {
        called_set_create.emplace_back(sample_rate, pcm_format, ch_count);
    };

    self->_cpp.rendering_handler(&buffer);

    // creatingならスキップ
    XCTAssertEqual(called_set_create.size(), 0);
}

- (void)test_state_rendering {
    audio::pcm_buffer buffer = player_test::cpp::make_out_buffer();

    self->_cpp.setup_initial();

    std::vector<std::tuple<double, audio::pcm_format, uint32_t>> called_needs_create;
    std::vector<std::tuple<double, audio::pcm_format, uint32_t>> called_set_create;
    bool needs_create = false;
    std::size_t called_setup_state = 0;

    auto const &reading = self->_cpp.reading;
    auto const &buffering = self->_cpp.buffering;

    reading->state_handler = [] { return playing::reading_resource_state::rendering; };
    reading->set_creating_handler = [&called_set_create](sample_rate_t sample_rate, audio::pcm_format pcm_format,
                                                         uint32_t length) {
        called_set_create.emplace_back(sample_rate, pcm_format, length);
    };
    reading->needs_create_handler = [&called_needs_create, &needs_create](
                                        sample_rate_t sample_rate, audio::pcm_format pcm_format, uint32_t length) {
        called_needs_create.emplace_back(sample_rate, pcm_format, length);
        return needs_create;
    };
    buffering->setup_state_handler = [&called_setup_state] {
        ++called_setup_state;
        return playing::audio_buffering_setup_state::creating;
    };

    self->_cpp.rendering_handler(&buffer);

    // renderingならバッファの生成が必要かを確認
    XCTAssertEqual(called_needs_create.size(), 1);

    // バッファの生成が必要でなければset_createが呼ばれない
    XCTAssertEqual(called_set_create.size(), 0);
    XCTAssertEqual(called_setup_state, 1);

    needs_create = true;

    self->_cpp.rendering_handler(&buffer);

    XCTAssertEqual(called_needs_create.size(), 2);

    // バッファの生成が必要ならset_createが呼ばれる
    XCTAssertEqual(called_set_create.size(), 1);
    XCTAssertEqual(called_setup_state, 1);
}

@end
