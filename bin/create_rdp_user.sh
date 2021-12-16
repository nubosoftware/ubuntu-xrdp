#!/bin/bash

export uname=$1
export plain=$2
export tz=$3
export locale=$4
export id=1000

# update time zone
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/$tz /etc/localtime

#update locale
update-locale LANGUAGE=$locale LANG=$locale LC_ALL=$locale

#create user name
export hash=`openssl passwd -1 $plain`
groupadd -g $id $uname
useradd -m -u $id -s /bin/bash -g $uname $uname
echo "$uname:$hash" | /usr/sbin/chpasswd -e

echo "User $uname created with locale $locale and timezone $tz."
exit 0

