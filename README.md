# MTSU CS S-STEM Cloud Infrastructure 2020

## Project: **Stand-alone K8S HPC Cluster**

## Purpose:

This project aims to create a fully functioning HPC cluster deployable on Kubernetes. The cluster will utilize Singularity containers for software management so that the deployed HPC cluster is capable of running any scientific application over Singularity/OpenMPI/SLURM. An NFS server and OpenLDAP server are also used to provide the shared file system and user authentication for the cluster (these could be replaced with already-existing alternatives if need-be).

## TL;DR:

To deploy/use the HPC cluster, you will need a functioning Kubernetes  cluster (we typically use **[k3s](https://k3s.io/)**) with host machines running **Ubuntu 20.04 LTS**. If you use another OS, your mileage may vary. You will also need to have the **NFS client** package/utilites installed **on all host machines in your cluster** so that your containers can mount the NFS server for the HPC cluster: `sudo apt-get install nfs-common` If you use **[k3d](https://k3d.io/)** (k3s in docker) for development/testing, then **you will have to mount the docker host's /sys/fs/cgroup on all of the server/agent containers** (see the documentation for `k3d cluster create` but a quick example is something like: `k3d cluster create -v /sys/fs/cgroup:/sys/fs/cgroup@server[0]`).

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
```text
NAME   TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                      AGE
nfs    ClusterIP   10.43.203.4   <none>        2049/TCP,20048/TCP,111/TCP   11s
```
Change 03-cluster.yaml (line 13) accordingly:
```text
  nfs:
    # Must be manually updated each re-deployment
    server: 10.43.203.4
```


5. Additional modifications to 03-cluster.yaml (ConfigMap openldap-login-public, slurm.conf section) may be needed to match the 4 (default) worker agent pods to your machines' architecture(s) (sockets/cores/threads) and uncomment pod antiaffinity rules in the StatefulSet for the agent pods if you want to distribute workers across nodes (see K8S docs if unsure, or just leave alone for testing purposes). In general, this config should match the number of agent replicas requested (here, 0-3):
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
```text
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


9. Download a testing singularity image (mpitest.sif), allocate a node on the cluster (8 procs by default), run the singularity job over OpenMPI, and then exit out:
```sh
wget https://www.cs.mtsu.edu/~jphillips/mpitest.sif
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
```sh
sinfo
```
```text
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
batch*       up 7-00:00:00      1  alloc agent-0
batch*       up 7-00:00:00      3   idle agent-[1-3]
```
```sh
mpiexec -n 8 singularity run mpitest.sif /opt/mpitest
```
Now you should see the ranks complete the computation (shown WARNINGS still being resolved but shouldn't have any significant impact on the calculations):
```text
WARNING: group: unknown groupid 1000
WARNING: group: unknown groupid 1000
WARNING: group: unknown groupid 1000
WARNING: group: unknown groupid 1000
WARNING: group: unknown groupid 1000
WARNING: group: unknown groupid 1000
WARNING: group: unknown groupid 1000
WARNING: group: unknown groupid 1000
Hello, I am rank 0/8
Hello, I am rank 3/8
Hello, I am rank 4/8
Hello, I am rank 5/8
Hello, I am rank 7/8
Hello, I am rank 1/8
Hello, I am rank 2/8
Hello, I am rank 6/8
```
Drop out of the job shell:
```sh
exit
```
You can now run any SLURM job in the `batch` queue as-provided (see the SLURM docs). Log out of the cluster using `exit` again if you are finished testing.


10. Tear it all down. This will usually takes less time than just deleting the namespace (since some pods will hang waiting to close out the NFS connections if the NFS server shuts down too quickly), and also allows more control over the break-down process:
First shutdown the OpenLDAP, Scheduler, Workers, and *then* shut down the NFS server:
```sh
kubectl -n hpc delete -f 03-cluster.yaml
kubectl -n hpc delete -f 02-nfs-server.yaml
```
(OPTIONAL) if you also *want* to delete the filesystem data (you can skip this step if you want the data to be available if/when you bring the cluster up again later):
```sh
kubectl -n hpc delete -f 01-nfs-volume.yaml
```
After this you can remove the namespace (even if you skipped the optional step above):
```sh
kubectl delete namespace hpc
```


## Advantages:

Some cool things this deployment **DOES** do right:

1. The current HPC cluster deployment can brought up and torn down on any K8S cluster.

2. Nodes can be tagged and agent containers assigned to nodes using these tags, but just uncomment the antiaffinity rules provided in 03-cluster.yaml and agents will automatically distributed one-per-node (using hostname antiaffinity rules).

3. A functioning Ubuntu 20.04 - OpenMPI/Singularity/SLURM deployment is provided so that *potentially any* scientific application can be run on the HPC cluster.

4. Different clusters can be created in different K8S namespaces to support unique/differing cluster topologies (nodeSelector and antiaffinity rules can be used to assign agents to relevant nodes).

5. Both the NFS and OpenLDAP components can be easily replaced with exiting NFS or OpenLDAP infrastructure using K8S ConfigMaps.

## Shortcomings:

At this point, the cluster is fully functional, but **VERY INSECURE**. You should only use it for testing purposes, and not production scientific computing. Here are the main security holes that we are aware of (and there may be many others):

1. OpenLDAP credentials are saved in the 03-cluster.yaml file at the moment. They should be edited and kept safe from other users.

2. The Munge private key is specified in 03-cluster.yaml file at the moment. Again, this should be edited and the key information kept safe from other users.

3. We have done little-to-no testing of the security of the NFS service, so it might actually be mountable by other users which would be another major security hole. There are networking guidelines in current k8s installations which suggest that this should not really be the case: it just needs to be confirmed.

4. MPI traffic is no-doubt insecure, and so someone else on the same K8S cluster can potentially interfere with computations or obtain all information shared/passed among the compute nodes. In general, it probably makes sense to run a seperate k8s installation on each cluster, or at least only only nodes where the users are trusted to run and inspect scientific applications (just like a standard HPC cluster). Some additional configuration is needed to prevent users from directly logging into the agents as well.

Additional issues left to be fixed:

1. Must bring up 01-nfs-volume.yaml, 02-nfs-server.yaml and then obtain the IP address of the nfs service - provide it in 03-cluster.yaml before bringing up the rest of the deployment.

2. Not easily configurable: could make it into a helm chart for easier configuration and setup.

3. Currently, you will get a warning when the user logs in that the user's group has no name. This doesn't impact functionality in any significant way, but is annoying since it shows up when jobs are run on the scheduler, and when new shells start up.

4. The user should preferably specify the worker node sockets/cores/threads setup in the 03-cluster.yaml (slurm.conf section) file and match this with the number of replicas requested by the agent StatefulSet.

Copyright 2021 - MTSU CS S-STEM Summer Research Group
