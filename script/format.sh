#!/bin/sh

clang-format -i -style=file `find ../audio ../audio_sample_ios ../audio_sample_mac -type f \( -name *.h -o -name *.cpp -o -name *.hpp -o -name *.m -o -name *.mm \)`
