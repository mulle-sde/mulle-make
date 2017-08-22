#! /bin/sh -e

. mulle-bootstrap-repositories.sh


run_test_1()
{
   local name
   local url
   local branch
   local scm
   local stashdir
   local scmoptions
   local tag

   parse_clone "url/name;stashdir;branch;tag;scm;scmoptions"

   [ "${url}"        = "url/name" ]   || fail "wrong name \"${url}\""
   [ "${name}"       = "name" ]       || fail "wrong name \"${name}\""
   [ "${stashdir}"   = "stashdir" ]   || fail "wrong stashdir \"${stashdir}\""
   [ "${branch}"     = "branch" ]     || fail "wrong branch \"${branch}\""
   [ "${tag}"        = "tag" ]        || fail "wrong tag \"${tag}\""
   [ "${scm}"        = "scm" ]        || fail "wrong scm \"${scm}\""
   [ "${scmoptions}" = "scmoptions" ] || fail "wrong scm \"${scmoptions}\""
}

run_test_2()
{
   local name
   local url
   local branch
   local scm
   local tag
   local stashdir

   parse_clone "url/name;whatever;;;;"

   [ "${url}"        = "url/name" ]  || fail "wrong name \"${url}\""
   [ "${name}"       = "name" ]      || fail "wrong name \"${name}\""
   [ "${stashdir}"   = "whatever" ]  || fail "wrong stashdir \"${stashdir}\""
   [ "${branch}"     = "" ]          || fail "wrong branch \"${branch}\""
   [ "${tag}"        = "" ]          || fail "wrong tag \"${tag}\""
   [ "${scm}"        = "" ]          || fail "wrong scm \"${scm}\""
   [ "${scmoptions}" = "" ]          || fail "wrong scmoptions \"${scmoptions}\""
}


run_test_3()
{
   local name
   local url
   local branch
   local scm
   local tag
   local stashdir

   parse_clone "url/name"

   [ "${url}"        = "url/name" ]  || fail "wrong name \"${url}\""
   [ "${name}"       = "name" ]      || fail "wrong name \"${name}\""
   [ "${stashdir}"   = "" ]          || fail "wrong stashdir \"${stashdir}\""
   [ "${branch}"     = "" ]          || fail "wrong branch \"${branch}\""
   [ "${tag}"        = "" ]          || fail "wrong tag \"${tag}\""
   [ "${scm}"        = "" ]          || fail "wrong scm \"${scm}\""
   [ "${scmoptions}" = "" ]          || fail "wrong scmoptions \"${scmoptions}\""
}


ROOT_DIR="`pwd`"

run_test_1
run_test_2
run_test_3

echo "test finished" >&2

