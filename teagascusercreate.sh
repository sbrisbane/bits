#!/bin/bash

usage() {
  echo "usage: $0 -u USER [ -g GROUP ] [ -a ACCOUNT ]"
  echo Creates NIS and slurm account entries for a user
}

GROUP=users
ACCOUNTDEFAULT=DEFAULT
#new user ID, override with optarg, -1 to autodetect
NUID=-1

pgrep  slurmdbd > /dev/null \
 && pgrep  slurmctld > /dev/null \
 && pgrep  mariadb > /dev/null \

if [[ $? -ne 0 ]] ; then
  echo slurmctld and slurmdbd needs to be running
  exit 1
fi

while getopts "hu:g:i:" arg
do
  case $arg in
    h)
      usage
      exit 0
      ;;
    u)
      USERN="$OPTARG"
      ;;
    g)
      GROUP="$OPTARG"
      ;;
    a)
      ACCOUNT="$OPTARG"
      ;;
    i)
      NUID="$OPTARG"
      ;;
    *)
      usage
      exit 2
  esac
done

if [[ -z "$USERN" ]]; then
  usage
  exit 3
fi

if getent passwd | grep -q $USERN; then
  echo "The account $USERN already exists"
  exit 4
fi

if [[ -z "$ACCOUNT" ]]; then
  ACCOUNT="$ACCOUNTDEFAULT"
fi

GID=0
getent group $GROUP > /dev/null
if [ $? -ne 0 ]; then
        echo "Something went wrong obtaining group infro for $GROUP"
        echo "User not created"
        exit 1
fi

#ID=$(getent group $GROUP | cut -f 3 -d : )
GID=$GROUP
# Create the account
#useradd -K UID_MIN=$MINUID -c "$USERN" -g  "$GROUP" -m  "$USERN" || exit 5


#linux quiestions bug 642172 says this doesnt always get the latest user
#NUID=$(getent passwd | cut -d ':' -f 3 | sort -n | grep -e [1-5]....$ | tail -1)


# update LDAP
if [ "$NUID" != -1 ];then
   cmsh -c "user; add  $USERN; set id $NUID ; set groupid $GID;commit"
else

NUID=$( cmsh -c "user list -f id -s id" | tail -1 )
   if [ -z "$NUID" ] || [ $NUID -lt 10000 ];then
        NUID=10000
   fi
   NUID=$(( $NUID + 1 ))
   echo $NUID
   cmsh -c "user; add  $USERN; set groupid $GID;commit"

fi


getent passwd $USERN > /dev/null ||  sleep 1
getent passwd $USERN > /dev/null ||  sleep 1
getent passwd $USERN || echo WARNING: USER HAS NOT YET APPEARED IN SSSD. Trying to continue...
xfs_quota -x -c 'limit bsoft=200M bhard=220M $USERN' /home

