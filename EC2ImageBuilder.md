# EC2 Image Builder
An [AWS website](https://aws.amazon.com/image-builder/faqs/) gives the following description of EC2 Image Builder: it \"simplifies the creation, maintenance, validation, sharing, and deployment of Linux or Windows images for use with Amazon EC2 and on-premises.\" This document focuses mainly on using EC2 Image Builder for automating the creation of Windows images.    

New images can be created and deployed manually or on a set schedule with EC2 Image Builder. These images can automatically include the latest OS updates, a number of preset components specified by AWS, or your own components to install and configure custom software. YAML configuration files can be used with PowerShell scripts to install and configure ExpressCluster X on Windows images. These files can be stored in an Amazon S3 bucket and utilized during the image build process.

## Create an image pipeline
Amazon provides instructions on how to [Create an image pipeline using the EC2 Image Builder console wizard](https://docs.aws.amazon.com/imagebuilder/latest/userguide/start-build-image-pipeline.html)

### Component builder
There is a Components section which is part of the process of creating a recipe. This is where YAML script code can be inserted to enable the automatic installation of ExpressCluster to the image to be created. The next section describes how to create a YAML code to configure the image with ExpressCluster. 

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
The YAML file and PowerShell scripts can be downloaded from [ECXInstall](ECXInstall). The following files are in this folder:    
1. **InstallECX.yml**    
This YAML file has two phases - _build_ and _validate_. In the build phase, it will download the ECX installation script (install-ecx.ps1) from an S3 bucket, run the script, delete it, and reboot the system. The validate phase will download the installation confirmation script (testECXConfig.ps1), run the script, and delete it. If using this YAML script, replace the <bucketname> placeholder with your own bucket name where the files reside.
2. **install-ecx.ps1**    
  This PowerShell script will download ExpressCluster X 5.1 from the NEC ExpressCluster website, extract the ExpressCluster files, install the software, and open ports through the firewall.
3. **testECXConfig.ps1**    
  This PowerShell script will check to see if the ports required by ExpressCluster are open and if ECX services are running or not.

#### Testing the YAML file and scripts without using the EC2 Image Builder
The YAML file can be tested without running EC2 Image Builder. This makes it simple to test and troubleshoot the YAML file to make sure it works correctly. The **AWS Task Orchestrator and Executor** (AWSTOE) is a standalone application which can be [downloaded](https://docs.aws.amazon.com/imagebuilder/latest/userguide/toe-get-started.html) to run YAML scripts. The referenced link also has a user's guide. AWSTOE can validate the syntax of a YAML file as well as run it.    

Note that it is easier to run awstoe from an AWS instance if you will be accessing scripts from an S3 bucket. Otherwise credentials will have to be set. Log files are created when a YAML file runs. This helps in troubleshooting any issues.

##### Prerequisites to running a YAML file on an EC2 instance
1. Copy the PowerShell scripts to your S3 bucket.
2. Create a role to allow access to the scripts in your S3 bucket.
3. Assign the newly created role to the instance on which you will be testing the YAML script.
4. Copy the YAML script file to a location on your instance.

Example syntax to validate a YAML file:  _C:\> awstoe.exe validate --documents C:\<YAML file name>.yml_    
Example syntax to run all phases in a YAML file:  _C:\>awstoe run --documents InstallECX.yml_    

## Addendum

## Links
[What is EC2 Image Builder?](https://docs.aws.amazon.com/imagebuilder/latest/userguide/what-is-image-builder.html)
