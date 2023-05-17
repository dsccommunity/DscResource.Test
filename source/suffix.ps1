$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    if ($script:machineOldPSModulePath)
    {
        Set-PSModulePath -Path $script:machineOldPSModulePath -Machine -ErrorAction 'Stop'

        $script:machineOldPSModulePath = $null
    }

    if ($script:MachineOldExecutionPolicy)
    {
        Set-ExecutionPolicy -ExecutionPolicy $script:MachineOldExecutionPolicy -Scope LocalMachine -Force -ErrorAction Stop
    }
}
