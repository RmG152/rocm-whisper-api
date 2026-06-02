#!/usr/bin/env bash
#########################################################
# list-rocm-tags.sh
#
# Lists every "modern" tag of the rocm/pytorch Docker Hub
# repository and emits a JSON object per tag on stdout.
#
# A modern tag matches:
#   rocm{MAJOR(.MINOR(.PATCH))}_ubuntu{YY.MM}_py{X.Y}_pytorch(_release)?_{X.Y.Z}
#
# Legacy tags (CentOS, Ubuntu 16.04/18.04, py2.7, caffe2,
# gfx* suffixes, hipthrust, rocthrust, vnc, ...) are filtered
# out because the Dockerfile requires the modern ROCm wheel
# layout shipped with Ubuntu 22.04+ and PyTorch >= 2.3.
#
# Usage:
#   ./scripts/list-rocm-tags.sh                          # all
#   ./scripts/list-rocm-tags.sh --rocm-major 7          # only ROCm 7.x
#   ./scripts/list-rocm-tags.sh --python 3.12           # only py3.12
#   ./scripts/list-rocm-tags.sh --pytorch 2.10.0        # only that torch
#   ./scripts/list-rocm-tags.sh --json > upstream.json
#
# Output (one JSON object per line):
#   {"upstream":"rocm7.2.4_ubuntu24.04_py3.12_pytorch_release_2.10.0",
#    "sane":"rocm7.2.4-ubuntu24.04-py3.12-pytorch2.10.0",
#    "rocm":"7.2.4","rocm_major":"7","rocm_minor":"2","rocm_patch":"4",
#    "ubuntu":"24.04","python":"3.12","pytorch":"2.10.0",
#    "minor_alias":"rocm7.2.4","major_alias":"rocm7",
#    "is_latest":true}
#########################################################

set -euo pipefail

REPO="${ROCM_PYTORCH_REPO:-rocm/pytorch}"
PAGE_SIZE="${ROCM_PYTORCH_PAGE_SIZE:-100}"
API="https://hub.docker.com/v2/repositories/${REPO}/tags"

ROCM_MAJOR_FILTER=""
PYTHON_FILTER=""
PYTORCH_FILTER=""
JSON_ONLY=0

usage() {
    sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rocm-major) ROCM_MAJOR_FILTER="$2"; shift 2 ;;
        --python)     PYTHON_FILTER="$2";     shift 2 ;;
        --pytorch)    PYTORCH_FILTER="$2";    shift 2 ;;
        --json)       JSON_ONLY=1;            shift ;;
        -h|--help)    usage 0 ;;
        *) echo "Unknown arg: $1" >&2; usage 1 ;;
    esac
done

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is required" >&2; exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required" >&2; exit 2
fi

fetch_page() {
    local page="$1"
    curl --silent --show-error --fail --max-time 60 \
        "${API}?page=${page}&page_size=${PAGE_SIZE}"
}

latest_digest() {
    local page digest
    for page in 1 2 3 4 5; do
        body=$(fetch_page "$page" 2>/dev/null) || continue
        digest=$(printf '%s' "$body" | jq -r '
            .results[] | select(.name=="latest") | .images[0].digest
        ' 2>/dev/null | head -n1 || true)
        if [[ -n "$digest" && "$digest" != "null" ]]; then
            printf '%s' "$digest"; return 0
        fi
    done
    return 1
}

LATEST_DIGEST="$(latest_digest || true)"

process_tag() {
    local name="$1"
    local digest="$2"

    # Modern pattern: rocmX(.Y(.Z)?)?_ubuntuYY.MM_pyX.Y_pytorch(_release)?_X.Y.Z
    if ! [[ "$name" =~ ^rocm([0-9]+)(\.([0-9]+))?(\.([0-9]+))?_ubuntu([0-9]+\.[0-9]+)_py([0-9]+\.[0-9]+)_pytorch(_release)?_([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
        return
    fi

    local rocm_major="${BASH_REMATCH[1]}"
    local rocm_minor="${BASH_REMATCH[3]:-}"
    local rocm_patch="${BASH_REMATCH[5]:-}"
    local ubuntu="${BASH_REMATCH[6]}"
    local python="${BASH_REMATCH[7]}"
    local pytorch="${BASH_REMATCH[9]}"

    # Reject anything below the minimum supported
    [[ "$ubuntu" =~ ^(22\.04|24\.04)$ ]] || return
    [[ "$python" =~ ^3\.(10|11|12|13|14)$ ]] || return

    local rocm="${rocm_major}"
    [[ -n "$rocm_minor" ]] && rocm="${rocm}.${rocm_minor}"
    [[ -n "$rocm_patch" ]] && rocm="${rocm}.${rocm_patch}"

    # Apply user filters
    [[ -z "$ROCM_MAJOR_FILTER" || "$ROCM_MAJOR_FILTER" == "all" || "$ROCM_MAJOR_FILTER" == "$rocm_major" ]] || return
    [[ -z "$PYTHON_FILTER"     || "$PYTHON_FILTER"     == "all" || "$PYTHON_FILTER"     == "$python"   ]] || return
    [[ -z "$PYTORCH_FILTER"    || "$PYTORCH_FILTER"    == "$pytorch" ]] || return

    local sane="rocm${rocm}-ubuntu${ubuntu}-py${python}-pytorch${pytorch}"
    local minor_alias="rocm${rocm}"
    local major_alias="rocm${rocm_major}"
    local is_latest="false"
    if [[ -n "$LATEST_DIGEST" && "$digest" == "$LATEST_DIGEST" ]]; then
        is_latest="true"
    fi

    jq -nc \
        --arg upstream "$name" \
        --arg sane "$sane" \
        --arg rocm "$rocm" \
        --arg rocm_major "$rocm_major" \
        --arg rocm_minor "$rocm_minor" \
        --arg rocm_patch "$rocm_patch" \
        --arg ubuntu "$ubuntu" \
        --arg python "$python" \
        --arg pytorch "$pytorch" \
        --arg minor_alias "$minor_alias" \
        --arg major_alias "$major_alias" \
        --argjson is_latest "$is_latest" \
        '{upstream:$upstream, sane:$sane, rocm:$rocm, rocm_major:$rocm_major,
          rocm_minor:$rocm_minor, rocm_patch:$rocm_patch, ubuntu:$ubuntu,
          python:$python, pytorch:$pytorch, minor_alias:$minor_alias,
          major_alias:$major_alias, is_latest:$is_latest}'
}

count=0
page=1
next=""

while :; do
    if [[ -z "$next" ]]; then
        body="$(fetch_page "$page")"
    else
        body="$(curl --silent --show-error --fail --max-time 60 "$next")"
    fi

    while IFS=$'\t' read -r name digest; do
        [[ -z "$name" ]] && continue
        process_tag "$name" "$digest" && count=$((count + 1))
    done < <(printf '%s' "$body" | jq -r '.results[] | [.name, (.images[0].digest // "")] | @tsv')

    next=$(printf '%s' "$body" | jq -r '.next // empty')
    if [[ -z "$next" ]]; then
        break
    fi
    page=$((page + 1))
    if [[ $page -gt 20 ]]; then
        echo "WARN: safety cap of 20 pages reached" >&2
        break
    fi
done

if [[ $JSON_ONLY -eq 0 ]]; then
    echo "Listed $count modern tag(s) from ${REPO}" >&2
fi
