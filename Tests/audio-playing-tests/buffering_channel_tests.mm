//
//  buffering_channel_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-playing/umbrella.hpp>
#import <thread>
#import "test_utils.h"

using namespace yas;
using namespace yas::playing;

namespace yas::playing::buffering_channel_test {
static sample_rate_t const sample_rate = 2;
static audio::format const format{
    {.sample_rate = sample_rate, .pcm_format = audio::pcm_format::int16, .channel_count = 1, .interleaved = false}};

static path::channel channel_path(sample_rate_t const sample_rate) {
    auto const root_path = test_utils::root_path();
    path::timeline const tl_path{.root_path = root_path, .identifier = "0", .sample_rate = sample_rate};
    return path::channel{.timeline_path = tl_path, .channel_index = 0};
}

static path::channel channel_path() {
    return channel_path(sample_rate);
}

struct element : buffering_element_for_buffering_channel {
    std::function<state_t(void)> state_handler;
    std::function<frame_index_t(void)> begin_frame_handler;
    std::function<fragment_index_t(void)> fragment_index_handler;
    std::function<bool(path::channel const &)> write_if_needed_handler;
    std::function<void(path::channel const &, fragment_index_t const)> force_write_handler;
    std::function<bool(frame_index_t const)> contains_frame_handler;
    std::function<bool(audio::pcm_buffer *, frame_index_t const)> read_into_buffer_handler;
    std::function<void(fragment_index_t const)> advance_handler;
    std::function<void(void)> overwrite_handler;

    state_t state() const {
        return this->state_handler();
    }

    fragment_index_t fragment_index_on_render() const {
        return this->fragment_index_handler();
    }

    bool write_if_needed_on_task(path::channel const &ch_path) {
        return this->write_if_needed_handler(ch_path);
    }

    void force_write_on_task(path::channel const &ch_path, fragment_index_t const frag_idx) {
        this->force_write_handler(ch_path, frag_idx);
    }

    bool contains_frame_on_render(frame_index_t const frame) {
        return this->contains_frame_handler(frame);
    }

    bool read_into_buffer_on_render(audio::pcm_buffer *buffer, frame_index_t const frame) {
        return this->read_into_buffer_handler(buffer, frame);
    }

    void advance_on_render(fragment_index_t const frag_idx) {
        this->advance_handler(frag_idx);
    }

    void overwrite_on_render() {
        this->overwrite_handler();
    }

    static std::shared_ptr<element> make_shared() {
        return std::make_shared<element>();
    }
};

static std::shared_ptr<element> cast_to_test_element(
    std::shared_ptr<buffering_element_for_buffering_channel> const &protocol) {
    return std::dynamic_pointer_cast<element>(protocol);
}

static buffering_element_ptr cast_to_buffering_element(
    std::shared_ptr<buffering_element_for_buffering_channel> const &protocol) {
    return std::dynamic_pointer_cast<buffering_element>(protocol);
}
}  // namespace yas::playing::buffering_channel_test

@interface buffering_channel_tests : XCTestCase

@end

@implementation buffering_channel_tests

- (void)test_initial_elements {
    auto const element0 = buffering_channel_test::element::make_shared();
    auto const element1 = buffering_channel_test::element::make_shared();
    auto const channel = buffering_channel::make_shared({element0, element1});

    auto const &elements = channel->elements_for_test();
    XCTAssertEqual(elements.size(), 2);

    auto const casted_element0 = buffering_channel_test::cast_to_test_element(elements.at(0));
    XCTAssertEqual(casted_element0, element0);
    auto const casted_element1 = buffering_channel_test::cast_to_test_element(elements.at(1));
    XCTAssertEqual(casted_element1, element1);
}

- (void)test_write_all_elements {
    std::vector<std::pair<path::channel, fragment_index_t>> called0;
    auto const element0 = buffering_channel_test::element::make_shared();
    element0->force_write_handler = [&called0](path::channel const &ch_path, fragment_index_t const frag_idx) {
        called0.emplace_back(ch_path, frag_idx);
    };

    std::vector<std::pair<path::channel, fragment_index_t>> called1;
    auto const element1 = buffering_channel_test::element::make_shared();
    element1->force_write_handler = [&called1](path::channel const &ch_path, fragment_index_t const frag_idx) {
        called1.emplace_back(ch_path, frag_idx);
    };

    auto const channel = buffering_channel::make_shared({element0, element1});
    auto const ch_path = buffering_channel_test::channel_path();

    channel->write_all_elements_on_task(ch_path, 0);

    XCTAssertEqual(called0.size(), 1);
    XCTAssertEqual(called0.at(0).first, ch_path);
    XCTAssertEqual(called0.at(0).second, 0);
    XCTAssertEqual(called1.size(), 1);
    XCTAssertEqual(called1.at(0).first, ch_path);
    XCTAssertEqual(called1.at(0).second, 1);
}

