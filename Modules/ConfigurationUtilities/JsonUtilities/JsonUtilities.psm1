function Merge-Objects {
    Param (
        [object] $BaseObject, 
        [object] $ObjectToMerge
    )
    $propertyNames = $($ObjectToMerge | Get-Member -MemberType *Property).Name
    foreach ($propertyName in $propertyNames) {
		# Check if property already exists
        if ($BaseObject.PSObject.Properties.Match($propertyName).Count) {
            if ($BaseObject.$propertyName.GetType().Name -eq 'PSCustomObject') {
				# Recursively merge subproperties
                $BaseObject.$propertyName = Merge-Objects $BaseObject.$propertyName $ObjectToMerge.$propertyName
            } else {
				# Overwrite Property
                $BaseObject.$propertyName = $ObjectToMerge.$propertyName
            }
        } else {
			# Add property
            $BaseObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value $ObjectToMerge.$propertyName
        }
    }
    return $BaseObject
}


function Format-Json{
    Param(
        [string] $JsonString
    )
    $indent = 0;
    ($JsonString -Split '\n' |
      % {
        if ($_ -match '[\}\]]') {
          # This line contains  ] or }, decrement the indentation level
          $indent--
        }
        $line = (' ' * $indent * 2) + $_.TrimStart().Replace(':  ', ': ')
        if ($_ -match '[\{\[]') {
          # This line contains [ or {, increment the indentation level
          $indent++
        }
        $line
    }) -Join "`n"
}


  function Object-PropertyRemover {
    Param(
        [Object] $Object,
        [array] $PropertiesToRemove
    )

    foreach($property in $PropertiesToRemove)
    {
        $propertyAndChildren = $Property.Split(".")
        if($propertyAndChildren.Count -gt 1)
        {
            $parentProperty = $propertyAndChildren[0]
            $property = ($propertyAndChildren | Where-Object { $_ -ne $parentProperty }) -Join "."
            $propertyArray = @($property)
            $object.$parentProperty = Object-PropertyRemover -Object $object.$parentProperty -PropertiesToRemove $propertyArray
        }
        else 
        {
            if(($object.PSObject.Properties.Name -match $Property))
            {
                $object.PSObject.Properties.Remove($Property)
            }
        }
    }
    return $object
}

function Object-PropertyAdder {
    Param(
        [Object] $Object,
        [array] $PropertiesToAdd
    )

    foreach($property in $PropertiesToAdd)
    {
        $propertyAndChildren = $Property.Split(".")
        if($propertyAndChildren.Count -gt 1)
        {
            $parentProperty = $propertyAndChildren[0]
            $childProperty = ($propertyAndChildren | Where-Object { $_ -ne $parentProperty }) -Join "."
            $childPropertyArray = @($childProperty)
            if(!($object.PSObject.Properties.Name -match $parentProperty))
            {
                $object | Add-Member -MemberType NoteProperty -Name $parentProperty -Value (New-Object PSObject)
            }
            $object.$parentProperty = Object-PropertyAdder -Object $object.$parentProperty -PropertiesToAdd $childPropertyArray
        }
        else 
        {
            if(!($object.PSObject.Properties.Name -match $property))
            {
                $object | Add-Member -Type NoteProperty -Name $property -Value ""
            }
        }
    }
    return $object
}

function Merge-Json{
      Param(
        [string] $SourcePath,
        [array] $TransformFilePaths,
        [bool] $FailIfTransformMissing,
        [array] $PropertiesToRemove,
        [array] $PropertiesToAdd,
        [string] $OutputPath
      )
      
	if(!(Test-Path $SourcePath)) {
		Write-Log -message "Source file $($SourcePath) does not exist!"
		Exit 1
	}
	
	$sourceObject = (Get-Content $SourcePath) -join "`n" | ConvertFrom-Json
	$mergedObject = $sourceObject
    
    foreach($transformPath in $TransformFilePaths)
    {
        if (!(Test-Path $transformPath)) {
            Write-Log -message "Transform file $transformPath does not exist!"
            if ([System.Convert]::ToBoolean($FailIfTransformMissing)) 
            {
                Exit 1
            }
            Write-Log -message "Skipping that file"
        } 
        else 
        {
            Write-Log -message "Applying transformations from $($transformPath) to $($SourcePath)"
            $transformObject = (Get-Content $transformPath) -join "`n" | ConvertFrom-Json
            $mergedObject = Merge-Objects $mergedObject $transformObject
        }
    }
    if($PropertiesToRemove -ne $null)
    {
        Write-Log -message "Removing Defined Properties."
        $mergedObject = Object-PropertyRemover -Object $mergedObject -PropertiesToRemove $PropertiesToRemove
    }
    if($PropertiesToAdd -ne $null)
    {
        Write-Log -message "Adding Defined Properties."
        $mergedObject = Object-PropertyAdder -Object $mergedObject -PropertiesToAdd $PropertiesToAdd
    }
    Write-Log -message "Writing merged JSON to $OutputPath..."
    $finalJson = $mergedObject | ConvertTo-Json -Depth 100
    $finalJson = Format-Json -json $finalJson
    [System.IO.File]::WriteAllLines($OutputPath, $finalJson)
}





