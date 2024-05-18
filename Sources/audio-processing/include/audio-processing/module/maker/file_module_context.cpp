//
//  file_module_context.cpp
//

#include "file_module_context.h"

#include <audio-processing/module/module.h>
#include <audio-processing/module/module_utils.h>
#include <audio-processing/processor/maker/send_signal_processor.h>

#include <audio-engine/umbrella.hpp>

using namespace yas;
using namespace yas::proc;

template <typename SampleType>
file::context<SampleType>::context(std::filesystem::path const &path, frame_index_t const module_offset,
                                   frame_index_t const file_offset)
    : _path(path), _module_offset(module_offset), _file_offset(file_offset) {
}

template file::context<double>::context(std::filesystem::path const &, frame_index_t const, frame_index_t const);
template file::context<float>::context(std::filesystem::path const &, frame_index_t const, frame_index_t const);
template file::context<int32_t>::context(std::filesystem::path const &, frame_index_t const, frame_index_t const);
template file::context<int16_t>::context(std::filesystem::path const &, frame_index_t const, frame_index_t const);

template <typename SampleType>
void file::context<SampleType>::read_from_file(time::range const &time_range, sync_source const &sync_src,
                                               connector_index_t const co_idx, SampleType *const signal_ptr) const {
    memset(signal_ptr, 0, time_range.length * sizeof(SampleType));

    auto file_result =
        audio::file::make_opened({.file_path = this->_path, .pcm_format = proc::pcm_format<SampleType>()});
    if (file_result.is_error()) {
        return;
    }

    audio::file_ptr const &file = file_result.value();

    audio::format const &file_format = file->file_format();
    if (file_format.channel_count() <= co_idx) {
        return;
    }

    if ((sample_rate_t)(roundl(file_format.sample_rate())) != sync_src.sample_rate) {
        return;
    }

    auto const range_result_opt =
        module_file_range(time_range, this->_module_offset, this->_file_offset, file->file_length());
    if (!range_result_opt.has_value()) {
        return;
    }
    module_file_range_result const &range_result = range_result_opt.value();

    audio::pcm_buffer buffer{file->processing_format(), static_cast<uint32_t>(range_result.range.length)};

    if (range_result.range.frame > 0) {
        file->set_file_frame_position(static_cast<uint32_t>(range_result.range.frame));
    }

    auto read_result = file->read_into_buffer(buffer);
    if (read_result.is_error()) {
        return;
    }

    auto copy_result = buffer.copy_to(&signal_ptr[range_result.offset], 1, 0, co_idx, 0,
                                      static_cast<uint32_t>(range_result.range.length));
};

template void file::context<double>::read_from_file(time::range const &, sync_source const &, connector_index_t const,
                                                    double *const) const;
template void file::context<float>::read_from_file(time::range const &, sync_source const &, connector_index_t const,
                                                   float *const) const;
template void file::context<int32_t>::read_from_file(time::range const &, sync_source const &, connector_index_t const,
                                                     int32_t *const) const;
template void file::context<int16_t>::read_from_file(time::range const &, sync_source const &, connector_index_t const,
                                                     int16_t *const) const;
