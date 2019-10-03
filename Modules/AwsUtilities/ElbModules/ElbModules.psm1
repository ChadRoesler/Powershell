function Get-CurrentMachineInstanceId
{
    Write-Log -message "Gathering instance id"
    
    $response = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-id" -Method Get
    $instanceId = ""
    
    if($response -ne $null)
    {
        $instanceId = $response
    }
    else 
    {
        Write-ErrorLog -message "Unable to gather instance id from local machine"
    }

    return $instanceId
}


function Get-ElbTargetState
{
    param(
        [string] $TargetGroup,
        [string] $InstanceId,
        [string] $Region,
        [string] $AccessKey,
        [string] $SecretKey
    )
    $target = New-Object -TypeName Amazon.ElasticLoadBalancingV2.Model.TargetDescription
    $target.Id = $InstanceId

    Write-Log -message "Gathering instance state."
    $stateObject = Get-ELB2TargetHealth -TargetGroupArn $TargetGroup `
                                        -Target $target `
                                        -AccessKey $AccessKey `
                                        -SecretKey $SecretKey `
                                        -Region $Region
                                        
	return $stateObject.TargetHealth.State
}

function Get-ElbTargetMachines
{
    param(
        [string] $TargetGroup,
        [string] $Region,
        [string] $AccessKey,
        [string] $SecretKey
    )

    Write-Log -message "Gathering instance state."
    $targetObjects = Get-ELB2TargetHealth -TargetGroupArn $TargetGroup `
                                          -AccessKey $AccessKey `
                                          -SecretKey $SecretKey `
                                          -Region $Region
    return $targetObjects
}
function Remove-InstanceFromElb
{
    param(
        [string] $TargetGroup,
        [string] $InstanceId,
        [string] $Region,
        [string] $AccessKey,
        [string] $SecretKey,
        [bool] $WaitTillUnused,
        [int] $CheckIntervalSeconds,
        [int] $CheckCount
    )

    $checksMade = 0

    $target = New-Object -TypeName Amazon.ElasticLoadBalancingV2.Model.TargetDescription
    $target.Id = $InstanceId
    Write-Log -message "Unregistereing Instance: $($InstanceId) from ARN: $($TargetGroup)"
    Unregister-ELB2Target -TargetGroupArn $TargetGroup `
                          -Target $target `
                          -AccessKey $AccessKey `
                          -SecretKey $SecretKey `
                          -Region $Region

    $instanceState = Get-ElbTargetState -TargetGroup $TargetGroup `
                                        -InstanceId $InstanceId `
                                        -Region $Region `
                                        -AccessKey $AccessKey `
                                        -SecretKey $SecretKey
    if($WaitTillUnused)
    {
        while($instanceState -ne "unused" -and $checksMade -le $CheckCount)
        {
            $checksMade += 1
            Start-Sleep -Seconds $CheckIntervalSeconds

            if($checksMade -le $CheckCount)
            {
                Write-Log -message "Attempt: $($checksMade) of $($CheckCount)"
            }

            $instanceState = Get-ElbTargetState -TargetGroup $TargetGroup `
                                                -InstanceId $InstanceId `
                                                -Region $Region `
                                                -AccessKey $AccessKey `
                                                -SecretKey $SecretKey
        }
    }

    if($instanceState -ne "unused")
    {
        Write-ErrorLog -message "Instance $($InstanceId) did not reach the state: Unused after $($CheckCount) Attemps."
    }

}


function Add-InstanceToElb
{
    param(
        [string] $TargetGroup,
        [string] $InstanceId,
        [string] $Region,
        [string] $AccessKey,
        [string] $SecretKey,
        [bool] $WaitTillHealthy,
        [int] $CheckIntervalSeconds,
        [int] $CheckCount
    )

    $checksMade = 0

    $target = New-Object -TypeName Amazon.ElasticLoadBalancingV2.Model.TargetDescription
    $target.Id = $InstanceId
    Write-Log -message "Registering Instance: $($InstanceId) from ARN: $($TargetGroup)"
    Register-ELB2Target -TargetGroupArn $TargetGroup `
                        -Target $target `
                        -AccessKey $AccessKey `
                        -SecretKey $SecretKey `
                        -Region $Region

    $instanceState = Get-ElbTargetState -TargetGroup $TargetGroup `
                                        -InstanceId $InstanceId `
                                        -Region $Region `
                                        -AccessKey $AccessKey `
                                        -SecretKey $SecretKey
    if($WaitTillHealthy)
    {
        while($instanceState -ne "healthy" -and $checksMade -le $CheckCount)
        {
            $checksMade += 1
            Start-Sleep -Seconds $CheckIntervalSeconds

            if($checksMade -le $CheckCount)
            {
                Write-Log -message "Attempt: $($checksMade) of $($CheckCount)"
            }

            $instanceState = Get-ElbTargetState -TargetGroup $TargetGroup `
                                                -InstanceId $InstanceId `
                                                -Region $Region `
                                                -AccessKey $AccessKey `
                                                -SecretKey $SecretKey
        }
    }

    if($instanceState -ne "healthy")
    {
        Write-ErrorLog -message "Instance $($InstanceId) did not reach the state: Healthy after $($CheckCount) Attemps."
    }

}