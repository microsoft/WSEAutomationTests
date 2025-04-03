param(
    [string]$file,   # Path to the Excel file
    [string]$folder  # Path to the target folder for saving graphs
)
# Add required assemblies for charting
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms.DataVisualization

# Ensure the ImportExcel module is installed and imported
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Install-Module -Name ImportExcel -Force
}
Import-Module ImportExcel

# Import Excel data
$data = Import-Excel -Path $file

# Define columns to check for null or empty values
$columnsToCheck = @(
    'timetofirstframe(In secs)', 'CameraAppInItTime(In secs)', 
    'AvgProcessingTimePerFrame(In ms)', 'MaxProcessingTimePerFrame(In ms)', 
    'MinProcessingTimePerFrame(In ms)', 'fps'
)

# Filter out rows with null or empty values in any of the key columns
$data = $data | Where-Object {
    $columnsToCheck -notcontains $null -and $columnsToCheck -notcontains ""
}

# Split data into plugged in and unplugged scenarios
$plugged_in = $data | Where-Object { $_.ScenarioName -like '*Pluggedin*' }
$unplugged = $data | Where-Object { $_.ScenarioName -like '*Unplugged*' }

# Ensure there is data before creating the plots
if ($plugged_in.Count -eq 0 -and $unplugged.Count -eq 0) {
    Write-Host "No valid data found for Plugged In or Unplugged scenarios. No graphs will be generated."
    exit
}

# Create x-values for plotting if data exists
$x_values_plugged_in = if ($plugged_in.Count -gt 0) { 1..$plugged_in.Count } else { @() }
$x_values_unplugged = if ($unplugged.Count -gt 0) { 1..$unplugged.Count } else { @() }

<#
DESCRIPTION:
    Configures and adds chart areas (subplots) with specified positions and styling. 
    Removes X-axis grid lines, styles Y-axis grid, and ensures a solid border for clarity.
    
INPUT PARAMETERS:
    - chartAreas [array] :- Names of chart areas (e.g., "PluggedIn", "Unplugged").  
    - positions  [array] :- X-axis positions for each chart area.  

RETURN TYPE:
    - void (Adds configured chart areas to the chart without returning a value.)
#>    
function Configure-ChartArea {
param($chartAreas, $xPos)
for ($i = 0; $i -lt $chartAreas.Count; $i++) {
   $chartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea $chartAreas[$i]
   $chartArea.Position.Width = 45
   $chartArea.Position.Height = 75
   $chartArea.Position.X = $xPos[$i]
   $chartArea.Position.Y = 15
   $chartArea.AxisX.Title = $xLabel
   $chartArea.AxisY.Title = $yLabel

   # Remove only internal X-axis grid lines and tick marks, but keep the subplot boundary
   $chartArea.AxisX.MajorGrid.Enabled = $false
   $chartArea.AxisX.MinorGrid.Enabled = $false
   $chartArea.AxisX.MajorTickMark.Enabled = $false 
   $chartArea.AxisX.MinorTickMark.Enabled = $false

   # Define color for y-axis grid
   $chartArea.AxisY.MajorGrid.LineColor = [System.Drawing.Color]::LightGray

   # Define font size for X-axis and Y-axis title (labels like 'X Label' and 'Y Label')
   $chartArea.AxisX.TitleFont = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
   $chartArea.AxisY.TitleFont = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)

   # Ensure the subplot boundary remains intact
   $chartArea.BorderDashStyle = [System.Windows.Forms.DataVisualization.Charting.ChartDashStyle]::Solid
   $chartArea.BorderColor = [System.Drawing.Color]::Black
   $chartArea.BorderWidth = 1
   $chart.ChartAreas.Add($chartArea)
   }
}
<#
DESCRIPTION:
    Adds a legend to the chart at a specified X-axis position for clear identification of data series.

INPUT PARAMETERS:
    - legendName [string] :- Name of the legend.  
    - xPos       [int]    :- X-axis position of the legend.  

RETURN TYPE:
    - void (Adds a legend to the chart without returning a value.)
#>
function Add-Legend {
   param($legendName, $xPos)
   $legend = New-Object System.Windows.Forms.DataVisualization.Charting.Legend
   $legend.Name, $legend.Docking = $legendName, [System.Windows.Forms.DataVisualization.Charting.Docking]::Top
   $legend.Position.X, $legend.Position.Y, $legend.Position.Width, $legend.Position.Height = $xPos, 5, 40, 10
   $chart.Legends.Add($legend)
}
<#
DESCRIPTION:
    Adds a text annotation (title) to the chart at a specified X-axis position for labeling.

