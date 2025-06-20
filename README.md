# Fiorali Infrastructure Operations Repository

Kubernetes cluster managed with ArgoCD and GitHub Actions, using Longhorn for persistent storage

[![k3s](https://img.shields.io/endpoint?url=https://jaredfiorali.github.io/infrastructure/kubernetes_version.json&style=for-the-badge&logo=kubernetes&logoColor=white&labelColor=blue&color=green&label=k3s)](https://k3s.io)
[![DietPi](https://img.shields.io/endpoint?url=https%3A%2F%2Fjaredfiorali.github.io%2Finfrastructure%2Fdietpi_version.json&style=for-the-badge&logo=raspberrypi&logoColor=white&labelColor=blue&color=green&label=dietpi)](https://dietpi.com)
[![ArgoCD](https://img.shields.io/endpoint?url=https://jaredfiorali.github.io/infrastructure/argocd_version.json&style=for-the-badge&logo=argo&logoColor=white&labelColor=blue&color=green&label=argocd)](https://argo-cd.readthedocs.io/en/stable)

![Uptime](https://img.shields.io/endpoint?url=https://jaredfiorali.github.io/infrastructure/cluster_uptime_days.json&style=flat-square&label=Uptime)
![Nodes](https://img.shields.io/endpoint?url=https://jaredfiorali.github.io/infrastructure/cluster_node_count.json&style=flat-square&label=Nodes)
![Pods](https://img.shields.io/endpoint?url=https://jaredfiorali.github.io/infrastructure/cluster_pod_count.json&style=flat-square&label=Pods)
![CPU](https://img.shields.io/endpoint?url=https://jaredfiorali.github.io/infrastructure/cluster_cpu_usage.json&style=flat-square&label=CPU)
![Memory](https://img.shields.io/endpoint?url=https://jaredfiorali.github.io/infrastructure/cluster_memory_usage.json&style=flat-square&label=Memory)
![Power](https://img.shields.io/endpoint?url=https://jaredfiorali.github.io/infrastructure/cluster_power_usage.json&style=flat-square&label=Power)
![Popeye](https://img.shields.io/endpoint?url=https://jaredfiorali.github.io/infrastructure/cluster_popeye_score.json&style=flat-square&label=Popeye)

This is a mono repository for my home infrastructure and Kubernetes cluster. I try to adhere to Infrastructure as Code (IaC) and GitOps practices using tools like [ArgoCD](https://argo-cd.readthedocs.io/en/stable), [Kubernetes](https://kubernetes.io), and [GitHub Actions](https://github.com/features/actions).

## Kubernetes

The Kubernetes cluster is running across 10 Raspberry Pi's, where 5 of the nodes are Raspberry Pi 4's (worker nodes), and the other 5 are Raspberry Pi 5's (master nodes). Node names are denoted with a numeric suffix, depending on their physical placement in the server room.

| Hardware Model  | Node Name   | Role   | Storage   |
|-----------------|-------------|--------|-----------|
| Raspberry Pi 4  | rpi4-node-x | worker | 500GB USB |
| Raspberry Pi 5  | rpi5-node-x | master | 2TB SSD   |

In a typical setup, workloads are only provisioned on worker nodes. However given the compute requirements for the entire cluster, workloads are provisioned across all nodes. In essence the only discernable difference between master and worker nodes is that `kubectl` commands can be run against the master nodes.

## Storage

Storage is handled by [Longhorn](https://longhorn.io). Storage is split between node types (you can reference the [Kubernetes hardware for details](#kubernetes)).

Given the speed difference between the two disk types (SSD vs USB), slower long term volumes are provisioned on the USB drives while the volumes that require speed are stored on the SSD's. The majority of volumes are configured with 2 replicas in the event a single node goes down.

A small subset (~10G) of "critical" data is [sent to an Amazon S3 bucket](https://ca-central-1.console.aws.amazon.com/console/home), in order to ensure that data will be secure in the event of an unrecoverable error in the cluster. Data being backed up includes (but is not limited to): dawarich, home-assistant, influxdb.

## Applications

Each application is defined in the [charts/fiorali](./charts/fiorali) directory. Below you will find a quick explainer on each application.

### Media Management

| Application                                 | Importance | Purpose                                              |
|---------------------------------------------|------------|------------------------------------------------------|
| [plex](https://www.plex.tv)                 | 🟠         | Serves local media (Movies, TV, Workout Videos, etc) |
| [prowlarr](https://prowlarr.com)            | 🔴         | Supplements radarr/sonarr with additional indexers   |
| [radarr](https://radarr.video)              | 🔴         | Movie indexer                                        |
| [sonarr](https://sonarr.tv)                 | 🔴         | TV Show indexer                                      |
| [tautulli](https://tautulli.com)            | 🔴         | Keeps track of various statistics for Plex           |
| [transmission](https://transmissionbt.com)  | 🔴         | Torrent downloader                                   |
| [gluetun](https://github.com/qdm12/gluetun) | 🔴         | VPN sidecar for transmission                         |

### Kubernetes Core

| Application                                                         | Importance | Purpose                                                    |
|---------------------------------------------------------------------|------------|------------------------------------------------------------|
| [longhorn](https://longhorn.io)                                     | 🟢         | Provisions persistent storage for Applications             |
| [argocd](https://argo-cd.readthedocs.io)                            | 🟠         | Deploys changes to this repo to the cluster                |
| [argocd-image-updater](https://argocd-image-updater.readthedocs.io) | 🟠         | Scans remote docker images and syncs this repo if there are updates |

### Monitoring

| Application                                        | Importance | Purpose                                                            |
|----------------------------------------------------|------------|--------------------------------------------------------------------|
| [alloy](https://grafana.com/docs/alloy)            | 🔴         | Scans pod logs and saves them to loki                              |
| git-sync                                           | 🔴         | Custom script to read kromgo endpoints and save metrics to git     |
| [grafana](https://grafana.com/docs/grafana/latest) | 🔴         | Create and display various dashboards for monitoring the cluster   |
| [kromgo](https://github.com/kashalls/kromgo)       | 🔴         | Easily surfaces and formats pre-defined prometheus queries         |
| [loki](https://grafana.com/docs/loki)              | 🔴         | Aggregates alloy output and log query tool                         |
| [prometheus](https://prometheus.io)                | 🔴         | Queryable bucket for cluster metrics                               |
| [popeye](https://popeyecli.io)                     | 🔴         | "linter" for the cluster                                           |
| [unifi-poller](https://unpoller.com)               | 🔴         | Scans the Unifi network equipment and stores metrics in prometheus |

### Home Security

| Application                                     | Importance | Purpose |
|-------------------------------------------------|------------|---------------------------------------------------------------------|
| [scrypted](https://www.scrypted.app)            | 🟠         | Reads Unifi camera feed and exposes it to HomeKit                   |
| [home-assistant](https://www.home-assistant.io) | 🟠         | Allows for complex automation to be written for various IoT devices |

### Other

| Application                                                    | Importance | Purpose                                                          |
|----------------------------------------------------------------|------------|------------------------------------------------------------------|
| [dawarich-app/dawarich-db](https://github.com/Freika/dawarich) | 🔴         | Stores ingested location data (from HA) and displays it on a map |
| [emulatorjs](https://emulatorjs.org)                           | 🔴         | Console emulator written in JS                                   |
| [influxdb](https://www.influxdata.com/products/influxdb)       | 🟢         | Stores data for the "reflection" app                             |
| [linkding](https://github.com/sissbruecker/linkding)           | 🔴         | Bookmark manager                                                 |
| [sillytavern](https://github.com/SillyTavern/SillyTavern)      | 🔴         | LLM chat frontend                                                |
| [speedtest](https://openspeedtest.com)                         | 🔴         | Local speedtest server to check internal network speeds          |
| [timemachine](https://github.com/mbentley/docker-timemachine)  | 🔴         | Stores MacOS backups                                             |

### Application Dependency Diagram

```mermaid
graph LR
L[grafana]:::blue -----> |depends| H[replicated\nvolumes]
Z[git-sync]:::blue --> |depends| N[kromgo]
N[kromgo]:::blue --> |depends| I[prometheus]
A[plex]:::red -----> |depends| H[replicated\nvolumes]
B[prowlarr]:::red -----> |depends| H[replicated\nvolumes]
C[radarr]:::red -----> |depends| H[replicated\nvolumes]
C[radarr]:::red ---> |depends| B[prowlarr]
C[radarr]:::red ---> |depends| F[transmission]
D[sonarr]:::red -----> |depends| H[replicated\nvolumes]
D[sonarr]:::red ---> |depends| B[prowlarr]
D[sonarr]:::red ---> |depends| F[transmission]
E[tautulli]:::red -----> |depends| H[replicated\nvolumes]
E[tautulli]:::red ---> |depends| A[plex]
F[transmission]:::red -----> |depends| H[replicated\nvolumes]
F[transmission]:::red ---> |depends| G[gluetun]
O[loki]:::blue ---> |depends| K[alloy]
T[dawarich-app]:::orange ---> |depends| U[dawarich-db]
T[dawarich-app]:::orange ---> |depends| P[dawarich-redis]
T[dawarich-app]:::orange ---> |depends| Q[dawarich-sidekiq]
T[dawarich-app]:::orange ---> |depends| H[replicated\nvolumes]
M[influxdb]:::orange -----> |depends| H[replicated\nvolumes]
U[dawarich-db]:::orange ---> |depends| H[replicated\nvolumes]
P[dawarich-redis]:::orange ---> |depends| H[replicated\nvolumes]
Q[dawarich-sidekiq]:::orange ---> |depends| H[replicated\nvolumes]
V[linkding]:::orange -----> |depends| H[replicated\nvolumes]
Y[timemachine]:::orange -----> |depends| H[replicated\nvolumes]
R[scrypted]:::green -----> |depends| H[replicated\nvolumes]
S[home-assistant]:::green -----> |depends| H[replicated\nvolumes]
I[prometheus]:::blue
G[gluetun]:::red
K[alloy]:::blue
H:::pink@{ shape: processes, label: "replicated\nvolumes" } <--- |< provisions| J[longhorn]:::pink

classDef red stroke:#f00
classDef blue stroke:#00f
classDef green stroke:#0f0
classDef orange stroke:#f96
classDef pink stroke:#f9f
```

## Directories

This Git repository contains the following directories for the [Kubernetes](./charts/fiorali) deployments.

```sh
📁 charts
├── 📁 fiorali        # application value definitions
   ├── 📄 Chart.yaml  # sets the version of the compiled helm charts
   ├── 📁 templates   # helm charts use to populate values
   ├── 📁 scripts     # various helper scripts
```

## Deployment workflow

### Codebase (Helm)

Each application is defined by a unique helm chart. The helm chart defines what kind of resources each application will need (deployment, service, networkPolicy, etc).

### Compiling Charts (Github Action)

When code is pushed to the `master` branch, it triggers a Github action which [compiles and packages](https://github.com/jaredfiorali/infrastructure/releases) the helm charts into actual kubernetes yaml files that can be used in deployments, and then publishes them via [github pages](https://github.com/jaredfiorali/infrastructure/deployments/github-pages).

### CD Pipeline (ArgoCD)

[ArgoCD](https://argo-cd.readthedocs.io) is the deployment automation tool that I use to keep each defined application in sync with the code defined in this repo. ArgoCD will watch for any code changes, and if any changes are discovered, it will auto-sync the updated application code with the cluster.

Most applications are configured to automatically sync with the latest version, with Longhorn as a notable exception. Given how critical that application is (as it manages the storage for most other applications), I have decided it makes sense to have it manually updated.

### Updates (argocd-image-updater)

The last piece of this system is the [argocd-image-updater](https://argocd-image-updater.readthedocs.io). Within each application is a definition to scan a specific docker image, and if an update is found, then the argocd-image-updater will update the code repo with the updated image.

In order to apply the updated image to the cluster, an update to the [Chart.yaml](./charts/fiorali/Chart.yaml) file will need to be done, as ArgoCD will only deploy when there's a chart version update, not a repo commit. This is helpful, as it means updates are as frequent as I want them to be.

```mermaid
graph TD
    A>User] -->|Commits| B(Github Repo)
    B>Github Repo] -->|Compiles Helm Charts| C>Github Pages]
    D>ArgoCD] -->|Reads| C(Github Pages)
    D>ArgoCD] -->|Deploys| E(Kubernetes Cluster)
    F>External Repo] -->|Watched By| G(ArgoCD Image Updater)
    G>ArgoCD Image Updater] -->|Updates| C(Github Pages)
```

## Network

The network infrastructure consists largely of [Unifi hardware](#hardware), which is managed through the [Unifi App portal](https://unifi.ui.com).

High level network diagram can be found below. Note that each connection denotes an ethernet connection.

```mermaid
graph TD
    A(Modem) --> B(Gateway UDM SE - Backup)
    A(Modem) --> C(Gateway UDM SE - Primary)
    B(Gateway UDM SE - Backup) --> D(USW Pro Max 24 PoE)
    C(Gateway UDM SE - Primary) --> D(USW Pro Max 24 PoE)
    D(USW Pro Max 24 PoE) --> E(U7 Pro XG - Family Room)
    D(USW Pro Max 24 PoE) --> F(U6 Mesh - Dining Room)
    D(USW Pro Max 24 PoE) --> G(USW-Ultra - Theatre)
    G(USW-Ultra - Theatre) --> H(U6-IW - Theatre)
    D(USW Pro Max 24 PoE) --> I(G4 Dome - East Camera)
    D(USW Pro Max 24 PoE) --> J(UP FloodLight - East Light)
    D(USW Pro Max 24 PoE) ---> K(USW Flex 2.5G - Garage)
    K(USW Flex 2.5G - Garage) --> L(U6-IW - Office)
    K(USW Flex 2.5G - Garage) --> M(G5 PTZ - Driveway Camera)
    K(USW Flex 2.5G - Garage) --> N(UP FloodLight - West Light)
```

### DNS

There is a network wide configuration which forces all traffic on port 53 to route to a specific CloudFlare endpoint. This endpoint was configured in using [CloudFlare's Zero Trust feature](https://one.dash.cloudflare.com), and essentially acts as an ad blocker across the network.

[There is a GitHub Action in this repo](https://github.com/jaredfiorali/Cloudflare-Gateway-Pihole) which runs every so often and updates the block list on CloudFlare's end. In rare cases the block list will incidentally block legitimate applications, which will need to be added to the Allow List.

### VPN

Trusted devices are configured with a [wireguard client provided by Unifi](https://help.ui.com/hc/en-us/articles/115005445768-UniFi-Gateway-WireGuard-VPN-Server), which automatically connects to the VPN when the device has left the local network.

Due to the DNS being forced to route to CloudFlare's Zero Trust (in order to get the Ad Blocker blocking over VPN) some WiFi networks (typically enterprise networks) do not work, since they have their own DNS block to force users to use their own DNS entry. At this point I usually skip connecting to enterprise WiFi networks for this reason.

## Hardware

### Server Rack

| Device                   | Function                        |
|--------------------------|---------------------------------|
| Raspberry Pi 5 (x5)      | Kubernetes master nodes         |
| Unifi USW Pro Max 24 PoE | Network Switch                  |
| Raspberry Pi 4 (x5)      | Kubernetes worker nodes         |
| Unifi UDM SE (Backup)    | Network Gateway (Backup)        |
| Unifi UDM SE (Primary)   | Network Gateway (Primary) & NVR |
| UniFi USP PDU Pro        | Monitored power outlets         |
| CyberPower CP1500PFCRM2U | Uninterruptible Power Supply    |

### Additional Devices

| Device              | Function                   |
|---------------------|----------------------------|
| Mac Studio          | Personal PC, hosts LLM     |
| Unifi U6-IW         | Access Point - Office      |
| Unifi U6-IW         | Access Point - Theatre     |
| Unifi U7 Pro XG     | Access Point - Family Room |
| Unifi U6-Mesh       | Access Point - Dining Room |
| Unifi USW-Ultra     | Network Switch - Theatre   |
| Unifi USW Flex 2.5G | Network Switch - Garage    |
| G5 PTZ              | Driveway Camera            |
| G4 Dome             | East Side Camera           |
| UP FloodLight       | East Side Floodlight       |
| UP FloodLight       | West Side Floodlight       |

## Handy Links

Here's a list of all the services that can be reached via a web portal (within the network):

- [argocd](http://argo.fiora.li)
- [dawarich](http://dawarich.fiora.li)
- [plex](http://plex.fiora.li)
- [prowlarr](http://prowlarr.fiora.li)
- [radarr](http://radarr.fiora.li)
- [sonarr](http://sonarr.fiora.li)
- [transmission](http://transmission.fiora.li)
- [emulatorjs](http://emulatorjs.fiora.li)
- [home-assistant](http://home-assistant.fiora.li)
- [linkding](http://linkding.fiora.li)
- [longhorn](http://longhorn.fiora.li)
- [grafana](http://grafana.fiora.li)
- [influxdb](http://influxdb.fiora.li)
- [kromgo](http://kromgo.fiora.li)
- [prometheus](http://prometheus.fiora.li)
- [scrypted](http://scrypted.fiora.li)
- [sillytavern](http://sillytavern.fiora.li)
- [speedtest](http://speedtest.fiora.li)
- [tautulli](http://tautulli.fiora.li)

I also use [k9s](http://k9scli.io) to easily run kubernetes commands against the cluster. Easier than remembering/aliasing kubectl commands :D
