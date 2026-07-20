# EXPRESSCLUSTER X on AWS

This repository covers deploying EXPRESSCLUSTER X high-availability clusters on Amazon Web Services (AWS). It includes guides for creating clusters, building automated machine images, and setting up a witness server.

## Contents

| Document | Description |
|---|---|
| [Create a Cluster on AWS](CreateCluster.md) | How to set up a mirror disk or shared disk EXPRESSCLUSTER cluster on AWS, including EBS volume configuration and network considerations. |
| [Build an Image with EXPRESSCLUSTER using EC2 Image Builder](EC2ImageBuilder.md) | How to automate the creation of Windows and Linux AMIs with EXPRESSCLUSTER pre-installed, using EC2 Image Builder, YAML component files, and PowerShell or Bash scripts. |
| [Build a Witness Server on AWS Lightsail](Lightsail-WitnessServer.pdf) | How to set up a lightweight witness server on AWS Lightsail for use as a tiebreaker in a 2-node EXPRESSCLUSTER cluster. |

## Scripts and YAML Files

The [ECXInstall](ECXInstall) folder contains the scripts and YAML component files referenced by the EC2 Image Builder guide:

| File | Platform | Description |
|---|---|---|
| `InstallECX.yml` | Windows | EC2 Image Builder component: downloads EXPRESSCLUSTER X installation script, validation script, and license files on Windows. Runs scripts. |
| `install-ecx.ps1` | Windows | Downloads EXPRESSCLUSTER X 5.2 from the NEC website, installs it silently, registers license files, and opens required firewall ports. |
| `testECXConfig.ps1` | Windows | Validates that EXPRESSCLUSTER firewall rules are in place and services are running. |
| `Linux/RHEL.yml` | RHEL (x86_64) | EC2 Image Builder component: installs EXPRESSCLUSTER X 5.2 on Red Hat Enterprise Linux. |
| `Linux/AMZNLIN2.yml` | Amazon Linux 2 (x86_64) | EC2 Image Builder component: installs EXPRESSCLUSTER X 5.2 on Amazon Linux 2. |
| `Linux/AMZNLIN2023x86.yml` | Amazon Linux 2023 (x86_64) | EC2 Image Builder component: installs EXPRESSCLUSTER X 5.2 on Amazon Linux 2023 (x86). |
| `Linux/AMZNLIN2023ARM64.yml` | Amazon Linux 2023 (ARM64) | EC2 Image Builder component: installs EXPRESSCLUSTER X 5.2 on Amazon Linux 2023 (ARM64). |
| `Linux/Ubuntu.yml` | Ubuntu (x86_64) | EC2 Image Builder component: installs EXPRESSCLUSTER X 5.2 on Ubuntu. |
