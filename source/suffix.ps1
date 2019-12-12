$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    if ($script:MachineOldPSModulePath)
    {
        [System.Environment]::SetEnvironmentVariable('PSModulePath', $script:MachineOldPSModulePath, 'Machine')
    }

    if ($script:MachineOldExecutionPolicy)
    {
        Set-ExecutionPolicy -ExecutionPolicy $script:MachineOldExecutionPolicy -Scope LocalMachine -Force -ErrorAction Stop
    }
}
