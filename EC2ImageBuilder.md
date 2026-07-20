# EC2 Image Builder with EXPRESSCLUSTER X

EC2 Image Builder is a fully managed AWS service that automates the creation, maintenance,
validation, and deployment of Amazon Machine Images (AMIs). This document covers using EC2
Image Builder to build Windows and Linux AMIs with EXPRESSCLUSTER X pre-installed, so that
cluster nodes can be launched from a pre-configured image rather than set up manually each time.

New images can be created on demand or on a schedule, and can automatically include the latest
OS updates alongside custom components. YAML component files combined with PowerShell or Bash
scripts handle the EXPRESSCLUSTER installation and configuration steps.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
   - [S3 Bucket Setup](#s3-bucket-setup)
   - [IAM Role for EC2 Image Builder](#iam-role-for-ec2-image-builder)
   - [IAM Role for S3 Access (AWSTOE Local Testing)](#iam-role-for-s3-access-awstoe-local-testing)
2. [Files in ECXInstall](#files-in-ecxinstall)
3. [Create an Image Pipeline](#create-an-image-pipeline)
   - [Component Builder and YAML](#component-builder-and-yaml)
   - [Windows YAML Example](#windows-yaml-example)
4. [Testing Locally with AWSTOE](#testing-locally-with-awstoe)
   - [Prerequisites for Local Testing](#prerequisites-for-local-testing)
   - [Install AWSTOE](#install-awstoe)
   - [Set AWS Credentials](#set-aws-credentials)
   - [Validate and Run YAML Files](#validate-and-run-yaml-files)
5. [Linux YAML Files](#linux-yaml-files)
6. [References](#references)

---

## Prerequisites

### S3 Bucket Setup

Before building an image, upload the required scripts and files to an S3 bucket in the
**same AWS Region** as your EC2 Image Builder pipeline and instances.

**For Windows images**, upload:
- The EXPRESSCLUSTER PowerShell installation script `install-ecx.ps1`
- The EXPRESSCLUSTER PowerShell post-installation validation script `testECXConfig.ps1`
- Three EXPRESSCLUSTER license files: Alert (`X5x_ALRT.key`), Base (`X5x_Base.key`),
  and Replication (`X5x_REPL.key`)

**For Linux images**, upload the appropriate YAML file for your target OS, along with:
- The EXPRESSCLUSTER `.rpm` or `.deb` installation package (e.g. `expresscls-5.2.0-1.x86_64.rpm`)
- Three EXPRESSCLUSTER license files: Alert (`X5_Alrt_Lin.key`), Base (`X5_Base_Lin.key`),
  and Replication (`X5_Repl_Lin.key`)

### IAM Role for EC2 Image Builder

EC2 Image Builder requires a service role with permissions to launch EC2 instances, write logs
to CloudWatch, and read from your S3 bucket. AWS provides a managed policy for this:
`EC2InstanceProfileForImageBuilder`. Attach this policy (along with `AmazonSSMManagedInstanceCore`)
to an instance profile role and assign it to your Image Builder infrastructure configuration.

For full instructions, see
[Set up Image Builder prerequisites](https://docs.aws.amazon.com/imagebuilder/latest/userguide/image-builder-setting-up.html).

### IAM Role for S3 Access (AWSTOE Local Testing)

When testing YAML files locally on an EC2 instance using AWSTOE, the instance needs read access
to your S3 bucket. Create a role with the `AmazonS3ReadOnlyAccess` policy and attach it to your
test instance. See [IAM Setup](#iam-setup) at the end of this document for step-by-step instructions.

---

## Files in ECXInstall

The [ECXInstall](ECXInstall) folder contains the YAML component files and scripts used during
the image build process. Update the `$ECX_URL` parameter
default value if using a different version.

### Windows

| File | Description |
|---|---|
| `InstallECX.yml` | EC2 Image Builder component. Build phase: downloads and runs `install-ecx.ps1`, then installs Windows updates. Validate phase: downloads and runs `testECXConfig.ps1`. Replace `<bucketname>` with your S3 bucket name before use. Targets EXPRESSCLUSTER X 5.2. |
| `install-ecx.ps1` | Downloads EXPRESSCLUSTER X 5.2 from the NEC website, extracts and silently installs it, registers license files, and opens required firewall ports using `clpfwctrl.bat`. Logs to `c:\temp\Install_Log.txt`. |
| `testECXConfig.ps1` | Validates the installation by checking that EXPRESSCLUSTER firewall rules are present and EXPRESSCLUSTER services are registered. |

### Linux

All Linux YAML files install EXPRESSCLUSTER X 5.2. Update the `ECXrpm` (or `ECXdeb`) parameter
default value if using a different version. The `S3Bucket` parameter must also be updated to match
your bucket name.

| File | OS | Architecture | Notes |
|---|---|---|---|
| `RHEL.yml` | Red Hat Enterprise Linux | x86_64 | Installs `firewalld` if not present, opens ports, disables SELinux, disables DNF cache timer, reboots. |
| `AMZNLIN2.yml` | Amazon Linux 2 | x86_64 | Installs `firewalld` if not present, opens ports, disables SELinux. No reboot step — reboot manually or add one if needed. |
| `AMZNLIN2023x86.yml` | Amazon Linux 2023 | x86_64 | Installs `libxcrypt-compat` (required by EXPRESSCLUSTER), then same steps as RHEL. No reboot step. |
| `AMZNLIN2023ARM64.yml` | Amazon Linux 2023 | ARM64 | Same as `AMZNLIN2023x86.yml` but uses the `aarch64` RPM package. |
| `Ubuntu.yml` | Ubuntu | x86_64 (amd64) | Uses `.deb` package via `dpkg`. Does not configure firewall rules or reboot — add these steps manually if your environment requires them. |

> **Note:** Update the version references in the relevant script files to match your licensed version
> of EXPRESSCLUSTER before use.

---

## Create an Image Pipeline

Amazon provides a console wizard to
[create an image pipeline](https://docs.aws.amazon.com/imagebuilder/latest/userguide/start-build-image-pipeline.html).
The pipeline defines the base image, the components to apply, the infrastructure to build on, and
the distribution targets for the finished AMI.

### Component Builder and YAML

The pipeline's **recipe** includes a **Components** section where you add YAML component documents.
Each component can have up to three phases: **build**, **validate**, and **test**. Not all phases
are required.

A minimal YAML component looks like this:

```yaml
name: "ExampleComponent-Windows"
description: "Demonstrates the component document structure."
schemaVersion: 1.0
parameters:
  - InputParameter:
      type: string
      default: "example value"
      description: An input parameter.
phases:
  - name: build
    steps:
      - name: BuildStep1
        action: ExecutePowerShell
        inputs:
          commands:
            - Write-Host "Build phase. Parameter value is {{ InputParameter }}"

  - name: validate
    steps:
      - name: ValidateStep1
        action: ExecutePowerShell
        inputs:
          commands:
            - Write-Host "Validate phase."

  - name: test
    steps:
      - name: TestStep1
        action: ExecutePowerShell
        inputs:
          commands:
            - Write-Host "Test phase."
```

### Windows YAML Example

The following snippet shows the pattern used in `InstallECX.yml`: download a PowerShell script
from S3, run it, delete it, reboot, and install Windows updates. This is the core of the build phase:

```yaml
phases:
  - name: build
    steps:
      - name: DownloadECXScript
        action: S3Download
        timeoutSeconds: 60
        onFailure: Abort
        maxAttempts: 3
        inputs:
          - source: 's3://<bucketname>/install-ecx.ps1'
            destination: 'C:\install-ecx.ps1'

      - name: RunConfigScript
        action: ExecutePowerShell
        timeoutSeconds: 120
        onFailure: Abort
        maxAttempts: 3
        inputs:
          file: '{{build.DownloadECXScript.inputs[0].destination}}'

      - name: Cleanup
        action: DeleteFile
        onFailure: Abort
        maxAttempts: 3
        inputs:
          - path: '{{build.DownloadECXScript.inputs[0].destination}}'

      - name: RebootAfterConfigApplied
        action: Reboot
        inputs:
          delaySeconds: 60

      - name: InstallWindowsUpdates
        action: UpdateOS
```

The full `InstallECX.yml` file downloads license files and adds a validate phase that downloads and runs `testECXConfig.ps1`
to confirm that EXPRESSCLUSTER firewall rules and services are in place before the AMI snapshot
is taken.

Replace `<bucketname>` in the YAML file with your actual S3 bucket name before uploading it to
Image Builder or running it with AWSTOE.

---

## Testing Locally with AWSTOE

The AWS Task Orchestrator and Executor (AWSTOE) is a standalone application that can run and
validate YAML component files without going through the full EC2 Image Builder pipeline. This
makes it much faster to iterate and troubleshoot your YAML files and scripts.

> **Recommendation:** Test on an EC2 instance in the same Region as your S3 bucket. This avoids
> having to configure AWS credentials manually — the instance's attached IAM role handles access.

### Prerequisites for Local Testing

1. Upload your PowerShell scripts to your S3 bucket.
2. [Create an IAM role](#create-an-iam-role-that-grants-access-to-amazon-s3-from-an-instance)
   that grants read access to your S3 bucket.
3. [Attach that IAM role to the EC2 instance](#attach-the-iam-role-to-the-ec2-instance) you will
   use for testing.
4. Edit the YAML file and replace the `<bucketname>` placeholder with your bucket name.
5. Copy the YAML file to the EC2 instance.
6. [Download and install AWSTOE](#install-awstoe) on the instance.

### Install AWSTOE

AWSTOE is a standalone executable — no installation step is required. Download the binary for
your platform from the
[AWSTOE downloads page](https://docs.aws.amazon.com/imagebuilder/latest/userguide/toe-get-started.html)
and copy it to your instance.

> **TLS requirement:** Accessing the AWSTOE download requires TLS 1.2 or later. Ensure your
> instance's HTTP client supports TLS 1.2 before downloading.

### Set AWS Credentials

If running on an EC2 instance with an IAM role attached, no manual credential setup is needed —
AWSTOE uses the instance profile automatically.

If running off an EC2 instance (e.g. on-premises), set credentials via environment variables:

**Windows (PowerShell):**
```powershell
$env:AWS_ACCESS_KEY_ID = "your-access-key"
$env:AWS_SECRET_ACCESS_KEY = "your-secret-key"
$env:AWS_DEFAULT_REGION = "us-east-1"
```

**Linux/macOS:**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### Validate and Run YAML Files

**Validate YAML syntax only (no execution):**
```
awstoe.exe validate --documents C:\InstallECX.yml
```

**Run all phases in a YAML file:**
```
awstoe.exe run --documents C:\InstallECX.yml
```

**Log files** are created in a subdirectory under the folder where `awstoe.exe` is run. Review
these logs to troubleshoot any failures — they include the output of each step and any error
messages.

---

## Linux YAML Files

The Linux YAML files follow the same general structure: create a temp folder, download the
EXPRESSCLUSTER package from S3, install it, download and register license files, configure the
firewall, clean up, and validate.

Key differences between the Linux YAML files:

**Amazon Linux 2023 (x86 and ARM64) vs. Amazon Linux 2 and RHEL:**
- AL2023 files include an additional first step that installs `libxcrypt-compat` via `dnf`.
  This package is required by EXPRESSCLUSTER on AL2023 but is already present on AL2 and RHEL.
- AL2023 files also disable the `dnf-makecache.timer` to prevent background repository cache
  updates that can interfere with image builds.
- AL2023 files do not include a reboot step. If a reboot is needed (e.g. for SELinux disablement
  to take effect), add a `Reboot` action step before the validate phase.

**Ubuntu vs. RPM-based distributions:**
- `Ubuntu.yml` uses `dpkg -i` to install the `.deb` package instead of `rpm -i`.
- `Ubuntu.yml` does not include firewall configuration steps. Ubuntu uses `ufw` rather than
  `firewalld`, so `clpfwctrl.sh` currently does not run on Ubuntu. Add explicit `ufw` rules if needed.
- `Ubuntu.yml` does not include a reboot step. Add one if required.
- The validate phase for Ubuntu does not check firewall state, as the other Linux files do.

**RHEL vs. Amazon Linux 2:**
- `RHEL.yml` includes a reboot step at the end of the build phase. `AMZNLIN2.yml` does not.
- The `CheckFirewall` step in all RPM-based files uses `yum` to install `firewalld` if it is
  not already present. On Amazon Linux 2023, `yum` is a compatibility alias for `dnf` — both
  work, but `dnf` is preferred on AL2023.

### Running a Linux YAML file with AWSTOE

The syntax is the same as for Windows:

```bash
./awstoe run --documents RHEL.yml
```

To override default parameter values (e.g. to use a different ECX version or bucket name):

```bash
./awstoe run --documents RHEL.yml --parameters '[{"name":"S3Bucket","value":"mybucket"},{"name":"ECXrpm","value":"expresscls-5.2.0-1.x86_64.rpm"}]'
```

---

## IAM Setup

### Create an IAM Role that Grants Access to Amazon S3 from an Instance

1. Open the [IAM console](https://console.aws.amazon.com/iam).
2. Choose **Roles**, then **Create role**.
3. Select **AWS Service** as the trusted entity type, then choose **EC2** under Use case.
4. Click **Next** for Permissions.
5. Search for and select **AmazonS3ReadOnlyAccess**.
6. Click **Next**, enter a Role name (e.g. `AWSInstanceS3ReadAccess`), and click **Create role**.

### Attach the IAM Role to the EC2 Instance

1. Open the [Amazon EC2 console](https://console.aws.amazon.com/ec2).
2. Choose **Instances** and select your instance.
3. Choose **Actions** → **Security** → **Modify IAM role**.
4. Select the role you just created (e.g. `AWSInstanceS3ReadAccess`) and choose **Update IAM role**.

The instance can now read from your S3 bucket, allowing AWSTOE to download scripts during testing.

---

## References

- [What is EC2 Image Builder?](https://docs.aws.amazon.com/imagebuilder/latest/userguide/what-is-image-builder.html)
- [Create an image pipeline using the EC2 Image Builder console wizard](https://docs.aws.amazon.com/imagebuilder/latest/userguide/start-build-image-pipeline.html)
- [Manual set up to develop custom components with AWSTOE](https://docs.aws.amazon.com/imagebuilder/latest/userguide/toe-get-started.html)
- [AWSTOE action modules reference](https://docs.aws.amazon.com/imagebuilder/latest/userguide/toe-action-modules.html)
- [EC2 Image Builder console](https://console.aws.amazon.com/imagebuilder/)
