#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/build/config/r8-host-tools.env"

HOST_TOOL_BOOTSTRAP_AUTHORIZED="${HOST_TOOL_BOOTSTRAP_AUTHORIZED:-NO}"
HOST_PACKAGE_INSTALL_AUTHORIZED="${HOST_PACKAGE_INSTALL_AUTHORIZED:-NO}"
NETWORK_FETCH_AUTHORIZED="${NETWORK_FETCH_AUTHORIZED:-NO}"

if [[ "$HOST_TOOL_BOOTSTRAP_AUTHORIZED" != YES ]]; then
    echo "SABLE_HOST_TOOL_BOOTSTRAP=REFUSED_NOT_AUTHORIZED"
    exit 2
fi

echo "===== SABLE CANONICAL HOST TOOL BOOTSTRAP ====="
echo "HOST_TOOL_BOOTSTRAP_AUTHORIZED=YES"
echo "HOST_PACKAGE_INSTALL_AUTHORIZED=$HOST_PACKAGE_INSTALL_AUTHORIZED"
echo "NETWORK_FETCH_AUTHORIZED=$NETWORK_FETCH_AUTHORIZED"
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "DEVICE_CONTACT_AUTHORIZED=NO"
echo "CANONICAL_ROOT=$SABLE_HOST_TOOLS_ROOT"

mkdir -p "$SABLE_SECURITY_BIN" "$SABLE_MOBSFSCAN_ROOT"

component_installed() {
    local pattern="$1"
    "$SABLE_RUSTUP" component list --installed --toolchain "$SABLE_RUST_TOOLCHAIN"         | grep -Eq "$pattern"
}

install_rust_component_once() {
    local component="$1"
    local pattern="$2"

    if component_installed "$pattern"; then
        echo "SABLE_RUST_COMPONENT_$component=ALREADY_PRESENT"
        return 0
    fi

    [[ "$NETWORK_FETCH_AUTHORIZED" == YES ]] || {
        echo "SABLE_RUST_COMPONENT_$component=FAIL_NETWORK_REQUIRED"
        return 1
    }

    echo "SABLE_RUST_COMPONENT_$component=INSTALLING_CANONICAL"
    "$SABLE_RUSTUP" component add         --toolchain "$SABLE_RUST_TOOLCHAIN"         "$component"

    component_installed "$pattern" || {
        echo "SABLE_RUST_COMPONENT_$component=FAIL_VERIFY"
        return 1
    }

    echo "SABLE_RUST_COMPONENT_$component=PASS"
}

install_rust_component_once llvm-tools-preview '^llvm-tools(-|$)'
install_rust_component_once rust-src '^rust-src($|-)'

# The pinned source checkout is already canonicalized by the centralization
# step. Bootstrap never clones an alternate MobSFScan source tree.
[[ -d "$SABLE_MOBSFSCAN_SOURCE/.git" ]] || {
    echo "SABLE_MOBSFSCAN_BOOTSTRAP=FAIL_SOURCE_MISSING path=$SABLE_MOBSFSCAN_SOURCE"
    exit 3
}
[[ "$(git -C "$SABLE_MOBSFSCAN_SOURCE" rev-parse HEAD)" == "$SABLE_MOBSFSCAN_COMMIT" ]] || {
    echo "SABLE_MOBSFSCAN_BOOTSTRAP=FAIL_SOURCE_COMMIT"
    exit 3
}

SABLE_MOBSFSCAN_VENV="$SABLE_MOBSFSCAN_ROOT/venv"
SABLE_MOBSFSCAN_PYTHON="$SABLE_MOBSFSCAN_VENV/bin/python"
SABLE_MOBSFSCAN_PIP="$SABLE_MOBSFSCAN_VENV/bin/pip"

python_has_ensurepip() {
    "$SABLE_PYTHON" -c 'import ensurepip' >/dev/null 2>&1
}

if [[ ! -x "$SABLE_MOBSFSCAN_PYTHON" ]] || [[ ! -x "$SABLE_MOBSFSCAN_PIP" ]]; then
    if ! python_has_ensurepip; then
        python_venv_pkg="$(
            "$SABLE_PYTHON" - <<'PY'
