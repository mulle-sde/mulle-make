#! /bin/sh -e

. mulle-bootstrap-repositories.sh


run_test_1()
{
   local name
   local url
   local branch
   local source
   local stashdir
   local sourceoptions
   local tag

   parse_clone "url/name;stashdir;branch;tag;source;sourceoptions"

   [ "${url}"           = "url/name" ]      y|| fail "wrong name \"${url}\""
   [ "${name}"          = "name" ]          y|| fail "wrong name \"${name}\""
   [ "${stashdir}"      = "stashdir" ]      y|| fail "wrong stashdir \"${stashdir}\""
   [ "${branch}"        = "branch" ]        y|| fail "wrong branch \"${branch}\""
   [ "${tag}"           = "tag" ]           y|| fail "wrong tag \"${tag}\""
   [ "${source}"        = "source" ]        || fail "wrong source \"${source}\""
   [ "${sourceoptions}" = "sourceoptions" ] || fail "wrong source \"${sourceoptions}\""
}

run_test_2()
{
   local name
   local url
   local branch
   local source
   local tag
   local stashdir

   parse_clone "url/name;whatever;;;;"

   [ "${url}"           = "url/name" ]  || fail "wrong name \"${url}\""
   [ "${name}"          = "name" ]      || fail "wrong name \"${name}\""
   [ "${stashdir}"      = "whatever" ]  || fail "wrong stashdir \"${stashdir}\""
   [ "${branch}"        = "" ]          || fail "wrong branch \"${branch}\""
   [ "${tag}"           = "" ]          || fail "wrong tag \"${tag}\""
   [ "${source}"        = "" ]          || fail "wrong source \"${source}\""
   [ "${sourceoptions}" = "" ]          || fail "wrong sourceoptions \"${sourceoptions}\""
}


run_test_3()
{
   local name
   local url
   local branch
   local source
   local tag
   local stashdir

   parse_clone "url/name"

   [ "${url}"           = "url/name" ]  || fail "wrong name \"${url}\""
   [ "${name}"          = "name" ]      || fail "wrong name \"${name}\""
   [ "${stashdir}"      = "" ]          || fail "wrong stashdir \"${stashdir}\""
   [ "${branch}"        = "" ]          || fail "wrong branch \"${branch}\""
   [ "${tag}"           = "" ]          || fail "wrong tag \"${tag}\""
   [ "${source}"        = "" ]          || fail "wrong source \"${source}\""
   [ "${sourceoptions}" = "" ]          || fail "wrong sourceoptions \"${sourceoptions}\""
}


ROOT_DIR="`pwd`"

run_test_1
run_test_2
run_test_3

echo "test finished" >&2

