#!/usr/bin/env bash
# Wrapper around SOPS for managing Terraform secret files.
#
# Usage:
#   scripts/tf-sops.sh edit    <sandbox|prod>    # open $EDITOR on the encrypted file
#   scripts/tf-sops.sh decrypt <sandbox|prod>    # write secrets.<env>.auto.tfvars.json (gitignored)
#   scripts/tf-sops.sh encrypt <sandbox|prod>    # encrypt a plaintext secrets.<env>.json into place
#   scripts/tf-sops.sh clean   <sandbox|prod>    # delete the decrypted auto.tfvars.json
#
# Requires: sops, an AWS profile with kms:Encrypt/Decrypt on the env's KMS key.

set -euo pipefail

INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../infra/aws" && pwd)"

cmd="${1:-}"
env="${2:-}"

if [[ -z "$cmd" || -z "$env" ]]; then
  grep -E '^# ' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

if [[ "$env" != "sandbox" && "$env" != "prod" ]]; then
  echo "error: env must be sandbox or prod (got: $env)" >&2
  exit 1
fi

enc="$INFRA_DIR/secrets.$env.enc.json"
plaintext="$INFRA_DIR/secrets.$env.json"
autovars="$INFRA_DIR/secrets.$env.auto.tfvars.json"

case "$cmd" in
  edit)
    cd "$INFRA_DIR"
    sops "secrets.$env.enc.json"
    ;;
  decrypt)
    sops --decrypt --output "$autovars" "$enc"
    echo "wrote $autovars (gitignored; terraform auto-loads it)"
    ;;
  encrypt)
    if [[ ! -f "$plaintext" ]]; then
      echo "error: $plaintext not found" >&2
      echo "tip: copy infra/aws/secrets.example.json to secrets.$env.json and fill it in" >&2
      exit 1
    fi
    cd "$INFRA_DIR"
    # Copy to the .enc.json name first so SOPS sees a filename that matches the
    # .sops.yaml creation rule. Encrypt in place. If SOPS fails, delete the
    # half-baked output and leave the plaintext untouched so the user doesn't
    # lose their secrets to a transient KMS/network failure.
    cp "secrets.$env.json" "secrets.$env.enc.json"
    if sops --encrypt --in-place --input-type json --output-type json "secrets.$env.enc.json"; then
      rm "secrets.$env.json"
      echo "encrypted → secrets.$env.enc.json (plaintext removed)"
    else
      rm -f "secrets.$env.enc.json"
      echo "encrypt failed; plaintext preserved at secrets.$env.json" >&2
      exit 1
    fi
    ;;
  clean)
    rm -f "$autovars"
    echo "removed $autovars"
    ;;
  *)
    echo "error: unknown command '$cmd' (expected edit|decrypt|encrypt|clean)" >&2
    exit 1
    ;;
esac
