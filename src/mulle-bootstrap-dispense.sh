#! /usr/bin/env bash
#
#   Copyright (c) 2015 Nat! - Mulle kybernetiK
#   All rights reserved.
#
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions are met:
#
#   Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#   Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
#   Neither the name of Mulle kybernetiK nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#   AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#   IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#   ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
#   LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#   INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#   POSSIBILITY OF SUCH DAMAGE.
#
MULLE_BOOTSTRAP_DISPENSE_SH="included"


#
# move stuff produced my cmake and configure to places
# where we expect them. Expect  others to build to
# <prefix>/include  and <prefix>/lib or <prefix>/Frameworks
#
dispense_files()
{
   local src="$1"
   local name="$2"
   local ftype="$3"
   local depend_subdir="$4"
   local dirpath="$5"

   local dst

   log_fluff "Consider copying ${ftype} from \"${src}\""


   if [ -d "${src}" ]
   then
      if dir_has_files "${src}"
      then

         dst="`add_component "${REFERENCE_DEPENDENCIES_DIR}${depend_subdir}" "${dirpath}"`"
         mkdir_if_missing "${dst}"

         # this fails with more nested header set ups, need to fix!

         log_fluff "Copying ${ftype} from \"${src}\" to \"${dst}\""
         exekutor cp -Ra ${COPYMOVEFLAGS} "${src}"/* "${dst}" >&2 || exit 1

         rmdir_safer "${src}"
      else
         log_fluff "But there are none"
      fi
   else
      log_fluff "But it doesn't exist"
   fi
}


dispense_headers()
{
   local sources="$1"
   local name="$2"
   local depend_subdir="$3"

   local headerpath

   headerpath="`read_build_setting "${name}" "dispense_headers_path" "${HEADER_DIR_NAME}"`"

   local src
   IFS="
"
   for src in $sources
   do
      IFS="${DEFAULT_IFS}"

      dispense_files "${src}" "${name}" "headers" "${depend_subdir}" "${headerpath}"
   done
   IFS="${DEFAULT_IFS}"
}


dispense_resources()
{
   local sources="$1"
   local name="$2"
   local depend_subdir="$3"

   local resourcepath

   resourcepath="`read_build_setting "${name}" "dispense_resources_path" "${RESOURCE_DIR_NAME}"`"

   local src
   IFS="
"
   for src in $sources
   do
      IFS="${DEFAULT_IFS}"

      dispense_files "${src}" "${name}" "resources" "${depend_subdir}" "${resourcepath}"
   done
   IFS="${DEFAULT_IFS}"
}


dispense_libexec()
{
   local sources="$1"
   local name="$2"
   local depend_subdir="$3"

   local libexecpath

   libexecpath="`read_build_setting "${name}" "dispense_resources_path" "/${LIBEXEC_DIR_NAME}"`"

   local src
   IFS="
"
   for src in $sources
   do
      IFS="${DEFAULT_IFS}"

      dispense_files "${src}" "${name}" "libexec" "${depend_subdir}" "${libexecpath}"
   done
   IFS="${DEFAULT_IFS}"
}


_dispense_binaries()
{
   local src="$1"
   local name="$2"
   local findtype="$3"
   local depend_subdir="$4"
   local subpath="$5"

   local dst
   local findtype2
   local copyflag

   findtype2="l"
   copyflag="-f"
   if [ "${findtype}" = "-d"  ]
   then
      copyflag="-n"
   fi
   log_fluff "Consider copying binaries from \"${src}\" for type \"${findtype}/${findtype2}\""

   if [ -d "${src}" ]
   then
      if dir_has_files "${src}"
      then
         dst="${REFERENCE_DEPENDENCIES_DIR}${depend_subdir}${subpath}"

         log_fluff "Moving binaries from \"${src}\" to \"${dst}\""
         mkdir_if_missing "${dst}"
         exekutor find "${src}" -xdev -mindepth 1 -maxdepth 1 \( -type "${findtype}" -o -type "${findtype2}" \) -print0 | \
            exekutor xargs -0 -I % mulle-bootstrap-mv-force.sh ${COPYMOVEFLAGS} "${copyflag}" % "${dst}" >&2
         [ $? -eq 0 ]  || exit 1
      else
         log_fluff "But there are none"
      fi
      rmdir_safer "${src}"
   else
      log_fluff "But it doesn't exist"
   fi
}


dispense_binaries()
{
   local sources="$1" ; shift

   local src
   IFS="
"
   for src in $sources
   do
      IFS="${DEFAULT_IFS}"

      _dispense_binaries "${src}" "$@"
   done
   IFS="${DEFAULT_IFS}"
}


collect_and_dispense_product()
{
   log_debug "_collect_and_dispense_product" "$@"

   local name="$1"
   local build_subdir="$2"
   local depend_subdir="$3"
   local wasxcode="$4"

   if read_yes_no_config_setting "skip_collect_and_dispense" "NO"
   then
      log_info "Skipped collection and dispensal on request"
      return 0
   fi

   log_verbose "Collecting and dispensing \"${name}\" products"

   if [ "${MULLE_FLAG_LOG_DEBUG}" = "YES"  ]
   then
      log_debug "Contents of BUILD_DEPENDENCIES_DIR:"

      ls -lRa ${BUILD_DEPENDENCIES_DIR} >&2
   fi

   [ -z "${LIBRARY_DIR_NAME}" ]     && internal_fail "LIBRARY_DIR_NAME undefined"
   [ -z "${LIBEXEC_DIR_NAME}" ]     && internal_fail "LIBEXEC_DIR_NAME undefined"
   [ -z "${BIN_DIR_NAME}" ]         && internal_fail "BIN_DIR_NAME undefined"
   [ -z "${FRAMEWORK_DIR_NAME}" ]   && internal_fail "FRAMEWORK_DIR_NAME undefined"
   [ -z "${RESOURCE_DIR_NAME}" ]    && internal_fail "LIBRARY_DIR_NAME undefined"
   [ -z "${HEADER_DIR_NAME}" ]      && internal_fail "LIBRARY_DIR_NAME undefined"

   #
   # ensure basic structure is there to squelch linker warnings
   #
   log_fluff "Create default lib/, include/, Frameworks/ in ${REFERENCE_DEPENDENCIES_DIR}${depend_subdir}"

   mkdir_if_missing "${REFERENCE_DEPENDENCIES_DIR}${depend_subdir}/${FRAMEWORK_DIR_NAME}"
   mkdir_if_missing "${REFERENCE_DEPENDENCIES_DIR}${depend_subdir}/${LIBRARY_DIR_NAME}"
   mkdir_if_missing "${REFERENCE_DEPENDENCIES_DIR}${depend_subdir}/${HEADER_DIR_NAME}"

   #
   # probably should use install_name_tool to hack all dylib paths that contain .ref
   # (will this work with signing stuff ?)
   #
   if true
   then
      local sources
      ##
      ## copy lib
      ## TODO: isn't cmake's output directory also platform specific ?
      ##
      sources="${BUILD_DEPENDENCIES_DIR}${build_subdir}/lib
${BUILD_DEPENDENCIES_DIR}/usr/local/lib
${BUILD_DEPENDENCIES_DIR}/usr/lib
${BUILD_DEPENDENCIES_DIR}/lib"

      dispense_binaries "${sources}" "${name}" "f" "${depend_subdir}" "/${LIBRARY_DIR_NAME}"

      ##
      ## copy libexec
      ##
      sources="${BUILD_DEPENDENCIES_DIR}${build_subdir}/libexec
${BUILD_DEPENDENCIES_DIR}/usr/local/libexec
${BUILD_DEPENDENCIES_DIR}/usr/libexec
${BUILD_DEPENDENCIES_DIR}/libexec"

      dispense_libexec "${sources}" "${name}" "${depend_subdir}"


      ##
      ## copy resources
      ##
      sources="${BUILD_DEPENDENCIES_DIR}${build_subdir}/share
${BUILD_DEPENDENCIES_DIR}/usr/local/share
${BUILD_DEPENDENCIES_DIR}/usr/share
${BUILD_DEPENDENCIES_DIR}/share"

      dispense_resources "${sources}" "${name}" "${depend_subdir}"

      ##
      ## copy headers
      ##
      sources="${BUILD_DEPENDENCIES_DIR}${build_subdir}/include
${BUILD_DEPENDENCIES_DIR}/usr/local/include
${BUILD_DEPENDENCIES_DIR}/usr/include
${BUILD_DEPENDENCIES_DIR}/include"

      dispense_headers  "${sources}" "${name}" "${depend_subdir}"


      ##
      ## copy bin and sbin
      ##
      sources="${BUILD_DEPENDENCIES_DIR}${build_subdir}/bin
${BUILD_DEPENDENCIES_DIR}/usr/local/bin
${BUILD_DEPENDENCIES_DIR}/usr/bin
${BUILD_DEPENDENCIES_DIR}/bin
${BUILD_DEPENDENCIES_DIR}${build_subdir}/sbin
${BUILD_DEPENDENCIES_DIR}/usr/local/sbin
${BUILD_DEPENDENCIES_DIR}/usr/sbin
${BUILD_DEPENDENCIES_DIR}/sbin"

      dispense_binaries "${sources}" "${name}" "f" "${depend_subdir}" "/${BIN_DIR_NAME}"

      ##
      ## copy frameworks
      ##
      sources="${BUILD_DEPENDENCIES_DIR}${build_subdir}/Library/Frameworks
${BUILD_DEPENDENCIES_DIR}${build_subdir}/Frameworks
${BUILD_DEPENDENCIES_DIR}/Library/Frameworks
${BUILD_DEPENDENCIES_DIR}/Frameworks"

      dispense_binaries "${sources}" "${name}" "d" "${depend_subdir}" "/${FRAMEWORK_DIR_NAME}"
   fi

   local dst
   local src

   #
   # Delete empty dirs if so
   #
   src="${BUILD_DEPENDENCIES_DIR}/usr/local"
   dir_has_files "${src}"
   if [ $? -ne 0 ]
   then
      rmdir_safer "${src}"
   fi

   src="${BUILD_DEPENDENCIES_DIR}/usr"
   dir_has_files "${src}"
   if [ $? -ne 0 ]
   then
      rmdir_safer "${src}"
   fi

   #
   # probably should hack all executables with install_name_tool that contain .ref
   #
   # now copy over the rest of the output
   if read_yes_no_build_setting "${name}" "dispense_other_product" "NO"
   then
      local usrlocal

      usrlocal="`read_build_setting "${name}" "dispense_other_path" "/usr/local"`"

      log_fluff "Considering copying ${BUILD_DEPENDENCIES_DIR}/*"

      src="${BUILD_DEPENDENCIES_DIR}"
      if [ "${wasxcode}" = "YES" ]
      then
         src="${src}${build_subdir}"
      fi

      if dir_has_files "${src}"
      then
         dst="${REFERENCE_DEPENDENCIES_DIR}${usrlocal}"

         log_fluff "Copying everything from \"${src}\" to \"${dst}\""
         exekutor find "${src}" -xdev -mindepth 1 -maxdepth 1 -print0 | \
               exekutor xargs -0 -I % mv ${COPYMOVEFLAGS} -f % "${dst}" >&2
         [ $? -eq 0 ]  || fail "moving files from ${src} to ${dst} failed"
      fi

      if [ "$MULLE_FLAG_LOG_VERBOSE" = "YES"  ]
      then
         if dir_has_files "${BUILD_DEPENDENCIES_DIR}"
         then
            log_fluff "Directory \"${dst}\" contained files after collect and dispense"
            log_fluff "--------------------"
            ( cd "${BUILD_DEPENDENCIES_DIR}" ; ls -lR >&2 )
            log_fluff "--------------------"
         fi
      fi
   fi

   rmdir_safer "${BUILD_DEPENDENCIES_DIR}"

   log_fluff "Done collecting and dispensing product"
   log_fluff
}


