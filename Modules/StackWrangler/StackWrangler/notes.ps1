$importModules = $true
$removeModules = $true
#########################################
# [A] RemoveModules
#########################################
if($removeModules)
{
    Remove-Module StackManagement
    Remove-Module CreateIamResource
    Remove-Module CreateS3Bucket
    Remove-Module PolicyManagement
    Remove-Module CreateEc2Instance
    Remove-Module CreateSecurityGroup
}

#########################################
# [B] ImportModules
#########################################
if($importModules)
{ 
    Import-Module C:\ChadRoesler_Workspace\Modules\StackWrangler\CreateIamResource\CreateIamResource.psd1
    Import-Module C:\ChadRoesler_Workspace\Modules\StackWrangler\CreateS3Bucket\CreateS3Bucket.psd1
    Import-Module C:\ChadRoesler_Workspace\Modules\StackWrangler\PolicyManagement\PolicyManagement.psd1
    Import-Module C:\ChadRoesler_Workspace\Modules\StackWrangler\CreateEc2Instance\CreateEc2Instance.psd1
    Import-Module C:\ChadRoesler_Workspace\Modules\StackWrangler\CreateSecurityGroup\CreateSecurityGroup.psd1
    Import-Module C:\ChadRoesler_Workspace\Modules\StackWrangler\StackManagement\StackManagement.psd1

}

Set-AWSCredential -ProfileName SandBoxA0R029 
Set-DefaultAwsRegion -Region us-east-2 
#########################################
# [C] Generate IAM Resources
#########################################
$iamUser1 = Create-IamUser -userName "IamUser1" -createAccessKey -storeKeyInSecretManager
$iamUser2 = Create-IamUser -userName "IamUser2" -createAccessKey
$iamUser3 = Create-IamUser -userName "IamUser3"

$iamRole1 = Create-IamRole -roleName "IamRole1" -service "ec2" -ec2InstanceProfile
$iamRole2 = Create-IamRole -roleName "IamRole2" -service "lambda"

$finalIamUsers = Merge-MultipleObjects -objectArray @($iamUser1, $iamUser2, $iamUser3)
$finalIamRoles = Merge-MultipleObjects -objectArray @($iamRole1, $iamRole2)

#########################################
# [D] Generate S3 Resources
#########################################
$accessLogs = "accesslogs-$((Get-STSCallerIdentity -Region "us-east-2").Account)-us-east-2"

$s3Bucket1 = Create-S3Bucket -bucketName "bucket1"
$s3BucketWithLogging1 = Create-S3Bucket -bucketName "bucket2newlog" -logBucketName "logbucket1-accountnumber" -logFilePrefix "{""Fn::Sub"": ""bucket2newlog-`${AWS::Region}""}" -logBucketLogFilePrefix """logbucket1"""
$s3BucketWithLogging2 = Create-S3Bucket -bucketName "bucket3withlog" -logBucketName $accessLogs -logFilePrefix """bucket3withlog"""

$finalS3Buckets = Merge-MultipleObjects -objectArray @($s3Bucket1, $s3BucketWithLogging1, $s3BucketWithLogging2)

#########################################
# [E] Generate Policy Documents
#########################################
$s3PolicyDocArray = @()
foreach($s3Bucket in $finalS3Buckets.Resources.PsObject.Properties)
{
    $s3PolicyDocArray += Create-PolicyDocument -actions "s3:*" -resources  @"
{
    "Fn::GetAtt": [
        "$($s3Bucket.Name)",
        "Arn"
    ]
}
"@
}
$finalPolicyDocumentEc2 = Create-PolicyDocument -actions "ec2:*" -resources "*"

$finalPolicyDocumentS3 = Merge-PolicyDocuments -policyDocuments $s3PolicyDocArray

#########################################
# [F] Generate Policies
#########################################
$iamUsers1And3 = Merge-MultipleObjects -objectArray @($iamUser1, $iamUser3)

$managedPolicy1 = Create-ManagedPolicy -managedPolicyName "PolicyForUsers1And3" -userObject $iamUsers1and3 -dependentObject $finalS3Buckets -policyDocumentObject $finalPolicyDocumentS3
$managedPolicy2 = Create-ManagedPolicy -managedPolicyName "PolicyForUser2" -userObject $iamUser2 -dependentObject $s3Bucket1 -policyDocumentObject $s3PolicyDocArray[0]
$managedPolicy3 = Create-ManagedPolicy -managedPolicyName "PolicyForRoles" -roleObject $finalIamRoles -policyDocumentObject $finalPolicyDocumentEc2

$finalManagedPolicies = Merge-MultipleObjects -objectArray @($managedPolicy1, $managedPolicy2, $managedPolicy3)

#########################################
# [G] Generate Gresses
#########################################
$ingressArray1 = @()
$RdpIpAddresses = @("10.0.0.0/8", "10.0.32.171/32","10.0.32.41/32")
$SmbIpAddresses = @("10.0.32.185/32", "10.0.32.186/32", "10.0.32.24/32", "10.0.32.194/32", "10.0.32.196/32")
$ingressArray1 += Create-SecruirtyGroupGress -protocol "TCP" -fromPort 3389 -toPort 3389 -cidrIpArray $RdpIpAddresses
$ingressArray1 += Create-SecruirtyGroupGress -protocol "TCP" -fromPort 445 -toPort 445 -cidrIpArray $SmbIpAddresses
$ingressArray1 += Create-SecruirtyGroupGress -protocol "icmp" -fromPort 8 -toPort -1 -cidrIpArray "10.0.0.0/8"

#########################################
# [H] Generate SecurityGroup
#########################################
$finalSecurityGroup = Create-SecurityGroup -securityGroupName "securityGroup1" -vpcId "vpc-f1f5fa99" -ingresses $ingressArray

#########################################
# [I] Generate Ec2 Instance 
#########################################
$instance1 = Create-Ec2Instance -instanceName "ec2Instance1" -instanceType "t2.nano" -amiId "ami-08b4a0f6e106c1dba" -iamRoleWithInstanceProfile $iamRole1 -securityGroups $finalSecurityGroup -keyName "test" -subnetId "subnet-a6274bdc"
$instance2 = Create-Ec2Instance -instanceName "ec2Instance2" -instanceType "t2.nano" -amiName "WINDOWS_2016_NANO" -iamRoleName "Ec2TestIam" -securityGroups $finalSecurityGroup -securityGroupIds @("sg-6293260d") -keyName "test" -subnetId "subnet-a6274bdc"

