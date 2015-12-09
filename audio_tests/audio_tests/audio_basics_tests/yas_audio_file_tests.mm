//
//  yas_audio_file_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

namespace yas {
namespace test {
    struct audio_file_test_data {
        Float64 file_sample_rate;
        Float64 processing_sample_rate;
        UInt32 channels;
        UInt32 file_bit_depth;
        UInt32 frame_length;
        UInt32 loop_count;
        audio::pcm_format pcm_format;
        bool interleaved;
        bool standard;
        bool async;

        audio_file_test_data() : _file_name(nullptr), _file_type(nullptr) {
        }

        ~audio_file_test_data() {
            set_file_type(nullptr);
            set_file_name(nullptr);
        }

        void set_file_type(const CFStringRef file_type) {
            yas::set_cf_property(_file_type, file_type);
        }

        CFStringRef file_type() const {
            return yas::get_cf_property(_file_type);
        }

        void set_file_name(const CFStringRef file_name) {
            yas::set_cf_property(_file_name, file_name);
        }

        CFStringRef file_name() const {
            return yas::get_cf_property(_file_name);
        }

        CFDictionaryRef settings() const {
            if (CFStringCompare(file_type(), yas::audio::file_type::wave, kNilOptions) == kCFCompareEqualTo) {
                return yas::audio::wave_file_settings(file_sample_rate, channels, file_bit_depth);
            } else if (CFStringCompare(file_type(), yas::audio::file_type::aiff, kNilOptions) == kCFCompareEqualTo) {
                return yas::audio::aiff_file_settings(file_sample_rate, channels, file_bit_depth);
            }
            return nullptr;
        }

       private:
        CFStringRef _file_type;
        CFStringRef _file_name;
    };
}
}

@interface yas_audio_file_tests : XCTestCase

@end

@implementation yas_audio_file_tests

- (void)setUp {
    [super setUp];

    [self setupDirectory];
}

- (void)tearDown {
    [self removeAllFiles];

    [super tearDown];
}

- (void)testWAVEFile {
#if WAVEFILE_LIGHT_TEST
    Float64 sample_rates[] = {44100.0, 382000.0};
    UInt32 channels[] = {1, 2};
    UInt32 file_bit_depths[] = {16, 24};
    yas::audio::pcm_format pcm_formats[] = {yas::audio::pcm_format::float32, yas::audio::pcm_format::float64};
    bool interleaveds[] = {YES, NO};
#else
    Float64 sample_rates[] = {8000.0, 44100.0, 48000.0, 382000.0};
    UInt32 channels[] = {1, 2, 3, 6};
    UInt32 file_bit_depths[] = {16, 24, 32};
    yas::audio::pcm_format pcm_formats[] = {yas::audio::pcm_format::float32, yas::audio::pcm_format::float64,
                                            yas::audio::pcm_format::int16, yas::audio::pcm_format::fixed824};
    bool interleaveds[] = {YES, NO};
#endif

    yas::test::audio_file_test_data test_data;
    test_data.frame_length = 8;
    test_data.loop_count = 4;
    test_data.set_file_name(CFSTR("test.wav"));
    test_data.set_file_type(yas::audio::file_type::wave);
    test_data.standard = NO;
    test_data.async = NO;

    for (Float64 file_sample_rate : sample_rates) {
        for (Float64 processing_sample_rate : sample_rates) {
            for (UInt32 channel : channels) {
                for (UInt32 file_bit_depth : file_bit_depths) {
                    for (yas::audio::pcm_format pcm_format : pcm_formats) {
                        for (bool interleved : interleaveds) {
                            test_data.file_sample_rate = file_sample_rate;
                            test_data.channels = channel;
                            test_data.file_bit_depth = file_bit_depth;
                            test_data.processing_sample_rate = processing_sample_rate;
                            test_data.pcm_format = pcm_format;
                            test_data.interleaved = interleved;
                            @autoreleasepool {
                                [self _commonAudioFileTest:test_data];
                            }
                        }
                    }
                }
            }
        }
    }

    test_data.standard = YES;
    test_data.file_sample_rate = 48000;
    test_data.channels = 2;
    test_data.file_bit_depth = 32;
    test_data.processing_sample_rate = 44100;
    test_data.pcm_format = yas::audio::pcm_format::float32;
    test_data.interleaved = NO;

    [self _commonAudioFileTest:test_data];
#if !WAVEFILE_LIGHT_TEST
    test_data.async = YES;
    [self _commonAudioFileTest:test_data];
#endif
}

