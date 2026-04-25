#!/bin/bash
# FiveM Installation Script
#
# Server Files: /mnt/server
apt update -y
apt install -y tar xz-utils curl git file jq unzip

mkdir -p /mnt/server
cd /mnt/server

RELEASE_PAGE=$(curl -sSL https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/)
CHANGELOGS_PAGE=$(curl -sSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server)

git_normalize_url() {
  local u="$1"
  [ -z "$u" ] && echo "" && return
  if [[ ${u} != *.git ]]; then
    u="${u}.git"
  fi
  if [ -n "${GIT_USERNAME}" ] && [ -n "${GIT_TOKEN}" ]; then
    echo "https://${GIT_USERNAME}:${GIT_TOKEN}@$(echo -e "${u}" | cut -d/ -f3-)"
  else
    echo "${u}"
  fi
}

git_clone_to() {
  local raw_url="$1"
  local dest="$2"
  local label="$3"
  [ -z "$raw_url" ] && return 0
  echo "Cloning ${label} repository..."
  local url
  url=$(git_normalize_url "${raw_url}")
  if [ -z "${GIT_BRANCH}" ]; then
    git clone "${url}" "${dest}" && echo "Finished cloning ${label}." || echo "Failed cloning ${label}."
  else
    git clone --single-branch --branch "${GIT_BRANCH}" "${url}" "${dest}" && echo "Finished cloning ${label} (branch ${GIT_BRANCH})." || echo "Failed cloning ${label}."
  fi
}