$finalInstances = Merge-MultipleObjects -objectArray @($instance1, $instance2)

#########################################
# [J]  Finalize ResourcesvTogether
#########################################

$resourceStacksHold = @((Clone-Object -objectToClone $finalIamRoles), (Clone-Object -objectToClone $finalIamUsers), (Clone-Object -objectToClone $finalS3Buckets), (Clone-Object -objectToClone $finalManagedPolicies), (Clone-Object -objectToClone $finalSecurityGroup), (Clone-Object -objectToClone $finalInstances))


#########################################
# [K] Organize All of it
#########################################
$stackManagementLocation = "C:\ChadRoesler_Workspace\Modules\StackWrangler\Templates\StackManagement.json"
$stackManagementFile = Get-Item $stackManagementLocation
$stackManagementText = [System.IO.File]::ReadAllText($stackManagementFile)
$stackManagementObject = ConvertFrom-Json $stackManagementText

$managedStackArray = @()
$dependantResourceArray = @()
$missingResourceArray = @()

$orderedResourceLayerList = $stackManagementObject.ResourceLayers | Sort-Object { $_.Layer }
$stackReferencedObjectsMap = $stackManagementObject.ReferencedObjectsMap
$stackArchitecture = $stackManagementObject.StackArchitecture | Sort-Object { $_.Order }
$stackTransientResources = $stackManagementObject.TransientResources
$stackRemoveables = $stackManagementObject.Remove

$unmanagedStackObjects = @()
$masterStackObjectArray = @()

$stackSystemName = "test"

#########################################
# [L] Gather Everything
#########################################
$stackFileLocations = @("C:\ChadRoesler_Workspace\wranglerTest\AtlassianVPC.json", "C:\ChadRoesler_Workspace\wranglerTest\users.json","C:\ChadRoesler_Workspace\wranglerTest\s3wait.json")
$stacks = $resourceStacksHold


foreach($stackFileLocation in $stackFileLocations)
{
    $stackFile = Get-Item $stackFileLocation
    $stackText = [System.IO.File]::ReadAllText($stackFile)
    $stackObject = ConvertFrom-Json $stackText
    $stackObject | Add-Member -MemberType NoteProperty -Name "OriginFile" -Value $stackFileLocation
    $unmanagedStackObjects += $stackObject
}

foreach($stackObject in $stacks)
{
    $stackObject | Add-Member -MemberType NoteProperty -Name "OriginFile" -Value "ObjectPassed"
    $unmanagedStackObjects += $stackObject
}

#########################################
# [M] Base Object Creation
#########################################

$stackConditionObjects = New-Object System.Object
$stackConditionObjects | Add-Member -MemberType NoteProperty -Name "Type" -Value "Conditions"
$stackConditionObjects | Add-Member -MemberType NoteProperty -Name "Objects" -Value @()

$stackParameterObjects = New-Object System.Object
$stackParameterObjects | Add-Member -MemberType NoteProperty -Name "Type" -Value "Parameters"
$stackParameterObjects | Add-Member -MemberType NoteProperty -Name "Objects" -Value @()

$stackOutputObjects = New-Object System.Object
$stackOutputObjects | Add-Member -MemberType NoteProperty -Name "Type" -Value "Outputs"
$stackOutputObjects | Add-Member -MemberType NoteProperty -Name "Objects" -Value @()

$stackMappingObjects = New-Object System.Object
$stackMappingObjects | Add-Member -MemberType NoteProperty -Name "Type" -Value "Mappings"
$stackMappingObjects | Add-Member -MemberType NoteProperty -Name "Objects" -Value @()

$stackResourceObjects = New-Object System.Object
$stackResourceObjects | Add-Member -MemberType NoteProperty -Name "Type" -Value "Resources"
$stackResourceObjects | Add-Member -MemberType NoteProperty -Name "Objects" -Value @()

$stackDescriptionObjects = New-Object System.Object
$stackDescriptionObjects | Add-Member -MemberType NoteProperty -Name "Type" -Value "Description"
$stackDescriptionObjects | Add-Member -MemberType NoteProperty -Name "Objects" -Value @()

$stackTemplateVersionObjects = New-Object System.Object
$stackTemplateVersionObjects | Add-Member -MemberType NoteProperty -Name "Type" -Value "AWSTemplateFormatVersion"
$stackTemplateVersionObjects | Add-Member -MemberType NoteProperty -Name "Objects" -Value @()

$stackTransientResourceObjects = New-Object System.Object
$stackTransientResourceObjects | Add-Member -MemberType NoteProperty -Name "Type" -Value "TransientResources"
$stackTransientResourceObjects | Add-Member -MemberType NoteProperty -Name "Objects" -Value @()


