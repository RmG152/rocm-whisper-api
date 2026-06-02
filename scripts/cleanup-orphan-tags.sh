#!/usr/bin/env bash
#########################################################
# cleanup-orphan-tags.sh
#
# Deletes tags from the rmg152/rocm-whisper-api Docker
# Hub repository that no longer correspond to any modern
# rocm/pytorch upstream tag.
#
# Usage (typically called from CI):
#   list_file="upstream.jsonl" ./scripts/cleanup-orphan-tags.sh
#
# Env vars:
#   list_file   File with one JSON object per line (output of
#               list-rocm-tags.sh). Used to build the "keep" set.
#   namespace   Docker Hub namespace/repo (default rmg152/rocm-whisper-api)
#   DOCKERHUB_USERNAME / DOCKERHUB_TOKEN  (required for DELETE)
#   DRY_RUN     "1" → only print, do not delete (default "1")
#########################################################

set -euo pipefail

NAMESPACE="${namespace:-rmg152/rocm-whisper-api}"
LIST_FILE="${list_file:-${1:-}}"
DRY_RUN="${DRY_RUN:-1}"

if [[ -z "$LIST_FILE" || ! -f "$LIST_FILE" ]]; then
    echo "ERROR: list_file '$LIST_FILE' not found" >&2
    exit 2
fi
if [[ -z "${DOCKERHUB_USERNAME:-}" || -z "${DOCKERHUB_TOKEN:-}" ]]; then
    echo "ERROR: DOCKERHUB_USERNAME and DOCKERHUB_TOKEN must be set" >&2
    exit 2
fi

# Build the keep-set from the upstream list.
declare -A KEEP=()
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    sane=$(printf '%s' "$line" | jq -r '.sane')
    minor=$(printf '%s' "$line" | jq -r '.minor_alias')
    major=$(printf '%s' "$line" | jq -r '.major_alias')
    is_latest=$(printf '%s' "$line" | jq -r '.is_latest')
    KEEP["$sane"]=1
    KEEP["$minor"]=1
    KEEP["$major"]=1
    if [[ "$is_latest" == "true" ]]; then
        KEEP["latest"]=1
    fi
done < "$LIST_FILE"

echo "Keep set has ${#KEEP[@]} tag(s): $(printf '%s ' "${!KEEP[@]}" | wc -w) entries"

# Fetch every tag currently in the repo (paginated, ~100/page).
API="https://hub.docker.com/v2/repositories/${NAMESPACE}/tags"
page=1
existing=()
while :; do
    body=$(curl --silent --show-error --fail --max-time 60 \
        -H "Authorization: Bearer ${DOCKERHUB_TOKEN}" \
        "${API}?page=${page}&page_size=100")
    while IFS=$'\t' read -r name; do
        [[ -n "$name" ]] && existing+=("$name")
    done < <(printf '%s' "$body" | jq -r '.results[].name')

    next=$(printf '%s' "$body" | jq -r '.next // empty')
    if [[ -z "$next" ]]; then break; fi
    page=$((page + 1))
    [[ $page -gt 20 ]] && break
done

echo "Repo '${NAMESPACE}' has ${#existing[@]} tag(s)"

orphans=()
for t in "${existing[@]}"; do
    if [[ -z "${KEEP[$t]+x}" ]]; then
        orphans+=("$t")
    fi
done

if [[ ${#orphans[@]} -eq 0 ]]; then
    echo "No orphan tags to delete."
    exit 0
fi

echo "Orphan tags (${#orphans[@]}):"
printf '  %s\n' "${orphans[@]}"

if [[ "$DRY_RUN" == "1" ]]; then
    echo "DRY_RUN=1 → not deleting. Re-run with DRY_RUN=0 to apply."
    exit 0
fi

# Auth: refresh JWT (Docker Hub tokens expire ~5min)
TOKEN=$(curl --silent --fail --max-time 30 \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${DOCKERHUB_USERNAME}\",\"password\":\"${DOCKERHUB_TOKEN}\"}" \
    "https://hub.docker.com/v2/users/login/" | jq -r '.token // empty')

if [[ -z "$TOKEN" ]]; then
    echo "ERROR: failed to obtain Docker Hub auth token" >&2
    exit 3
fi

# Delete one-by-one. Tag names with '/' cannot be in path: use ?tag=.
for t in "${orphans[@]}"; do
    encoded=$(printf '%s' "$t" | jq -sRr @uri)
    http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" \
        -X DELETE \
        -H "Authorization: Bearer ${TOKEN}" \
        "${API}/${encoded}/")
    if [[ "$http_code" =~ ^2 ]]; then
        echo "  deleted: $t"
    else
        echo "  FAILED ($http_code): $t" >&2
    fi
done
