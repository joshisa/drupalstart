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
echo -e "${cloud}${Cyan}  Evaluated deployed application URI is ${Yellow}${DRUPAL_DOMAIN_NAME}${no_color}"
if [ -z "$SSHFS_ADDRESS" ]; then
  echo -e "${delivery}${Yellow}  Detected SSHFS Environment Variables ...{$no_color}"
  echo -e "${delivery}${Yellow}  Temporarily renaming assembled sites folder ...{$no_color}"
  mv /home/vcap/app/htdocs/drupal-7.41/sites /home/vcap/app/htdocs/drupal-7.41/mirage
  echo -e "${delivery}${Yellow}  Reading SSHFS mount environment variables ...{$no_color}"
  echo -e "${delivery}${Yellow}    Persisting Provided Public Key to file id_rsa.pub ...{$no_color}"
  echo "$SSHFS_PUBLIC" > "/home/vcap/app/.profile.d/id_rsa.pub"
  echo -e "${delivery}${Yellow}    Persisting Provided Private Key to file id_rsa ...{$no_color}"
  echo "$SSHFS_PRIV" > "/home/vcap/app/.profile.d/id_rsa"
  echo -e "${delivery}${Yellow}    Persisting Provided known_hosts to file known_hosts ...{$no_color}"
  echo "$SSHFS_KNOWNHOSTS" > "/home/vcap/app/.profile.d/known_hosts"
  echo -e "${delivery}${Yellow}    Securing files from Man-In-The-Middle Attacks ...{$no_color}"
  chmod 600 /home/vcap/app/.profile.d/id_rsa
  chmod 600 /home/vcap/app/.profile.d/id_rsa.pub
  chmod 600 /home/vcap/app/.profile.d/known_hosts
  echo -e "${delivery}${Yellow}    Creating mount location ...{$no_color}"
  mkdir -p /home/vcap/misc
  echo -e "${delivery}${Yellow}  Initiating SSHFS mount ...{$no_color}"
  sshfs ${SSHFS_ADDRESS} /home/vcap/misc -o IdentityFile=/home/vcap/app/.profile.d/id_rsa,StrictHostKeyChecking=yes,UserKnownHostsFile=/home/vcap/app/.profile.d/known_hosts,idmap=user,compression=no
  echo -e "${delivery}${Yellow}  Creating Domain Namespace within mounted location ...{$no_color}"
  mkdir -p /home/vcap/misc/${DRUPAL_DOMAIN_NAME}
  echo -e "${delivery}${Yellow}  Creating Symlink between Drupal Sites folder and mounted location ...{$no_color}"
  ln -s /home/vcap/misc/${DRUPAL_DOMAIN_NAME} /home/vcap/app/htdocs/drupal-7.41/sites
  echo -e "${delivery}${Yellow}  Moving previously assembled sites folder content back ...{$no_color}"
  mv /home/vcap/app/htdocs/drupal-7.41/mirage/* /home/vcap/app/htdocs/drupal-7.41/sites/*
  rm -rf /home/vcap/app/htdocs/drupal-7.41/mirage
  touch /home/vcap/app/htdocs/drupal-7.41/sites/foo.man.txt
  ls -al /home/vcap/app/htdocs/drupal-7.41/sites
else
  echo -e "${delivery}${Yellow}  No SSHFS Environment Variables detected. Proceeding with local ephemeral sites folder.{$no_color}"
fi


# ssh-keygen -b 2048 -t rsa -f /home/vcap/app/.profile.d/sshkey -q -N ""
# ssh-keyscan 134.168.17.44 >> ~/.ssh/known_hosts
# Command below uses debug options which causes process to run in foreground ... good for debugging but not useful for running with cf apps.
# sshfs root@134.168.17.44:/home/paramount /home/vcap/misc -o IdentityFile=/home/vcap/app/.profile.d/id_rsa,StrictHostKeyChecking=yes,UserKnownHostsFile=/home/vcap/app/.profile.d/known_hosts,idmap=user,compression=no,sshfs_debug,debug
