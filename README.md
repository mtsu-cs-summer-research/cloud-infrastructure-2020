# MTSU CS S-STEM Cloud Infrastructure 2020

## Project: **Stand-alone K8S HPC Cluster**

## Purpose:

This project aims to create a fully functioning HPC cluster deployable on Kubernetes. The cluster will utilize Singularity containers for software management so that the deployed HPC cluster is capable of running any scientific application over MPI/SLURM. An NFS server and OpenLDAP server are also used to provide the shared file system and user authentication for the cluster.

## TL;DR:

To deploy/use the HPC cluster, you will need a functioning Kubernetes deployment (we typically use [k3s](https://k3s.io/) or [k3d](https://k3d.io/)).

From the terminal, generally follow these steps:

1. Clone the repository and change working directory to the base directory of the repository.
```sh
git clone https://github.com/mtsu-cs-summer-research/cloud-infrastructure-2020.git
cd cloud-infrastructure-2020
```


2. Make a namespace for the hpc cluster. If you decide to use a different namespace, be sure to replace the DNS search base entries (mpi.hpc.svc.cluster.local) in 03-cluster.yaml with your chosen namespace:
```sh
kubectl create namespace hpc
```


3. Deploy the NFS server:
```sh
kubectl -n hpc create -f 01-nfs-volume.yaml
kubectl -n hpc create -f 02-nfs-server.yaml
```


4. Find the IP address of the NFS server and edit 03-cluster.yaml (line 13) to contain the correct IP address:
```sh
kubectl -n hpc get svc
```
```text=
NAME   TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                      AGE
nfs    ClusterIP   10.43.203.4   <none>        2049/TCP,20048/TCP,111/TCP   11s
```
Change 03-cluster.yaml (line 13) accordingly:
```text
  nfs:
    # Must be manually updated each re-deployment
    server: 10.43.203.4
```


5. Additional modifications to 03-cluster.yaml (ConfigMap ldap-login-slurm-conf, slurm.conf section) may be needed to match the 4 (default) worker agent pods to your machines' architecture(s) (sockets/cores/threads) and set the nodeSelector if you want to assign workers to particular nodes (see K8S docs if unsure, or just leave alone for testing purposes):
```
NodeName=agent-[0-3] Sockets=1 CoresPerSocket=8 ThreadsPerCore=1 State=UNKNOWN
```


6. Bring up the OpenLDAP, SLURM Scheduler, and SLUM Agent Workers:
```sh
kubectl -n hpc create -f 03-cluster.yaml
```


7. Determine the IP address of the login node:
```sh
kubectl -n hpc get svc
```
```
NAME       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
nfs        ClusterIP   10.43.203.4     <none>        2049/TCP,20048/TCP,111/TCP   16m
openldap   ClusterIP   10.43.232.229   <none>        1389/TCP                     10m
mpi        ClusterIP   None            <none>        <none>                       10m
login      ClusterIP   10.43.171.12    <none>        22/TCP                       10m
```


8. Use SSH to log into the scheduler (default username is `jovyan` and the default password is `password`):
```sh
ssh jovyan@10.43.171.12
```


9. Download a testing singularity image (mpitest.sif), allocate part of the cluster, run the singularity job, and then exit out.
```sh
wget https://www.cs.mtsu.edu/~jphillips/mpitest.sif
salloc -n 8 /bin/sh
sinfo
```
```text
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
batch*       up 7-00:00:00      4   idle agent-[0-3]
```
```sh
salloc -n 8 /bin/sh
```
```text
salloc: Granted job allocation 4
```
sinfo
    PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
    batch*       up 7-00:00:00      1  alloc agent-0
    batch*       up 7-00:00:00      3   idle agent-[1-3]

```


## Advantages:

Some cool things this deployment **DOES** do right:

1. The current HPC cluster deployment can brought up and torn down on any K8S cluster.

2. Nodes can be tagged and worker containers assigned to nodes using these tags.

3. A functioning Ubuntu 20.04 - OpenMPI/Singularity/SLURM deployment is provided so that *potentially any* scientific application can be run on the HPC cluster.

4. Different clusters can be created in different K8S namespaces to provide unique cluster topologies.

5. Both the NFS and OpenLDAP components can be easily replaced with exiting NFS or OpenLDAP infrastructure using K8S ConfigMaps.

## Shortcomings:

At this point, the cluster is fully functional, but **VERY INSECURE**. You should only use it for testing purposes, and not production scientific computing. Here are the main security holes that we are aware of (and there may be many others):

1. OpenLDAP credentials are saved in the 03-cluster.yaml file at the moment. They should be edited and kept safe from other users.

2. The Munge private key is specified in 03-cluster.yaml file at the moment. Again, this should be edited and the key information kept safe from other users.

3. We have done little-to-no testing of the security of the NFS service, so it might actually be mountable by other users which would be another major security hole.

4. MPI traffic is no-doubt insecure, and so someone else on the same K8S cluster can potentially interfere with computations or obtain all information shared/passed among the compute nodes.

Additional issues left to be fixed:

1. Must bring up 01-nfs-volume.yaml, 02-nfs-server.yaml and then obtain the IP address of the nfs service - provide it in 03-cluster.yaml before bringing up the rest of the deployment.

2. Not easily configurable: could make it into a helm chart for easier configuration and setup.

3. Currently, you will get a warning when the user logs in that the user's group has no name. This doesn't impact functionality in any significant way, but is annoying since it shows up when jobs are run on the scheduler, and when new shells start up.

4. The user should preferably specify the worker node sockets/cores/threads setup in the 03-cluster.yaml (slurm.conf section) file.

5. The number of workers is currently not flexible and they must be added/removed by adding/removing from the 03-cluster.yaml file.

Copyright 2021 - MTSU CS S-STEM Summer Research Group