#########################################
# [N] Base Object Organization
#########################################
foreach($stackObject in $unmanagedStackObjects)
{
    foreach($removeable in $stackObject.PsObject.Properties | Where-Object { $stackRemoveables -contains $_.Name })
    {
        $stackObject.PsObject.Properties.Remove($removeable)
    }
    if($null -ne $stackObject.Description)
    {
        $stackDescriptionObjects.Objects += $stackObject.Description
        $stackObject.PsObject.Properties.Remove("Description")
    }
    if($null -ne $stackObject.AWSTemplateFormatVersion)
    {
        $stackTemplateVersionObjects.Objects += $stackObject.AWSTemplateFormatVersion
        $stackObject.PsObject.Properties.Remove("AWSTemplateFormatVersion")
    }
    if($null -ne $stackObject.Conditions)
    {
        foreach($condition in $stackObject.Conditions.PsObject.Properties)
        {
            $newRefObject = New-object System.Object
            $newRefObject | Add-Member -MemberType NoteProperty -Name $condition.Name -Value (Clone-Object2 -objectToClone $stackObject.Conditions."$($condition.Name)")

            $conditional = New-Object System.Object
            $conditional | Add-Member -MemberType NoteProperty -Name "Name" -Value $condition.Name
            $conditional | Add-Member -MemberType NoteProperty -Name "ConditionsObject" -Value $newRefObject
            $conditional | Add-Member -MemberType NoteProperty -Name "OriginFile" -Value $stackObject.OriginFile
            $conditional | Add-Member -MemberType NoteProperty -Name "Layer" -Value 666
            $conditional | Add-Member -MemberType NoteProperty -Name "CreateOutput" -Value $false
            $stackConditionObjects.Objects += $conditional
            
        }
        $stackObject.PsObject.Properties.Remove("Conditions")
    }
    if($null -ne $stackObject.Parameters)
    {
        foreach($parameter in $stackObject.Parameters.PsObject.Properties)
        {
            $newRefObject = New-object System.Object
            $newRefObject | Add-Member -MemberType NoteProperty -Name $parameter.Name -Value (Clone-Object2 -objectToClone $stackObject.Parameters."$($parameter.Name)")

            $parameterization = New-Object System.Object
            $parameterization | Add-Member -MemberType NoteProperty -Name "Name" -Value $parameter.Name
            $parameterization | Add-Member -MemberType NoteProperty -Name "ParametersObject" -Value $newRefObject
            $parameterization | Add-Member -MemberType NoteProperty -Name "OriginFile" -Value $stackObject.OriginFile
            $parameterization | Add-Member -MemberType NoteProperty -Name "Layer" -Value 666
            $parameterization | Add-Member -MemberType NoteProperty -Name "CreateOutput" -Value $false
            $stackParameterObjects.Objects += $parameterization
        }
        $stackObject.PsObject.Properties.Remove("Parameters")
    }
    if($null -ne $stackObject.Outputs)
    {
        foreach($output in $stackObject.Outputs.PsObject.Properties)
        {
            $newRefObject = New-object System.Object
            $newRefObject | Add-Member -MemberType NoteProperty -Name $output.Name -Value (Clone-Object2 -objectToClone $stackObject.Outputs."$($output.Name)")

            $outputable = New-Object System.Object
            $outputable | Add-Member -MemberType NoteProperty -Name "Name" -Value $output.Name
            $outputable | Add-Member -MemberType NoteProperty -Name "OutputsObject" -Value $newRefObject
            $outputable | Add-Member -MemberType NoteProperty -Name "OriginFile" -Value $stackObject.OriginFile
            $outputable | Add-Member -MemberType NoteProperty -Name "Layer" -Value 666
            $outputable | Add-Member -MemberType NoteProperty -Name "CreateOutput" -Value $false
            $stackOutputObjects.Objects += $outputable
        }
        $stackObject.PsObject.Properties.Remove("Outputs")
    }
    if($null -ne $resourceStackObject.Mappings)
    {
        foreach($mapping in $stackObject.Mappings.PsObject.Properties)
        {
            $newRefObject = New-object System.Object
            $newRefObject | Add-Member -MemberType NoteProperty -Name $mapping.Name -Value (Clone-Object2 -objectToClone $stackObject.Mappings."$($mapping.Name)")

            $map = New-Object System.Object
            $map | Add-Member -MemberType NoteProperty -Name "Name" -Value $mapping.Name
            $map | Add-Member -MemberType NoteProperty -Name "MappingsObject" -Value $newRefObject
            $map | Add-Member -MemberType NoteProperty -Name "OriginFile" -Value $stackObject.OriginFile
            $map | Add-Member -MemberType NoteProperty -Name "Layer" -Value 666
            $map | Add-Member -MemberType NoteProperty -Name "CreateOutput" -Value $false
            $stackMappingObjects.Objects += $map
        }
        $stackObject.PsObject.Properties.Remove("Mappings")
    }
    
    if($null -ne $stackObject.Resources)
    {
        foreach($resource in $stackObject.Resources.PsObject.Properties)
        {
            $newRefObject = New-Object System.Object
            $newRefObject | Add-Member -MemberType NoteProperty -Name $resource.Name -Value (Clone-Object2 -objectToClone $stackObject.Resources."$($resource.Name)")

            $resourceable = New-Object System.Object
            $resourceable | Add-Member -MemberType NoteProperty -Name "Name" -Value $resource.Name
            #$resourceable | Add-Member -MemberType NoteProperty -Name "ResourcesObject" -Value $newRefObject
            $resourceable | Add-Member -MemberType NoteProperty -Name "OriginFile" -Value $stackObject.OriginFile
            $resourceable | Add-Member -MemberType NoteProperty -Name "ResourceType" -Value $stackObject.Resources."$($resource.Name)".Type
            $resourceable | Add-Member -MemberType NoteProperty -Name "Layer" -Value 999
            $resourceable | Add-Member -MemberType NoteProperty -Name "CreateOutput" -Value $false
            
            if($stackTransientResources -contains $stackObject.Resources."$($resource.Name)".Type)
            {
                $resourceable | Add-Member -MemberType NoteProperty -Name "ResourcesObject" -Value $newRefObject
                $stackTransientResourceObjects.Objects += $resourceable
            }
            else 
            {
                $resourceable | Add-Member -MemberType NoteProperty -Name "TransientResourcesObject" -Value $newRefObject
                $stackResourceObjects.Objects += $resourceable    
            }
        }
        $stackObject.PsObject.Properties.Remove("Resources")
    }
}


$masterStackObjectArray += $stackConditionObjects
$masterStackObjectArray += $stackResourceObjects
$masterStackObjectArray += $stackParameterObjects
$masterStackObjectArray += $stackOutputObjects
$masterStackObjectArray += $stackMappingObjects
$masterStackObjectArray += $stackTransientResourceObjects
#$masterStackObjectArray += $stackDescriptionObjects
$masterStackObjectArray += $stackTemplateVersionObjects

if(($stackTemplateVersionObjects.Objects | Get-Unique).Count -gt 1)
{
    Write-ErrorLog -message "Mutliple Template Versions Detected"
}

#########################################
# [O] Resource Layer Organization 
# This pass orders the resources
#########################################
    Write-Log -message "Ordering Resources"
    foreach($orderedResourceLayer in $orderedResourceLayerList)
    {
        $orderedResourceList = $orderedResourceLayer.Resources | Sort-Object { $_.Order }  | Select-Object -Property Type
        $resourceLayer = New-Object System.Object
        $resourceLayer | Add-Member -MemberType NoteProperty -Name "Layer" -Value $orderedResourceLayer.Layer
        $resourceLayer | Add-Member -MemberType NoteProperty -Name "Resources" -Value (New-Object System.Object)
        $resourceLayer | Add-Member -MemberType NoteProperty -Name "LayerName" -Value $orderedResourceLayer.LayerName
        
        foreach($orderedResource in $orderedResourceList)
        {
            foreach($resource in $stackResourceObjects.Objects | Where-Object { $_.ResourceType -eq $orderedResource.Type })
            {
                if(($resource.ResourcesObject."$($resource.Name)".PsObject.Properties | Where-Object { $_.Name -eq "DependsOn" }).Length -gt 0)
                {
                    $newRefObject = New-Object System.Object
                    $newRefObject | Add-Member -MemberType NoteProperty -Name "Resource" -Value $resource.Name
                    $newRefObject | Add-Member -MemberType NoteProperty -Name "DependsOn" -Value $resource.ResourcesObject."$($resource.Name)".DependsOn
                    $newRefObject | Add-Member -MemberType NoteProperty -Name "ResourceLayer" -Value $orderedResourceLayer.Layer
                    
                    $dependantResourceArray += $newRefObject
                    $resource.ResourcesObject."$($resource.Name)".PsObject.Properties.Remove("DependsOn")
                }
                $resource.Layer = $orderedResourceLayer.Layer
                $resourceLayer.Resources | Add-Member -MemberType NoteProperty -Name $resource.Name -Value $resource.ResourcesObject."$($resource.Name)"
            }
            
        }
        $managedStackArray += $resourceLayer
    }
