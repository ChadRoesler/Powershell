<#
How to edit a single elements Attribute
Syntax: RootElement|Element:Element;AttributeToEdit
Ex:
<KingOfTheHill>
   <People>
      <HankHill>
         <Quote say="Bwhaaa!" 
      </HankHill>
   </People>
</KingOfTheHill>
Parameter Hash to find and Change the Quote:
@{"KingOfTheHill|People:HankHill:Quote;say" = "Dangit Bobby!"

Parameter Hash to add an attribute this same way:
@{"KingOfTheHill|People:HankHill:Quote;open" = "Beer"}
Produces:
<KingOfTheHill>
   <People>
      <HankHill>
         <Quote say="Dangit Bobby!" open="Beer" /> 
      </HankHill>
   </People>
</KingOfTheHill>

How to edit a sing elements Attribute where multiple Elements have the same name of the attribute but have some distinct values
Syntax: RootElement|Element:Element:Element;[AttributeToFind=ValueOfAttributeToFind]\AttributeToEdit
Ex:
<KingOfTheHill>
   <Texas>
      <AlleyWay>
         <Person Name="Hank" Job="PropaneManager" />
         <Person Name="Dale" Job="Exterminator" />
         <Person Name="Boomhauer" Job="Unknown" />
         <Person Name="Bill" Job="Barber" />
      </AlleyWay>
   </Texas>
</KingOfTheHill>

Parameter Hash to find and Change Boomhauer's Job:
@{"KingOfTheHill|Texas:AlleyWay:Person;[Name=Boomhauer]\Job" = "TexasRanger"}
Parameter Hash to find and Change Hank's Name:
@{"KingOfTheHill|Texas:AlleyWay:Person;[Name=Hank]\Name" = "HankHill"}

Parameter Hash to add an attribute this same way:
@{"KingOfTheHill|Texas:AlleyWay:Person;[Name=Hank]\FavoriteBeer" = "Alamo"}
Produces:
<KingOfTheHill>
   <Texas>
      <AlleyWay>
         <Person Name="Hank" Job="PropaneManager" FavoriteBeer="Alamo" />
         <Person Name="Dale" Job="Exterminator" />
         <Person Name="Boomhauer" Job="Unknown" />
         <Person Name="Bill" Job="Barber" />
      </AlleyWay>
   </Texas>
</KingOfTheHill>
#>

function Write-ConfigFileValues
{
    param(
        [string] $ConfigFilePath,
        [hashtable] $ParameterHash
    )

    $xmlContent = New-Object System.Xml.XmlDocument
    $xmlContent.PreserveWhitespace = $true
    $xmlContent.Load($ConfigFilePath)

    foreach($parameter in $ParameterHash.Keys)
    {
        $rootElement = ($parameter.Split("|"))[0]
        $childElements = ($parameter.Split("|"))[-1]
        $attribute = ($childElements.Split(";"))[-1]
        $elements = ($childElements.Split(";"))[0]
        $attributeValue = $ParameterHash.Item($parameter)
        $elementPath = $elements.Split(":")
        $elementToSet = $xmlContent.$rootElement    

        if($elementToSet -ne $null)
        {
            foreach($element in $elementPath)
            {
                if(($elementToSet.ChildNodes | Where-Object { $_.ToString() -eq $element }) -ne $null)
                { 
                    $elementToSet = $elementToSet.$element
                }
                else
                {
                    Write-Log -message "Path [$($elements)] Attribute [$($attribute)] does not exist in $($ConfigFilePath)"
                    $attribute = ""
                    break
                }
            }
            if($attribute)
            {
                if($attribute -match "\\[*\\]*")
                {
                    $matchingSyntax = (($attribute.Split("\"))[0]).Replace("[","").Replace("]","")
                    $attributeName = ($attribute.Split("\"))[-1]
                    $attributeToMatch = ($matchingSyntax.Split("="))[0]
                    $attirbuteValueToMatch = ($matchingSyntax.Split("="))[-1]
                    foreach($singleElementToSet in $elementToSet)
                    {
                        if($singleElementToSet.$attributeToMatch -eq $attirbuteValueToMatch)
                        {
                            Write-Log -message "Setting [$($elements)] Attribute [$($attribute)] to: $attributeValue"
                            $singleElementToSet.SetAttribute($attributeName, $attributeValue)
                        }
                    }
                }
                else
                {
                    Write-Log -message "Setting [$($elements)] Attribute [$($attribute)] to: $attributeValue"
                    $elementToSet.SetAttribute($attribute, $attributeValue)
                }
            }
        }
        else 
        {
            Write-Log -message "Root Element [$($elementToSet)] does not exist in $($ConfigFilePath)"   
        }
    }
    Write-Log "Saving Config File."
    $xmlContent.Save($ConfigFilePath)
}

function Write-MultipleConfigFileValues
{
    param(
        [array] $ConfigFilePaths,
        [hashtable] $ParameterHash
    )

    foreach($configFile in $ConfigFilePaths)
    {
        Write-Log -message "Updating Values in $($configFile)"
        Write-ConfigFileValues -ConfigFilePath $configFile `
                               -ParameterHash $ParameterHash
    }
}
