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

   diffs="`diff -b -B "${output}" "${expect}"`"
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
   local autoreconf_expect="$1"; shift
   local autoconf_expect="$1"; shift
   local configure_expect="$1"; shift
   local make_expect="$1"; shift

   AUTORECONF_REDIRECT_FILE="${directory}/autoreconf-args.txt" \
   AUTOCONF_REDIRECT_FILE="${directory}/autoconf-args.txt" \
   CONFIGURE_REDIRECT_FILE="${directory}/configure-args.txt" \
   MAKE_REDIRECT_FILE="${directory}/make-args.txt" \
      run_mulle_make make --build-dir "${directory}/build" \
                          -DAUTORECONF="${PWD}/../mock-autoreconf" \
                          -DAUTOCONF="${PWD}/../mock-autoconf" \
                          -DMAKE="${PWD}/../mock-make" \
                          "$@"
   if [ "$?" -ne 0 ]
   then
      exit 1
   fi
   expect_content "${directory}/autoreconf-args.txt" "${autoreconf_expect}"
   expect_content "${directory}/autoconf-args.txt" "${autoconf_expect}"
   expect_content "${directory}/configure-args.txt" "${configure_expect}"
   expect_content "${directory}/make-args.txt" "${make_expect}"

   remove_file_if_present "${directory}/autoreconf-args.txt"
   remove_file_if_present "${directory}/autoconf-args.txt"
   remove_file_if_present "${directory}/configure-args.txt"
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
   run_test "autoreconf.txt" "autoconf.txt" "configure.txt" "make.txt" --no-determine-xcode-sdk
   log_verbose "----- #1 PASSED -----"
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