#########################################
# [P] Missing Resource Catch 
# Checks for built resource Types that are not listed in the Stack Management Config
#########################################   
    if(($stackResourceObjects.Objects | Where-Object { $null -eq $_.Layer }).Length -gt 0)
    {
        $missingResourceLayerNumber = (($managedStackArray | Sort-Object -Property Layer -Descending | Select-Object -first 1).Layer + 1)
        $missingResourceLayer = New-Object System.Object
        $missingResourceLayer | Add-Member -MemberType NoteProperty -Name "Layer" -Value $missingResourceLayerNumber
        $missingResourceLayer | Add-Member -MemberType NoteProperty -Name "Resources" -Value (New-Object System.Object)
        $missingResourceLayer | Add-Member -MemberType NoteProperty -Name "LayerName" -Value "MissingResources"
        
        $missingResourceArray = @()
        foreach($missingResource in $stackResourceObjects.Objects | Where-Object { $null -eq $_.Layer } | Sort-Object { $_.ResourceType })
        {
            if(($missingResourceArray | Where-Object { $_.ResourceType -eq $($missingResource.ResourcesObject."$($missingResource.Name)".ResourceType) }).Length -eq 0)
            {
                $missingObject = New-Object System.Object
                $missingObject | Add-Member -MemberType NoteProperty -Name "ResourceType" -Value $missingResource.ResourcesObject."$($missingResource.Name)".ResourceType
                $missingObject | Add-Member -MemberType NoteProperty -Name "Names" -Value @($missingResource.Name)
                $missingResourceArray += $missingObject
            }
            else
            {
                $missingObject = $missingResourceArray | Where-Object { $_.ResourceType -eq $($missingResource.ResourcesObject."$($missingResource.Name)".ResourceType) }
                $missingObject.Names += $missingResource.Name
            }
        }
        foreach($missingResource in $missingResourceArray)
        {
            $missingResourceWarning = @"
The Resource Type: $($missingResource.ResourceType) was not found in the stack configuration.
The following Resources of that type have been found: $($missingResource.Names -join ', ').
"@
            Write-WarningLog -message $missingResourceWarning
            
        }
        Write-WarningLog -message "The resources listed above will be placed in their own as a last layer"
        foreach($missingResource in $stackResourceObjects.Objects | Where-Object { $null -eq $_.Layer } | Sort-Object { $_.ResourceType })
        {
            
            if(($missingResource.ResourcesObject."$($missingResource.Name)".PsObject.Properties | Where-Object { $_.Name -eq "DependsOn" }).Length -gt 0)
            {
                $newRefObject = New-Object System.Object
                $newRefObject | Add-Member -MemberType NoteProperty -Name "Resource" -Value $missingResource.Name
                $newRefObject | Add-Member -MemberType NoteProperty -Name "DependsOn" -Value $missingResource.ResourcesObject."$($missingResource.Name)".DependsOn
                $newRefObject | Add-Member -MemberType NoteProperty -Name "ResourceLayer" -Value $missingResourceLayer
                    
                $dependantResourceArray += $newRefObject
                $missingResource.ResourcesObject."$($missingResource.Name)".PsObject.Properties.Remove("DependsOn")
            }
            $resource.Layer = $missingResourceLayerNumber
            $missingResourceLayer.Resources | Add-Member -MemberType NoteProperty -Name $missingResource.Name -Value $missingResource.ResourcesObject."$($missingResource.Name)"
        }
        $managedStackArray += $missingResourceLayer
    }

#########################################
# [Q] Dependancy Fixer
# Removes Objects Depenancies on a higher level [0 being the top, 1 being lower, etc], leaves depenancies if on the same level
# If object has dependancies on a lower level, Error for now
#########################################
    Write-Log -message "Remove Dependancies on lower levels to higher levels"
    foreach($dependantResource in $dependantResourceArray)
    {
        foreach($dependant in $dependantResource.DependsOn)
        {
            $resource = $stackResourceObjects.Objects| Where-Object { $_.Name -eq $dependant }
            if($null -eq $resource)
            {
                $resource = $stackTransientResourceObjects.Objects | Where-Object { $_.Name -eq $dependant }
                $newDependObject = New-Object System.Object
                $newDependObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $dependantResource.Resource
                $newDependObject | Add-Member -MemberType NoteProperty -Name "Layer" -Value $dependantResource.ResourceLayer

                if(($resource.PsObject.Properties | Where-Object { $_.Name -eq "DependantOf" }).Length -eq 0)
                {
                    $resource | Add-Member -MemberType NoteProperty -Name "DependentOf" -Value @()
                }
                $resource.DependentOf += $newDependObject
                
            }
            else
            {
                if($resource.Layer -eq $dependantResource.ResourceLayer)
                {
                    $resourceLayer = $managedStackArray | Where-Object { $_.Layer -eq $resource.Layer }
                    $resourceToSet = $resourceLayer.Resources."$($dependantResource.Resource)"
                    if(($resourceToSet.PsObject.Properties | Where-Object { $_.Name -eq "DependsOn" }).Length -eq 0)
                    {
                        $resourceToSet | Add-Member -MemberType NoteProperty -Name "DependsOn" -Value @()
                    }
                    $resourceToSet.DependsOn += $dependant
                }
                elseif($resource.Layer -gt $dependantResource.ResourceLayer)
                {
                    Write-ErrorLog -message "Resource: $($dependantResource.Resource), has dependancies on a lower layer: $($dependant), please review your stack management configuration"
                }
            }
        }
    }
