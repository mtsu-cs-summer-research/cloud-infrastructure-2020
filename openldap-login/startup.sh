#!/bin/sh

# Regenerate SSH host key
/bin/rm -v /etc/ssh/ssh_host_*
echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d
RUNLEVEL=1 dpkg-reconfigure -f noninteractive openssh-server
chmod 600 /etc/ssh/*_key

service xinetd start
service nscd start
service ssh start

if [ -f /etc/munge/munge.key.tmp ]; then
  echo "Configuring node for mpi cluster: `hostname`"
  cp /etc/munge/munge.key.tmp /etc/munge/munge.key
  chown munge:munge /etc/munge/munge.key

  service munge start

  if [ `hostname` != 'scheduler' ]; then
    echo "Node type: agent"
    service slurmd start
  else
    echo "Node type: scheduler"
    service slurmctld start
  fi
fi

# Just wait
sleep infinity

