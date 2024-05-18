//
//  buffering_element_tests.mm
//

#import <XCTest/XCTest.h>
#import <cpp-utils/file_manager.h>
#import <audio-playing/umbrella.hpp>
#import <audio-processing/umbrella.hpp>
#import <future>
#import <thread>
#import "test_utils.h"

using namespace yas;
using namespace yas::playing;

namespace yas::playing::buffering_element_test {
static audio::pcm_format const pcm_format = audio::pcm_format::float32;
static sample_rate_t const sample_rate = 2;
static audio::format const format{{.sample_rate = buffering_element_test::sample_rate,
                                   .pcm_format = buffering_element_test::pcm_format,
                                   .channel_count = 1}};

static path::channel channel_path(sample_rate_t const sample_rate) {
    auto const root_path = test_utils::root_path();
    path::timeline const tl_path{.root_path = root_path, .identifier = "0", .sample_rate = sample_rate};
    return path::channel{.timeline_path = tl_path, .channel_index = 0};
}

static path::channel channel_path() {
    return channel_path(sample_rate);
}

static buffering_element_ptr make_element() {
    return buffering_element::make_shared(buffering_element_test::format, sample_rate);
}

static bool write_signal_to_file(proc::signal_event_ptr const &write_event, fragment_index_t const frag_idx) {
    auto const frame = frag_idx * buffering_element_test::sample_rate;
    path::fragment const frag_path{.channel_path = buffering_element_test::channel_path(), .fragment_index = frag_idx};
    path::signal_event const signal_path{.fragment_path = frag_path,
                                         .range = proc::time::range{frame, write_event->size()},
                                         .sample_type = write_event->sample_type()};

    if (!file_manager::create_directory_if_not_exists(frag_path.value())) {
        return false;
    }

    if (!signal_file::write(signal_path.value(), *write_event)) {
        return false;
    }

    return true;
}
}  // namespace yas::playing::buffering_element_test

@interface buffering_element_tests : XCTestCase

@end

@implementation buffering_element_tests

- (void)setUp {
    file_manager::remove_content(test_utils::root_path());
}

- (void)tearDown {
    file_manager::remove_content(test_utils::root_path());
}

- (void)test_initial_buffer {
    audio::format const format{
        {.sample_rate = 16, .pcm_format = audio::pcm_format::float64, .channel_count = 1, .interleaved = false}};
    sample_rate_t const length = 8;

    auto const element = buffering_element::make_shared(format, length);

    XCTAssertEqual(element->buffer_for_test().format(), format);
    XCTAssertEqual(element->buffer_for_test().frame_length(), length);
}

- (void)test_state {
    auto const ch_path = buffering_element_test::channel_path();
    auto const element = buffering_element_test::make_element();

    XCTAssertEqual(element->state(), buffering_element::state_t::initial);

    element->force_write_on_task(ch_path, 10);

    XCTAssertEqual(element->state(), buffering_element::state_t::readable);
    XCTAssertEqual(element->fragment_index_on_render(), 10);
    XCTAssertEqual(element->begin_frame_on_render(), 20);

    element->force_write_on_task(ch_path, 10);

    element->advance_on_render(13);

    XCTAssertEqual(element->state(), buffering_element::state_t::writable);
    XCTAssertEqual(element->fragment_index_on_render(), 13);
    XCTAssertThrows(element->begin_frame_on_render());

    auto const load_result = element->write_if_needed_on_task(ch_path);
    XCTAssertTrue(load_result);

    XCTAssertEqual(element->state(), buffering_element::state_t::readable);
    XCTAssertEqual(element->fragment_index_on_render(), 13);
    XCTAssertEqual(element->begin_frame_on_render(), 26);
}

- (void)test_begin_frame {
    auto const ch_path = buffering_element_test::channel_path();
    auto const element = buffering_element_test::make_element();

    element->force_write_on_task(ch_path, 0);

    XCTAssertEqual(element->begin_frame_on_render(), 0);

    element->force_write_on_task(ch_path, 100);

    XCTAssertEqual(element->begin_frame_on_render(), 200);
}

- (void)test_contains_frame {
    auto const ch_path = buffering_element_test::channel_path();
    auto const element = buffering_element_test::make_element();

    XCTAssertFalse(element->contains_frame_on_render(0));
    XCTAssertFalse(element->contains_frame_on_render(200));

    element->force_write_on_task(ch_path, 100);

    XCTAssertFalse(element->contains_frame_on_render(199));
    XCTAssertTrue(element->contains_frame_on_render(200));
    XCTAssertTrue(element->contains_frame_on_render(201));
    XCTAssertFalse(element->contains_frame_on_render(202));

    element->advance_on_render(103);

    auto const load_result = element->write_if_needed_on_task(ch_path);
    XCTAssertTrue(load_result);

    XCTAssertFalse(element->contains_frame_on_render(205));
    XCTAssertTrue(element->contains_frame_on_render(206));
    XCTAssertTrue(element->contains_frame_on_render(207));
    XCTAssertFalse(element->contains_frame_on_render(208));
}