#########################################
# [R] ReferenceableObject Mapping
#########################################
foreach($stackObjectType in $masterStackObjectArray)
{
    if($stackObjectType.Objects.Count -gt 0)
    {
        $referenceMap = $stackReferencedObjectsMap | Where-Object { $_.ObjectType -eq $stackObjectType.Type }
        $foundInMap = $referenceMap.FoundIn
        $containsMap = $referenceMap.Contains
        if($foundInMap.Count -gt 0)
        {
            Write-Log -message "Searching for $($stackObjectType.Type) in: $($foundInMap -join ", ") "
            $stackObjectsFoundIn = $masterStackObjectArray | Where-Object { $foundInMap -contains $_.Type }
            foreach($referenceType in $referenceMap.ReferenceTypes)
            {
                $foundInPropertyPathList = @()
                for($s = 0; $s -lt $stackObjectsFoundIn.Count; $s++ )
                {
                    $startingString = "[$($s)]"
                    for($o = 0; $o -lt $stackObjectsFoundIn[$s].Objects.Count; $o++)
                    {
                        $objectPathString = "$($startingString).Objects[$($o)].$($stackObjectsFoundIn[$s].Type)Object"
                        $foundInPropertyPathList += Find-ObjectPropertiesRecursive -object $stackObjectsFoundIn[$s].Objects[$o]."$($stackObjectsFoundIn[$s].Type)Object" -matchToken "^$($referenceType.Name)$" -pathName $objectPathString
                    }
                }
                foreach($propertyPath in $foundInPropertyPathList)
                {
                    $transformedPropertyPath = ($propertyPath -replace "\.$($referenceType.Name)$")
                    $object = Get-PropertyObjectDynamic -object $stackObjectsFoundIn -propertyPath $transformedPropertyPath
                    $rootPosition = $transformedPropertyPath.Split(".")[0] -replace "\[" -replace "\]"
                    $rootObjectPath = $transformedPropertyPath.Split(".")[0..1] -join "."
                    $rootObject = Get-PropertyObjectDynamic -object $stackObjectsFoundIn -propertyPath $rootObjectPath
                    if($object."$($referenceType.Name)".GetType().ToString() -eq $referenceType.Type)
                    {
                        $stackObject = $null
                        if($null -ne $referenceType.ReferenceAt)
                        {
                            $referencedValue = $object."$($referenceType.Name)"[$referenceType.ReferenceAt]
                        }
                        else
                        {
                            $referencedValue = $object."$($referenceType.Name)"
                        }
                        if(!$referencedValue.StartsWith("AWS::"))
                        {
                            if($null -ne $referenceType.SearchString)
                            {
                                $stackObject = $stackObjectType.Objects | Where-Object { $referencedValue -match ($referenceType.SearchString -replace "ResourceName", $_.Name) }
                            }
                            else
                            {
                                $stackObject = $stackObjectType.Objects | Where-Object { $_.Name -eq $referencedValue }                   
                            }
                            if($null -ne $stackObject)
                            {
                                if(($stackObject.PsObject.Properties | Where-Object { $_.Name -eq "FoundIn" }).Length -eq 0)
                                {
                                    $stackObject | Add-Member -MemberType NoteProperty -Name "FoundIn" -Value @()
                                }
                                $trimmedPath = $transformedPropertyPath.Split(".")[1..($transformedPropertyPath.Split(".").Length - 1)] -join "."
                                $layer = $rootObject.Layer
                                $newRefObject = New-Object System.Object
                                $newRefObject | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $stackObjectsFoundIn[$rootPosition].Type
                                $newRefObject | Add-Member -MemberType NoteProperty -Name "Path" -Value $trimmedPath
                                $newRefObject | Add-Member -MemberType NoteProperty -Name "Layer" -Value $layer
                                $newRefObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $rootObject.Name
                                $newRefObject | Add-Member -MemberType NoteProperty -Name "ReferenceTypeName" -Value $referenceType.Name
                                $newRefObject | Add-Member -MemberType NoteProperty -Name "ReferenceAt" -Value $referenceType.ReferenceAt
                                if(($stackObject.FoundIn | Where-Object { $_.Path -eq $newRefObject.Path }).Length -eq 0)
                                {
                                    $stackObject.FoundIn += $newRefObject
                                }
                            }
                        }
                    }
                }
            }
        }
        if($containsMap.Length -ne 0)
        {
            Write-Log -message "Searching $($stackObjectType.Type) for: $($containsMap -join ", ") "
            $containsObjects = $stackReferencedObjectsMap | Where-Object { $containsMap -contains $_.ObjectType }
            foreach($containsObject in $containsObjects)
            {
                $containsObjectTypeList = $masterStackObjectArray | Where-Object { $_.Type -eq $containsObject.ObjectType }
                foreach($referenceType in $containsObject.ReferenceTypes)
                {
                    $containsPropertyPathList = @()
                    for($i = 0; $i -lt $stackObjectType.Objects.Length; $i++)
                    {
                        $objectPathString = "Objects[$($i)].$($stackObjectType.Type)Object"
                        $containsPropertyPathList += Find-ObjectPropertiesRecursive -object $stackObjectType.Objects[$i]."$($stackObjectType.Type)Object" -matchToken "^$($referenceType.Name)$" -pathName $objectPathString
                    }
                    foreach($propertyPath in $containsPropertyPathList)
                    {
                        $transformedPropertyPath = ($propertyPath -replace "\.$($referenceType.Name)$")
                        $object = Get-PropertyObjectDynamic -object $stackObjectType -propertyPath $transformedPropertyPath
                        $rootObjectPath = $transformedPropertyPath.Split(".")[0]
                        $rootObject = Get-PropertyObjectDynamic -object $stackObjectType -propertyPath $rootObjectPath
                        if($null -ne $referenceType.ReferenceAt)
                        {
                            $referencedValue = $object."$($referenceType.Name)"[$referenceType.ReferenceAt]
                        }
                        else
                        {
                            $referencedValue = $object."$($referenceType.Name)"
                        }
                        if(!$referencedValue.StartsWith("AWS::"))
                        {
                            if($null -ne $referenceType.SearchString)
                            {
                                $stackObject = $containsObjectTypeList.Objects | Where-Object { $referencedValue -match ($referenceType.SearchString -replace "ResourceName", $_.Name) }
                            }
                            else
                            {
                                $stackObject = $containsObjectTypeList.Objects | Where-Object { $_.Name -eq $referencedValue }
                            }
                            if($null -ne $stackObject)
                            {
                                $position = $containsObjectTypeList.Objects.IndexOf($stackObject)
                                $propertyToPath = "Objects[$($position)].$($containsObjectTypeList.Type)Object"
                                if(($rootObject.PsObject.Properties | Where-Object { $_.Name -eq "Contains" }).Length -eq 0)
                                {
                                    $rootObject | Add-Member -MemberType NoteProperty -Name "Contains" -Value @()
                                }
                                $layer = $stackObject.Layer
                                $newRefObject = New-Object System.Object
                                $newRefObject | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $containsObjectTypeList.Type
                                $newRefObject | Add-Member -MemberType NoteProperty -Name "Path" -Value $propertyToPath
                                $newRefObject | Add-Member -MemberType NoteProperty -Name "Layer" -Value $layer
                                $newRefObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $stackObject.Name
                                $newRefObject | Add-Member -MemberType NoteProperty -Name "ReferenceTypeName" -Value $referenceType.Name
                                $newRefObject | Add-Member -MemberType NoteProperty -Name "ReferenceAt" -Value $referenceType.ReferenceAt
                                if(($rootObject.Contains | Where-Object { $_.Path -eq $newRefObject.Path }).Length -eq 0)
                                {
                                    $rootObject.Contains += $newRefObject
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}



Write-Log -message "Manage Resources referenceing Resources"
##########################################
# Manage Resources Referencing Resources
##########################################
foreach($stackObject in $stackResourceObjects.Objects)
{
    if($null -ne $stackObject.FoundIn)
    {
        if($stackObject.FoundIn.Length -gt 0)
        {
            $stackLayer = $managedStackArray[$stackObject.Layer]
            $exportObjectName = "$($stackSystemName)$($stackLayer.LayerName)$($stackLayer.Layer)$($stackObject.Name)$($foundObject.Name)"
            $layersIn = @()
            $layersIn = ($stackObject.FoundIn | Where-Object { $_.ObjectType -eq "Resources" } | Select-Object -ExpandProperty "Layer" | Where-Object { $_ -ne $stackObject.Layer } | Get-Unique)
            if($null -ne $layersIn)
            {
                if(($layersIn | Where-Object { $_ -lt $stackObject.Layer}).Length -gt 1)
                {
                    Write-ErrorLog "Object: $($stackObject.Name) is on a Lower layer yet is referenced by Objects on a Higher layer."
                }
                else
                {
                    if(($layersIn | Where-Object { $_ -gt $stackObject.Layer }).Length -gt 0)
                    {
                        if(($stackLayer.PsObject.Properties | Where-Object { $_.Name -eq "Outputs" }).Length -eq 0)
                        {
                            $stackLayer | Add-Member -MemberType NoteProperty -Name "Outputs" -Value (New-Object System.Object)
                        }
                    }
                    foreach($foundObject in $stackObject.FoundIn | Where-Object { $_.Layer -gt $stackObject.Layer -and $_.ObjectType -eq "Resources" })
                    {
                        $stackObjectType = $masterStackObjectArray | Where-Object { $_.Type -eq $foundObject.ObjectType }
                        $splitPath = $foundObject.Path.Split(".")
                        $lastPath = $splitPath[-1]
                        $previousPath = $splitPath[0..($splitPath.Length - 2)] -join "."
                        $rootObjectToModify = Get-PropertyObjectDynamic -object $stackObjectType -propertyPath $previousPath
                        $objectToModify = Get-PropertyObjectDynamic -object $stackObjectType -propertyPath $foundObject.Path
                        $newSubObject = New-Object System.Object
                        $newSubObject | Add-Member -MemberType NoteProperty -Name "Fn::Sub" -Value $exportObjectName
                        $newImpObject = New-Object System.Object
                        $newImpObject | Add-Member -MemberType NoteProperty -Name "Fn::ImportValue" -Value $newSubObject

                        if(($stackLayer.Outputs.PsObject.Properties | Where-Object { $_.Name -eq $exportObjectName }).Length -eq 0)
                        {
                            $newOutputExportObject = New-Object System.Object
                            $newOutputExportObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $exportObjectName
                            $newReferenceExportObject = New-Object System.Object
                            $newReferenceExportObject | Add-Member -MemberType NoteProperty -Name $foundObject.ReferenceTypeName -Value (Clone-Object2 -objectToClone $objectToModify."$($foundObject.ReferenceTypeName)")
                            $newOutputObject = New-Object System.Object
                            $newOutputObject | Add-Member -MemberType NoteProperty -Name "Value" -Value (Clone-Object2 -objectToClone $newReferenceExportObject) 
                            $newOutputObject | Add-Member -MemberType NoteProperty -Name "Export" -Value $newOutputExportObject
                            $stackLayer.Outputs | Add-Member -MemberType NoteProperty -Name $exportObjectName -Value $newOutputObject
                        }
                        if($lastPath -match ".+?(\[[0-9]+\])$")
                        {
                            $lastPathSplit = $lastPath.Split("[")
                            $lastPathProperty = $lastPathSplit[0]
                            $position = $lastPathSplit[1].TrimEnd("]")
                            $rootObjectToModify."$($lastPathProperty)"[$position] = $newImpObject
                        }
                        else
                        {
                            $rootObjectToModify."$($lastPath)" = $newImpObject
                        }
                    }
                }
            }
        }
    }
}

Write-Log -message "Manage Outputs referenceing Resources"
##########################################
# Manage Outputs Referencing Resources
##########################################
foreach($stackObject in $stackOutputObjectsObjects)
{
    if($null -ne $stackObject.Contains)
    {
        $layersIn = @()
        $otherLayers = @()
        $layersIn = ($stackObject.Contains | Where-Object { $_.ObjectType -eq "Resources" } | Select-Object -ExpandProperty "Layer" | Get-Unique) | Sort-Object -Descending
        if($layersIn.Length -ne 0)
        {
            $initialLayer = $layersIn[0]
            $stackObject.Layer = $initialLayer
            
            if($layersIn.Length -gt 1)
            {
                $otherLayers = $layersIn[1..($layersIn.Length - 1)]
            }
            $stackLayer = $managedStackArray[$initialLayer]
            if(($stackLayer.PsObject.Properties | Where-Object { $_.Name -eq "Outputs" }).Length -eq 0)
            {
                $stackLayer | Add-Member -MemberType NoteProperty -Name "Outputs" -Value (New-Object System.Object)
            }
            $stackLayer.Outputs | Add-Member -MemberType NoteProperty -Name $stackObject.Name -Value $stackObject.OutputsObject."$($stackObject.Name)"
            if($otherLayers.Length -gt 0)
            {
                Write-Warning "We have an Output problem"
            }
            foreach($container in $stackObject.Contains)
            {
                $containerObject = Get-PropertyObjectDynamic -object ($masterStackObjectArray | Where-Object { $_.Type -eq $container.ObjectType })[0] -propertyPath $container.Path.Split(".")[0]
                ($containerObject.FoundIn | Where-Object { $_.Name -eq $stackObject.Name -and $_.ObjectType -eq  "Outputs"}).Layer = $initialLayer
            }
        }
    }
}

Write-Log -message "Manage Conditions referenceing Resources and Outputs"
##########################################
# Manage Conditions Referencing Resources and Outputs
##########################################
foreach($stackObject in $stackConditionObjects.Objects)
{
    if($null -ne $stackObject.FoundIn)
    {
        $layersIn = @()
        $otherLayers = @()
        $layersIn = ($stackObject.FoundIn | Where-Object { @("Resources", "Outputs") -contains $_.ObjectType } | Select-Object -ExpandProperty "Layer" | Where-Object { $_ -ne $stackObject.Layer } | Get-Unique ) | Sort-Object -Descending
        if($layersIn.Length -ne 0)
        {
            $initialLayer = $layersIn[0]
            $stackObject.Layer = $initialLayer
            if($layersIn.Length -gt 1)
            {
                $otherLayers = $layersIn[1..($layersIn.Length - 1)]
            }
            $stackLayer = $managedStackArray[$initialLayer]
            if(($stackLayer.PsObject.Properties | Where-Object { $_.Name -eq "Conditions" }).Length -eq 0)
            {
                $stackLayer | Add-Member -MemberType NoteProperty -Name "Conditions" -Value (New-Object System.Object)
            }
            $stackLayer.Conditions | Add-Member -MemberType NoteProperty -Name $stackObject.Name -Value $stackObject.ConditionsObject."$($stackObject.Name)"
            if($otherLayers.Length -gt 0)
            {
                Write-Warning "We have a Conditon problem"
            }
            foreach($container in $stackObject.Contains)
            {
                $containerObject = Get-PropertyObjectDynamic -object ($masterStackObjectArray | Where-Object { $_.Type -eq $container.ObjectType })[0] -propertyPath $container.Path.Split(".")[0]
                ($containerObject.FoundIn | Where-Object { $_.Name -eq $stackObject.Name -and $_.ObjectType -eq  "Conditions"}).Layer = $initialLayer
            }
            foreach($foundin in $stackObject.FoundIn)
            {
                $foundInObject = Get-PropertyObjectDynamic -object ($masterStackObjectArray | Where-Object { $_.Type -eq $foundin.ObjectType })[0] -propertyPath $foundin.Path.Split(".")[0]
                ($foundInObject.Contains | Where-Object { $_.Name -eq $stackObject.Name -and $_.ObjectType -eq  "Conditions"}).Layer = $initialLayer
            }
        }
    }
}

Write-Log -message "Manage Conditions referenceing Conditions"
##########################################
# Manage Conditions referenceing Conditions
##########################################
foreach($stackObject in $stackConditionObjects.Objects)
{
    if($null -ne $stackObject.FoundIn)
    {
        $layersIn = @()
        $otherLayers = @()

        $layersIn = ($stackObject.FoundIn | Where-Object { $_.ObjectType -eq "Conditions" } | Select-Object -ExpandProperty "Layer" | Where-Object { $_ -ne $stackObject.Layer } | Get-Unique ) | Sort-Object -Descending
        if($layersIn.Length -ne 0)
        {
            $initialLayer = $layersIn[0]
            $stackObject.Layer = $initialLayer
            if($layersIn.Length -gt 1)
            {
                $otherLayers = $layersIn[1..($layersIn.Length - 1)]
            }
            $stackLayer = $managedStackArray[$initialLayer]
            if(($stackLayer.PsObject.Properties | Where-Object { $_.Name -eq "Conditions" }).Length -eq 0)
            {
                $stackLayer | Add-Member -MemberType NoteProperty -Name "Conditions" -Value (New-Object System.Object)
            }
            $stackLayer.Conditions | Add-Member -MemberType NoteProperty -Name $stackObject.Name -Value $stackObject.ConditionsObject."$($stackObject.Name)"
            if($otherLayers.Length -gt 0)
            {
                Write-Warning "We have a Conditon problem"
            }
            foreach($container in $stackObject.Contains)
            {
                $containerObject = Get-PropertyObjectDynamic -object ($masterStackObjectArray | Where-Object { $_.Type -eq $container.ObjectType })[0] -propertyPath $container.Path.Split(".")[0]
                ($containerObject.FoundIn | Where-Object { $_.Name -eq $stackObject.Name -and $_.ObjectType -eq  "Conditions"}).Layer = $initialLayer
            }
            foreach($foundin in $stackObject.FoundIn)
            {
                $foundInObject = Get-PropertyObjectDynamic -object ($masterStackObjectArray | Where-Object { $_.Type -eq $foundin.ObjectType })[0] -propertyPath $foundin.Path.Split(".")[0]
                ($foundInObject.Contains | Where-Object { $_.Name -eq $stackObject.Name -and $_.ObjectType -eq  "Conditions"}).Layer = $initialLayer
            }
        }
    }
}

Write-Log -message "Manage Parameters referenceing Resources and Outputs and Conditions"
##########################################
# Manage Parameters Referencing Resources and Outputs and Conditions
##########################################
foreach($stackObject in $stackParameterObjects.Objects)
{
    if($null -ne $stackObject.FoundIn)
    {
        $layersIn = @()
        $otherLayers = @()
        $layersIn = ($stackObject.FoundIn | Where-Object { @("Resources", "Outputs", "Conditions") -contains $_.ObjectType } | Select-Object -ExpandProperty "Layer" | Where-Object { $_ -ne $stackObject.Layer } | Get-Unique ) | Sort-Object -Descending
        if($layersIn.Length -ne 0)
        {
            $initialLayer = $layersIn[0]
            $stackObject.Layer = $initialLayer
            if($layersIn.Length -gt 1)
            {
                $otherLayers = $layersIn[1..($layersIn.Length - 1)]
            }
            $stackLayer = $managedStackArray[$initialLayer]
            if(($stackLayer.PsObject.Properties | Where-Object { $_.Name -eq "Parameters" }).Length -eq 0)
            {
                $stackLayer | Add-Member -MemberType NoteProperty -Name "Parameters" -Value (New-Object System.Object)
            }
            $stackLayer.Parameters | Add-Member -MemberType NoteProperty -Name $stackObject.Name -Value $stackObject.ParametersObject."$($stackObject.Name)"
            if($otherLayers.Length -gt 0)
            {
                Write-Warning "We have a Parameter problem"
            }
            foreach($foundin in $stackObject.FoundIn)
            {
                $foundInObject = Get-PropertyObjectDynamic -object ($masterStackObjectArray | Where-Object { $_.Type -eq $foundin.ObjectType })[0] -propertyPath $foundin.Path.Split(".")[0]
                ($foundInObject.Contains | Where-Object { $_.Name -eq $stackObject.Name -and $_.ObjectType -eq  "Parameters"}).Layer = $initialLayer
            }
        }
    }
}

Write-Log -message "Manage Mappings referenceing Resources and Outputs and Conditions"
##########################################
# Manage Mappings Referencing Resources and Outputs and Conditions
##########################################
foreach($stackObject in $stackMappingObjects.Objects)
{
    if($null -ne $stackObject.FoundIn)
    {
        $layersIn = @()
        $otherLayers = @()
        $layersIn = ($stackObject.FoundIn | Where-Object { @("Resources", "Outputs", "Conditions") -contains $_.ObjectType } | Select-Object -ExpandProperty "Layer" | Where-Object { $_ -ne $stackObject.Layer } | Get-Unique ) | Sort-Object -Descending
        if($layersIn.Length -ne 0)
        {
            $initialLayer = $layersIn[0]
            $stackObject.Layer = $initialLayer
            if($layersIn.Length -gt 1)
            {
                $otherLayers = $layersIn[1..($layersIn.Length - 1)]
            }
            $stackLayer = $managedStackArray[$initialLayer]
            if(($stackLayer.PsObject.Properties | Where-Object { $_.Name -eq "Mappings" }).Length -eq 0)
            {
                $stackLayer | Add-Member -MemberType NoteProperty -Name "Mappings" -Value (New-Object System.Object)
            }
            $stackLayer.Mappings | Add-Member -MemberType NoteProperty -Name $stackObject.Name -Value $stackObject.MappingsObject."$($stackObject.Name)"
            if($otherLayers.Length -gt 0)
            {
                Write-Warning "We have a Mapping problem"
            }
            foreach($foundin in $stackObject.FoundIn)
            {
                $foundInObject = Get-PropertyObjectDynamic -object ($masterStackObjectArray | Where-Object { $_.Type -eq $foundin.ObjectType })[0] -propertyPath $foundin.Path.Split(".")[0]
                ($foundInObject.Contains | Where-Object { $_.Name -eq $stackObject.Name -and $_.ObjectType -eq  "Mappings"}).Layer = $initialLayer
            }
        }
    }
}


Write-Log -message "Manage Outputs in Conditions and Resources"
##########################################
# Manage Outputs Referencing Resources
##########################################
foreach($stackObject in ($stackOutputObjects.Objects | Where-Object { $_.Layer -eq 666 } ))
{
    if($null -ne $stackObject.Contains)
    {
        $layersIn = @()
        $otherLayers = @()
        $layersIn = ($stackObject.Contains | Where-Object { $_.ObjectType -ne "Resources" } | Select-Object -ExpandProperty "Layer" | Get-Unique) | Sort-Object -Descending
        if($layersIn.Length -ne 0)
        {
            $initialLayer = $layersIn[0]
            $stackObject.Layer = $initialLayer
            
            if($layersIn.Length -gt 1)
            {
                $otherLayers = $layersIn[1..($layersIn.Length - 1)]
            }
            $stackLayer = $managedStackArray[$initialLayer]
            if(($stackLayer.PsObject.Properties | Where-Object { $_.Name -eq "Outputs" }).Length -eq 0)
            {
                $stackLayer | Add-Member -MemberType NoteProperty -Name "Outputs" -Value (New-Object System.Object)
            }
            $stackLayer.Outputs | Add-Member -MemberType NoteProperty -Name $stackObject.Name -Value $stackObject.OutputsObject."$($stackObject.Name)"
            if($otherLayers.Length -gt 0)
            {
                Write-Warning "We have an Output problem"
            }
            foreach($container in $stackObject.Contains)
            {
                $containerObject = Get-PropertyObjectDynamic -object ($masterStackObjectArray | Where-Object { $_.Type -eq $container.ObjectType })[0] -propertyPath $container.Path.Split(".")[0]
                ($containerObject.FoundIn | Where-Object { $_.Name -eq $stackObject.Name -and $_.ObjectType -eq  "Outputs"}).Layer = $initialLayer
            }
        }
    }
}
<#
foreach($stackObject in $stackTransientResourceObjects.Objects)
{
    if(($stackObject.ResourcesObject."$($stackObject.Name)".PsObject.Properties | Where-Object { $_.Name -eq "DependsOn" }).Length -gt 0)
    {
        foreach($dependantResource in $stackObject.ResourcesObject."$($stackObject.Name)".DependsOn)
        {
            $resource = $stackResourceObjects.Objects | Where-Object { $_.Name -eq $dependantResource }
            if($null -ne $resource)
            {
                if(($stackObject.PsObject.Properties | Where-Object { $_.Name -eq "DependsOn" }).Length -eq 0)
                {
                    $stackObject | Add-Member -MemberType NoteProperty -Name "DependsOn" -Value @()
                }
                $newDependObject = New-Object System.Object
                $newDependObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $resource.Name
                $newDependObject | Add-Member -MemberType NoteProperty -Name "Layer" -Value $resource.Layer
                $stackObject.DependsOn += $newDependObject
            }
        }
    }
}
#>


Write-Log -message "Output to files (to do, dont output empty layers)"
##########################################
# Manage Outputs Referencing Resources
##########################################
foreach($stackLayer in $managedStackArray)
{
    $cloudFormationStack = New-Object System.Object
    foreach($stackObjectType in $stackArchitecture)
    {
        if($null -ne $stackLayer."$($stackObjectType.Type)")
        {
            $cloudFormationStack | Add-Member -MemberType NoteProperty -Name $stackObjectType.Type -Value $stackLayer."$($stackObjectType.Type)"
        }
    }
    $cloudformationString = ConvertTo-Json $cloudFormationStack -Depth 100

    [IO.File]::WriteAllLines("C:\ChadRoesler_Workspace\wranglerTest\WrangledConditions5\test_$($stackLayer.LayerName)_$($stackLayer.Layer.ToString()).json", $cloudformationString)
}
