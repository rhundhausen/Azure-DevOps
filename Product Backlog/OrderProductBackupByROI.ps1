function Main
{
  cls
  $VstsAccount = "https://<yourAccount>.visualstudio.com"
  $VstsToken = "<personal access token>"
  $VstsTeamProject = "<yourTeamProject>"

  # Uncomment the following line if necessary
  # Set-ExecutionPolicy Unrestricted

  # Don't change anything below here

  $basicAuth = ("{0}:{1}" -f "",$VstsToken)
  $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
  $basicAuth = [System.Convert]::ToBase64String($basicAuth)
  $headers = @{Authorization=("Basic {0}" -f $basicAuth)}
  
  # Order the Product Backlog by ROI

  OrderProductBacklog
}

function OrderProductBacklog
{
  write-host -NoNewline "Retrieving Product Backlog IDs"

  $resource = $VstsAccount + "/" + $VstsTeamProject + '/_apis/wit/wiql/?api-version=3.0'
  $json = '{ "query": "Select [System.ID] FROM WorkItems Where [System.WorkItemType] IN (''Product Backlog Item'') AND [System.TeamProject] = ' + "'" + $VstsTeamProject + "'" + '" }'
  try {
    $response = Invoke-RestMethod -Uri $resource -headers $headers -Method Post -Body $json -ContentType 'application/json'

    write-host ":"$response.workItems.Count "PBIs"
    write-host -NoNewline "Retrieving Product Backlog Items: "

    $count = $response.workItems.count
    $backlog = New-Object 'object[,]' $count, 7
    # ,0 = ID
    # ,1 = Title
    # ,2 = Business Value
    # ,3 = Effort
    # ,4 = ROI
    # ,5 = BacklogPriority (current)
    # ,6 = BacklogPriority (new)

    $item = 0

    foreach ($workItem in $response.workItems) {
      $id = $workItem.id

      write-host -NoNewline "."

      $resource2 = $VstsAccount + '/_apis/wit/workitems?ids=' + $id + '&$expand=all&api-version=3.0'
      $response2 = Invoke-RestMethod -Uri $resource2 -headers $headers -Method Get -ContentType 'application/json'

      # Get and save fields to array

      $businessvalue = GetValue $response2.value.fields "Microsoft.VSTS.Common.BusinessValue"
      $effort = GetValue $response2.value.fields "Microsoft.VSTS.Scheduling.Effort"
      $backlog[$item,0] = $id
      $backlog[$item,1] = GetValue $response2.value.fields "System.Title"
      $backlog[$item,2] = $businessvalue
      $backlog[$item,3] = $effort
      if (!$businessvalue -eq 0)
      {
        if (!$effort -eq 0)
        {
           $backlog[$item,4] = ($businessvalue / $effort) + 100 # Added 100 to make room for BV w/o Effort below
        }
        else
        {
           $backlog[$item,4] = 50 # BV w/o Effort should be above no BV
        }
      }
      else
      {
        $backlog[$item,4] = 0 # No BV = No ROI
      }
      $backlog[$item,5] = GetValue $response2.value.fields "Microsoft.VSTS.Common.BacklogPriority"
      $backlog[$item,6] = $backlog[$item,5]
      $item++
    }

    write-host
    write-host -NoNewline "Computing ROI: "

    for ($i=0; $i -lt $count; $i++) {
      write-host -NoNewline "."

      $id = $backlog[$i,0]
      $val1 = [int]2147483647 # int maxvalue
      $val2 = [int]$backlog[$i,4] # ROI
      $backlog[$i,6] = ($val1 - $val2) # higher ROIs have lower priorities
    }

    write-host
    write-host -NoNewline "Reordering Backlog: "

    for ($i=0; $i -lt $count; $i++) {
      write-host -NoNewline "."

      $id = $backlog[$i,0]
      $backlogPriority = $backlog[$i,6]
      $resource2 = $VstsAccount + '/_apis/wit/workitems/' + $id + '?api-version=3.0'
      $json = '[{"op": "add","path": "/fields/Microsoft.VSTS.Common.BacklogPriority","value": '+$backlogPriority+'}]'
      try {
        $response2 = Invoke-RestMethod -Uri $resource2 -headers $headers -Method Patch -Body $json -ContentType 'application/json-patch+json'
      }
      catch {
        echo $_.Exception|format-list -force
      }
    }
    write-host
    write-host
    write-host "Product Backlog has been ordered by ROI"

    # Uncomment for troubleshooting
    # $backlog

  }
  catch {
    echo $_.Exception|format-list -force
  }
}

function GetValue($fields,$searchField)
{
  $value = ""
  foreach ($field in $fields) {
    $field.PsObject.get_properties() | foreach {
      if ($_.Name -eq $searchField) {
        $value = $_.Value
      }
    }
  }
  return $value
}

Main