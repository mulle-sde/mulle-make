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
   local directory="$1"; shift
   local xcodebuild_expect="$1"; shift

   #
   # MOCK_TEST_DIR is passed to mock-xcodebuild so it can create
   # paths that look the same
   #
   MOCK_TEST_DIR="${directory}" \
   XCODEBUILD_REDIRECT_FILE="${directory}/xcodebuild-args.txt" \
   XCODEBUILD_REDIRECT_FILE="${directory}/xcodebuild-args.txt" \
      run_mulle_make make --build-dir "${directory}/build" \
                          -DXCODEBUILD="${PWD}/../mock-xcodebuild" \
                          "$@"

   if [ "$?" -ne 0 ]
   then
      exit 1
   fi

   expect_content "${directory}/xcodebuild-args.txt" "${xcodebuild_expect}"

   remove_file_if_present "${directory}/xcodebuild-args.txt"
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
   run_test "${directory}" "release_xcodebuild.txt" -c "Release"
   log_verbose "----- #1 PASSED -----"

   run_test "${directory}" "debug_xcodebuild.txt" -c "Debug"
   log_verbose "----- #2 PASSED -----"

   run_test "${directory}" "prefix_xcodebuild.txt" -c "Release" -p "/tmp"
   log_verbose "----- #3 PASSED -----"

   run_test "${directory}" "sdk_xcodebuild.txt" -c "Release" -s "mulle-sdk"
   log_verbose "----- #4 PASSED -----"

   run_test "${directory}" "user_xcodebuild.txt" -c "Release" -DUSER_INFO="VfL Bochum 1848"
   log_verbose "----- #5 PASSED -----"

   run_test "${directory}" "userplus_xcodebuild.txt" -c "Release" -DUSER_INFO+="VfL Bochum 1848"
   log_verbose "----- #6 PASSED -----"

   run_test "${directory}" "xcconfig_xcodebuild.txt" -c "Release" --xcode-config-file whatever.xcconfig
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