INPUT PARAMETERS:
    - title [string] :- Annotation text to be displayed.  
    - xPos  [int]    :- X-axis position of the annotation.  

RETURN TYPE:
    - void (Adds an annotation to the chart without returning a value.)
#>
function Add-Annotation {
   param($title, $xPos)
   $annotation = New-Object System.Windows.Forms.DataVisualization.Charting.TextAnnotation
   $annotation.Text, $annotation.ForeColor, $annotation.Font = $title, [System.Drawing.Color]::Black, (New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold))
   $annotation.X, $annotation.Y, $annotation.Alignment = $xPos, 2, [System.Drawing.ContentAlignment]::TopCenter
   $chart.Annotations.Add($annotation)
}
<#
DESCRIPTION:
    Generates a line chart with one or two subplots based on available data (PluggedIn/Unplugged).  
    It dynamically adjusts the chart layout based on data presence and saves the output as an image.

INPUT PARAMETERS:
    - fileName       [string] :- Path to save the chart image.  
    - title1         [string] :- Title for the PluggedIn subplot (if available).  
    - title2         [string] :- Title for the Unplugged subplot (if available).  
    - xLabel         [string] :- Label for the X-axis.  
    - yLabel         [string] :- Label for the Y-axis.  
    - xValues1       [array]  :- X-axis values for PluggedIn data.  
    - yValues1_List  [array]  :- List of Y-axis values for PluggedIn data series.  
    - series1_Names  [string[]] :- Names of PluggedIn data series.  
    - xValues2       [array] (optional) :- X-axis values for Unplugged data.  
    - yValues2_List  [array] (optional) :- List of Y-axis values for Unplugged data series.  
    - series2_Names  [string[]] (optional) :- Names of Unplugged data series.
    - colors         [Color[]] :- Array of colors for different series.   

RETURN TYPE:
    - void (Saves the generated chart as an image without returning a value.)
#>
function Plot-LineGraph {
    param(
        [string]$fileName,
        [string]$title1,
        [string]$title2,
        [string]$xLabel,
        [string]$yLabel,
        [array]$xValues1,
        [array]$yValues1_List,
        [string[]]$series1_Names,
        [array]$xValues2 = @(),
        [array]$yValues2_List = @(),
        [string[]]$series2_Names = @(),
        [System.Drawing.Color[]]$colors
    )

    $chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
    $chart.Width = 1200
    $chart.Height = 600

    # Determine if both datasets exist
    $hasPluggedIn = $xValues1.Count -gt 0
    $hasUnplugged = $xValues2.Count -gt 0
    
    # Set positions for charts dynamically
    $chartAreas = @()
    if ($hasPluggedIn) { $chartAreas += "PluggedIn" }
    if ($hasUnplugged) { $chartAreas += "Unplugged" }
    $positions = @(5, 50)


    # Add series function
    function Add-LineSeries{
       param($namePrefix, $xValues, $yValuesList, $seriesNames, $chartArea, $legendName, $colors)
       for ($i = 0; $i -lt $yValuesList.Count; $i++) {
          $series = New-Object System.Windows.Forms.DataVisualization.Charting.Series
          $series.Name = "$namePrefix-$($seriesNames[$i])"
          $series.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
          $series.Points.DataBindXY($xValues, $yValuesList[$i])
          $series.ChartArea = $chartArea
          $series.Legend = $legendName
          $series.Color = $colors[$i]
          $series.BorderWidth = 2
          $chart.Series.Add($series)
       }
    }
    # Add data series based on available data
    if(($hasPluggedIn) -and ($hasUnplugged))
    {
        Configure-ChartArea $chartAreas $positions
        # PluggedIn
        Add-Legend "Legend_PluggedIn" 10
        Add-LineSeries "PluggedIn" $xValues1 $yValues1_List $series1_Names "PluggedIn" "Legend_PluggedIn" $colors
        Add-Annotation $title1 13.5
        # UnPlugged
        Add-Legend "Legend_Unplugged" 55
        Add-LineSeries "Unplugged" $xValues2 $yValues2_List $series2_Names "Unplugged" "Legend_Unplugged" $colors
        Add-Annotation $title2 57.5
    } 
    if (($hasPluggedIn) -and (!$hasUnplugged))
    { 
        Configure-ChartArea $chartAreas $positions
        Add-Legend "Legend_PluggedIn" 10
        Add-LineSeries "PluggedIn" $xValues1 $yValues1_List $series1_Names "PluggedIn" "Legend_PluggedIn" $colors
        Add-Annotation $title1 13.5
    }
    if (($hasUnplugged) -and (!$hasPluggedIn))
    {
        Configure-ChartArea $chartAreas $positions
        Add-Legend "Legend_Unplugged" 10
        Add-LineSeries "Unplugged" $xValues2 $yValues2_List $series2_Names "Unplugged" "Legend_Unplugged" $colors
        Add-Annotation $title2 13.5
    }

    # Save the chart
    $chart.SaveImage($fileName, [System.Windows.Forms.DataVisualization.Charting.ChartImageFormat]::Png)
}
<#
DESCRIPTION:
    Generates a bubble chart with one or two subplots based on available data (PluggedIn/Unplugged).  
    Adjusts layout dynamically and saves the output as an image.

