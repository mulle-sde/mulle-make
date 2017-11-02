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




main()
{
   MULLE_MAKE_FLAGS="$@"

   _options_mini_main "$@"

   local directory
   local dstdir
   local builddir

   directory="`make_tmp_directory`" || exit 1
   directory="${directory:-/tmp/build}"

   builddir="${directory}/build"
   dstdir="${directory}/root"

   #
   # Default is release
   #
   if ! run_mulle_make install --build-dir "${builddir}" "." "${dstdir}"
   then
      exit 1
   fi

   [ -x "${dstdir}/usr/local/bin/myexe" ]           || fail "myexe failed"
   [ -f "${dstdir}/usr/local/lib/libmylib.dylib" ]  || fail "libmylib.dylib failed"
   [ -f "${dstdir}/usr/local/include/mylib.h" ]     || fail "mylib.h failed"

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

