#!/bin/sh
# Renders the edge node cloud-init with fictitious values and checks it is valid YAML with a valid compose file.
set -eu
cd "$(dirname "$0")/../tofu/tests/render-userdata"
state="$(mktemp -d)/render.tfstate"
tofu init -backend=false -input=false >/dev/null
tofu apply -auto-approve -input=false -state="$state" >/dev/null
mkdir -p build
tofu output -state="$state" -raw user_data > build/user-data.yaml
python3 - build/user-data.yaml <<'PY'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
assert open(sys.argv[1]).readline().strip() == "#cloud-config", "first line must be #cloud-config"
files = {f["path"]: f["content"] for f in doc["write_files"]}
yaml.safe_load(files["/opt/ops-edge/docker-compose.yml"])
yaml.safe_load(files["/opt/ops-edge/otel/edge-collector.yaml"])
print(f"user data ok: {len(files)} files")
PY