#pragma mark -

- (void)_commonAudioFileTest:(yas::test::audio_file_test_data &)test_data {
    NSString *filePath =
        [[self temporaryTestDirectory] stringByAppendingPathComponent:(__bridge NSString *)test_data.file_name()];
    CFURLRef fileURL = (__bridge CFURLRef)[NSURL fileURLWithPath:filePath];
    const UInt32 frame_length = test_data.frame_length;
    const UInt32 loopCount = test_data.loop_count;
    const Float64 file_sample_rate = test_data.file_sample_rate;
    const Float64 processing_sample_rate = test_data.processing_sample_rate;
    const yas::audio::pcm_format pcm_format = test_data.pcm_format;
    const bool interleaved = test_data.interleaved;
    const bool async = test_data.async;
    CFDictionaryRef settings = test_data.settings();

    auto default_processing_format = yas::audio::format(file_sample_rate, test_data.channels, pcm_format, interleaved);
    auto processing_format = yas::audio::format(processing_sample_rate, test_data.channels, pcm_format, interleaved);

    // write

    @autoreleasepool {
        yas::audio::file audio_file;

        if (test_data.standard) {
            XCTAssertTrue(audio_file.create(fileURL, test_data.file_type(), settings));
        } else {
            XCTAssertTrue(audio_file.create(fileURL, test_data.file_type(), settings, pcm_format, interleaved));
        }

        XCTAssertTrue(audio_file.processing_format() == default_processing_format);

        audio_file.set_processing_format(processing_format);

        yas::audio::pcm_buffer buffer(processing_format, frame_length);

        UInt32 startIndex = 0;

        for (NSInteger i = 0; i < loopCount; i++) {
            [self _writeToBuffer:buffer fileFormat:audio_file.file_format() startIndex:startIndex];

            XCTAssertTrue(audio_file.write_from_buffer(buffer, async));

            startIndex += frame_length;
        }
    }

    // read

    @autoreleasepool {
        yas::audio::file audio_file;

        if (test_data.standard) {
            XCTAssertTrue(audio_file.open(fileURL));
        } else {
            XCTAssertTrue(audio_file.open(fileURL, pcm_format, interleaved));
        }

        SInt64 looped_frame_length = frame_length * loopCount;
        XCTAssertEqualWithAccuracy(audio_file.file_length(),
                                   (SInt64)(looped_frame_length * (file_sample_rate / processing_sample_rate)), 1);

        audio_file.set_processing_format(processing_format);

        XCTAssertEqualWithAccuracy(audio_file.processing_length(),
                                   audio_file.file_length() * (processing_sample_rate / file_sample_rate), 1);

        yas::audio::pcm_buffer buffer(processing_format, frame_length);

        UInt32 startIndex = 0;

        for (NSInteger i = 0; i < loopCount; i++) {
            XCTAssertTrue(audio_file.read_into_buffer(buffer));
            if (test_data.file_sample_rate == test_data.processing_sample_rate) {
                XCTAssert(buffer.frame_length() == frame_length);
                XCTAssert([self _compareData:buffer fileFormat:audio_file.file_format() startIndex:startIndex]);
            }

            startIndex += frame_length;
        }

        audio_file.set_file_frame_position(0);
        XCTAssertEqual(audio_file.file_frame_position(), 0);
    }
}

#pragma mark -

