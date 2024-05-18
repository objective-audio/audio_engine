//
//  test_utils.cpp
//

#include "test_utils.h"

#include <cpp-utils/file_manager.h>
#include <cpp-utils/system_path_utils.h>

using namespace yas;
using namespace yas::proc;

std::filesystem::path test_utils::test_path() {
    auto directory = system_path_utils::directory_path(system_path_utils::dir::temporary);
    return directory.append("jp.objective-audio.processing_tests");
}

void test_utils::create_test_directory() {
    auto result = file_manager::create_directory_if_not_exists(test_path());
}

void test_utils::remove_contents_in_test_directory() {
    file_manager::remove_contents_in_directory(test_path());
}
