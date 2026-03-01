#!/usr/bin/env bash
# =============================================================================
# generate.sh — Generate random SHA-3 test vectors via OpenSSL
# =============================================================================
# Usage:
#   ./generate.sh <PLAINTEXT_BYTES>
#
# Arguments:
#   PLAINTEXT_BYTES   Number of random input bytes to hash
#
# Output folder: ./out/
#   plaintext.hex   — random input as hex string
#   sha3_224.hex    — SHA3-224 digest
#   sha3_256.hex    — SHA3-256 digest
#   sha3_384.hex    — SHA3-384 digest
#   sha3_512.hex    — SHA3-512 digest
#
# Example:
#   ./generate.sh 64
#   ./generate.sh 1000
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Install OpenSSL if not present
# ---------------------------------------------------------------------------
install_openssl() {
    echo "OpenSSL not found. Attempting installation..." >&2

    if command -v apt-get &>/dev/null; then
        echo "[apt] Installing openssl libssl-dev..." >&2
        sudo apt-get update -qq
        sudo apt-get install -y openssl libssl-dev

    elif command -v yum &>/dev/null; then
        echo "[yum] Installing openssl openssl-devel..." >&2
        sudo yum install -y openssl openssl-devel

    elif command -v dnf &>/dev/null; then
        echo "[dnf] Installing openssl openssl-devel..." >&2
        sudo dnf install -y openssl openssl-devel

    elif command -v pacman &>/dev/null; then
        echo "[pacman] Installing openssl..." >&2
        sudo pacman -Sy --noconfirm openssl

    elif command -v brew &>/dev/null; then
        echo "[brew] Installing openssl..." >&2
        brew install openssl

    else
        echo "Error: No supported package manager found." >&2
        echo "Please install OpenSSL manually: https://www.openssl.org" >&2
        exit 1
    fi

    if ! command -v openssl &>/dev/null; then
        echo "Error: OpenSSL installation failed." >&2
        exit 1
    fi

    echo "OpenSSL $(openssl version) installed successfully." >&2
}

# ---------------------------------------------------------------------------
# Dependency check and auto-install
# ---------------------------------------------------------------------------
if ! command -v openssl &>/dev/null; then
    install_openssl
else
    echo "OpenSSL $(openssl version) found." >&2
fi

if ! command -v python3 &>/dev/null; then
    echo "Error: 'python3' not found. Please install Python 3." >&2
    exit 1
fi

if ! openssl dgst -sha3-256 /dev/null &>/dev/null; then
    echo "Error: Installed OpenSSL does not support SHA-3 (requires >= 1.1.1)." >&2
    echo "Please upgrade: https://www.openssl.org" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <PLAINTEXT_BYTES>" >&2
    echo "  PLAINTEXT_BYTES : positive integer (bytes of random input)" >&2
    exit 1
fi

PLAINTEXT_BYTES="$1"

if ! [[ "$PLAINTEXT_BYTES" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: PLAINTEXT_BYTES must be a positive integer, got: '$PLAINTEXT_BYTES'" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Fixed output directory
# ---------------------------------------------------------------------------
OUTPUT_DIR="./out"
mkdir -p "$OUTPUT_DIR"

# ---------------------------------------------------------------------------
# Generate random plaintext into a temp file
# ---------------------------------------------------------------------------
TMPFILE=$(mktemp /tmp/sha3_plain_XXXXXX)
trap 'rm -f "$TMPFILE"' EXIT

echo "Generating ${PLAINTEXT_BYTES} random bytes..." >&2
openssl rand "$PLAINTEXT_BYTES" > "$TMPFILE"

# ---------------------------------------------------------------------------
# Write plaintext.hex
# ---------------------------------------------------------------------------
python3 -c "
import sys
with open(sys.argv[1], 'rb') as f:
    print(f.read().hex())
" "$TMPFILE" > "${OUTPUT_DIR}/plaintext.hex"

# ---------------------------------------------------------------------------
# Compute and write each SHA-3 digest to its own file
# ---------------------------------------------------------------------------
echo "Computing SHA-3 digests..." >&2

sha3_to_file() {
    local variant="$1"
    local outfile="$2"
    openssl dgst "-${variant}" "$TMPFILE" | awk '{print $NF}' > "${OUTPUT_DIR}/${outfile}"
}

sha3_to_file sha3-224  sha3_224.hex
sha3_to_file sha3-256  sha3_256.hex
sha3_to_file sha3-384  sha3_384.hex
sha3_to_file sha3-512  sha3_512.hex

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "" >&2
echo "=== Output: ${OUTPUT_DIR}/ ===" >&2
printf "  %-20s %s\n"  "plaintext.hex:"   "${PLAINTEXT_BYTES} bytes encoded" >&2
printf "  %-20s %s\n"  "sha3_224.hex:"    "$(cat "${OUTPUT_DIR}/sha3_224.hex")" >&2
printf "  %-20s %s\n"  "sha3_256.hex:"    "$(cat "${OUTPUT_DIR}/sha3_256.hex")" >&2
printf "  %-20s %s\n"  "sha3_384.hex:"    "$(cat "${OUTPUT_DIR}/sha3_384.hex")" >&2
printf "  %-20s %s\n"  "sha3_512.hex:"    "$(cat "${OUTPUT_DIR}/sha3_512.hex")" >&2
echo "" >&2
echo "Done." >&2