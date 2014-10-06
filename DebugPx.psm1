<#############################################################################
The DebugPx module provides a set of commands that make it easier to debug
PowerShell scripts, functions and modules. These commands leverage the native
debugging capabilities in PowerShell (the callstack, breakpoints, error output
and the -Debug common parameter) and provide additional functionality that
these features do not provide, enabling a richer debugging experience.

Copyright � 2014 Kirk Munro.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License in the
license folder that is included in the DebugPx module. If not, see
<https://www.gnu.org/licenses/gpl.html>.
#############################################################################>

#region Initialize the module.

Invoke-Snippet -Name Module.Initialize

#endregion

#region Import helper (private) function definitions.

Invoke-Snippet -Name ScriptFile.Import -Parameters @{
    Path = Join-Path -Path $PSModuleRoot -ChildPath helpers
}

#endregion

#region Import public function definitions.

Invoke-Snippet -Name ScriptFile.Import -Parameters @{
    Path = Join-Path -Path $PSModuleRoot -ChildPath functions
}

#endregion

#region Export commands defined in nested modules.

. $PSModuleRoot\scripts\Export-BinaryModule.ps1

#endregion

#region Define the breakpoints that are used by this module.

$Breakpoint = @{
    Statement = New-BreakpointCommandBreakpoint
}

#endregion

#region If we are not in an interactive session, disable the breakpoints by default.

if (-not [System.Environment]::UserInteractive) {
    Disable-BreakpointCommand
}

#endregion

#region Define an event handler that will re-create the breakpoints used by this script if they are manually removed.

$OnBreakpointUpdated = {
    param(
        [System.Object]$sender,
        [System.Management.Automation.BreakpointUpdatedEventArgs]$eventArgs
    )
    if (($eventArgs.UpdateType -eq [System.Management.Automation.BreakpointUpdateType]::Removed) -and
        ($eventArgs.Breakpoint.Id -eq $script:Breakpoint.Command.Id)) {
        #region If the breakpoint command breakpoint was removed, re-create it and warn the user about the requirement.

        $enabled = $eventArgs.Breakpoint.Enabled
        Write-Warning "The breakpoint command breakpoint is required by the DebugPx module and cannot be manually removed. You can disable this breakpoint by invoking ""Disable-BreakpointCommand"", or you can remove it by invoking ""Remove-Module -Name DebugPx"". This breakpoint is currently $(if ($enabled) {'enabled'} else {'disabled'})."
        $script:Breakpoint['Command'] = New-BreakpointCommandBreakpoint
        if (-not $enabled) {
            Disable-BreakpointCommand
        }

        #endregion
        break
    }
}

#endregion

#region Activate the OnBreakpointUpdated event handler.

$Host.Runspace.Debugger.add_BreakpointUpdated($OnBreakpointUpdated)

#endregion

$PSModule.OnRemove = {

    #region Deactivate the OnBreakpointUpdated event handler.

    $Host.Runspace.Debugger.remove_BreakpointUpdated($OnBreakpointUpdated)

    #endregion

    #region Remove any breakpoints that are used by this module.

    foreach ($key in $Breakpoint.Keys) {
        Remove-PSBreakpoint -Breakpoint $Breakpoint.$key -ErrorAction Ignore
    }

    #endregion
}