- (void)test_write_elements_if_needed {
    std::vector<path::channel> called0;
    bool result0 = false;
    auto const element0 = buffering_channel_test::element::make_shared();
    element0->force_write_handler = [](path::channel const &, fragment_index_t const) {};
    element0->write_if_needed_handler = [&called0, &result0](path::channel const &ch_path) {
        called0.emplace_back(ch_path);
        return result0;
    };

    std::vector<path::channel> called1;
    bool result1 = false;
    auto const element1 = buffering_channel_test::element::make_shared();
    element1->force_write_handler = [](path::channel const &, fragment_index_t const) {};
    element1->write_if_needed_handler = [&called1, &result1](path::channel const &ch_path) {
        called1.emplace_back(ch_path);
        return result1;
    };

    auto const channel = buffering_channel::make_shared({element0, element1});
    auto const ch_path = buffering_channel_test::channel_path();

    channel->write_all_elements_on_task(ch_path, 0);

    XCTAssertFalse(channel->write_elements_if_needed_on_task());

    XCTAssertEqual(called0.size(), 1);
    XCTAssertEqual(called0.at(0), ch_path);
    XCTAssertEqual(called1.size(), 1);
    XCTAssertEqual(called1.at(0), ch_path);

    result0 = true;
    result1 = false;

    XCTAssertTrue(channel->write_elements_if_needed_on_task());

    XCTAssertEqual(called0.size(), 2);
    XCTAssertEqual(called0.at(1), ch_path);
    XCTAssertEqual(called1.size(), 2);
    XCTAssertEqual(called1.at(1), ch_path);

    result0 = false;
    result1 = true;

    XCTAssertTrue(channel->write_elements_if_needed_on_task());

    XCTAssertEqual(called0.size(), 3);
    XCTAssertEqual(called0.at(2), ch_path);
    XCTAssertEqual(called1.size(), 3);
    XCTAssertEqual(called1.at(2), ch_path);

    result0 = true;
    result1 = true;

    XCTAssertTrue(channel->write_elements_if_needed_on_task());

    XCTAssertEqual(called0.size(), 4);
    XCTAssertEqual(called0.at(3), ch_path);
    XCTAssertEqual(called1.size(), 4);
    XCTAssertEqual(called1.at(3), ch_path);
}

- (void)test_advance {
    std::vector<fragment_index_t> called0;
    auto const element0 = buffering_channel_test::element::make_shared();
    element0->fragment_index_handler = [] { return 0; };
    element0->advance_handler = [&called0](fragment_index_t const frag_idx) { called0.emplace_back(frag_idx); };

    std::vector<fragment_index_t> called1;
    auto const element1 = buffering_channel_test::element::make_shared();
    element1->fragment_index_handler = [] { return 1; };
    element1->advance_handler = [&called1](fragment_index_t const frag_idx) { called1.emplace_back(frag_idx); };

    auto const channel = buffering_channel::make_shared({element0, element1});

    channel->advance_on_render(0);

    XCTAssertEqual(called0.size(), 1);
    XCTAssertEqual(called0.at(0), 2);

    XCTAssertEqual(called1.size(), 0);
}

- (void)test_overwrite_element {
    std::size_t called0 = 0;
    auto const element0 = buffering_channel_test::element::make_shared();
    element0->fragment_index_handler = [] { return 0; };
    element0->overwrite_handler = [&called0]() { ++called0; };

    std::size_t called1 = 0;
    auto const element1 = buffering_channel_test::element::make_shared();
    element1->fragment_index_handler = [] { return 1; };
    element1->overwrite_handler = [&called1]() { ++called1; };

    auto const channel = buffering_channel::make_shared({element0, element1});

    channel->overwrite_element_on_render({0, 1});

    XCTAssertEqual(called0, 1);
    XCTAssertEqual(called1, 0);

    channel->overwrite_element_on_render({1, 1});

    XCTAssertEqual(called0, 1);
    XCTAssertEqual(called1, 1);

    channel->overwrite_element_on_render({0, 2});

    XCTAssertEqual(called0, 2);
    XCTAssertEqual(called1, 2);
}

