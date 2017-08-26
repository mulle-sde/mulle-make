#! /usr/bin/env bash
#
#   Copyright (c) 2017 Nat! - Mulle kybernetiK
#   All rights reserved.
#
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions are met:
#
#   Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
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
#
MULLE_BOOTSTRAP_SOURCE_PLUGIN_SYMLINK_SH="included"


###
### PLUGIN API
###

symlink_clone_project()
{
#   local reposdir="$1"     # ususally .bootstrap.repos
#   local name="$2"         # name of the clone
   local url="$3"           # URL of the clone
   local branch="$4"        # branch of the clone
   local tag="$5"           # tag to checkout of the clone
#   local source="$6"          # source to use for this clone
#   local sourceoptions="$7"   # options to use on source
   local stashdir="$8"      # stashdir of this clone (absolute or relative to $PWD)

   assert_sane_parameters "empty reposdir is ok"

   local absolute

   absolute="`read_config_setting "absolute_symlinks" "NO"`"
   if ! exekutor create_symlink "${url}" "${stashdir}" "${absolute}"
   then
      return 1
   fi

   local branchlabel

   branchlabel="branch"
   if [ -z "${branch}" -a ! -z "${tag}" ]
   then
      branchlabel="tag"
      branch="${tag}"
   fi

   if [ "${branch}" != "master" ]
   then
      log_warning "The intended ${branchlabel} ${C_RESET_BOLD}${branch}${C_WARNING} \
will be ignored, because the repository is symlinked.
If you want to checkout this ${branchlabel} do:
   ${C_RESET_BOLD}(cd ${stashdir}; git checkout ${GITOPTIONS} \"${branch}\" )${C_WARNING}"
   fi
}

