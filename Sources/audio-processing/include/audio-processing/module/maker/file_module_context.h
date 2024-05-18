//
//  file_module_context.h
//

#pragma once

#include <audio-processing/common/common_types.h>
#include <audio-processing/common/ptr.h>
#include <audio-processing/sync_source/sync_source.h>
#include <audio-processing/time/time.h>

#include <filesystem>

namespace yas::proc::file {
template <typename SampleType>
struct context {
    context(std::filesystem::path const &, frame_index_t const module_offset, frame_index_t const file_offset);

    void read_from_file(time::range const &time_range, sync_source const &sync_src, connector_index_t const co_idx,
                        SampleType *const signal_ptr) const;

   private:
    std::filesystem::path _path;
    frame_index_t const _module_offset;
    frame_index_t const _file_offset;
};
}  // namespace yas::proc::file