- (void)_writeToBuffer:(yas::audio::pcm_buffer &)buffer
            fileFormat:(const yas::audio::format &)fileFormat
            startIndex:(NSInteger)startIndex {
    const auto &format = buffer.format();
    const UInt32 buffer_count = format.buffer_count();
    const UInt32 stride = format.stride();

    for (UInt32 buf_idx = 0; buf_idx < buffer_count; buf_idx++) {
        auto pointer = buffer.flex_ptr_at_index(buf_idx);
        for (NSInteger frameIndex = 0; frameIndex < buffer.frame_length(); frameIndex++) {
            SInt16 value = frameIndex + startIndex + 1;
            for (NSInteger ch_idx = 0; ch_idx < stride; ch_idx++) {
                switch (format.pcm_format()) {
                    case yas::audio::pcm_format::int16: {
                        pointer.i16[frameIndex * stride + ch_idx] = value;
                    } break;
                    case yas::audio::pcm_format::fixed824: {
                        pointer.i32[frameIndex * stride + ch_idx] = value << 16;
                    } break;
                    case yas::audio::pcm_format::float32: {
                        Float32 float32Value = (Float32)value / INT16_MAX;
                        pointer.f32[frameIndex * stride + ch_idx] = float32Value;
                    } break;
                    case yas::audio::pcm_format::float64: {
                        Float64 float64Value = (Float64)value / INT16_MAX;
                        pointer.f64[frameIndex * stride + ch_idx] = (Float64)float64Value;
                    } break;
                    default:
                        break;
                }
            }
        }
    }
}

- (bool)_compareData:(yas::audio::pcm_buffer &)buffer
          fileFormat:(const yas::audio::format &)fileFormat
          startIndex:(NSInteger)startIndex {
    const auto &format = buffer.format();
    const UInt32 buffer_count = format.buffer_count();
    const UInt32 stride = format.stride();

    for (UInt32 buf_idx = 0; buf_idx < buffer_count; buf_idx++) {
        const auto pointer = buffer.flex_ptr_at_index(buf_idx);
        for (NSInteger frameIndex = 0; frameIndex < buffer.frame_length(); frameIndex++) {
            SInt16 value = frameIndex + startIndex + 1;
            for (NSInteger ch_idx = 0; ch_idx < stride; ch_idx++) {
                SInt16 ptrValue = 0;
                switch (format.pcm_format()) {
                    case yas::audio::pcm_format::int16: {
                        ptrValue = pointer.i16[frameIndex * stride + ch_idx];
                    } break;
                    case yas::audio::pcm_format::fixed824: {
                        ptrValue = pointer.i32[frameIndex * stride + ch_idx] >> 16;
                    } break;
                    case yas::audio::pcm_format::float32: {
                        ptrValue = roundf(pointer.f32[frameIndex * stride + ch_idx] * INT16_MAX);
                    } break;
                    case yas::audio::pcm_format::float64: {
                        ptrValue = round(pointer.f64[frameIndex * stride + ch_idx] * INT16_MAX);
                    } break;
                    default:
                        break;
                }
                if (value != ptrValue) {
                    return NO;
                }
            }
        }
    }
    return YES;
}

#pragma mark -

- (NSString *)temporaryTestDirectory {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"yas_audio_test_files"];
}

- (void)setupDirectory {
    [self removeAllFiles];

    NSString *path = [self temporaryTestDirectory];

    NSFileManager *fileManager = [[NSFileManager alloc] init];

    [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];

    yas_release(fileManager);
}

- (void)removeAllFiles {
    NSString *path = [self temporaryTestDirectory];

    NSFileManager *fileManager = [[NSFileManager alloc] init];

    for (NSString *fileName in [fileManager contentsOfDirectoryAtPath:path error:nil]) {
        NSString *fullPath = [path stringByAppendingPathComponent:fileName];
        [fileManager removeItemAtPath:fullPath error:nil];
    }

    [fileManager removeItemAtPath:path error:nil];

    yas_release(fileManager);
}

@end
