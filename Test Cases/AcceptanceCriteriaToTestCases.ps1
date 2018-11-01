function Main
{
  cls
  $adsOrg = "https://dev.azure.com/<your organization>"
  $adsToken = "<your personal access token>"
  $adsTeamProject = "<your team project>"

  # Uncomment the following line if necessary
  # Set-ExecutionPolicy Unrestricted

  # Don't change anything below here

  $basicAuth = ("{0}:{1}" -f "",$adsToken)
  $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
  $basicAuth = [System.Convert]::ToBase64String($basicAuth)
  $headers = @{Authorization=("Basic {0}" -f $basicAuth)}

  Write-Host
  Write-Host "Removing existing test cases ..."
  Write-Host

  # The following is a destructive operation - only uncomment if you want to delete all existing test cases in this team project
  
  # DeleteWorkItemsByType "Test Case"

  Write-Host
  Write-Host "Creating test cases ..."

  CreateTestCases

  Write-Host
  Write-Host
  Write-Host "Done"
}

function CreateTestCases
{
  $resource = $adsOrg + "/" + $adsTeamProject + '/_apis/wit/wiql/?api-version=3.0'

  # This will look for all "Product Backlog Items" (Scrum process) in the "Committed" state for the team project - change the query as needed

  $json = '{ "query": "Select [System.ID], [Microsoft.VSTS.Common.AcceptanceCriteria] FROM WorkItems Where [System.WorkItemType] IN (''Product Backlog Item'') AND [System.State] = ''Committed'' AND [System.TeamProject] = ' + "'" + $adsTeamProject + "'" + '" }'
  try {
    $response = Invoke-RestMethod -Uri $resource -headers $headers -Method Post -Body $json -ContentType 'application/json'
    foreach ($workItem in $response.workItems) {
      $parent = $workItem.id
      $url = $workItem.url

      # Lookup fields

      $response2 = Invoke-RestMethod -Uri $url -headers $headers -Method Get -ContentType 'application/json'
      $title = $response2.fields."System.Title"
      $acField = $response2.fields."Microsoft.VSTS.Common.AcceptanceCriteria"
      $iteration = $response2.fields."System.IterationPath"
      $area = $response2.fields."System.AreaPath"
      $testCases = New-Object System.Collections.ArrayList

      Write-Host
      Write-Host ""$title" " -foregroundcolor "yellow" -NoNewline
      
      # This code will find all items in the Acceptance Criteria field whether delimited by HTML bullets, HTML numbers, or <div> tags 

      # Look for <div> tags

      $matches = ([regex]'<div>(.*?)</div>').Matches($acField);
      foreach ($match in $matches) {
        $Criterion = $match.Value.replace("<div>","").replace("</div>","").Trim()
        If ($Criterion -ne "<br>")
        {
          $testCases.add($Criterion) | out-null
        }
      }

      # Look for <li> tags

      $matches = ([regex]'<li>(.*?)</li>').Matches($acField);
      foreach ($match in $matches) {
        $Criterion = $match.Value.replace("<li>","").replace("</li>","").Trim()
        If ($Criterion -ne "<br>")
        {
          $testCases.add($Criterion) | out-null
        }
      }

      # Sort

      $testCases = $testCases | Sort-Object

      # Create test cases

      foreach ($testCase in $testCases) {
        # Write-Host " -"$testCase
        CreateTestCase $testCase $iteration $area $parent 
      }
    }
  }
  catch {
    echo $_.Exception|format-list -force
  }
}

function CreateTestCase([string]$title, [string]$iteration, [string]$area, [string]$parentId)
{
  $resource = $adsOrg + "/" + $adsTeamProject + '/_apis/wit/workitems/$test%20case?api-version=3.0'
  $fields = @(@{"op"= "add"; "path"= "/fields/System.Title";"value"="$title"},
              @{"op"= "add"; "path"= "/fields/System.IterationPath";"value"="$iteration"},
              @{"op"= "add"; "path"= "/fields/System.AreaPath";"value"="$area"})
  $json = @($fields) | ConvertTo-Json
  try {
    $response = Invoke-RestMethod -Uri $resource -Body $json -headers $headers -Method PATCH -ContentType 'application/json-patch+json'
    $taskId = $response.id
    $resource2 = $adsOrg + '/_apis/wit/workitems/' + $taskId + '?api-version=3.0'
    $json = '[{"op": "add","path": "/relations/-","value": {
             "rel": "Microsoft.VSTS.Common.TestedBy-Reverse",
             "url": "' + $adsOrg + '/_apis/wit/workItems/' + $parentId + '"}}]'
    try {
      $response2 = Invoke-RestMethod -Uri $resource2 -headers $headers -Method Patch -Body $json -ContentType 'application/json-patch+json'
    }
    catch {
      echo $_.Exception|format-list -force
    }
    write-host "." -nonewline
  }
  catch {
    echo $_.Exception|format-list -force
    return
  }
}

function DeleteWorkItemsByType([string]$workItemType)
{
  Write-Host " Deleting " -NoNewline
  Write-Host $workItemType -foregroundcolor "yellow" -NoNewline
  Write-Host " work items" -NoNewline
  
  $workItemCount = 0
  $resource = $adsOrg + "/" + $adsTeamProject + '/_apis/wit/wiql/?api-version=3.0'
  $json = '{ "query": "Select [System.ID] FROM WorkItems Where [System.WorkItemType] = ' + "'" + $workItemType + "'" + ' AND [System.TeamProject] = ' + "'" + $adsTeamProject + "'" + '" }'
  try {
    $response = Invoke-RestMethod -Uri $resource -headers $headers -Method Post -Body $json -ContentType 'application/json'
    foreach ($workItem in $response.workItems) {
      $id = $workItem.id
      if ($workItemType.toLower().Equals("test case")) {
        $resource = $adsOrg + "/" + $adsTeamProject + '/_apis/test/testcases/' + $id + '?api-version=3.0-preview'
      }
      elseif ($workItemType.toLower().Equals("shared steps")) {
        $resource = $adsOrg + "/" + $adsTeamProject + '/_apis/test/sharedstep/' + $id + '?api-version=3.0-preview.1'
      }
      elseif ($workItemType.toLower().Equals("shared parameter")) {
        $resource = $adsOrg + "/" + $adsTeamProject + '/_apis/test/sharedparameter/' + $id + '?api-version=3.0-preview.1'
      }
      else {
        $resource = $adsOrg + '/_apis/wit/workitems/' + $id + '?api-version=3.0'
      }
      try {
        $response = Invoke-RestMethod -Uri $resource -headers $headers -Method Delete
        $workItemCount++
      }
      catch {
        echo $_.Exception|format-list -force
      }
    }
  }
  catch {
    echo $_.Exception|format-list -force
  }

  Write-Host " (" -NoNewline
  if ($workItemCount -gt 0)
   { Write-Host $workItemCount -foregroundcolor "yellow" -NoNewline }
  else
   { Write-Host 0 -NoNewline }
  Write-Host ")"
}

Main