import sys
print(f"python{sys.version_info.major}.{sys.version_info.minor}-venv")
PY
        )"

        [[ "$HOST_PACKAGE_INSTALL_AUTHORIZED" == YES ]] || {
            echo "SABLE_MOBSFSCAN_BOOTSTRAP=FAIL_PYTHON_VENV_PACKAGE_REQUIRED package=$python_venv_pkg"
            echo "HINT=rerun with HOST_PACKAGE_INSTALL_AUTHORIZED=YES NETWORK_FETCH_AUTHORIZED=YES"
            exit 4
        }
        [[ "$NETWORK_FETCH_AUTHORIZED" == YES ]] || {
            echo "SABLE_MOBSFSCAN_BOOTSTRAP=FAIL_PACKAGE_NETWORK_REQUIRED package=$python_venv_pkg"
            exit 4
        }

        command -v apt-get >/dev/null 2>&1 || {
            echo "SABLE_MOBSFSCAN_BOOTSTRAP=FAIL_APT_GET_MISSING"
            exit 4
        }
        command -v sudo >/dev/null 2>&1 || {
            echo "SABLE_MOBSFSCAN_BOOTSTRAP=FAIL_SUDO_MISSING"
            exit 4
        }

        echo "SABLE_HOST_PACKAGE_INSTALL=$python_venv_pkg"
        sudo apt-get update
        sudo apt-get install -y "$python_venv_pkg"

        python_has_ensurepip || {
            echo "SABLE_MOBSFSCAN_BOOTSTRAP=FAIL_ENSUREPIP_STILL_MISSING"
            exit 4
        }
    fi

    rm -rf --one-file-system -- "$SABLE_MOBSFSCAN_VENV"
    "$SABLE_PYTHON" -m venv "$SABLE_MOBSFSCAN_VENV"
fi

[[ -x "$SABLE_MOBSFSCAN_PYTHON" && -x "$SABLE_MOBSFSCAN_PIP" ]] || {
    echo "SABLE_MOBSFSCAN_BOOTSTRAP=FAIL_VENV"
    exit 5
}

if ! PYTHONPATH="$SABLE_MOBSFSCAN_SOURCE" "$SABLE_MOBSFSCAN_PYTHON" - <<'PY' >/dev/null 2>&1
import mobsfscan
import libsast
import sarif_om
import semgrep
import yaml
import xmltodict
assert mobsfscan.__version__ == "1.0.0"
PY
then
    [[ "$NETWORK_FETCH_AUTHORIZED" == YES ]] || {
        echo "SABLE_MOBSFSCAN_BOOTSTRAP=FAIL_DEPENDENCY_NETWORK_REQUIRED"
        exit 5
    }

    echo "SABLE_MOBSFSCAN_DEPENDENCIES=INSTALLING_CANONICAL"
    "$SABLE_MOBSFSCAN_PIP" install         --disable-pip-version-check         --requirement "$SABLE_MOBSFSCAN_SOURCE/requirements.txt"

    PYTHONPATH="$SABLE_MOBSFSCAN_SOURCE" "$SABLE_MOBSFSCAN_PYTHON" - <<'PY'
import mobsfscan
import libsast
import sarif_om
import semgrep
import yaml
import xmltodict
assert mobsfscan.__version__ == "1.0.0"
PY
fi

cat > "$SABLE_MOBSFSCAN" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export PYTHONPATH="$SABLE_MOBSFSCAN_SOURCE"
exec "$SABLE_MOBSFSCAN_PYTHON" -m mobsfscan "\$@"
EOF
chmod 0755 "$SABLE_MOBSFSCAN"

"$SABLE_MOBSFSCAN" --version 2>&1 | grep -Fq "$SABLE_MOBSFSCAN_VERSION" || {
    echo "SABLE_MOBSFSCAN_BOOTSTRAP=FAIL_VERSION"
    exit 6
}

{
    echo "SABLE_MOBSFSCAN_COMMIT=$SABLE_MOBSFSCAN_COMMIT"
    echo "SABLE_MOBSFSCAN_VERSION=$SABLE_MOBSFSCAN_VERSION"
    echo "PYTHON=$("$SABLE_MOBSFSCAN_PYTHON" --version 2>&1)"
    echo "REQUIREMENTS_SHA256=$(sha256sum "$SABLE_MOBSFSCAN_SOURCE/requirements.txt" | awk '{print $1}')"
    echo "INSTALLED_AT_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    "$SABLE_MOBSFSCAN_PIP" freeze
} > "$SABLE_MOBSFSCAN_ROOT/INSTALLATION_MANIFEST.txt"

sha256sum "$SABLE_MOBSFSCAN_ROOT/INSTALLATION_MANIFEST.txt"     > "$SABLE_MOBSFSCAN_ROOT/INSTALLATION_MANIFEST.txt.sha256"

bash "$ROOT/build/host/verify-r8-host-tools.sh"

echo "SABLE_HOST_TOOL_BOOTSTRAP=PASS"
