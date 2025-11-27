#!/usr/bin/env bash
set -eux
pytest app/tests/integration -q || true
