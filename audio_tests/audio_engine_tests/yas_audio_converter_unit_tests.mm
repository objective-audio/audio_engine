//
//  yas_audio_converter_unit_tests.mm
//

#include <future>
#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_converter_unit_tests : XCTestCase

@end

@implementation yas_audio_converter_unit_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_set_format_success {
    auto converter_unit = audio::avf_au::make_shared(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);

    auto promise = std::make_shared<std::promise<void>>();
    auto future = promise->get_future();

    auto observer = converter_unit->load_state_chain()
                        .perform([promise](auto const &state) {
                            if (state == audio::avf_au::load_state::loaded) {
                                promise->set_value();
                            }
                        })
                        .sync();

    future.get();

    audio::pcm_format const pcm_formats[] = {audio::pcm_format::float32, audio::pcm_format::float64,
                                             audio::pcm_format::int16, audio::pcm_format::fixed824};
    double const sample_rates[] = {4000, 8000, 16000, 22050, 44100, 48000, 88100, 96000, 192000, 382000};
    bool const interleaves[] = {false, true};

    for (auto const &pcm_format : pcm_formats) {
        for (auto const &sample_rate : sample_rates) {
            for (auto const &interleaved : interleaves) {
                audio::format const format{{.sample_rate = sample_rate,
                                            .channel_count = 2,
                                            .pcm_format = pcm_format,
                                            .interleaved = interleaved}};
                XCTAssertNoThrow(converter_unit->initialize());
                XCTAssertNoThrow(converter_unit->set_output_format(format, 0));
                XCTAssertNoThrow(converter_unit->set_input_format(format, 0));

                std::optional<audio::format> output_format = std::nullopt;
                XCTAssertNoThrow(output_format = converter_unit->output_format(0));
                XCTAssertTrue(format == output_format);

                std::optional<audio::format> input_format = std::nullopt;
                XCTAssertNoThrow(input_format = converter_unit->input_format(0));
                XCTAssertTrue(format == input_format);

                XCTAssertNoThrow(converter_unit->uninitialize());
            }
        }
    }
}

@end
