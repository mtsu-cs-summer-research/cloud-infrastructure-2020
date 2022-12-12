#!/bin/sh

# Configure timezone
# ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Regenerate SSH host key
/bin/rm -v /etc/ssh/ssh_host_*
# echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d
dpkg-reconfigure -f noninteractive openssh-server
chmod 600 /etc/ssh/*_key

if [ -f /etc/munge/munge.key.tmp ]; then
  echo "Configuring node for mpi cluster: `hostname`"
  cp /etc/munge/munge.key.tmp /etc/munge/munge.key
  chown munge:munge /etc/munge/munge.key

  systemctl enable munge

  if [ `hostname` != 'scheduler' ]; then
    echo "Node type: agent"
    systemctl disable slurmctld
    systemctl enable slurmd
  else
    echo "Node type: scheduler"
    systemctl enable slurmctld
    systemctl disable slurmd
  fi
fi

# Just wait
exec /sbin/init

