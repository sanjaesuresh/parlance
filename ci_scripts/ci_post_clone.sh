#!/bin/sh
set -euo pipefail

cd "$CI_PRIMARY_REPOSITORY_PATH/ParlanceApp"
agvtool new-version -all "$CI_BUILD_NUMBER"
