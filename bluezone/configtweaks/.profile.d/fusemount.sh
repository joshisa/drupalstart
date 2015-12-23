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
echo -e "${cloud}${Cyan}  Evaluated deployed application URI is ${Yellow}${DRUPAL_DOMAIN_NAME}"
if [ -n "${SSHFS_PRIV+set}" ]; then
  echo -e "${delivery}${Yellow}  Detected SSHFS Environment Variables ..."
  echo -e "${delivery}${Yellow}  Temporarily renaming assembled sites folder ..."
  mv /home/vcap/app/htdocs/drupal-7.41/sites /home/vcap/app/htdocs/drupal-7.41/mirage
  echo -e "${delivery}${Yellow}  Reading SSHFS mount environment variables ..."
  echo -e "${delivery}${Yellow}    Persisting Provided Private Key to file id_rsa ..."
  echo "$SSHFS_PRIV" > "/home/vcap/app/.profile.d/id_rsa"
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
  # Reference: http://manpages.ubuntu.com/manpages/karmic/en/man1/sshfs.1.html
  # SSHFS Tuning Reference: http://www.admin-magazine.com/HPC/Articles/Sharing-Data-with-SSHFS
  sshfs ${SSHFS_USER}@${SSHFS_HOST}:${SSHFS_DIR} /home/vcap/misc -o IdentityFile=/home/vcap/app/.profile.d/id_rsa,StrictHostKeyChecking=yes,UserKnownHostsFile=/home/vcap/app/.profile.d/known_hosts,idmap=user,compression=yes,cache=yes,kernel_cache,large_read,Ciphers=arcfour,cache_timeout=115200,attr_timeout=115200
  echo -e "${delivery}${Yellow}  Creating Domain Namespace within mounted location ..."
  mkdir -p /home/vcap/misc/${DRUPAL_DOMAIN_NAME}
  mkdir -p /home/vcap/misc/${DRUPAL_DOMAIN_NAME}/sites
  echo -e "${delivery}${Yellow}  Creating Symlink between Drupal Sites folder and mounted location ..."
  ln -s /home/vcap/misc/${DRUPAL_DOMAIN_NAME}/sites /home/vcap/app/htdocs/drupal-7.41
  echo -e "${delivery}${Yellow}  Moving previously assembled sites folder content onto SSHFS mount (Overwrite enabled).  Estimated time: 135 seconds ..."
  # Comment:  cp is too slow, even with 180 sec extended health check
  # cp -R /home/vcap/app/htdocs/drupal-7.41/mirage/. /home/vcap/app/htdocs/drupal-7.41/sites
  # Comment:  scp was too slow, even with 180 sec extended health check
  # scp -r /home/vcap/app/htdocs/drupal-7.41/mirage/. /home/vcap/app/htdocs/drupal-7.41/sites
  # Comment:  Tar over ssh fits within the 180 second timeout health check.  ~135 seconds to move all default modules
  # If health check timeouts occur during deploy, one mitigation is to reduce the amount of "desired" modules within the default assembly.
  # In theory, now that we are using a SSHFS file storage, installation via website should persist.  This should also enable multiple cf instances
  tar -C /home/vcap/app/htdocs/drupal-7.41/mirage -jcf - ./ | ssh -i /home/vcap/app/.profile.d/id_rsa -o UserKnownHostsFile=/home/vcap/app/.profile.d/known_hosts ${SSHFS_USER}@${SSHFS_HOST} "tar -C/home/paramount/${DRUPAL_DOMAIN_NAME}/sites -ojxf -"
  rm -rf /home/vcap/app/htdocs/drupal-7.41/mirage
  echo -e "${delivery}${Yellow}  Per best practices - Create Domain specific sites folder"
  mkdir /home/vcap/app/htdocs/drupal-7.41/sites/${DRUPAL_DOMAIN_NAME}
  mkdir /home/vcap/app/htdocs/drupal-7.41/sites/${DRUPAL_DOMAIN_NAME}/themes
  mkdir /home/vcap/app/htdocs/drupal-7.41/sites/${DRUPAL_DOMAIN_NAME}/tmp
  mkdir /home/vcap/app/htdocs/drupal-7.41/sites/${DRUPAL_DOMAIN_NAME}/files
  mkdir /home/vcap/app/htdocs/drupal-7.41/sites/${DRUPAL_DOMAIN_NAME}/modules
  mkdir /home/vcap/app/htdocs/drupal-7.41/sites/${DRUPAL_DOMAIN_NAME}/libraries
  touch /home/vcap/app/htdocs/drupal-7.41/sites/${DRUPAL_DOMAIN_NAME}/placeholder.settings.php
else
  echo -e "${delivery}${Yellow}  No SSHFS Environment Variables detected. Proceeding with local ephemeral sites folder."
fi

# Reference Commands
# How to generate a key-pair with no passphrase in a single command
# ssh-keygen -b 2048 -t rsa -f /home/vcap/app/.profile.d/sshkey -q -N ""
# Command below uses debug options which causes process to run in foreground ... good for debugging but not useful for running with cf apps.
# sshfs root@134.168.17.44:/home/paramount /home/vcap/misc -o IdentityFile=/home/vcap/app/.profile.d/id_rsa,StrictHostKeyChecking=yes,UserKnownHostsFile=/home/vcap/app/.profile.d/known_hosts,idmap=user,compression=no,sshfs_debug,debug
