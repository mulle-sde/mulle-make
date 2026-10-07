#
# This (intentionally empty) file marks this test directory as a self-contained
# mulle-env environment root. It MUST exist for this test to resolve its own
# local .mulle fixtures.
#
# Why: mulle tools resolve their ETC/SHARE dirs via
#      `mulle-env --search-as-is mulle-tool-env <tool>`. That search climbs the
#      directory tree looking for a `.mulle/share/env/environment.sh` and latches
#      onto the first one it finds (AS_IS == NEAREST with fallback to start).
#      Without this marker here, the search walks *past* this test directory and
#      attaches to any enclosing mulle-env project (e.g. when the test tree is
#      checked out inside a larger monorepo that has its own `.mulle`). The tool's
#      ETC/SHARE dirs would then point at that outer project, the test-local
#      fixtures would be ignored, and the test would fail with unexpected output.
#      (Note: the search only ever checks share/env/, never etc/env/.)
#
# Having this file pins the search to this directory so local fixtures are used,
# making the test pass regardless of where the test tree is checked out.
#
