# EC2 Image Builder
An [AWS website](https://aws.amazon.com/image-builder/faqs/) gives the following description of EC2 Image Builder: it \"simplifies the creation, maintenance, validation, sharing, and deployment of Linux or Windows images for use with Amazon EC2 and on-premises.\" This document focuses mainly on using EC2 Image Builder for automating the creation of Windows images.    

New images can be created and deployed manually or on a set schedule with EC2 Image Builder. These images can automatically include the latest OS updates, a number of preset components specified by AWS, or your own components to install and configure custom software. YAML configuration files can be used with PowerShell scripts to install and configure ExpressCluster X on Windows images. These PowerShell scripts can be stored in an Amazon S3 bucket and utilized during the image build process. The first step of automation is to build an image pipeline.

## Create an image pipeline
Amazon provides instructions on how to [Create an image pipeline](https://docs.aws.amazon.com/imagebuilder/latest/userguide/start-build-image-pipeline.html) using the EC2 Image Builder console wizard.

### Component builder
There is a **Components** section which is part of the process of creating a recipe for image creation. This section is where YAML script code can be inserted to enable the automatic installation of ExpressCluster to the image to be created. The next section describes how to create YAML code to execute a PowerShell script which can install and configure ExpressCluster on the new image.

#### YAML
The YAML component builder includes three possible phases: **build**, **validate**, and **test**. It is not necessary to run each phase. Following is an example of this YAML file syntax:
```
name: "TestDocument-Windows"
description: "Document to demonstrate parameters."
schemaVersion: 1.0
parameters:
  - InputParameter:
      type: string
      default: "Parameter test section"
      description: Input parameter.
phases:
  - name: build
    steps:
      - name: BuildStep1
        action: ExecutePowerShell
        inputs:
          commands:
            - Write-Host "Build phase. The input parameter value is {{ InputParameter }}"

  - name: validate
    steps:
      - name: ValidateStep1
        action: ExecutePowerShell
        inputs:
          commands:
            - Write-Host "Validate phase. The input parameter value is {{ MyInputParameter }}"

  - name: test
    steps:
      - name: TestStep1
        action: ExecutePowerShell
        inputs:
          commands:
            - Write-Host "Test phase. The input parameter value is {{ MyInputParameter }}"
```
The above script sample only writes output to the console. The following code snippet will download a PowerShell script from an AWS S3 bucket, run the script, delete it, and then reboot the system:
```
phases:
  - name: build
    steps:
      - name: DownloadECXScript
        action: S3Download
        timeoutSeconds: 60
        onFailure: Abort
        maxAttempts: 3
        inputs:
          - source: 's3://<bucket name>/install-ecx.ps1'
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
```
The YAML file and PowerShell scripts can be downloaded from [ECXInstall](ECXInstall). Upload them to your S3 bucket. The following files are in this folder:    
1. **InstallECX.yml**    
This YAML file has two phases - _build_ and _validate_. In the build phase, it will download the ECX installation script (install-ecx.ps1) from an S3 bucket, run the script, delete it, and reboot the system. The validate phase will download the installation confirmation script (testECXConfig.ps1), run the script, and delete it. If using this YAML script, replace the <bucketname> placeholder with your own bucket name where the files reside.
2. **install-ecx.ps1**    
  This PowerShell script will download ExpressCluster X 5.1 from the NEC ExpressCluster website, extract the ExpressCluster files, install the software, and open ports through the firewall.
3. **testECXConfig.ps1**    
  This PowerShell script will check to see if the ports required by ExpressCluster are open and if ECX services are running or not.

#### Testing the YAML file and scripts without using EC2 Image Builder
The YAML file can be tested without running EC2 Image Builder. This makes it simple to test and troubleshoot the YAML file to make sure it works correctly. The **AWS Task Orchestrator and Executor** (AWSTOE) is a standalone application which can be [downloaded](https://docs.aws.amazon.com/imagebuilder/latest/userguide/toe-get-started.html) to run YAML scripts. The referenced link also has a user's guide. AWSTOE can validate the syntax of a YAML file as well as run it.    

Note that it is easier to run awstoe from an AWS instance if you will be accessing scripts from an S3 bucket. Otherwise credentials will have to be set. Log files are created when a YAML file runs. This helps in troubleshooting any issues.

##### Prerequisites to running a YAML file on an EC2 instance
1. Copy the PowerShell scripts to your S3 bucket.
2. [Create a role](#Create-an-IAM-role-that-grants-access-to-Amazon-S3-from-an-instance) to allow access to the scripts in your S3 bucket.
3. [Assign the newly created role to the instance](#Attach-the-IAM-role-to-the-EC2-instance) on which you will be testing the YAML script.
4. Edit the YAML script and change the bucket name place holder with the name of your bucket. e.g. s3://ecxbucket/install-ecx.ps1
5. Copy the YAML script file to a location on your instance.
6. Download the AWSTOE application to your instance.
7. Run the YAML file as a parameter for the AWSTOE application.  e.g. C:\> awstoe.exe run --documents InstallECX.yml
8. View the log files which will be created in a subdirectory from where awstoe.exe is run from.

Example syntax to validate a YAML file:  _C:\> awstoe.exe validate --documents C:\<YAML file name>.yml_    
Example syntax to run all phases in a YAML file:  _C:\>awstoe run --documents InstallECX.yml_    

### Linux
A YAML file was created to install ExpressCluster on Red Hat Linux. When run without parameters, it will use the default values, which will install ExpressCluster X v5.2. The name of your S3 bucket will most likely differ, so that parameter will need to change. Before running the YAML script, be sure to upload the ExpressCluster .rpm file (e.g. expresscls-5.2.0-1.x86_64.rpm) and the Alert, Base, and Replication license files to your S3 bucket. This script does the following:    
1. Creates a temporary folder to download files from the S3 bucket.
2. Downloads the ExpressCluster installation packet from the bucket.
3. Installs ExpressCluster.
4. Downloads the three license files from the bucket.
5. Registers the license files.
6. Checks to see if firewalld is running and if not, will install and enable it.
7. Runs a script to open ports through the firewall.
8. Disables SELinux.
9. Disables caching of repositories.
10. Deletes the temporary folder.
11. Reboots the system.
12. Verifies that license files were registered, gets the SELINUX state, checks if the firewall is running or not, and checks if the ExpressCluster ports were opened.

[Download RHEL.yml](ECXInstall/RHEL.yml)

## Addendum
### Create an IAM role that grants access to Amazon S3 from an instance
1. Open the [IAM console](https://console.aws.amazon.com/iam).
2. Choose **Roles**, and then choose **Create role**.
3. Select **AWS Service** as the Trusted entity type, and then choose **EC2** under **Use Case**.    
   (Allows EC2 instances to call AWS services on your behalf)
4. Click **Next** for **Permissions**.
5. Search for *AmazonS3ReadOnlyAccess* and then select this policy.    
   (This policy provides read only access to all buckets via the AWS Management Console.)
6. Click **Next** for **Role details**.
7. Enter a **Role name** e.g. *AWSInstanceS3ReadAccess* and click **Create role**.

### Attach the IAM role to the EC2 instance
1. Open the [Amazon EC2 console](https://console.aws.amazon.com/ec2).
2. Choose **Instances**.
3. Select the instance that you want to attach the IAM role to.
4. Choose the **Actions** tab, choose **Security**, and then choose **Modify IAM role**.
5. Select the IAM role that you just created (e.g. AWSInstanceS3ReadAccess), and then choose **Save**. The IAM role is assigned to your EC2 instance, allowing access to your S3 bucket.

## Yoshida Research (Uneder edit)
I was able to start the ECX installation using yaml and powershell scripts. However, due to awstoe, the ECX installation did not complete. The cause is still under investigation, but I will summarize it briefly.

One reason is that an error occurred in the authentication key settings, and the correct authentication key needs to be set. The other reason is whether AWSTOE was installed correctly in the first place. A TLS1.2 or later environment is required, so I will check the startup of AWSTOE on another machine.

## Links
[What is EC2 Image Builder?](https://docs.aws.amazon.com/imagebuilder/latest/userguide/what-is-image-builder.html)    
[EC2 Image Builder console landing page](https://console.aws.amazon.com/imagebuilder/).
