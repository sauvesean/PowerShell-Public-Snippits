function Compare-ObjectRecursive {
    <#
        .SYNOPSIS
        Compares two objects, and traverses the properties of the objects to determine if sub-properties are equal.

        .DESCRIPTION
        Can support more complex objects than Compare-Object such as arrays, hashtables, PSCustomObject, etc.

        .PARAMETER ReferenceObject
        The reference object

        .PARAMETER DifferenceObject
        The difference object

        .PARAMETER BooleanOutput
        Return only true, if the objects are equal, or false, if the objects are not equal.

        .PARAMETER IgnoreProperty
        Ignore the specified properties when comparing properties and their values

        .PARAMETER EvaluateNullOrEmptyAsEqual
        Null, empty strings, DBNull, etc will all be treated as equal

        .PARAMETER EvaluateGuidTypesAsString
        A GUID type will be treated as equal to a GUID encoded as a string as long as they have the same values

        .EXAMPLE
        PS> Compare-ObjectRecursive @('a', 'b') @('a', 'c')

        InputObject SideIndicator
        ----------- -------------
        c           =>
        b           <=

        .EXAMPLE
        PS> $ReferenceObject = @(
            @{ 'Name' = 'John'; 'DOB' = '1/1/1999' }
            @{ 'Name' = 'Jane'; 'DOB' = '12/1/2005' }
        )
        PS> $DifferenceObject = @(
            @{ 'Name' = 'John'; 'DOB' = '1/1/1999' }
            @{ 'Name' = 'Jane'; 'DOB' = '12/1/2007' }
            @{ 'Name' = 'Jill'; 'DOB' = '6/1/2005' }
        )
        PS> $Comparison = Compare-ObjectRecursive $ReferenceObject $DifferenceObject
        PS> $Comparison | ConvertTo-Json

        [
            {
                "InputObject": {
                    "Name": "Jane",
                    "DOB": "12/1/2007"
                },
                "SideIndicator": "=>"
            },
            {
                "InputObject": {
                    "Name": "Jill",
                    "DOB": "6/1/2005"
                },
                "SideIndicator": "=>"
            },
            {
                "InputObject": {
                    "Name": "Jane",
                    "DOB": "12/1/2005"
                },
                "SideIndicator": "<="
            }
        ]

        .NOTES
        ===========================================================================
		Created with: 	Visual Studio Code
		Created on:   	5/10/2023
		Created by:   	Sean.Sauve
		Filename:     	Compare-ObjectRecursive.ps1
		===========================================================================
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$ReferenceObject,
        [Parameter(Mandatory)]
        [object]$DifferenceObject,
        [switch]$BooleanOutput,
        [string[]]$IgnoreProperty,
        [switch]$EvaluateNullOrEmptyAsEqual,
        [switch]$EvaluateGuidTypesAsString
    )
    $RecursiveParams = @{}
    if ($PSBoundParameters.ContainsKey('IgnoreProperty')) {
        $RecursiveParams['IgnoreProperty'] = $IgnoreProperty
    }
    if ($EvaluateNullOrEmptyAsEqual) {
        $RecursiveParams['EvaluateNullOrEmptyAsEqual'] = $true
    }
    if ($EvaluateGuidTypesAsString) {
        $RecursiveParams['EvaluateGuidTypesAsString'] = $true
    }
    $BothAreStrings = $ReferenceObject -is [string] -and $DifferenceObject -is [string]
    $OneIsAStringTheOtherIsAGUID = $EvaluateGuidTypesAsString -eq $true -and (($ReferenceObject -is [string] -and $DifferenceObject -is [guid]) -or ($ReferenceObject -is [guid] -and $DifferenceObject -is [string]))
    $OneIsAStringTheOtherIsNot = ($ReferenceObject -is [string]) -ne ($DifferenceObject -is [string])
    $BothAreNumbers = $ReferenceObject -is [ValueType] -and $DifferenceObject -is [ValueType]
    $OneIsANumberTheOtherIsNot = ($ReferenceObject -is [ValueType]) -ne ($DifferenceObject -is [ValueType])
    if ($BothAreStrings) {
        #Write-Debug 'Compare-ObjectRecursive: Both are strings'
        if ($BooleanOutput) {
            $ReferenceObject -eq $DifferenceObject
        } elseif ($ReferenceObject -ne $DifferenceObject) {
            [PSCustomObject]@{
                'InputObject'   = $ReferenceObject
                'SideIndicator' = '<='
            }
            [PSCustomObject]@{
                'InputObject'   = $DifferenceObject
                'SideIndicator' = '=>'
            }
        }
        return
    } elseif ($OneIsAStringTheOtherIsAGUID) {
        #Write-Debug 'Compare-ObjectRecursive: One is a string, the other is a GUID'
        if ($BooleanOutput) {
            "$ReferenceObject" -eq "$DifferenceObject"
        } elseif ("$ReferenceObject" -ne "$DifferenceObject") {
            [PSCustomObject]@{
                'InputObject'   = $ReferenceObject
                'SideIndicator' = '<='
            }
            [PSCustomObject]@{
                'InputObject'   = $DifferenceObject
                'SideIndicator' = '=>'
            }
        }
        return
    } elseif ($OneIsAStringTheOtherIsNot) {
        #Write-Debug 'Compare-ObjectRecursive: One is a string, the other is not'
        if ($BooleanOutput) {
            $false
        } else {
            [PSCustomObject]@{
                'InputObject'   = $ReferenceObject
                'SideIndicator' = '<='
            }
            [PSCustomObject]@{
                'InputObject'   = $DifferenceObject
                'SideIndicator' = '=>'
            }
        }
        return
    } elseif ($BothAreNumbers) {
        #Write-Debug 'Compare-ObjectRecursive: Both are numbers'
        if ($BooleanOutput) {
            $ReferenceObject -eq $DifferenceObject
        } elseif ($ReferenceObject -ne $DifferenceObject) {
            [PSCustomObject]@{
                'InputObject'   = $ReferenceObject
                'SideIndicator' = '<='
            }
            [PSCustomObject]@{
                'InputObject'   = $DifferenceObject
                'SideIndicator' = '=>'
            }
        }
        return
    } elseif ($OneIsANumberTheOtherIsNot) {
        #Write-Debug 'Compare-ObjectRecursive: One is a number, the other is not'
        if ($BooleanOutput) {
            $false
        } else {
            [PSCustomObject]@{
                'InputObject'   = $ReferenceObject
                'SideIndicator' = '<='
            }
            [PSCustomObject]@{
                'InputObject'   = $DifferenceObject
                'SideIndicator' = '=>'
            }
        }
        return
    } elseif ($ReferenceObject -is [array] -and $DifferenceObject -isnot [array]) {
        #Write-Debug 'Compare-ObjectRecursive: reference is an array, difference is not'
        if ($BooleanOutput) {
            $false
            return
        }
        [PSCustomObject]@{
            'InputObject'   = $DifferenceObject
            'SideIndicator' = '=>'
        }
        foreach ($Value in $ReferenceObject) {
            [PSCustomObject]@{
                'InputObject'   = $Value
                'SideIndicator' = '<='
            }
        }
        return
    } elseif ($ReferenceObject -isnot [array] -and $DifferenceObject -is [array]) {
        #Write-Debug 'Compare-ObjectRecursive: difference is an array, reference is not'
        if ($BooleanOutput) {
            $false
            return
        }
        [PSCustomObject]@{
            'InputObject'   = $ReferenceObject
            'SideIndicator' = '<='
        }
        foreach ($Value in $DifferenceObject) {
            [PSCustomObject]@{
                'InputObject'   = $Value
                'SideIndicator' = '=>'
            }
        }
        return
    } elseif ($ReferenceObject -is [array] -and $DifferenceObject -is [array]) {
        #Write-Verbose 'Compare-ObjectRecursive: Both objects are arrays'
        $IndexFoundInReferenceObject = @()
        $IndexDifference = 0
        foreach ($Value in $DifferenceObject) {
            $FoundMatch = $false
            if ($Value -is [object]) {
                $IndexReference = 0
                foreach ($Value2 in $ReferenceObject) {
                    if ($IndexReference -notin $IndexFoundInReferenceObject) {
                        $ObjectsAreTheSame = $false
                        $ObjectsAreTheSame = Compare-ObjectRecursive -ReferenceObject $Value -DifferenceObject $Value2 -BooleanOutput @RecursiveParams
                        if ($ObjectsAreTheSame) {
                            $FoundMatch = $true
                            $IndexFoundInReferenceObject += $IndexReference
                            break
                        }
                    }
                    $IndexReference ++
                }
            } elseif ($Value -in $ReferenceObject) {
                $FoundMatch = $true
            }
            if ($FoundMatch -eq $false) {
                if ($BooleanOutput) {
                    $false
                    return
                }
                [PSCustomObject]@{
                    'InputObject'   = $Value
                    'SideIndicator' = '=>'
                }
            }
            $IndexDifference ++
        }
        $IndexFoundInDifferenceObject = @()
        $IndexReference = 0
        foreach ($Value in $ReferenceObject) {
            if ($IndexFoundInReferenceObject -in $IndexReference) {
                $IndexReference ++
                continue
            }
            $FoundMatch = $false
            if ($Value -is [object]) {
                $IndexDifference = 0
                foreach ($Value2 in $DifferenceObject) {
                    if ($IndexDifference -notin $IndexFoundInDifferenceObject) {
                        $ObjectsAreTheSame = $false
                        $ObjectsAreTheSame = Compare-ObjectRecursive -ReferenceObject $Value -DifferenceObject $Value2 -BooleanOutput @RecursiveParams
                        if ($ObjectsAreTheSame) {
                            $FoundMatch = $true
                            $IndexFoundInDifferenceObject += $IndexDifference
                            break
                        }
                    }
                    $IndexDifference ++
                }
            } elseif ($Value -in $DifferenceObject) {
                $FoundMatch = $true
            }
            if ($FoundMatch -eq $false) {
                if ($BooleanOutput) {
                    $false
                    return
                }
                [PSCustomObject]@{
                    'InputObject'   = $Value
                    'SideIndicator' = '<='
                }
            }
            $IndexReference ++
        }
        if ($BooleanOutput) {
            $true
        }
        return
    }
    #Write-Verbose 'Compare-ObjectRecursive: neither object is and string, number, or array'
    if ($ReferenceObject -is [hashtable]) {
        $Props1 = $ReferenceObject.Keys
    } else {
        $Props1 = $ReferenceObject | Get-Member -MemberType 'Properties' | Where-Object -FilterScript {
            $_.MemberType -in @('Property', 'NoteProperty')
        } | Select-Object -ExpandProperty 'Name'
    }
    if ($DifferenceObject -is [hashtable]) {
        $Props2 = $DifferenceObject.Keys
    } else {
        $Props2 = $DifferenceObject | Get-Member -MemberType 'Properties' | Where-Object -FilterScript {
            $_.MemberType -in @('Property', 'NoteProperty')
        } | Select-Object -ExpandProperty 'Name'
    }
    $Props = @($Props1) + @($Props2) | Select-Object -Unique
    #Select-Object -Unique is inconsistently case sensitive.  This has to be run to eliminate duplicate properties with
    # different casing.  Otherwise, Add-Member will error later on in this function.
    # See this issue for more details: https://github.com/PowerShell/PowerShell/issues/12059
    $Properties = @()
    foreach ($Prop in $Props) {
        if ($Prop -in $Properties) {
            continue
        }
        $Properties += $Prop
    }
    #Write-Verbose "Compare-ObjectRecursive: properties are $( $Properties -join '; ')"
    $OutputRight = [PSCustomObject]@{
        'SideIndicator' = '=>'
    }
    $OutputLeft = [PSCustomObject]@{
        'SideIndicator' = '<='
    }
    $ObjectsAreTheSame = $true
    foreach ($Property in $Properties) {
        $Value1 = $ReferenceObject.$Property
        $PropertyOutputLeft = $Value1
        $Value2 = $DifferenceObject.$Property
        $PropertyOutputRight = $Value2
        #Write-Debug "Compare-ObjectRecursive: Comparing property $Property with values '$Value1' and '$Value2'"
        if ($Property -in $IgnoreProperty) {
            #Write-Verbose "Compare-ObjectRecursive: ignoring property '$Property'"
        } elseif ($Value1 -is [object] -and $Value2 -is [object]) {
            if ($BooleanOutput) {
                $Result = Compare-ObjectRecursive -ReferenceObject $Value1 -DifferenceObject $Value2 -BooleanOutput @RecursiveParams
                if ($Result -eq $false) {
                    $ObjectsAreTheSame = $false
                    break
                }
            } else {
                $Result = Compare-ObjectRecursive -ReferenceObject $Value1 -DifferenceObject $Value2 @RecursiveParams
                if ($null -ne $Result) {
                    $ObjectsAreTheSame = $false
                    $PropertyOutputRight = $Result | Where-Object -Property 'SideIndicator' -EQ '=>'
                    $PropertyOutputLeft = $Result | Where-Object -Property 'SideIndicator' -EQ '<='
                }
            }
        } elseif ($Value1 -ne $Value2) {
            $BothAreSomeTypeOfNull = [string]::IsNullOrEmpty($Value1) -and [string]::IsNullOrEmpty($Value2)
            if ($EvaluateNullOrEmptyAsEqual -eq $true -and $BothAreSomeTypeOfNull -eq $false) {
                #Write-Verbose "Compare-ObjectRecursive: Values for property $Property are different.  ReferenceObject: $Value1; DifferenceObject: $Value2"
                $ObjectsAreTheSame = $false
                if ($BooleanOutput) {
                    break
                }
            }
        }
        $OutputLeft | Add-Member -NotePropertyName $Property -NotePropertyValue $PropertyOutputLeft
        $OutputRight | Add-Member -NotePropertyName $Property -NotePropertyValue $PropertyOutputRight
    }
    if ($BooleanOutput) {
        $ObjectsAreTheSame
    } elseif ($ObjectsAreTheSame -eq $false) {
        @(
            $OutputRight
            $OutputLeft
        )
    }
}
