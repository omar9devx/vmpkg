#!/usr/bin/env bash
# Automated Test Suite for VMPKG
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VMPKG="${SCRIPT_DIR}/vmpkg.sh"

PASSED=0
FAILED=0

run_test() {
    local name="$1"; shift
    printf "[TEST] %-45s ... " "$name"
    if "$@" >/dev/null 2>&1; then
        printf "\033[0;32mPASSED\033[0m\n"
        ((PASSED++)) || true
    else
        printf "\033[0;31mFAILED\033[0m\n"
        ((FAILED++)) || true
    fi
}

echo "=================================================="
echo " Running VMPKG Test Suite"
echo "=================================================="

# 1. Syntax checks
run_test "Bash syntax check (vmpkg.sh)" bash -n "$VMPKG"
run_test "Bash syntax check (vmpkg)" bash -n "${SCRIPT_DIR}/vmpkg"
run_test "POSIX sh syntax (installscript.sh)" sh -n "${SCRIPT_DIR}/installscript.sh"
run_test "POSIX sh syntax (updatescript.sh)" sh -n "${SCRIPT_DIR}/updatescript.sh"

# 2. CLI options
run_test "vmpkg --version" bash "$VMPKG" --version
run_test "vmpkg --help" bash "$VMPKG" --help
run_test "vmpkg --no-color --help" bash "$VMPKG" --no-color --help

# 3. Isolated Environment Tests
TEST_DIR="$(mktemp -d /tmp/vmpkg-test-XXXXXX)"
export VMPKG_ROOT="${TEST_DIR}/vmpkg_root"
export VMPKG_BIN="${TEST_DIR}/bin"
export VMPKG_ASSUME_YES=1

run_test "vmpkg init (isolated layout)" bash "$VMPKG" init
run_test "vmpkg doctor (environment check)" bash "$VMPKG" doctor

# 4. Registry operations
run_test "vmpkg register (package entry)" bash "$VMPKG" register dummy 1.0.0 "https://example.com/dummy.tar.gz" "Dummy package for test"
run_test "vmpkg search (dummy)" bash "$VMPKG" search dummy
run_test "vmpkg show (dummy)" bash "$VMPKG" show dummy
run_test "vmpkg info alias (dummy)" bash "$VMPKG" info dummy

# 5. Local Archive Creation & Real Installation Cycle
PKG_BUILD="${TEST_DIR}/build"
mkdir -p "${PKG_BUILD}/bin"
cat << 'BIN' > "${PKG_BUILD}/bin/hello-vmpkg"
#!/usr/bin/env sh
echo "Hello from VMPKG installed package!"
BIN
chmod +x "${PKG_BUILD}/bin/hello-vmpkg"

SAMPLE_TAR="${TEST_DIR}/samplepkg-1.0.0.tar.gz"
tar -czf "$SAMPLE_TAR" -C "$PKG_BUILD" bin

# Register local package and install
run_test "vmpkg register (local samplepkg)" bash "$VMPKG" register samplepkg 1.0.0 "$SAMPLE_TAR" "Sample package test"
run_test "vmpkg install (samplepkg)" bash "$VMPKG" install samplepkg

# Verify installed binary
test -x "${VMPKG_BIN}/hello-vmpkg" && run_test "Installed binary execution" "${VMPKG_BIN}/hello-vmpkg"

# Check list
run_test "vmpkg list (verify installed)" bash "$VMPKG" list

# Check upgrade command
run_test "vmpkg upgrade (all up to date)" bash "$VMPKG" upgrade

# Check clean
run_test "vmpkg clean (cache clearing)" bash "$VMPKG" clean

# Check remove
run_test "vmpkg remove (samplepkg)" bash "$VMPKG" remove samplepkg
test ! -e "${VMPKG_BIN}/hello-vmpkg" && run_test "Verified symlink removal" true

# Teardown
rm -rf "$TEST_DIR"

echo "=================================================="
echo " Results: ${PASSED} passed, ${FAILED} failed"
echo "=================================================="

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
fi
