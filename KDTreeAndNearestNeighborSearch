function New-TSAGVKDTree {
    <#
        .SYNOPSIS
        Builds a K-dimensional tree from a list of objects.

        .DESCRIPTION
        Builds a K-dimensional tree from a list of objects.

        InputObject should be an array with these properties:
            * The IDPropertyName property should be a unique identifier for the object, if you specify IDPropertyName.
            * Each value in the Dimensions array should be a property of the object.

        The result will be a K-D tree with the following properties on each node:
            * Axis:      The name of the dimension used to split the tree at this node.
            * LeftSide:  The left side of the tree.
            * RightSide: The right side of the tree.
            * Payload:   The original object at this node.  The name of this property can be changed with PayloadPropertyName.
            * ID:        The ID of the object at this node.  The name of this property can be changed with IDPropertyName.

        .PARAMETER InputObject
        The objects to build the tree from.

        .PARAMETER IDPropertyName
        The name of the property that contains the unique identifier for each object.

        .PARAMETER PayloadPropertyName
        The name of the property to use on the output for storing the original object at each node.

        .PARAMETER Dimensions
        The names of the properties to use for each dimension.

        .EXAMPLE
        PS> $Params = @{
            'InputObject' = @(
                [PSCustomObject]@{
                    'ID'        = 'A'
                    'Latitude'  = 1
                    'Longitude' = 1
                }
                [PSCustomObject]@{
                    'ID'        = 'B'
                    'Latitude'  = 2
                    'Longitude' = 2
                }
                [PSCustomObject]@{
                    'ID'        = 'C'
                    'Latitude'  = 3
                    'Longitude' = 3
                }
            )
            'IDPropertyName'      = 'ID'
            'PayloadPropertyName' = 'Payload'
            'Dimensions'          = @('Latitude', 'Longitude')
        }
        PS> New-TSAGVKDTree @Params | ConvertTo-Json -Depth 20

        {
            "Axis":"Latitude",
            "LeftSide":[{
                "Axis":"Longitude",
                "LeftSide":null,
                "RightSide":null,
                "Payload":{
                    "ID":"A",
                    "Latitude":1,
                    "Longitude":1
                },
                "Longitude":1,
                "Latitude":1,
                "ID":"A"
            }],
            "RightSide":[{
                "Axis":"Longitude","LeftSide":null,"RightSide":null,
                "Payload":{
                    "ID":"C",
                    "Latitude":3,
                    "Longitude":3
                },
                "Longitude":3,
                "Latitude":3,
                "ID":"C"
            }],
            "Payload":{
                "ID":"B",
                "Latitude":2,
                "Longitude":2
            },
            "Latitude":2,
            "Longitude":2,
            "ID":"B"
        }

        .NOTES
        ===========================================================================
        Created with:   Visual Studio Code
        Created on:     11/28/2023
        Created by:     Sean Sauve
        Filename:       New-TSAGVKDTree.ps1
        ===========================================================================
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][PSCustomObject[]]$InputObject,
        [string]$IDPropertyName,
        [string]$PayloadPropertyName = 'Payload',
        [Parameter(Mandatory)]$Dimensions = @('Latitude', 'Longitude')
    )
    $NewDimensions = $Dimensions[1..($Dimensions.Count - 1) + 0] #Move first to last
    $RecursiveParams = @{
        'PayloadPropertyName' = $PayloadPropertyName
        'Dimensions'          = $NewDimensions
    }
    if ($PSBoundParameters.ContainsKey('IDPropertyName')) {
        $RecursiveParams['IDPropertyName'] = $IDPropertyName
    }
    $Count = $InputObject.Count
    $Median = [math]::Floor($Count / 2)
    $DebugOutput = "Count: $Count; Median: $Median"
    $InputObject = $InputObject | Sort-Object -Property $Dimensions[0]
    $HasLeft = $Median -gt 0
    $LeftObjects = $null
    if ($HasLeft) {
        $LeftObjects = $InputObject[0..($Median - 1)]
        $DebugOutput += "; Left: 0..$($Median - 1); LeftObjects: $($LeftObjects.$IDPropertyName -join ', ')"
    }
    $HasRight = $Count - $Median - 1 -gt 0
    $RightObjects = $null
    if ($HasRight) {
        $RightObjects = $InputObject[($Median + 1)..($Count - 1)]
        $DebugOutput += "; Right: $($Median + 1)..$($Count - 1); RightObjects: $($RightObjects.$IDPropertyName -join ', ')"
    }
    Write-Debug $DebugOutput
    $Left = $null
    if ($HasLeft) {
        $Left = @(New-TSAGVKDTree -InputObject $LeftObjects @RecursiveParams)
    }
    $Right = $null
    if ($HasRight) {
        $Right = @(New-TSAGVKDTree -InputObject $RightObjects @RecursiveParams)
    }
    $MedianObject = $InputObject[$Median]
    $Output = [PSCustomObject]@{
        'Axis'               = $Dimensions[0]
        $PayloadPropertyName = $MedianObject
        'LeftSide'           = $Left
        'RightSide'          = $Right
    }
    foreach ($Property in $Dimensions) {
        $Output | Add-Member -NotePropertyName $Property -NotePropertyValue $MedianObject.$Property -Force
    }
    if ($PSBoundParameters.ContainsKey('IDPropertyName')) {
        $Output | Add-Member -NotePropertyName $IDPropertyName -NotePropertyValue $MedianObject.$IDPropertyName -Force
    }
    $Output
}

