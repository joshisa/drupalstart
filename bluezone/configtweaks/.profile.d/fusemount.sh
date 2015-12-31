#!/bin/bash
##########
# Colors - Lets have some fun ##
##########
Green='\e[0;32m'
Red='\e[0;31m'
Yellow='\e[0;33m'
Cyan='\e[0;36m'
no_color='\e[0m' # No Color
beer='\xF0\x9f\x8d\xba'
delivery='\xF0\x9F\x9A\x9A'
beers='\xF0\x9F\x8D\xBB'
eyes='\xF0\x9F\x91\x80'
cloud='\xE2\x98\x81'
litter='\xF0\x9F\x9A\xAE'
fail='\xE2\x9B\x94'
harpoons='\xE2\x87\x8C'
tools='\xE2\x9A\x92'
present='\xF0\x9F\x8E\x81'
#############
export DRUPAL_DOMAIN_NAME="$(python $HOME/.profile.d/app_uri.py)"
echo ""
if [ -n "${SSHFS_HOST+set}" ]; then
  echo -e "${delivery}${Yellow}  Detected SSHFS Environment Variables. Initiating relocation of sites content to remote storage ..."
  echo -e "${delivery}${Yellow}  Reading SSHFS mount environment variables ..."
  if [ -f "/home/vcap/app/.profile.d/id_rsa" ]; then
    echo -e "${beer}${Cyan}    Existing Identity file detected."
  else
    if [ -n "${SSHFS_PRIV+set}" ]; then
      echo -e "${tools}${Yellow}    Persisting Private Key Env Var to file id_rsa ..."
      echo "$SSHFS_PRIV" > "/home/vcap/app/.profile.d/id_rsa"
    else
      echo -e "${fail}${Red}    User-provided Env Var SSHFS_PRIV not set!"
    fi
  fi
  echo -e "${delivery}${Yellow}    Securing IdentityFile from Man-In-The-Middle Attacks ..."
  chmod 600 /home/vcap/app/.profile.d/id_rsa
  echo -e "${delivery}${Yellow}    Adding the key to the ssh-agent ..."
  eval $(ssh-agent)
  ssh-add /home/vcap/app/.profile.d/id_rsa
  echo -e "${delivery}${Yellow}    Generating known_hosts file ..."
  ssh-keyscan -t RSA -H ${SSHFS_HOST} > "/home/vcap/app/.profile.d/known_hosts"
  echo -e "${delivery}${Yellow}    Creating mount location ..."
  mkdir -p /home/vcap/misc
  echo -e "${delivery}${Yellow}  Initiating SSHFS mount ..."
  if [ -n "${SSHFS_USER+set}" ] && [ -n "${SSHFS_DIR+set}" ]; then
    # Reference: http://manpages.ubuntu.com/manpages/karmic/en/man1/sshfs.1.html
    # SSHFS Tuning Reference: http://www.admin-magazine.com/HPC/Articles/Sharing-Data-with-SSHFS
    sshfs ${SSHFS_USER}@${SSHFS_HOST}:${SSHFS_DIR} /home/vcap/misc -o IdentityFile=/home/vcap/app/.profile.d/id_rsa,StrictHostKeyChecking=yes,UserKnownHostsFile=/home/vcap/app/.profile.d/known_hosts,idmap=user,compression=yes,cache=yes,kernel_cache,large_read,Ciphers=arcfour,cache_timeout=115200,attr_timeout=115200
  else
    echo -e "${fail}${Red}    SSHFS Mount failed!"
    echo -e "${fail}${Red}    User-provided Env Var SSHFS_USER AND/OR SSHFS_DIR not set!"
  fi
  if [ -n "${DRUPAL_DOMAIN_NAME+set}" ]; then
    echo -e "${cloud}${Cyan}  Current deployed application URI is ${Yellow}${DRUPAL_DOMAIN_NAME}"
    echo -e "${delivery}${Yellow}  Creating Domain Namespace within mounted location ..."
    mkdir -p /home/vcap/misc/${DRUPAL_DOMAIN_NAME}
    echo -e "${delivery}${Yellow}  Creating sites folder within mounted Domain Namespace ..."
    mkdir -p /home/vcap/misc/${DRUPAL_DOMAIN_NAME}/sites
    # Note:  Rename of existing assembled sites folder must always precede the Symlink creation
    echo -e "${delivery}${Yellow}  Temporarily renaming assembled sites folder ..."
    mv /home/vcap/app/htdocs/drupal-7.41/sites /home/vcap/app/htdocs/drupal-7.41/mirage
    echo -e "${delivery}${Yellow}  Creating Symlink between Drupal Sites folder and mounted Domain Namespace location ..."
    ln -s /home/vcap/misc/${DRUPAL_DOMAIN_NAME}/sites /home/vcap/app/htdocs/drupal-7.41
    # Comment:  cp is too slow, even with 180 sec extended health check
    # cp -R /home/vcap/app/htdocs/drupal-7.41/mirage/. /home/vcap/app/htdocs/drupal-7.41/sites
    # Comment:  scp was too slow, even with 180 sec extended health check
    # scp -r /home/vcap/app/htdocs/drupal-7.41/mirage/. /home/vcap/app/htdocs/drupal-7.41/sites
    # Comment:  Tar over ssh fits within the 180 second timeout health check.  ~135 seconds to move all default modules
    # If health check timeouts occur during deploy, one mitigation is to reduce the amount of "desired" modules within the default assembly.
    # In theory, now that we are using a SSHFS file storage, installation via website should persist.  This should also enable multiple cf instances
    echo -e "${eyes}${Cyan}  Inspecting mounted Domain Namespace for existing site files ..."
    if [ -f "/home/vcap/misc/${DRUPAL_DOMAIN_NAME}/sites/default/settings.php" ]; then
      echo -e "${beer}${Cyan}    Existing settings.php file detected.  Skipping transfer of assembled sites folder."
    else
      echo -e "${harpoons}${Yellow}    Moving previously assembled sites folder content onto SSHFS mount (Overwrite enabled).  Estimated time: 135 seconds ..."
      tar -C /home/vcap/app/htdocs/drupal-7.41/mirage -jcf - ./ | ssh -i /home/vcap/app/.profile.d/id_rsa -o UserKnownHostsFile=/home/vcap/app/.profile.d/known_hosts ${SSHFS_USER}@${SSHFS_HOST} "tar -C/home/paramount/${DRUPAL_DOMAIN_NAME}/sites -ojxf -"
    fi
    echo -e "${litter}${Yellow}  Removing legacy sites folder"
    rm -rf /home/vcap/app/htdocs/drupal-7.41/mirage
  else
    echo -e "${fail}${Red}    Symlink creation failed!"
    echo -e "${fail}${Red}    Calculated Var DRUPAL_DOMAIN_NAME not set!"
  fi
else
  echo -e "${delivery}${Yellow}  No SSHFS Environment Variables detected. Proceeding with local ephemeral sites folder."
fi

# Reference Commands
# How to generate a key-pair with no passphrase in a single command
# ssh-keygen -b 2048 -t rsa -f /home/vcap/app/.profile.d/sshkey -q -N ""
# Command below uses debug options which causes process to run in foreground ... good for debugging but not useful for running with cf apps because it will hold the process and block the app from starting.

# sshfs root@134.168.17.44:/home/paramount /home/vcap/misc -o IdentityFile=/home/vcap/app/.profile.d/id_rsa,StrictHostKeyChecking=yes,UserKnownHostsFile=/home/vcap/app/.profile.d/known_hosts,idmap=user,compression=no,sshfs_debug,debug
