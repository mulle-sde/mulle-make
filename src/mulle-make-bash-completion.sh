#! /usr/bin/env bash
#
#   Copyright (c) 2018 Nat! - Mulle kybernetiK
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
#   POSSIBILITY OF SUCH DAMAGE.
#
[ "${TRACE}" = "YES" ] && set -x && : "$0" "$@"


_mulle_make_complete()
{
   local cur=${COMP_WORDS[COMP_CWORD]}
   local prev=${COMP_WORDS[COMP_CWORD-1]}

   local i
   local context
   local subcontext

   for i in "${COMP_WORDS[@]}"
   do
      case "${context}" in
         definition)
            case "$i" in
               get|keys|list|set)
                  subcontext="$i"
               ;;
            esac
         ;;

         *)
            case "$i" in
               build|definition|install|log)
                  context="$i"
               ;;
            esac
         ;;
      esac
   done

   # handle options with arguments
   case "${prev}" in
      -i|--info-dir)
         COMPREPLY=( $( compgen -d -- "$cur" ) )
         return 0
      ;;
   esac

   # handle options and flags
   case "${cur}" in
      -*)
         case "${subcontext}" in
            set)
               COMPREPLY=( $( compgen -W "-+ --additive" -- $cur ) )
               return 0
            ;;
         esac

         case "${context}" in
            definition)
               COMPREPLY=( $( compgen -W "--info-dir" -- $cur ) )
               return 0
            ;;
         esac
         return 0 # dunno
      ;;
   esac

   # handle other keywords
   case "${context}" in
      definition)
         case "${prev}" in
            get|set)
               keys="`mulle-make definition keys`"
               COMPREPLY=( $( compgen -W "${keys}" -- $cur ) )
            ;;
            return 0
         esac

         COMPREPLY=( $( compgen -W "get keys list set" -- $cur ) )
      ;;

      build|install|log)
         COMPREPLY=( $( compgen -d -- "$cur" ) )
      ;;

      "")
         COMPREPLY=( $( compgen -W "build definition install log" -- $cur ) )
      ;;
   esac

   return 0
}

complete -F _mulle_make_complete mulle-make