- (void)test_read_into_buffer {
    std::vector<frame_index_t> called_contains0;
    std::vector<frame_index_t> called_read0;
    auto const element0 = buffering_channel_test::element::make_shared();
    element0->contains_frame_handler = [&called_contains0](frame_index_t const frame) {
        called_contains0.emplace_back(frame);
        return false;
    };
    element0->read_into_buffer_handler = [&called_read0](audio::pcm_buffer *buffer, frame_index_t const frame) {
        called_read0.emplace_back(frame);
        return false;
    };

    std::vector<frame_index_t> called_contains1;
    std::vector<frame_index_t> called_read1;
    bool contains1 = false;
    bool is_read1 = false;
    auto const element1 = buffering_channel_test::element::make_shared();
    element1->contains_frame_handler = [&called_contains1, &contains1](frame_index_t const frame) {
        called_contains1.emplace_back(frame);
        return contains1;
    };
    element1->read_into_buffer_handler = [&is_read1, &called_read1](audio::pcm_buffer *buffer,
                                                                    frame_index_t const frame) {
        called_read1.emplace_back(frame);

        if (is_read1) {
            int16_t *data = buffer->data_ptr_at_index<int16_t>(0);
            data[0] = 123;
            data[1] = 456;
            return true;
        } else {
            return false;
        }
    };

    std::vector<frame_index_t> called_contains2;
    std::vector<frame_index_t> called_read2;
    auto const element2 = buffering_channel_test::element::make_shared();
    element2->contains_frame_handler = [&called_contains2](frame_index_t const frame) {
        called_contains2.emplace_back(frame);
        return false;
    };
    element2->read_into_buffer_handler = [&called_read2](audio::pcm_buffer *buffer, frame_index_t const frame) {
        called_read2.emplace_back(frame);
        return false;
    };

    auto const channel = buffering_channel::make_shared({element0, element1, element2});

    audio::pcm_buffer buffer{buffering_channel_test::format, buffering_channel_test::sample_rate};
    int16_t const *const data = buffer.data_ptr_at_index<int16_t>(0);

    XCTAssertFalse(channel->read_into_buffer_on_render(&buffer, 100));

    XCTAssertEqual(called_contains0.size(), 1);
    XCTAssertEqual(called_contains0.at(0), 100);
    XCTAssertEqual(called_read0.size(), 0);
    XCTAssertEqual(called_contains1.size(), 1);
    XCTAssertEqual(called_contains1.at(0), 100);
    XCTAssertEqual(called_read1.size(), 0);
    XCTAssertEqual(called_contains2.size(), 1);
    XCTAssertEqual(called_contains2.at(0), 100);
    XCTAssertEqual(called_read2.size(), 0);

    XCTAssertEqual(data[0], 0);
    XCTAssertEqual(data[1], 0);

    contains1 = true;

    XCTAssertFalse(channel->read_into_buffer_on_render(&buffer, 200));

    XCTAssertEqual(called_contains0.size(), 2);
    XCTAssertEqual(called_contains0.at(1), 200);
    XCTAssertEqual(called_read0.size(), 0);
    XCTAssertEqual(called_contains1.size(), 2);
    XCTAssertEqual(called_contains1.at(1), 200);
    XCTAssertEqual(called_read1.size(), 1);
    XCTAssertEqual(called_read1.at(0), 200);
    XCTAssertEqual(called_contains2.size(), 1);
    XCTAssertEqual(called_read2.size(), 0);

    XCTAssertEqual(data[0], 0);
    XCTAssertEqual(data[1], 0);

    is_read1 = true;

    XCTAssertTrue(channel->read_into_buffer_on_render(&buffer, 300));

    XCTAssertEqual(called_contains0.size(), 3);
    XCTAssertEqual(called_contains0.at(2), 300);
    XCTAssertEqual(called_read0.size(), 0);
    XCTAssertEqual(called_contains1.size(), 3);
    XCTAssertEqual(called_contains1.at(2), 300);
    XCTAssertEqual(called_read1.size(), 2);
    XCTAssertEqual(called_read1.at(1), 300);
    XCTAssertEqual(called_contains2.size(), 1);
    XCTAssertEqual(called_read2.size(), 0);

    XCTAssertEqual(data[0], 123);
    XCTAssertEqual(data[1], 456);
}

- (void)test_make_channel {
    audio::format const format{
        {.sample_rate = 4, .channel_count = 2, .pcm_format = audio::pcm_format::int16, .interleaved = false}};
    auto const channel = playing::make_buffering_channel(3, format, 5);

    auto const &elements = channel->elements_for_test();
    XCTAssertEqual(elements.size(), 3);

    auto const casted_element0 = buffering_channel_test::cast_to_buffering_element(elements.at(0));
    auto const &buffer0 = casted_element0->buffer_for_test();
    XCTAssertEqual(buffer0.frame_length(), 5);
    XCTAssertEqual(buffer0.format(), format);

    auto const casted_element1 = buffering_channel_test::cast_to_buffering_element(elements.at(1));
    auto const &buffer1 = casted_element1->buffer_for_test();
    XCTAssertEqual(buffer1.frame_length(), 5);
    XCTAssertEqual(buffer1.format(), format);

    auto const casted_element2 = buffering_channel_test::cast_to_buffering_element(elements.at(2));
    auto const &buffer2 = casted_element2->buffer_for_test();
    XCTAssertEqual(buffer2.frame_length(), 5);
    XCTAssertEqual(buffer2.format(), format);
}

@end
