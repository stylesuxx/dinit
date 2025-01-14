#!/bin/sh

rm -f ../mconfig

INST_PATH_OPTS=$(
  echo "# Installation path options.";
  echo "";
  echo "SBINDIR=/sbin";
  echo "MANDIR=/usr/share/man";
  echo "SYSCONTROLSOCKET=/run/dinitctl"
)

test_compiler_arg() {
  "$1" -c "$2" testfile.cc -o testfile.o > /dev/null 2>&1
  if test $? = 0; then
    rm testfile.o
    supported_opts="$supported_opts $2"
    supported_opts=${supported_opts# }
    return 0
  else
    return 1
  fi
}

# test argument is supported by compiler at both compile and link
test_compile_link_arg() {
  "$1" "$2" testfile.cc -o testfile > /dev/null 2>&1
  if test $? = 0; then
    rm testfile
    supported_opts="$supported_opts $2"
    supported_opts=${supported_opts# }
    return 0
  else
    return 1
  fi
}

for compiler in g++ clang++ c++ ""; do
  if test -z "$compiler"; then
    break # none found
  fi
  type $compiler > /dev/null
  if test $? = 0; then
    break # found
  fi
done

if test -z "$compiler"; then
  echo "*** No compiler found ***"
  exit 1
fi

echo "Compiler found          : $compiler"

echo "int main(int argc, char **argv) { return 0; }" > testfile.cc
supported_opts=""
test_compiler_arg "$compiler" -flto
HAS_LTO=$?
test_compiler_arg "$compiler" -fno-rtti
test_compiler_arg "$compiler" -fno-plt
BUILD_OPTS="-D_GLIBCXX_USE_CXX11_ABI=1 -std=c++11 -Os -Wall $supported_opts"

echo "Using build options     : $supported_opts"

supported_opts=""
test_compile_link_arg "$compiler" -fsanitize=address,undefined
SANITIZE_OPTS="$supported_opts"

echo "Sanitize options        : $SANITIZE_OPTS"

rm testfile.cc

GENERAL_BUILD_SETTINGS=$(
  echo ""
  echo ""
  echo "# General build options."
  echo ""
  echo "# Linux (GCC). Note with GCC 5.x/6.x you must use the old ABI, with GCC 7.x you must use"
  echo "# the new ABI. See BUILD.txt file for more information."
  echo "CXX=$compiler"
  echo "CXXOPTS=$BUILD_OPTS"
  echo "LDFLAGS="
  echo "BUILD_SHUTDOWN=yes"
  echo "SANITIZEOPTS=$SANITIZE_OPTS"
  echo ""
  echo "# Notes:"
  echo "#   -D_GLIBCXX_USE_CXX11_ABI=1 : force use of new ABI, see above / BUILD.txt"
  echo "#   -fno-rtti (optional) : Dinit does not require C++ Run-time Type Information"
  echo "#   -fno-plt  (optional) : Recommended optimisation"
  echo "#   -flto     (optional) : Perform link-time optimisation"
  echo "#   -fsanitize=address,undefined :  Apply sanitizers (during unit tests)"
)

#echo "$INST_PATH_OPTS"
#echo "$GENERAL_BUILD_SETTINGS"

(
  echo "$INST_PATH_OPTS"
  echo "$GENERAL_BUILD_SETTINGS" 
) >> ../mconfig
