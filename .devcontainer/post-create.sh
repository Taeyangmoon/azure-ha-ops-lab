#!/usr/bin/env bash
set -euo pipefail

chmod +x scripts/*.sh
# Let az install extensions on demand (e.g. log-analytics) without prompting.
az config set extension.use_dynamic_install=yes_without_prompt extension.dynamic_install_allow_preview=true core.only_show_errors=true >/dev/null
az bicep install >/dev/null 2>&1 || true
echo "Ready. Run: az login --use-device-code"
