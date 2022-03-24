function Create-Ec2Instance
{
    param(
        [string] $autoScalingGroupName,
        [array] $availabilityZones,
        [string] $desiredCapacity,
        [string] $healthCheckType,
        [System.Object] $launchTemplate,
        [string] $maxSize,
        [string] $minSize,
        [array] $targetGroupARNs,
        [arrat] $vpcZoneIdentifiers,
        [string] $cooldown = "300",
        [string] $healthCheckGracePeriod = "300",
        [string] $templateLocation = "$($PSScriptRoot)\..\Templates\Ec2\AutoScalingGroupTemplate.json"
    )

    $resourceName = ($autoScalingGroupName -replace "[^a-zA-Z0-9]","")

    $instanceVarDictionary = New-Object Octostache.VariableDictionary
    $instanceVarDictionary.Add("AutoScalingGroup", $resourceName)
    $instanceVarDictionary.Add("AutoScalingGroupName", $autoScalingGroupName)
    $instanceVarDictionary.Add("Cooldown", $cooldown)
    $instanceVarDictionary.Add("DesiredCapacity", $amdesiredCapacityiId)
    $instanceVarDictionary.Add("HealthCheckGracePeriod", $healthCheckGracePeriod)
    $instanceVarDictionary.Add("KeyName", $keyName)
    $instanceVarDictionary.Add("UserDataLines", $transformedUserData)
}