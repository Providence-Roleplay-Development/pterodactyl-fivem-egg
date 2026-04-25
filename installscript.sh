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

if [ -z "${REPOS_ROOT}" ]; then
  GIT_REPOS_BASE="/mnt/server/resources"
else
  if [ "${REPOS_ROOT#/}" != "$REPOS_ROOT" ]; then
    GIT_REPOS_BASE="${REPOS_ROOT}"
  else
    GIT_REPOS_BASE="/mnt/server/${REPOS_ROOT}"
  fi
fi

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
  if [ "${GIT_ENABLED}" == "1" ] && [ ! -d "${GIT_REPOS_BASE}" ]; then
    echo "Preparing to clone resources from git."

    MULTI_ANY=0
    [ -n "${GIT_YMAP_REPOURL}" ] && MULTI_ANY=1
    [ -n "${GIT_VEHICLE_REPOURL}" ] && MULTI_ANY=1
    [ -n "${GIT_SCRIPTS_REPOURL}" ] && MULTI_ANY=1
    [ -n "${GIT_EUP_REPOURL}" ] && MULTI_ANY=1

    if [ "${MULTI_ANY}" == "1" ]; then
      mkdir -p "${GIT_REPOS_BASE}"
      if [ -z "${GIT_USERNAME}" ] && [ -z "${GIT_TOKEN}" ]; then
        echo -e "Git Username or Git Token was not specified (private repos may fail)."
      fi
      git_clone_to "${GIT_YMAP_REPOURL}" "${GIT_REPOS_BASE}/ymap" "ymap"
      git_clone_to "${GIT_VEHICLE_REPOURL}" "${GIT_REPOS_BASE}/vehicle" "vehicle"
      git_clone_to "${GIT_SCRIPTS_REPOURL}" "${GIT_REPOS_BASE}/scripts" "scripts"
      git_clone_to "${GIT_EUP_REPOURL}" "${GIT_REPOS_BASE}/eup" "eup"
    elif [ -n "${GIT_REPOURL}" ]; then
      if [[ ${GIT_REPOURL} != *.git ]]; then
        GIT_REPOURL=${GIT_REPOURL}.git
      fi

      if [ -z "${GIT_USERNAME}" ] && [ -z "${GIT_TOKEN}" ]; then
        echo -e "Git Username or Git Token was not specified."
      else
        GIT_REPOURL="https://${GIT_USERNAME}:${GIT_TOKEN}@$(echo -e ${GIT_REPOURL} | cut -d/ -f3-)"
      fi

      if [ -z ${GIT_BRANCH} ]; then
        echo -e "Cloning default branch into ${GIT_REPOS_BASE}/*."
        git clone ${GIT_REPOURL} "${GIT_REPOS_BASE}"
      else
        echo -e "Cloning ${GIT_BRANCH} branch into ${GIT_REPOS_BASE}/*."
        git clone --single-branch --branch ${GIT_BRANCH} ${GIT_REPOURL} "${GIT_REPOS_BASE}" && echo "Finished cloning into ${GIT_REPOS_BASE} from Git." || echo "Failed cloning from Git."
      fi
    else
      mkdir -p "${GIT_REPOS_BASE}"
      echo "Git enabled but no repository URLs configured; installing default FiveM resources."
      git clone https://github.com/citizenfx/cfx-server-data.git /tmp && echo "Downloaded server from git." || echo "Downloading from git failed."
      cp -Rf /tmp/resources/* "${GIT_REPOS_BASE}/"
    fi

  else
    # Download FiveM default server resources

    mkdir -p /mnt/server/resources
    echo "Preparing to clone default FiveM resources."
    git clone https://github.com/citizenfx/cfx-server-data.git /tmp && echo "Downloaded server from git." || echo "Downloading from git failed."
    cp -Rf /tmp/resources/* resources/

  fi

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

  echo "Update complete."

fi