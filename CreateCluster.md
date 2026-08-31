# Create a Cluster on AWS

EXPRESSCLUSTER X supports two cluster storage topologies on AWS: **mirror disk** and **shared disk**.
This document covers the requirements and setup considerations for each.

## Table of Contents

1. [Mirror Disk Cluster](#mirror-disk-cluster)
2. [Shared Disk Cluster with EBS Multi-Attach](#shared-disk-cluster-with-ebs-multi-attach)
3. [Witness Server](#witness-server)
4. [Network Considerations](#network-considerations)

---

## Mirror Disk Cluster

A mirror disk cluster uses standard EBS volumes attached individually to each node. EXPRESSCLUSTER
synchronizes data between nodes over the network in real time. This is the most flexible topology
on AWS because it works across Availability Zones and with any EBS volume type (gp3, gp2, io2, etc.).

**Setup overview:**
1. Launch two EC2 instances — these can be in the same or different Availability Zones.
2. Attach an additional EBS volume to each instance for the mirror disk data partition.
3. Install EXPRESSCLUSTER X on both nodes.
4. Configure a mirror disk resource in the EXPRESSCLUSTER cluster configuration.

No special EBS configuration is required for mirror disk clusters. Use standard EBS volume attachment.

---

## Shared Disk Cluster with EBS Multi-Attach

A shared disk cluster uses a single EBS volume attached simultaneously to multiple EC2 instances.
EXPRESSCLUSTER controls which node has active access to the disk at any given time.

NEC has validated EXPRESSCLUSTER X with EBS Multi-Attach. For a detailed walkthrough, see the
[NEC EXPRESSCLUSTER blog post on building an HA cluster with EBS Multi-Attach](https://www.nec.com/en/global/prod/expresscluster/en/blog/20211202/we-built-an-ha-cluster-using-the-multi-attach-feature-of-amazon-ebs-windows_linux.html).

### Requirements

| Requirement | Detail |
|---|---|
| EBS volume type | **io1 or io2** (Provisioned IOPS only — gp2/gp3 do not support Multi-Attach) |
| I/O fencing | **io2 only** — io2 volumes support NVMe reservations for I/O fencing; io1 volumes do not |
| Instance types | **Nitro-based instances only** (e.g. M5, C5, R5, and later generations) |
| Availability Zone | All attached instances must be in the **same Availability Zone** |
| Maximum instances | Up to 16 instances per Multi-Attach volume |

> **Important:** EBS Multi-Attach is a single-AZ feature. If you require cross-AZ high availability,
> use a mirror disk cluster instead, or consider Amazon FSx for Windows File Server as the shared storage layer.

### Setup overview

1. Launch two EC2 instances (Nitro-based) in the **same Availability Zone**.
2. Create an EBS io2 volume with Multi-Attach enabled.
3. Attach the volume to both EC2 instances.
4. Install EXPRESSCLUSTER X on both nodes.
5. Configure a shared disk resource in the EXPRESSCLUSTER cluster configuration.
   EXPRESSCLUSTER's disk resource control ensures only the active node accesses the volume at any time.

The cluster can be built following the standard EXPRESSCLUSTER X shared disk cluster procedure described
in the EXPRESSCLUSTER X manual. No additional special configuration beyond enabling Multi-Attach on the
EBS volume is required.

> **Note on I/O fencing:** io2 volumes with NVMe reservations provide I/O fencing to maintain data
> consistency in the event of a split-brain scenario. This aligns with EXPRESSCLUSTER's SCSI-PR
> (SCSI Persistent Reservation) functionality. If using io1 volumes, I/O fencing is not available —
> io2 is strongly recommended for production shared disk clusters.

---

## Witness Server

For a 2-node cluster, a witness server provides a tiebreaker to prevent split-brain scenarios. An
AWS Lightsail instance is a cost-effective option for hosting a witness server on AWS.

See [Build a Witness Server on AWS Lightsail](Lightsail-WitnessServer.pdf) for setup instructions.

---

## Network Considerations

- **Virtual IP (VIP):** EXPRESSCLUSTER manages a virtual IP address for client access. On AWS, this
  requires configuring an AWS Virtual IP resource within EXPRESSCLUSTER, which uses the AWS API to
  reassign a secondary private IP address between nodes on failover.
- **Security Groups:** Ensure that the security groups for both cluster nodes allow inbound traffic
  on the EXPRESSCLUSTER communication ports between nodes. See the EXPRESSCLUSTER X installation
  guide for the list of required ports.
- **Subnets:** For mirror disk clusters across Availability Zones, nodes will be in different subnets.
  Ensure routing between subnets is in place and that EXPRESSCLUSTER's interconnect traffic can pass
  between them.