- (void)test_read_into_buffer {
    auto const ch_path = buffering_element_test::channel_path();
    auto const element = buffering_element_test::make_element();
    audio::format const format{{.sample_rate = buffering_element_test::sample_rate, .channel_count = 1}};

    path::fragment const frag_path{.channel_path = ch_path, .fragment_index = 1000};
    auto const create_result = file_manager::create_directory_if_not_exists(frag_path.value());
    XCTAssertTrue(create_result);

    auto const signal_event = proc::signal_event::make_shared<float>(2);
    float *data = signal_event->data<float>();
    data[0] = 1.0f;
    data[1] = 0.5f;

    proc::time::range const range{2000, 2};
    auto const signal_path_value = path::signal_event{frag_path, range, signal_event->sample_type()}.value();

    auto const write_result = signal_file::write(signal_path_value, *signal_event);
    XCTAssertTrue(write_result);

    element->force_write_on_task(ch_path, 1000);

    XCTAssertEqual(element->state(), buffering_element::state_t::readable);

    audio::pcm_buffer buffer{format, 2};
    {
        auto const read_result = element->read_into_buffer_on_render(&buffer, 1999);
        XCTAssertFalse(read_result);
    }
    {
        auto const read_result = element->read_into_buffer_on_render(&buffer, 2000);
        XCTAssertTrue(read_result);

        float const *const data = buffer.data_ptr_at_channel<float>(0);
        XCTAssertEqual(data[0], 1.0f);
        XCTAssertEqual(data[1], 0.5f);
    }
    {
        auto const read_result = element->read_into_buffer_on_render(&buffer, 2001);
        XCTAssertFalse(read_result);
    }

    buffer.clear();
    buffer.set_frame_length(1);

    {
        auto const read_result = element->read_into_buffer_on_render(&buffer, 1999);
        XCTAssertFalse(read_result);
    }
    {
        auto const read_result = element->read_into_buffer_on_render(&buffer, 2000);
        XCTAssertTrue(read_result);

        XCTAssertEqual(buffer.data_ptr_at_channel<float>(0)[0], 1.0f);
    }
    {
        auto const read_result = element->read_into_buffer_on_render(&buffer, 2001);
        XCTAssertTrue(read_result);

        XCTAssertEqual(buffer.data_ptr_at_channel<float>(0)[0], 0.5f);
    }
    {
        auto const read_result = element->read_into_buffer_on_render(&buffer, 2002);
        XCTAssertFalse(read_result);
    }
}

- (void)test_advance {
    auto const ch_path = buffering_element_test::channel_path();
    auto const element = buffering_element_test::make_element();

    element->force_write_on_task(ch_path, 0);

    XCTAssertEqual(element->state(), buffering_element::state_t::readable);

    XCTAssertEqual(element->fragment_index_on_render(), 0);

    element->advance_on_render(3);

    XCTAssertEqual(element->fragment_index_on_render(), 3);

    XCTAssertEqual(element->state(), buffering_element::state_t::writable);
}

- (void)test_overwrite {
    auto const ch_path = buffering_element_test::channel_path();
    auto const element = buffering_element_test::make_element();

    element->force_write_on_task(ch_path, 0);

    XCTAssertEqual(element->state(), buffering_element::state_t::readable);

    element->overwrite_on_render();

    XCTAssertEqual(element->state(), buffering_element::state_t::writable);
}

