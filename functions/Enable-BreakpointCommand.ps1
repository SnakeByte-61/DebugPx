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

<#
.SYNOPSIS
    Enables the breakpoint command.
.DESCRIPTION
    The Enable-BreakpointCommand command enables the breakpoint command in your PowerShell environment.
.PARAMETER WhatIf
    Shows what would happen if the command was run unrestricted. The command is run, but any changes it would make are prevented, and text descriptions of those changes are written to the console instead.
.PARAMETER Confirm
    Prompts you for confirmation before any system changes are made using the command.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    When the breakpoint command is enabled, invoking breakpoint, bp, or Enter-Debugger may result in a script that is running stopping on a breakpoint on that line. For more information, invoke Get-Help breakpoint.
.EXAMPLE
    PS C:\> Enable-BreakpointCommand
    PS C:\> Get-Service w* | breakpoint {$_.Name -eq 'wuauserv'} | Select-Object -ExpandProperty Name

    The first command enables the breakpoint command. When the next command is invoked, a breakpoint will be hit when the Windows Update service is passed down the pipeline.
.EXAMPLE
    PS C:\> Enable-BreakpointCommand
    PS C:\> & {'Before breakpoint'; breakpoint; 'After breakpoint'}

    The first command enables the breakpoint command. When the next command is invoked, the string "Before breakpoint" will be output to the console, and then the debugger will stop on the breakpoint command. "After breakpoint" will only be output to the console when the debugger is told to step or continue execution.
.LINK
    Disable-BreakpointCommand
.LINK
    breakpoint
#>
function Enable-BreakpointCommand {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([System.Void])]
    param()
    try {
        #region Enable the breakpoint command breakpoint.

        Enable-PSBreakpoint -Breakpoint $script:Breakpoint.Command

        #endregion
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function Enable-BreakpointCommand

if (-not (Get-Alias -Name ebpc -ErrorAction Ignore)) {
    New-Alias -Name ebpc -Value Enable-BreakpointCommand
    Export-ModuleMember -Alias ebpc
}