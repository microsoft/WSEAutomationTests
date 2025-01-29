Add-Type -AssemblyName UIAutomationClient

function CheckIfElementExists($uiEle, $clsNme, $proptyNme){
    $classNameCondition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ClassNameProperty, $clsNme)
    $nameCondition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty, $proptyNme)
    $jointCondition = New-Object Windows.Automation.AndCondition($classNameCondition, $nameCondition)

    $elemt = $uiEle.FindFirst([Windows.Automation.TreeScope]::Descendants, $jointCondition)
    sleep -s 2
    return $elemt
}

function FindClickableElement($uiEle, $clsNme, $proptyNme){
    if ($uiEle -eq $null)
    {
      Write-Error " UI Element for $proptyNme is Null" -ErrorAction Stop  
    }
    $classNameCondition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ClassNameProperty, $clsNme)
    $nameCondition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty, $proptyNme)
    $jointCondition = New-Object Windows.Automation.AndCondition($classNameCondition, $nameCondition)

    $elemt = $uiEle.FindFirst([Windows.Automation.TreeScope]::Descendants, $jointCondition)
    sleep -s 2
    if ($elemt -eq $null){
        Write-Error " $proptyNme not found " -ErrorAction Stop  
    }
    return $elemt
}
function FindClickableElementByAutomationID($uiEle, $autoID){
    if ($uiEle -eq $null)
    {
      Write-Error " UI Element for automation ID $autoID is Null" -ErrorAction Stop  
    }
    $autoIDCondition = [System.Windows.Automation.PropertyCondition]::new(
                       [System.Windows.Automation.AutomationElementIdentifiers]::AutomationIdProperty, $autoID)

    $elemt = $uiEle.FindFirst([Windows.Automation.TreeScope]::Descendants, $autoIDCondition)
    sleep -s 2
    if ($elemt -eq $null){
        Write-Error " $autoID not found " -ErrorAction Stop  
    }
    return $elemt
} 
function FindClickableElementByName($uiEle, $proptyNme){
    if ($uiEle -eq $null)
    {
      Write-Error " UI Element for $proptyNme is Null" -ErrorAction Stop  
    }
    $nameCondition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElementIdentifiers]::NameProperty, $proptyNme)
    $elemt = $uiEle.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$nameCondition)
    sleep -s 2
    if ($elemt -eq $null){
        Write-Error " $proptyNme not found " -ErrorAction Stop  
    }
    return $elemt
}
function FindFirstElementsNameWithClassName($uiEle, $clsNme)
{
    if ($uiEle -eq $null)
    {
      Write-Error " UI Element for $proptyNme is Null" -ErrorAction Stop
    }

    $classNameCondition = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ClassNameProperty, $clsNme)
    $elemt = $uiEle.FindFirst([Windows.Automation.TreeScope]::Descendants, $classNameCondition)
    sleep -s 2
    if ($elemt -eq $null){
        Write-Error " $clsNme not found " -ErrorAction Stop
    }
    return $elemt.GetCurrentPropertyValue([Windows.Automation.AutomationElement]::NameProperty)
}
    
function FindAndClick ($uiEle,$clsNme,$proptyNme,$autoID){
       if ($uiEle -eq $null)
       {
         Write-Error " UI Element for $proptyNme is Null" -ErrorAction Stop  
       }
       if($autoID -ne $null)
       {  
          #Find the element based on AutomationID property
          $clickableElement = FindClickableElementByAutomationID $uiEle $autoID
       }
       elseif($clsNme -eq $null -and $proptyNme -ne $null)
       {
          #Find the element based on Name property
          $clickableElement = FindClickableElementByName $uiEle $proptyNme
       }
       elseif($clsNme -ne $null -and $proptyNme -ne $null)
       {
          #Find the element based on Name and ClassName property
          $clickableElement = FindClickableElement $uiEle $clsNme $proptyNme
       }
       else 
       {
          Write-Error "No Element can be searched- parameters not passed correctly" -ErrorAction Stop 
       }
       if ( $clickableElement.GetCurrentPropertyValue([Windows.Automation.AutomationElement]::IsInvokePatternAvailableProperty) ){
            $clickableElement.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
       }
       
       if ( $clickableElement.GetCurrentPropertyValue([Windows.Automation.AutomationElement]::IsSelectionItemPatternAvailableProperty) ){
           $clickableElement.GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern).Select()
       }
       
       if ( $clickableElement.GetCurrentPropertyValue([Windows.Automation.AutomationElement]::IsTogglePatternAvailableProperty) ){
           $clickableElement.GetCurrentPattern([Windows.Automation.TogglePattern]::Pattern).Toggle()
       }
       
       if ( $clickableElement.GetCurrentPropertyValue([Windows.Automation.AutomationElement]::IsExpandCollapsePatternAvailableProperty) ) {
           $clickableElement.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Expand()
       }
}
function FindAndGetValue($uiEle, $clsNme, $proptyNme) 
{      
       if ($uiEle -eq $null)
       {
         Write-Error " UI Element for $proptyNme is Null" -ErrorAction Stop  
       }
       $clickableElement = FindClickableElement $uiEle $clsNme $proptyNme
       if ( $clickableElement.GetCurrentPropertyValue([Windows.Automation.AutomationElement]::IsTogglePatternAvailableProperty) )
       {
           $result = $clickableElement.GetCurrentPattern([Windows.Automation.TogglePattern]::Pattern).current.ToggleState
           return $result.ToString()
       }
       
       if ( $clickableElement.GetCurrentPropertyValue([Windows.Automation.AutomationElement]::IsSelectionItemPatternAvailableProperty) )
       {
           $result = $clickableElement.GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern).current.IsSelected
           return $result.ToString()
       }   
       Write-Error "$proptyNme could not be found" -ErrorAction Stop  
}
function FindAndSetValue($uiEle, $clsNme, $proptyNme, $proptyVal)
{    
     $result = FindAndGetValue $uiEle $clsNme $proptyNme  #Will add parameters validation at the later point of time.
     if ($clsNme -eq "RadioButton" -and $proptyVal -eq "False" -and $result -eq "True")
     {
        Write-Output "A value of $proptyVal cannot be set to $proptyNme  when it is $result as it is of type $clsNme."
        return
     }
     if($result -ne $proptyVal)
     {
         Write-Output "Updating property [$proptyNme] from [$result] to [$proptyVal]" 
         FindAndClick $uiEle $clsNme $proptyNme
         Start-Sleep -Seconds 1
         $result = FindAndGetValue $uiEle $clsNme $proptyNme 
         if($result -ne $proptyVal)
         {
             Write-Error "$proptyNme value could not be toggled" -ErrorAction Stop  
         }
     }
     else
     {
         Write-Output "$proptyNme is already $result"
     } 
}
function FindAndClickList 
{
   param (
       $uiEle,
       $clsNme,
       [string[]]$proptyNmeLst
   )

   $foundIt = $false

   foreach ($listEntry in $proptyNmeLst)
   {
       $exists = CheckIfElementExists $uiEle $clsNme $listEntry

       if ($exists -ne $null)
       {
           FindAndClick $uiEle $clsNme $listEntry
           $foundIt = $true
           break
       }
   }

   # Check if we located the entry
   if (-not $foundIt)
   {   
      Write-Error "Could not locate element in this list: $($proptyNmeLst -join ', ')" -ErrorAction Stop
   }
}