INPUT PARAMETERS:
    - fileName       [string] :- Path to save the chart image.  
    - title1         [string] :- Title for the PluggedIn subplot (if available).  
    - title2         [string] :- Title for the Unplugged subplot (if available).  
    - xLabel         [string] :- Label for the X-axis.  
    - yLabel         [string] :- Label for the Y-axis.  
    - xValues1       [array]  :- X-axis values for PluggedIn data.  
    - yValues1_List  [array]  :- Y-axis values for PluggedIn data (bubble sizes derived from these values).  
    - xValues2       [array] (optional) :- X-axis values for Unplugged data.  
    - yValues2_List  [array] (optional) :- Y-axis values for Unplugged data (bubble sizes derived from these values).  
    - colors         [Color[]] :- Array of colors for different series.  

RETURN TYPE:
    - void (Saves the generated chart as an image without returning a value.)
#>
function Plot-BubbleGraph {
    param(
        [string]$fileName,
        [string]$title1,
        [string]$title2,
        [string]$xLabel,
        [string]$yLabel,
        [array]$xValues1,
        [array]$yValues1_List,
        [array]$xValues2 = @(),
        [array]$yValues2_List = @(),
        [System.Drawing.Color[]]$colors
    )

    $chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
    $chart.Width = 1200
    $chart.Height = 600

    # Determine if both datasets exist
    $hasPluggedIn = $xValues1.Count -gt 0
    $hasUnplugged = $xValues2.Count -gt 0
    
    # Set positions for charts dynamically
    $chartAreas = @()
    if ($hasPluggedIn) { $chartAreas += "PluggedIn" }
    if ($hasUnplugged) { $chartAreas += "Unplugged" }
    $positions = @(5, 50)

    # Function to add a Bubble Series
    function Add-BubbleSeries {
       param ($name, $chartArea, $xValues, $yValues, $legendName, $colors)
       $series = New-Object System.Windows.Forms.DataVisualization.Charting.Series
       $series.Name = $name
       $series.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Bubble
       $series["BubbleMaxSize"] = "5"
       $series["BubbleMinSize"] = "0.5"
       $series.ChartArea = $chartArea
       $series.Color = $colors[0]
       $series.Legend = $legendName

       for ($i = 0; $i -lt $xValues.Count; $i++) {
          $index = $series.Points.AddXY($xValues[$i], $yValues[$i])
          $series.Points[$index].MarkerSize = [math]::Round($yValues[$i] * 0.5)
       }

        $chart.Series.Add($series)
    }
    # Add data series based on available data
    if(($hasPluggedIn) -and ($hasUnplugged))
    {
        Configure-ChartArea $chartAreas $positions
        # PluggedIn
        Add-Legend "Legend_PluggedIn" 10
        Add-BubbleSeries "PluggedIn-FPS" "PluggedIn" $xValues1 $yValues1_List "Legend_PluggedIn" $colors
        Add-Annotation $title1 14.5
        # Unplugged
        Add-Legend "Legend_Unplugged" 55
        Add-BubbleSeries "Unplugged-FPS" "Unplugged" $xValues2 $yValues2_List "Legend_Unplugged" $colors
        Add-Annotation $title2 57.5
    } 
    if (($hasPluggedIn) -and (!$hasUnplugged))
    { 
        Configure-ChartArea $chartAreas $positions
        Add-Legend "Legend_PluggedIn" 10
        Add-BubbleSeries "PluggedIn-FPS" "PluggedIn" $xValues1 $yValues1_List "Legend_PluggedIn" $colors

        Add-Annotation $title1 14.5
    }
    if (($hasUnplugged) -and (!$hasPluggedIn))
    {
        Configure-ChartArea $chartAreas $positions
        Add-Legend "Legend_Unplugged" 10
       Add-BubbleSeries "Unplugged-FPS" "Unplugged" $xValues2 $yValues2_List "Legend_Unplugged" $colors

        Add-Annotation $title2 14.5
    }
    # Adjust the X-axis to display all values (1, 2, 3, 4, 5, etc.)
    $chartArea = $chart.ChartAreas[0]
    $chartArea.AxisX.IsMarginVisible = $true
    $chartArea.AxisX.Interval = 1  # Ensure every value is displayed on the X-axis

    # Save the chart
    $chart.SaveImage($fileName, [System.Windows.Forms.DataVisualization.Charting.ChartImageFormat]::Png)
}

