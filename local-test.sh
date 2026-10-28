#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="pki-guide-local"
PORT="${PORT:-4000}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is required but not found in PATH."
  exit 1
fi

echo "Building local docs image: ${IMAGE_NAME}"
docker build -f Dockerfile.local -t "${IMAGE_NAME}" .

echo "Starting local docs server on http://localhost:${PORT}/"
docker run --rm -it \
  -p "${PORT}:4000" \
  -v "$(pwd):/site" \
  -w /site \
  "${IMAGE_NAME}" \
  bash -lc '
    set -euo pipefail
    export PATH="/usr/local/bundle/bin:${PATH}"
    mkdir -p docs/assets/img

    cat > /tmp/_config.local.yml <<EOF
url: "http://localhost:4000"
baseurl: ""
defaults:
  - scope:
      path: ""
      type: "pages"
    values:
      layout: "default"
EOF

    cat > /tmp/puppeteer-config.json <<EOF
{
  "executablePath": "/usr/bin/chromium",
  "args": ["--no-sandbox", "--disable-setuid-sandbox"]
}
EOF

    mmdc -p /tmp/puppeteer-config.json -i docs/diagrams/tls13-server-auth.mmd -o docs/assets/img/tls13-server-auth.svg -b transparent
    mmdc -p /tmp/puppeteer-config.json -i docs/diagrams/mtls-auth.mmd -o docs/assets/img/mtls-auth.svg -b transparent

    exec jekyll serve \
      --config docs/_config.yml,/tmp/_config.local.yml \
      --source docs \
      --destination _site \
      --host 0.0.0.0 \
      --port 4000 \
      --livereload
  '
