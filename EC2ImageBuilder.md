# EC2 Image Builder
An [AWS website](https://aws.amazon.com/image-builder/faqs/) gives the following description of EC2 Image Builder: it \"simplifies the creation, maintenance, validation, sharing, and deployment of Linux or Windows images for use with Amazon EC2 and on-premises.\"    

New images can be created and deployed manually or on a set schedule. These images can automatically include the latest OS updates, a number of preset components specified by AWS, or your own components to install and configure custom software. YAML configuration files can be used with PowerShell scripts to install and configure ExpressCluster X on Windows images. These files can be stored in an Amazon S3 bucket and utilized during the image build process.

## YAML
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
This script sample only writes output to the console. The following code snippet will download a PowerShell script from an AWS S3 bucket, run the script, delete it, and then reboot the system:
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
The YAML file and PowerShell scripts can be downloaded from [
