#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jq hjson stow

set -Eeuxo pipefail

cd "$(dirname "$0")"

(
	cd figuradocs
	git checkout latest
	git fetch --all
	git pull
	stow src --ignore='^\.luarc\.json$'
)



< figuradocs/src/.luarc.json hjson -c | jq -s '.[0] * .[1]' - ./.luarc-local.json > .luarc.json

git add .luarc.json
git status
