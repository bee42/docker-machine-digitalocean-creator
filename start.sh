#!/bin/sh
if [ ! -f /etc/ssh/ssh_host_rsa_key ] ; then
  /usr/bin/ssh-keygen -A
fi
/usr/bin/supervisord $@