- (void)test_write_if_needed {
    auto const ch_path = buffering_element_test::channel_path();
    auto const element = buffering_element_test::make_element();

    if (auto const signal = proc::signal_event::make_shared<float>(buffering_element_test::sample_rate)) {
        float *data = signal->data<float>();
        data[0] = 2.0f;
        data[1] = 4.0f;

        XCTAssertTrue(buffering_element_test::write_signal_to_file(signal, 3));
    }

    XCTAssertEqual(element->state(), buffering_element::state_t::initial);

    std::thread{[&ch_path, &element] {
        // initialは書き込みできない
        XCTAssertFalse(element->write_if_needed_on_task(ch_path));

        element->force_write_on_task(ch_path, 0);
    }}.join();

    XCTAssertEqual(element->state(), buffering_element::state_t::readable);

    std::thread{[&ch_path, &element] {
        // readableは書き込みできない
        XCTAssertFalse(element->write_if_needed_on_task(ch_path));
    }}.join();

    std::thread{[&ch_path, &element] { element->advance_on_render(3); }}.join();

    XCTAssertEqual(element->state(), buffering_element::state_t::writable);

    std::thread{[&ch_path, &element] {
        // writableは書き込みできる
        XCTAssertTrue(element->write_if_needed_on_task(ch_path));
    }}.join();

    XCTAssertEqual(element->state(), buffering_element::state_t::readable);

    std::thread{[&element] {
        // バッファに書き込まれたデータを確認
        audio::pcm_buffer buffer{buffering_element_test::format, buffering_element_test::sample_rate};
        XCTAssertTrue(element->read_into_buffer_on_render(&buffer, 3 * buffering_element_test::sample_rate));

        float const *const data = buffer.data_ptr_at_index<float>(0);
        XCTAssertEqual(data[0], 2.0f);
        XCTAssertEqual(data[1], 4.0f);
    }}.join();

    std::thread{[&ch_path, &element] {
        // readableは書き込みできない
        XCTAssertFalse(element->write_if_needed_on_task(ch_path));
    }}.join();
}

- (void)test_write {
    auto const ch_path = buffering_element_test::channel_path();
    auto const element = buffering_element_test::make_element();

    if (auto const signal = proc::signal_event::make_shared<float>(buffering_element_test::sample_rate)) {
        float *data = signal->data<float>();

        data[0] = 8.0f;
        data[1] = 16.0f;

        XCTAssertTrue(buffering_element_test::write_signal_to_file(signal, 0));

        data[0] = 32.0f;
        data[1] = 64.0f;

        XCTAssertTrue(buffering_element_test::write_signal_to_file(signal, 1));

        data[0] = 128.0f;
        data[1] = 256.0f;

        XCTAssertTrue(buffering_element_test::write_signal_to_file(signal, 5));
    }

    audio::pcm_buffer buffer{buffering_element_test::format, buffering_element_test::sample_rate};

    XCTAssertEqual(element->state(), buffering_element::state_t::initial);

    // initialでも書き込める
    element->force_write_on_task(ch_path, 0);

    XCTAssertEqual(element->state(), buffering_element::state_t::readable);

    std::thread{[&element, &buffer] {
        XCTAssertEqual(element->fragment_index_on_render(), 0);

        buffer.clear();

        XCTAssertTrue(element->read_into_buffer_on_render(&buffer, 0 * buffering_element_test::sample_rate));

        float const *const data = buffer.data_ptr_at_index<float>(0);
        XCTAssertEqual(data[0], 8.0f);
        XCTAssertEqual(data[1], 16.0f);
    }}.join();

    std::thread{[&ch_path, &element] {
        // readableで書き込める
        element->force_write_on_task(ch_path, 1);
    }}.join();

    XCTAssertEqual(element->state(), buffering_element::state_t::readable);

    std::thread{[&element, &buffer] {
        XCTAssertEqual(element->fragment_index_on_render(), 1);

        buffer.clear();

        XCTAssertTrue(element->read_into_buffer_on_render(&buffer, 1 * buffering_element_test::sample_rate));

        float const *const data = buffer.data_ptr_at_index<float>(0);
        XCTAssertEqual(data[0], 32.0f);
        XCTAssertEqual(data[1], 64.0f);

        element->advance_on_render(4);

        XCTAssertEqual(element->fragment_index_on_render(), 4);
    }}.join();

    XCTAssertEqual(element->state(), buffering_element::state_t::writable);

    std::thread{[&ch_path, &element] {
        // 現在のfragment_indexに関係なく書き込む
        element->force_write_on_task(ch_path, 5);
    }}.join();

    XCTAssertEqual(element->state(), buffering_element::state_t::readable);

    std::thread{[&element, &buffer] {
        XCTAssertEqual(element->fragment_index_on_render(), 5);

        buffer.clear();

        XCTAssertTrue(element->read_into_buffer_on_render(&buffer, 5 * buffering_element_test::sample_rate));

        float const *const data = buffer.data_ptr_at_index<float>(0);
        XCTAssertEqual(data[0], 128.0f);
        XCTAssertEqual(data[1], 256.0f);
    }}.join();
}

- (void)test_state_to_string {
    XCTAssertEqual(to_string(audio_buffering_element_state::initial), "initial");
    XCTAssertEqual(to_string(audio_buffering_element_state::writable), "writable");
    XCTAssertEqual(to_string(audio_buffering_element_state::readable), "readable");
}

- (void)test_state_ostream {
    auto const values = {audio_buffering_element_state::initial, audio_buffering_element_state::writable,
                         audio_buffering_element_state::readable};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end
