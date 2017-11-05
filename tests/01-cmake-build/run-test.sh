#! /usr/bin/env bash

[ "${TRACE}" = "YES" ] && set -x


run_mulle_make()
{
   log_fluff "####################################"
   log_fluff ${MULLE_MAKE} ${MULLE_MAKE_FLAGS} "$@"
   log_fluff "####################################"

   exekutor ${MULLE_MAKE} ${MULLE_MAKE_FLAGS} "$@"
}


expect_content()
{
   local output="$1"
   local expect="$2"

   if [ ! -f "${output}" ]
   then
      if [ -z "${expect}" ]
      then
         return
      fi
      fail "Did not produce \"${output}\" as expected"
   else
      if [ -z "${expect}" ]
      then
         fail "Did produce \"${output}\" unexpectedly. Nothing was expected"
      fi
   fi

   if [ -f "${expect}.${UNAME}" ]
   then
      expect="${expect}.${UNAME}"
   fi

   if [ ! -f "${expect}" ]
   then
      internal_fail "\"${expect}\" is missing from test"
   fi

   local diffs

   diffs="`diff "${output}" "${expect}"`"
   if [ $? -ne 0 ]
   then
      log_error "Unexpected output generated"
      cat <<EOF >&2
----------------
Output: ($output)
----------------
`cat "${output}"`
----------------
Expected: ($expect)
----------------
`cat "${expect}"`
----------------
Diff:
----------------
${diff}
----------------
EOF
      exit 1
   fi
}


run_test()
{
   local cmake_expect="$1"; shift
   local make_expect="$1"; shift

   CMAKE_REDIRECT_FILE="${directory}/cmake-args.txt" \
   MAKE_REDIRECT_FILE="${directory}/make-args.txt" \
      run_mulle_make make --build-dir "${directory}/build" \
                          -DCMAKE="${PWD}/../mock-cmake" \
                          -DMAKE="${PWD}/../mock-make" \
                          "$@"

   if [ "$?" -ne 0 ]
   then
      exit 1
   fi

   expect_content "${directory}/cmake-args.txt" "${cmake_expect}"
   expect_content "${directory}/make-args.txt" "${make_expect}"

   remove_file_if_present "${directory}/cmake-args.txt"
   remove_file_if_present "${directory}/make-args.txt"
   rmdir_safer "${directory}/build"
}


main()
{
   MULLE_MAKE_FLAGS="$@"

   _options_mini_main "$@"

   local directory

   directory="`make_tmp_directory`" || exit 1
   directory="${directory:-/tmp/build}"

   #
   # Default is release
   #
   run_test "release_cmake.txt" "make.txt"
   log_verbose "----- #1 PASSED -----"
   run_test "release_cmake.txt" "make.txt" -c Release
   log_verbose "----- #2 PASSED -----"
   run_test "release_cmake.txt" "make.txt" --release
   log_verbose "----- #3 PASSED -----"

   run_test "debug_cmake.txt" "make.txt" -c Debug
   log_verbose "----- #4 PASSED -----"
   run_test "debug_cmake.txt" "make.txt" --debug
   log_verbose "----- #5 PASSED -----"

   run_test "xxx_cmake.txt" "make.txt" -DXXX=yyy
   log_verbose "----- #6 PASSED -----"

   run_test "release_cmake.txt" "make.txt" -DDISPENSE_STYLE=filtered
   log_verbose "----- #7 PASSED -----"

   log_info "----- ALL PASSED -----"

   rmdir_safer "${directory}"
}



init()
{
   MULLE_BASHFUNCTIONS_LIBEXEC_DIR="`mulle-bashfunctions-env library-path`" || exit 1

   . "${MULLE_BASHFUNCTIONS_LIBEXEC_DIR}/mulle-bashfunctions.sh" || exit 1

   MULLE_MAKE="${MULLE_MAKE:-${PWD}/../../mulle-make}"
}



init "$@"
main "$@"