# Define Colors for Different Metrics
$colors = @{
    "TimeToFirstFrame" = [System.Drawing.Color]::Orange
    "CameraInitTime"   = [System.Drawing.Color]::LightBlue
    "MaxProcessing"    = [System.Drawing.Color]::Orange
    "MinProcessing"    = [System.Drawing.Color]::Green
    "AvgProcessing"    = [System.Drawing.Color]::LightBlue
    "FPS"              = [System.Drawing.Color]::LightBlue
}

#Graph 1: Time to First Frame & Camera App Init Time
$filePath1 = Join-Path $folder 'TimeToFirstFrame_CameraInitTime.png'
Plot-LineGraph -fileName $filePath1 `
    -title1 "PluggedIn - Time to First Frame & Camera Init Time" `
    -title2 "Unplugged - Time to First Frame & Camera Init Time" `
    -xLabel "Measurements" `
    -yLabel "Time (secs)" `
    -xValues1 $x_values_plugged_in `
    -yValues1_List @(
       $plugged_in.'timetofirstframe(In secs)', 
       $plugged_in.'CameraAppInItTime(In secs)') `
    -series1_Names @("TimeToFirstFrame", "CameraInitTime") `
    -xValues2 $x_values_unplugged `
    -yValues2_List @(
       $unplugged.'timetofirstframe(In secs)',
       $unplugged.'CameraAppInItTime(In secs)') `
    -series2_Names @("TimeToFirstFrame", "CameraInitTime") `
    -colors  @(
       $colors["TimeToFirstFrame"],
       $colors["CameraInitTime"]
    )

# Graph 2: Processing Time (Max, Min, Avg)
$filePath2 = Join-Path $folder 'ProcessingTime.png'
Plot-LineGraph -fileName $filePath2 `
    -title1 "PluggedIn - Processing Time" `
    -title2 "Unplugged - Processing Time" `
    -xLabel "Measurements" `
    -yLabel "Processing Time (In ms)" `
    -xValues1 $x_values_plugged_in `
    -yValues1_List @(
       $plugged_in.'MaxProcessingTimePerFrame(In ms)',
       $plugged_in.'MinProcessingTimePerFrame(In ms)',
       $plugged_in.'AvgProcessingTimePerFrame(In ms)') `
    -series1_Names @("MaxProcessingTime", "MinProcessingTime", "AvgProcessingTime") `
    -xValues2 $x_values_unplugged `
    -yValues2_List @( 
       $unplugged.'MaxProcessingTimePerFrame(In ms)', 
       $unplugged.'MinProcessingTimePerFrame(In ms)', 
       $unplugged.'AvgProcessingTimePerFrame(In ms)') `
    -series2_Names @("MaxProcessingTime", "MinProcessingTime", "AvgProcessingTime") `
    -colors  @(
       $colors["MaxProcessing"],
       $colors["MinProcessing"],
       $colors["AvgProcessing"]
    )

#  Graph 3: Video fps
$filePath3 = Join-Path $folder 'FPS_BubbleChart.png'
Plot-BubbleGraph -fileName $filePath3 `
    -title1 "Plugged In - Video FPS" `
    -title2 "Unplugged - Video FPS" `
    -xLabel "Measurements" `
    -yLabel "Video FPS" `
    -xValues1 $x_values_plugged_in `
    -yValues1_List $plugged_in.'fps' `
    -xValues2 $x_values_unplugged `
    -yValues2_List $unplugged.'fps' `
    -colors @($colors["FPS"])
Write-Host "Graphs saved to $folder"
