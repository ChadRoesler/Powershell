function Create-SecurityGroup
{
    param(
        [string] $securityGroupName,
        [string] $vpcId,
        [System.Object[]] $egresses,
        [System.Object[]] $ingresses,
        [switch] $skipExistanceCheck = $false,
        [string] $templateLocation = "$($PSScriptRoot)\..\Templates\Ec2\SecurityGroupTemplate.json"
    )

    try
    {
        if(!$skipExistanceCheck)
        {
            $existingSecurityGroup = Get-EC2SecurityGroup -GroupName $securityGroupName
        }
        else
        {
            $existingSecurityGroup = $null
        }
    }
    catch
    {
        $existingSecurityGroup = $null
    }

    if($null -ne $existingSecurityGroup)
    {
        Write-ErrorLog -message "SecurityGroyp: $($securityGroupName) already exists"
    }
    else
    {
        $securityGroupObject = New-Object System.Object

        $resourceName = ($securityGroupName -replace "[^a-zA-Z0-9]","")

        Write-Log -message "Generating SecurityGroup Object: $($securityGroupName)"
        write-Host $templateLocation
        $securityGroupFile = Get-Item $templateLocation
        $securityGroupText = [System.IO.File]::ReadAllText($securityGroupFile)
        $securityGroupObject = ConvertFrom-Json $securityGroupText
        $securityGroupObject.Resources.SecurityGroupTemplate.Properties.GroupName = $securityGroupName
        $securityGroupObject.Resources.SecurityGroupTemplate.Properties.VpcId = $vpcId

        if($egresses.Count -gt 0)
        {
            $securityGroupObject.Resources.SecurityGroupTemplate.Properties | Add-Member -MemberType NoteProperty -Name "SecurityGroupEgress" -Value $egresses
        }

        if($ingresses.Count -gt 0)
        {
            $securityGroupObject.Resources.SecurityGroupTemplate.Properties | Add-Member -MemberType NoteProperty -Name "SecurityGroupIngress" -Value $ingresses
        }

        $securityGroupObject.Resources | Add-Member -MemberType NoteProperty -Name $resourceName -Value $securityGroupObject.Resources.SecurityGroupTemplate
        $securityGroupObject.Resources.PsObject.Properties.Remove("SecurityGroupTemplate")

        return $securityGroupObject
    }
}

function Create-SecruirtyGroupGress
{
    param(
        [string] $protocol,
        [int] $fromPort,
        [int] $toPort,
        [string[]] $cidrIpArray,
        [string] $templateLocation = "$($PSScriptRoot)\..\Templates\Ec2\GressTemplate.json"
    )

    $securityGroupGressObjectArray = @()
    foreach($cidrIp in $cidrIpArray)
    {
        $securityGroupGressObject = New-Object System.Object

        $securityGroupGressFile = Get-Item $templateLocation
        $securityGroupGressText = [System.IO.File]::ReadAllText($securityGroupGressFile)
        $securityGroupGressObject = ConvertFrom-Json $securityGroupGressText
        $securityGroupGressObject.IpProtocol = $protocol
        $securityGroupGressObject.CidrIp = $cidrIp
        if($protocol -ne "-1")
        {
            $securityGroupGressObject | Add-Member -MemberType NoteProperty -Name "FromPort" -Value $fromPort
            $securityGroupGressObject | Add-Member -MemberType NoteProperty -Name "ToPort" -Value $toPort
        }

        $securityGroupGressObjectArray += $securityGroupGressObject
    }

    return $securityGroupGressObjectArray

}