function Update-JsonFile 
{
       param (
        [string]$FilePath,
        [hashtable]$Variables
        ) 
    Write-Log -message 'Starting the json file variable substitution' $Variables.Count
    if ($Variables -eq $null) {
        throw "Missing parameter value $Variables"
    }

	$pathExists = Test-Path $FilePath
	if(!$pathExists) {
		Write-Log -message "ERROR: Path $($FilePath) does not exist"
		Exit 1
	}

	$json = Get-Content $FilePath -Raw | ConvertFrom-Json
    Write-Log -message "Json content read from file"

	foreach($variable in $Variables.GetEnumerator()) {
		$key = $variable.Key
        Write-Log -message "Processing $($key)"
        $keys = $key.Split(':')
		$sub = $json
		$pre = $json
		$found = $true
		$lastKey = ''
		foreach($k in $keys) {
			if($sub | Get-Member -name $k -Membertype Properties){
				$pre = $sub
				$sub = $sub.$k
			}
			else
			{
				$found = $false
				break
			}

			$lastKey = $k
		}

		if($found) {
            Write-Log -message "$($key) found in Json content"
            if($pre.$lastKey -eq $null) {
                Write-ErrorLog -message "$($key) is null in the original source json...values CANNOT be null on the source json file...exiting with 1"
                Exit 1
            }

			$typeName = $pre.$lastKey.GetType().Name
			[bool]$b = $true
			[int]$i = 0
			[decimal]$d = 0.0
			if($typeName -eq 'String'){
				$pre.$lastKey = $variable.Value
			}
			elseif($typeName -eq 'Boolean' -and [bool]::TryParse($variable.Value, [ref]$b)) {
				$pre.$lastKey = $b
			}
			elseif($typeName -eq 'Int32' -and [int]::TryParse($variable.Value, [ref]$i)){
				$pre.$lastKey = $i
			}
			elseif($typeName -eq 'Decimal' -and [decimal]::TryParse($variable.Value, [ref]$d)){
				$pre.$lastKey = $d
			}
			elseif($typeName -eq 'Object[]') {
                if($pre.$lastKey.Length -ne 0 -and $pre.$lastKey[0].GetType().Name -eq 'String') {
				    $pre.$lastKey = $variable.Value.TrimStart('[').TrimEnd(']').Split(',')
                }
                else {
                    Write-ErrorLog -message "ERROR: Cannot handle $($key) with type $($typeName) 
				    Only nonempty string arrays are supported at the moment meaning that it has to be a 
				    string array with atleast one element in it in the original source appsettings.json 
				    file...Skipping update and exiting with 1"
				    Exit 1
                }
			}
			else {
				Write-ErrorLog -message "ERROR: Cannot handle $($key) with type $($typeName) 
				Only string, boolean, interger, decimal and non-empty string arrays are supported at the moment
                ...Skipping update and exiting with 1"
				Exit 1
			}

            Write-Log -message "$($key) updated in json content with value $($pre.$lastKey)" 

		}
        else {
            Write-Log -message "$($key) not found in Json content...skipping it"
        }
	}
    
    $finalJson = $json | ConvertTo-Json -Depth 100
    $finalJson = Format-Json -json $finalJson
    [System.IO.File]::WriteAllLines($FilePath, $finalJson)
    
    Write-Log -message "$($FilePath) file variables updated successfully...Done"
}


function Write-MultipleJsonFileValues
{
    param(
        [array] $JsonFilePaths,
        [hashtable] $ParameterHash
    )

    foreach($jsonFile in $JsonFilePaths)
    {
        Write-Log -message "Updating Values in $($jsonFile)"
        Update-JsonFile -fullpath $jsonFile `
                        -variables $ParameterHash
    }
}