#!/bin/bash
set -u
[ "${GIT_ENABLED:-0}" = "1" ] || exit 0
command -v git >/dev/null 2>&1 || { echo "[ptero] git is not installed in this container image; add git to the game Docker image to enable clone/pull."; exit 0; }

cd "$(dirname "$0")" || exit 0
w="$(pwd)"
rr="${GIT_REPOS_ROOT:-${REPOS_ROOT:-resources}}"
case "$rr" in
  /*) b="$rr" ;;
  *) b="$w/$rr" ;;
esac
echo "[ptero] git repos base: $b"
mkdir -p "$b"

git_normalize_url() {
  local u="$1"
  [ -z "$u" ] && { echo ""; return; }
  if [[ ${u} != *.git ]]; then
    u="${u}.git"
  fi
  if [ -n "${GIT_USERNAME:-}" ] && [ -n "${GIT_TOKEN:-}" ]; then
    echo "https://${GIT_USERNAME}:${GIT_TOKEN}@$(echo -e "${u}" | cut -d/ -f3-)"
  else
    echo "${u}"
  fi
}

git_pull_or_clone() {
  local raw_url="$1"
  local dest="$2"
  local label="$3"
  [ -z "$raw_url" ] && return 0
  local url
  url=$(git_normalize_url "${raw_url}")
  [ -z "$url" ] && return 0
  if [ -d "$dest/.git" ]; then
    echo "[ptero] pulling ${label} in ${dest}..."
    (cd "$dest" && git pull) || (cd "$dest" && git pull --rebase) || true
  else
    if [ -d "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null || true)" ]; then
      echo "[ptero] skip ${label}: ${dest} is not empty and is not a git repository"
      return 0
    fi
    echo "[ptero] cloning ${label} to ${dest}..."
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    if [ -z "${GIT_BRANCH:-}" ]; then
      git clone "$url" "$dest" && echo "[ptero] cloned ${label}." || echo "[ptero] failed clone ${label}."
    else
      git clone --single-branch --branch "${GIT_BRANCH}" "$url" "$dest" && echo "[ptero] cloned ${label}." || echo "[ptero] failed clone ${label}."
    fi
  fi
}

MULTI_ANY=0
[ -n "${GIT_YMAP_REPOURL:-}" ] && MULTI_ANY=1
[ -n "${GIT_VEHICLE_REPOURL:-}" ] && MULTI_ANY=1
[ -n "${GIT_SCRIPTS_REPOURL:-}" ] && MULTI_ANY=1
[ -n "${GIT_EUP_REPOURL:-}" ] && MULTI_ANY=1

if [ "$MULTI_ANY" = "1" ]; then
  git_pull_or_clone "${GIT_YMAP_REPOURL:-}" "$b/ymap" "ymap"
  git_pull_or_clone "${GIT_VEHICLE_REPOURL:-}" "$b/vehicle" "vehicle"
  git_pull_or_clone "${GIT_SCRIPTS_REPOURL:-}" "$b/scripts" "scripts"
  git_pull_or_clone "${GIT_EUP_REPOURL:-}" "$b/eup" "eup"
elif [ -n "${GIT_REPOURL:-}" ]; then
  lraw="$GIT_REPOURL"
  if [[ $lraw != *.git ]]; then
    lraw="${lraw}.git"
  fi
  if [ -n "${GIT_USERNAME:-}" ] && [ -n "${GIT_TOKEN:-}" ]; then
    lurl="https://${GIT_USERNAME}:${GIT_TOKEN}@$(echo -e "${lraw}" | cut -d/ -f3-)"
  else
    lurl="${lraw}"
  fi
  if [ -d "$b/.git" ]; then
    echo "[ptero] pulling legacy single-repo in $b..."
    (cd "$b" && git pull) || true
  else
    if [ -d "$b" ] && [ -n "$(ls -A "$b" 2>/dev/null || true)" ]; then
      echo "[ptero] skip legacy clone: $b is not empty and is not a git repository"
    else
      echo "[ptero] cloning legacy single-repo to $b..."
      rm -rf "$b"
      mkdir -p "$(dirname "$b")"
      if [ -z "${GIT_BRANCH:-}" ]; then
        git clone "$lurl" "$b" || true
      else
        git clone --single-branch --branch "${GIT_BRANCH}" "$lurl" "$b" || true
      fi
    fi
  fi
fi
