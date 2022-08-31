FROM nvidia/cuda:11.7.1-base-ubuntu22.04
LABEL maintainer="Joshua L. Phillips <https://www.cs.mtsu.edu/~jphillips/>"

USER root

# Make this a user-friendly container (Ubuntu Server)
WORKDIR /root
RUN yes | unminimize

# BUILD DEPS for Singularity (may overlap with other below)
# Tools needed for Singularity
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    cryptsetup-bin \
    libglib2.0-dev \
    libseccomp-dev \
    pkg-config \
    git \
    golang \
    rsync \
    squashfs-tools \
    wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download/Compile Singularity
WORKDIR /root
# Download/Compile/Install Singularity
# ENV PATH="/usr/lib/go-1.18/bin:${PATH}"
ENV GOCACHE="/root/gocache"
RUN wget https://github.com/sylabs/singularity/releases/download/v3.10.2/singularity-ce-3.10.2.tar.gz && \
    tar -xzf singularity-ce-3.10.2.tar.gz && \
    cd singularity-ce-3.10.2 && \
    ./mconfig && \                      
    make -C ./builddir && \                          
    make -C ./builddir install && \
    cd .. && \
    rm -rf singularity* && \
    rm -rf /root/go* && \
    ln -s /usr/local/etc/bash_completion.d/singularity /etc/bash_completion.d/.

# DEPS for LDAP and PAM (MTSU Login and Debugging)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    dnsutils \
    finger \
    ldap-utils \
    libpam-ldap \
    nscd \
    openssh-server \
    vim \
    wget \
    xinetd && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# HPC Software Support
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libmunge-dev \
    libmunge2 \
    libopenmpi-dev \
    locales-all \
    # mpich \
    munge \
    openmpi-bin \
    openmpi-common \
    slurm-wlm \
    tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Clean up before finalizing container
RUN apt-get clean

# Prep NFS mountpoint(s)
RUN mkdir /nfshome && \
    mkdir /sandbox

# XINETD - SSH port forward for LDAP
# Needs additional ConfigMaps on K8S
# to use these elements
RUN touch /etc/xinetd.d/ldap && \
    mkdir /root/.ssh && \
    touch /root/.ssh/known_hosts && \
    touch /root/ldap.key && \
    chmod 600 /root/ldap.key

# LDAP - local setup for MTSU
RUN cp /etc/nsswitch.conf /etc/nsswitch.conf.bak && \
    cat /etc/nsswitch.conf.bak | \
    sed -e '/^passwd:/ s/$/ ldap/' | \
    sed -e '/^group:/ s/$/ ldap/' | \
    sed -e '/^shadow:/ s/$/ ldap/' > /etc/nsswitch.conf
# Note that this assumes Bitnami OpenLDAP container
# is part of the deployment... you could use a
# ConfigMap to modify this.
RUN echo "base dc=example,dc=org" > /etc/ldap.conf && \
    echo "uri ldap://openldap:1389/" >> /etc/ldap.conf && \
    echo "ldap_version 3" >> /etc/ldap.conf && \
    echo "pam_password md5" >> /etc/ldap.conf

# Allow for automatic home directory creation
RUN echo "session optional        pam_mkhomedir.so skel=/etc/skel/ umask=0077" >> /etc/pam.d/common-session

# SSH - no host key confirmation
# Make current host key auto-login via known_hosts.
# This is generally a BAD idea, but we used it
# some during testing and decided to leave it
# documented here is it's useful for someone...
# RUN echo -n "* " >> /etc/ssh/ssh_known_hosts && \
#     cat /etc/ssh/ssh_host_ecdsa_key.pub >> /etc/ssh/ssh_known_hosts && \
#     chmod 644 /etc/ssh/ssh_known_hosts

# Make munge log to syslog
RUN echo 'OPTIONS="--syslog"' >> /etc/default/munge

# SSH - execution
COPY startup.sh /usr/local/bin/.
WORKDIR /srv/openldap-login
CMD ["/usr/local/bin/startup.sh"]
