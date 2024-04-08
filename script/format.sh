#!/bin/sh

if [ ! $CI ]; then
  export PATH=$PATH:/opt/homebrew/bin
  clang-format -i -style=file `find ./Sources ./Tests ./Examples -type f \( -name *.h -o -name *.cpp -o -name *.hpp -o -name *.m -o -name *.mm \)`
fi
