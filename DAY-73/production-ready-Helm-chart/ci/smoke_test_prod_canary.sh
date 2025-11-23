#!/usr/bin/env bash
set -eux
URL="http://python-app.prod.svc.cluster.local/health"
curl -fsS $URL | grep -q "ok"