resolve_git_repos_base() {
  local rr="${GIT_REPOS_ROOT:-${REPOS_ROOT:-resources}}"
  case "$rr" in
    /*) echo "$rr" ;;
    *) echo "/mnt/server/$rr" ;;
  esac
}

deploy_ptero_git_sync() {
  cat > /mnt/server/ptero-git-sync.sh << 'PTERO_GIT_SYNC_EOF'
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
  git_pull_or_clone "${GIT_YMAP_REPOURL:-}" "$b/[ymap]" "ymap"
  git_pull_or_clone "${GIT_VEHICLE_REPOURL:-}" "$b/[vehicle]" "vehicle"
  git_pull_or_clone "${GIT_SCRIPTS_REPOURL:-}" "$b/[scripts]" "scripts"
  git_pull_or_clone "${GIT_EUP_REPOURL:-}" "$b/[eup]" "eup"
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
PTERO_GIT_SYNC_EOF
  chmod +x /mnt/server/ptero-git-sync.sh
  echo "Deployed ptero-git-sync.sh to /mnt/server."
}

# Check wether to run installation or update version of script
if [ ! -d "./alpine/" ] && [ ! -d "./resources/" ]; then
  # Install script
  echo "Beginning installation of new FiveM server."

  if [[ "${FIVEM_VERSION}" == "recommended" ]] || [[ -z ${FIVEM_VERSION} ]]; then
    DOWNLOAD_LINK=$(echo $CHANGELOGS_PAGE | jq -r '.recommended_download')
  elif [[ "${FIVEM_VERSION}" == "latest" ]]; then
    DOWNLOAD_LINK=$(echo $CHANGELOGS_PAGE | jq -r '.latest_download')
  else
    VERSION_LINK=$(echo -e "${RELEASE_PAGE}" | grep -Eo '".*/*.tar.xz"' | grep -Eo '".*/*.tar.xz"' | sed 's/\"//g'  | sed 's/\.\///1' | grep -i "${FIVEM_VERSION}" | grep -o =.* |  tr -d '=')
    if [[ "${VERSION_LINK}" == "" ]]; then
      echo -e "Defaulting to recommended as the version requested was invalid."
      DOWNLOAD_LINK=$(echo $CHANGELOGS_PAGE | jq -r '.recommended_download')
    else
      DOWNLOAD_LINK=$(echo https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${VERSION_LINK})
    fi
  fi

  # Download artifact and get filetype
  echo -e "Running curl -sSL ${DOWNLOAD_LINK} -o ${DOWNLOAD_LINK##*/}..."
  curl -sSL ${DOWNLOAD_LINK} -o ${DOWNLOAD_LINK##*/}
  
  # Unpack artifact depending on filetype
  echo "Extracting FiveM/RedM FXServer artifact files..."
  FILETYPE=$(file -F ',' ${DOWNLOAD_LINK##*/} | cut -d',' -f2 | cut -d' ' -f2)
  if [ "$FILETYPE" == "gzip" ]; then
    tar xzvf ${DOWNLOAD_LINK##*/}
  elif [ "$FILETYPE" == "Zip" ]; then
    unzip ${DOWNLOAD_LINK##*/}
  elif [ "$FILETYPE" == "XZ" ]; then
    tar xvf ${DOWNLOAD_LINK##*/}
  else
    echo -e "Downloaded artifact of unknown filetype. Exiting."
    exit 2
  fi

  # Delete original bash launch script
  rm -rf ${DOWNLOAD_LINK##*/} run.sh

  if [ -e server.cfg ]; then
    echo "Server config file already exists. Skipping download of new one."
  else
    echo "Downloading default FiveM server config..."
    curl https://raw.githubusercontent.com/darksaid98/pterodactyl-fivem-egg/master/server.cfg >> server.cfg
  fi

  # Clone resources repo from git or install FiveM default resources
  if [ "${GIT_ENABLED}" == "1" ]; then
    echo "Preparing to clone resources from git."

    MULTI_ANY=0
    [ -n "${GIT_YMAP_REPOURL}" ] && MULTI_ANY=1
    [ -n "${GIT_VEHICLE_REPOURL}" ] && MULTI_ANY=1
    [ -n "${GIT_SCRIPTS_REPOURL}" ] && MULTI_ANY=1
    [ -n "${GIT_EUP_REPOURL}" ] && MULTI_ANY=1

    if [ "${MULTI_ANY}" == "1" ]; then
      GIT_REPOS_BASE="$(resolve_git_repos_base)"
      mkdir -p "$GIT_REPOS_BASE"
      if [ -z "${GIT_USERNAME}" ] && [ -z "${GIT_TOKEN}" ]; then
        echo -e "Git Username or Git Token was not specified (private repos may fail)."
      fi
      git_clone_to "${GIT_YMAP_REPOURL}" "${GIT_REPOS_BASE}/[ymap]" "ymap"
      git_clone_to "${GIT_VEHICLE_REPOURL}" "${GIT_REPOS_BASE}/[vehicle]" "vehicle"
      git_clone_to "${GIT_SCRIPTS_REPOURL}" "${GIT_REPOS_BASE}/[scripts]" "scripts"
      git_clone_to "${GIT_EUP_REPOURL}" "${GIT_REPOS_BASE}/[eup]" "eup"
    elif [ -n "${GIT_REPOURL}" ]; then
      if [[ ${GIT_REPOURL} != *.git ]]; then
        GIT_REPOURL=${GIT_REPOURL}.git
      fi

      if [ -z "${GIT_USERNAME}" ] && [ -z "${GIT_TOKEN}" ]; then
        echo -e "Git Username or Git Token was not specified."
      else
        GIT_REPOURL="https://${GIT_USERNAME}:${GIT_TOKEN}@$(echo -e ${GIT_REPOURL} | cut -d/ -f3-)"
      fi

      GIT_REPOS_BASE="$(resolve_git_repos_base)"
      mkdir -p "$(dirname "$GIT_REPOS_BASE")"
      if [ -z ${GIT_BRANCH} ]; then
        echo -e "Cloning default branch into ${GIT_REPOS_BASE}."
        git clone ${GIT_REPOURL} "${GIT_REPOS_BASE}"
      else
        echo -e "Cloning ${GIT_BRANCH} branch into ${GIT_REPOS_BASE}."
        git clone --single-branch --branch ${GIT_BRANCH} ${GIT_REPOURL} "${GIT_REPOS_BASE}" && echo "Finished cloning from Git." || echo "Failed cloning from Git."
      fi
    else
      mkdir -p /mnt/server/resources
      echo "Git enabled but no repository URLs configured; installing default FiveM resources."
      git clone https://github.com/citizenfx/cfx-server-data.git /tmp && echo "Downloaded server from git." || echo "Downloading from git failed."
      cp -Rf /tmp/resources/* resources/
    fi

  else
    # Download FiveM default server resources

    mkdir -p /mnt/server/resources
    echo "Preparing to clone default FiveM resources."
    git clone https://github.com/citizenfx/cfx-server-data.git /tmp && echo "Downloaded server from git." || echo "Downloading from git failed."
    cp -Rf /tmp/resources/* resources/

  fi

  deploy_ptero_git_sync
  mkdir logs/
  echo "Installation complete."

else
  # Update script
  echo "Beginning update of existing FiveM/RedM FXServer server artifact."

  # Delete old artifact
  if [ -d "./alpine/" ]; then
    echo "Deleting old FXServer artifact..."
    rm -r ./alpine/
    while [ -d "./alpine/" ]; do
      sleep 1s
    done
    echo "Deleted old FXServer artifact files successfully."
  fi

  if [[ "${FIVEM_VERSION}" == "recommended" ]] || [[ -z ${FIVEM_VERSION} ]]; then
    DOWNLOAD_LINK=$(echo $CHANGELOGS_PAGE | jq -r '.recommended_download')
  elif [[ "${FIVEM_VERSION}" == "latest" ]]; then
    DOWNLOAD_LINK=$(echo $CHANGELOGS_PAGE | jq -r '.latest_download')
  else
    VERSION_LINK=$(echo -e "${RELEASE_PAGE}" | grep -Eo '".*/*.tar.xz"' | grep -Eo '".*/*.tar.xz"' | sed 's/\"//g'  | sed 's/\.\///1' | grep -i "${FIVEM_VERSION}" | grep -o =.* |  tr -d '=')
    if [[ "${VERSION_LINK}" == "" ]]; then
      echo -e "Defaulting to recommended as the version requested was invalid."
      DOWNLOAD_LINK=$(echo $CHANGELOGS_PAGE | jq -r '.recommended_download')
    else
      DOWNLOAD_LINK=$(echo https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${VERSION_LINK})
    fi
  fi

  # Download artifact and get filetype
  echo -e "Running curl -sSL ${DOWNLOAD_LINK} -o ${DOWNLOAD_LINK##*/}..."
  curl -sSL ${DOWNLOAD_LINK} -o ${DOWNLOAD_LINK##*/}

  # Unpack artifact depending on filetype
  echo "Extracting FiveM/RedM FXServer artifact files..."
  FILETYPE=$(file -F ',' ${DOWNLOAD_LINK##*/} | cut -d',' -f2 | cut -d' ' -f2)
  if [ "$FILETYPE" == "gzip" ]; then
    tar xzvf ${DOWNLOAD_LINK##*/}
  elif [ "$FILETYPE" == "Zip" ]; then
    unzip ${DOWNLOAD_LINK##*/}
  elif [ "$FILETYPE" == "XZ" ]; then
    tar xvf ${DOWNLOAD_LINK##*/}
  else
    echo -e "Downloaded artifact of unknown filetype. Exiting."
    exit 2
  fi

  # Delete original bash launch script
  rm -rf ${DOWNLOAD_LINK##*/} run.sh

  deploy_ptero_git_sync
  echo "Update complete."

fi