function Search-TSAGVNearestNeighbor {
    <#
        .SYNOPSIS
        Searches for the nearest neighbor to a point in a K-dimensional tree.

        .DESCRIPTION
        Searches for the nearest neighbor to a point in a K-dimensional tree.  Use New-TSAGVKDTree to build the tree.

        .PARAMETER KDTree
        The tree to search.

        .PARAMETER IDPropertyName
        The name of the property that contains the unique identifier for the what you are searching against.  Use this
        to avoid returning the search object as the nearest neighbor.

        .PARAMETER SelfID
        The ID of the object you are searching against.  Use this to avoid returning the search object as the nearest
        neighbor.

        .PARAMETER Dimensions
        The names of the properties to use for each dimension.

        .PARAMETER SearchPosition
        The position to search for the nearest neighbor to.  Must be a PSCustomObject with properties matching the names
        in the Dimensions parameter.

        .PARAMETER MaximumDistance
        The maximum distance to search for a neighbor.  If no neighbor is found within this distance, no neighbor will
        be returned.

        .PARAMETER DimensionWeights
        The weight to apply to each dimension when calculating distance.  Must be a PSCustomObject with properties
        matching the names in the Dimensions parameter.  Usefull for when the dimensions and the MaximumDistance are
        not on the same scale.

        For example, you can specify a weight of 364000 for latitude and 288200 for longitude to convert the distance to
        feet.  This will not be an exact conversion, as longitude lines get closer together as the latitude approaches
        the poles.  It will also fail to find neighbors that cross the anti-meridian.  This could be fixed by using the
        haversine formula, but it will be close enough for most purposes for the time being.

        .EXAMPLE
        $Locations = @(
            [PSCustomObject]@{ 'ID' = 'A'; 'Latitude' = 33.952103; 'Longitude' = -84.138643 }
            [PSCustomObject]@{ 'ID' = 'B'; 'Latitude' = 33.952104; 'Longitude' = -84.138644 }
            [PSCustomObject]@{ 'ID' = 'C'; 'Latitude' = 33.652107; 'Longitude' = -84.138647 }
            [PSCustomObject]@{ 'ID' = 'D'; 'Latitude' = 33.652111; 'Longitude' = -84.138651 }
            [PSCustomObject]@{ 'ID' = 'E'; 'Latitude' = 33.852103; 'Longitude' = -84.238643 }
            [PSCustomObject]@{ 'ID' = 'F'; 'Latitude' = 33.852103; 'Longitude' = -84.238644 }
            [PSCustomObject]@{ 'ID' = 'G'; 'Latitude' = 33.852103; 'Longitude' = -84.238646 }
            [PSCustomObject]@{ 'ID' = 'H'; 'Latitude' = 33.752103; 'Longitude' = -84.138643 }
        )
        $KDTreeParams = @{
            'InputObject'         = $Locations
            'IDPropertyName'      = 'ID'
            'PayloadPropertyName' = 'Payload'
            'Dimensions'          = @('Latitude', 'Longitude')
        }
        $KDTree = New-TSAGVKDTree @KDTreeParams
        $CommonParams = @{
            'KDTree'              = $KDTree
            'IDPropertyName'      = 'ID'
            'Dimensions'          = @('Latitude', 'Longitude')
            'DimensionWeights'    = [PSCustomObject]@{ 'Latitude' = 364000; 'Longitude' = 288200 }
            'MaximumDistance'     = 500 # in feet
        }
        foreach ($Location in $Locations) {
            $Global:Iterations = 0
            $NearestParams = @{
                'SelfID'       = $Location.ID
                'SearchPosition' = [PSCustomObject]@{
                    'Latitude'  = $Location.Latitude
                    'Longitude' = $Location.Longitude
                }
            }
            $NearestNeighborResult = $null
            $NearestNeighborResult = Search-TSAGVNearestNeighbor @CommonParams @NearestParams
            $NearestNeighbor = $NearestNeighborResult.Payload
            $Location | Add-Member -NotePropertyName 'NearestNeighbor' -NotePropertyValue $NearestNeighbor -Force
            $Location | Add-Member -NotePropertyName 'NearestNeighborLatitude' -NotePropertyValue $NearestNeighbor.Latitude -Force
            $Location | Add-Member -NotePropertyName 'NearestNeighborLongitude' -NotePropertyValue $NearestNeighbor.Longitude -Force
        }

        $Locations

        Output: (Note that the nearest neighbor to H is null, because it is too far away.)
        ID                       : A
        Latitude                 : 33.952103
        Longitude                : -84.138643
        NearestNeighbor          : @{ID=B; Latitude=33.952104; Longitude=-84.138644; NearestNeighbor=; NearestNeighborLatitude=33.952103; NearestNeighborLongitude=-84.138643}
        NearestNeighborLatitude  : 33.952104
        NearestNeighborLongitude : -84.138644

        ID                       : B
        Latitude                 : 33.952104
        Longitude                : -84.138644
        NearestNeighbor          : @{ID=A; Latitude=33.952103; Longitude=-84.138643; NearestNeighbor=; NearestNeighborLatitude=33.952104; NearestNeighborLongitude=-84.138644}
        NearestNeighborLatitude  : 33.952103
        NearestNeighborLongitude : -84.138643

        ID                       : C
        Latitude                 : 33.652107
        Longitude                : -84.138647
        NearestNeighbor          : @{ID=D; Latitude=33.652111; Longitude=-84.138651; NearestNeighbor=; NearestNeighborLatitude=33.652107; NearestNeighborLongitude=-84.138647}
        NearestNeighborLatitude  : 33.652111
        NearestNeighborLongitude : -84.138651

        ID                       : D
        Latitude                 : 33.652111
        Longitude                : -84.138651
        NearestNeighbor          : @{ID=C; Latitude=33.652107; Longitude=-84.138647; NearestNeighbor=; NearestNeighborLatitude=33.652111; NearestNeighborLongitude=-84.138651}
        NearestNeighborLatitude  : 33.652107
        NearestNeighborLongitude : -84.138647

        ID                       : E
        Latitude                 : 33.852103
        Longitude                : -84.238643
        NearestNeighbor          : @{ID=F; Latitude=33.852103; Longitude=-84.238644; NearestNeighbor=; NearestNeighborLatitude=33.852103; NearestNeighborLongitude=-84.238643}
        NearestNeighborLatitude  : 33.852103
        NearestNeighborLongitude : -84.238644

        ID                       : F
        Latitude                 : 33.852103
        Longitude                : -84.238644
        NearestNeighbor          : @{ID=E; Latitude=33.852103; Longitude=-84.238643; NearestNeighbor=; NearestNeighborLatitude=33.852103; NearestNeighborLongitude=-84.238644}
        NearestNeighborLatitude  : 33.852103
        NearestNeighborLongitude : -84.238643

        ID                       : G
        Latitude                 : 33.852103
        Longitude                : -84.238646
        NearestNeighbor          : @{ID=F; Latitude=33.852103; Longitude=-84.238644; NearestNeighbor=; NearestNeighborLatitude=33.852103; NearestNeighborLongitude=-84.238643}
        NearestNeighborLatitude  : 33.852103
        NearestNeighborLongitude : -84.238644

        ID                       : H
        Latitude                 : 33.752103
        Longitude                : -84.138643
        NearestNeighbor          :
        NearestNeighborLatitude  :
        NearestNeighborLongitude :

        .NOTES
        ===========================================================================
        Created with:   Visual Studio Code
        Created on:     11/28/2023
        Created by:     Sean Sauve
        Filename:       Search-TSAGVNearestNeighbor.ps1
        ===========================================================================
    #>
    [CmdletBinding()]
    param (
        [Alias('Node')][Parameter(Mandatory)][PSCustomObject[]]$KDTree,
        [Parameter(Mandatory)][string[]]$Dimensions,
        $SelfID,
        [string]$IDPropertyName = 'ID',
        [Parameter(Mandatory)][PSCustomObject]$SearchPosition,
        [Parameter(Mandatory)][int]$MaximumDistance,
        [ValidateNotNullOrEmpty()][PSCustomObject]$DimensionWeights
    )
    if ($PSBoundParameters.ContainsKey('DimensionWeights') -eq $false) {
        $DimensionWeights = [PSCustomObject]@{}
        foreach ($Dimension in $Dimensions) {
            $DimensionWeights | Add-Member -NotePropertyName $Dimension -NotePropertyValue 1
        }
    }
    $DimensionCount = $Dimensions.Count
    $DebugString = "SelfID: $SelfID; SearchPosition: $SearchPosition; NodeID: $($KDTree.$IDPropertyName)"
    $NodesInBox = @()
    $NodeInBox = $false
    $NodeIsSelf = $PSBoundParameters.ContainsKey('SelfID') -and $KDTree.$IDPropertyName -eq $SelfID
    if ($NodeIsSelf -eq $false) {
        $NodeInBox = $true
        foreach ($Dimension in $Dimensions) {
            $DimensionWeight = $DimensionWeights.$Dimension
            $MaximumWeightedDistance = $MaximumDistance / $DimensionWeight
            $Distance = [math]::Abs($SearchPosition.$Dimension - $KDTree.$Dimension)
            $DebugString += "; Node$($Dimension): $($KDTree.$Dimension); Distance$($Dimension): $Distance; MaximumWeightedDistance$($Dimension): $MaximumWeightedDistance"
            if ($Distance -gt $MaximumWeightedDistance) {
                $NodeInBox = $false
                break
            }
        }
        if ($NodeInBox -eq $true) {
            $NodesInBox += $KDTree
        }
        $DebugString += "; NodeInBox: $NodeInBox"
    } else {
        $DebugString += "; NodeInBox: [NodeIsSelf]"
    }
    $Dimension = $KDTree.Axis
    $DimensionWeight = $DimensionWeights.$Dimension
    $MaximumWeightedDistance = $MaximumDistance / $DimensionWeight
    $MinimumPosition = $SearchPosition.$Dimension - $MaximumWeightedDistance
    $MaximumPosition = $SearchPosition.$Dimension + $MaximumWeightedDistance
    $DebugString += "; NodeTreeDimension: $Dimension; MinimumPosition: $MinimumPosition; MaximumPosition: $MaximumPosition"
    $CommonParams = @{
        'IDPropertyName'      = $IDPropertyName
        'Dimensions'          = $Dimensions
        'SelfID'              = $SelfID
        'SearchPosition'      = $SearchPosition
        'MaximumDistance'     = $MaximumDistance
        'DimensionWeights'    = $DimensionWeights
    }
    $UseLeft = $null -ne $KDTree.LeftSide -and $KDTree.$Dimension -ge $MinimumPosition
    $DebugString += "; UseLeft: $UseLeft"
    if ($UseLeft) {
        $Side = $null
        $Side = Search-TSAGVNearestNeighbor -KDTree $KDTree.LeftSide @CommonParams
        if ($null -ne $Side) {
            $NodesInBox += $Side
        }
    }
    $UseRight = $null -ne $KDTree.RightSide -and $KDTree.$Dimension -le $MaximumPosition
    $DebugString += "; UseRight: $UseRight"
    if ($UseRight) {
        $Side = $null
        $Side = Search-TSAGVNearestNeighbor -KDTree $KDTree.RightSide @CommonParams
        if ($null -ne $Side) {
            $NodesInBox += $Side
        }
    }
    $Nearest = $null
    $NearestDistance = $null
    if ($NodesInBox.Count -eq 0) {
        Write-Debug "$DebugString`n; [NoNodesInBox]"
        return
    }
    foreach ($Match in $NodesInBox) {
        $SideSquares = 0
        foreach ($Dimension in $Dimensions) {
            $DimensionWeight = $DimensionWeights.$Dimension
            $SideLength = ($SearchPosition.$Dimension - $Match.$Dimension) / $DimensionWeight
            $SideSquares += [math]::Pow($SideLength, 2)
        }
        $Distance = [math]::Pow($SideSquares, 1.0 / $DimensionCount) # square root, cubedroot, etc.
        if ($Distance -gt $MaximumDistance) {
            continue
        }
        if ($Distance -ge $NearestDistance -and $null -ne $NearestDistance) {
            continue
        }
        $Nearest = $Match
        $NearestDistance = $Distance
    }
    if ($null -eq $Nearest) {
        $DebugString += "; Nearest: [NodesInBoxAreTooFar]"
    } else {
        $DebugString += "; Nearest: $($Nearest.$IDPropertyName); Distance: $NearestDistance"
        $Nearest
    }
    Write-Debug "$DebugString`n"
}
