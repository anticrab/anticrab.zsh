#!/usr/bin/env sh
# Run the whole suite. Non-zero exit means something failed.
#
#   tests/run.sh          everything
#   tests/run.sh -v       with each check named
#   tests/run.sh test_prompt   one module
set -eu
cd "$(dirname "$0")/.."
exec python3 -m unittest discover -s tests "$@"
