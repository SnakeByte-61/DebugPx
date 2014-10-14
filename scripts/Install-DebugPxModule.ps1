﻿<#############################################################################
The DebugPx module provides a set of commands that make it easier to debug
PowerShell scripts, functions and modules. These commands leverage the native
debugging capabilities in PowerShell (the callstack, breakpoints, error output
and the -Debug common parameter) and provide additional functionality that
these features do not provide, enabling a richer debugging experience.

Copyright 2014 Kirk Munro

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#############################################################################>

# This script should only be invoked when you want to download the latest
# version of DebugPx from the GitHub page where it is hosted.

[CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='InCurrentLocation')]
[OutputType([System.Management.Automation.PSModuleInfo])]
param(
    [Parameter(ParameterSetName='ForCurrentUser')]
    [System.Management.Automation.SwitchParameter]
    $CurrentUser,

    [Parameter(ParameterSetName='ForAllUsers')]
    [System.Management.Automation.SwitchParameter]
    $AllUsers,

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $PassThru
)
try {
    #region Identify the modules folders that may be used.

    Write-Progress -Activity 'Installing DebugPx' -Status 'Defining common Windows PowerShell modules folder paths.'
    $modulesFolders = @{
        CurrentUser = Join-Path -Path ([System.Environment]::GetFolderPath('MyDocuments'))  -ChildPath WindowsPowerShell\Modules
           AllUsers = Join-Path -Path ([System.Environment]::GetFolderPath('ProgramFiles')) -ChildPath WindowsPowerShell\Modules
    }

    #endregion

    #region Get the currently installed module (if there is one).

    Write-Progress -Activity 'Installing DebugPx' -Status 'Looking for an installed DebugPx module.'
    $module = Get-Module -ListAvailable | Where-Object {$_.Guid -eq [System.Guid]'161b91e7-ca3d-40e2-8d0e-e00b31740f90'}
    if ($module -is [System.Array]) {
        [System.String]$message = 'More than one version of DebugPx is installed on this system. Manually remove the old versions and then try again.'
        [System.Management.Automation.SessionStateException]$exception = New-Object -TypeName System.Management.Automation.SessionStateException -ArgumentList $message
        [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'SessionStateException',([System.Management.Automation.ErrorCategory]::InvalidOperation),$module
        throw $errorRecord
    }

    #endregion

    #region Identify which modules folder will be used.

    Write-Progress -Activity 'Installing DebugPx' -Status 'Identifying the target modules folder.'
    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('AllUsers') -and $AllUsers) {
        $modulesFolder = $modulesFolders.AllUsers
    } elseif ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('CurrentUser') -and $CurrentUser) {
        $modulesFolder = $modulesFolders.CurrentUser
    } elseif ($module) {
        # Grab the modules folder from the current installed location.
        $modulesFolder = $module.ModuleBase | Split-Path -Parent
    } else {
        $modulesFolder = $modulesFolders.CurrentUser
    }

    #endregion

    #region Create the modules folder and add it to PSModulePath if necessary.

    if (-not (Test-Path -LiteralPath $modulesFolder)) {
        Write-Progress -Activity 'Installing DebugPx' -Status 'Creating modules folder.'
        New-Item -Path $modulesFolder -ItemType Directory -ErrorAction Stop > $null
    }
    if (@($env:PSModulePath -split ';') -notcontains $modulesFolder) {
        Write-Progress -Activity 'Installing DebugPx' -Status 'Updating the PSModulePath environment variable.'
        if ($modulesFolder -match "^$([System.Text.RegularExpressions.RegEx]::Escape($env:USERPROFILE))") {
            $environmentVariableTarget = [System.EnvironmentVariableTarget]::User
        } else {
            $environmentVariableTarget = [System.EnvironmentVariableTarget]::Machine
        }
        $systemPSModulePath = [System.Environment]::GetEnvironmentVariable('PSModulePath',$environmentVariableTarget) -as [System.String]
        if ($systemPSModulePath -notmatch ';$') {
            $systemPSModulePath += ';'
        }
        $systemPSModulePath += $modulesFolder
        [System.Environment]::SetEnvironmentVariable('PSModulePath',$systemPSModulePath,$environmentVariableTarget)
        if ($env:PSModulePath -notmatch ';$') {
            $env:PSModulePath += ';'
        }
        $env:PSModulePath += $modulesFolder
    }

    #endregion

    #region Download and unblock the latest release from GitHub.

    Write-Progress -Activity 'Installing DebugPx' -Status 'Downloading the latest version of DebugPx.'
    $zipFilePath = Join-Path -Path $modulesFolder -ChildPath DebugPx.zip
    $response = Invoke-WebRequest -Uri https://github.com/KirkMunro/DebugPx/zipball/release -ErrorAction Stop
    [System.IO.File]::WriteAllBytes($zipFilePath, $response.Content)
    Unblock-File -LiteralPath $zipFilePath -ErrorAction Stop

    #endregion

    #region Extract the contents of the downloaded zip file into the modules folder.

    Write-Progress -Activity 'Installing DebugPx' -Status 'Extracting the DebugPx zip file contents.'
    # Check to see if we have the System.IO.Compression.FileSystem assembly installed.
    # This comes as part of .NET 4.5 and later.
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    } catch {
    }
    if ('System.IO.Compression.ZipFile' -as [System.Type]) {
        # If we have .NET 4.5 installed, use the ExtractToDirectory static method
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $modulesFolder)
    } else {
        # Otherwise, use the CopyHere COM method (this is significantly slower)
        $shell = New-Object -ComObject Shell.Application
        $zip = $shell.NameSpace($zipFilePath)
        foreach($item in $zip.items()) {
            $shell.Namespace($modulesFolder).CopyHere($item)
        }
    }

    #endregion

    #region Remove the downloaded zip file.

    Write-Progress -Activity 'Installing DebugPx' -Status 'Removing the DebugPx zip file.'
    Remove-Item -LiteralPath $zipFilePath

    #endregion

    #region Remove the old version (if one was installed).

    if ($module) {
        Write-Progress -Activity 'Installing DebugPx' -Status 'Unloading and removing the installed DebugPx module.'
        # Unload the module if it is currently loaded.
        if ($loadedModule = Get-Module | Where-Object {$_.Guid -eq $module.Guid}) {
            $loadedModule | Remove-Module -ErrorAction Stop
        }
        # Remove the currently installed module.
        Remove-Item -LiteralPath $module.ModuleBase -Recurse -Force -ErrorAction Stop
    }

    #endregion

    #region Rename the extracted zip file contents folder as the module name.

    Write-Progress -Activity 'Installing DebugPx' -Status 'Installing the new DebugPx module.'
    Join-Path -Path $modulesFolder -ChildPath KirkMunro-DebugPx-* `
        | Get-Item `
        | Sort-Object -Property LastWriteTime -Descending `
        | Select-Object -First 1 `
        | Rename-Item -NewName DebugPx

    #endregion

    #region Now return the updated module to the caller if they requested it.

    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('PassThru') -and $PassThru) {
        Get-Module -ListAvailable -Name DebugPx
    }

    #endregion
} catch {
    $PSCmdlet.ThrowTerminatingError($_)
}