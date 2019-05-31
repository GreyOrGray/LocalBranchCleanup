<#
.SYNOPSIS
Remove local repo branches that don't exist in remote repo

.DESCRIPTION
Compares the local branches of the specified repo with the remote branches.
Differences are displayed and can be chosen for deletion. Multiple chances
to quit are given and no changes are made until the user actively confirms
the selections. 

Once confirmation has been given, the selected branches are deleted and the
branches are compared again, presenting a final output of differences if any.

If the directory chosen is NOT a valid repo clone, the script should return
an error message saying as much and quit out. 

If there are no differences, the function will say as much and exit.

.PARAMETER Path
String representing the local path for the repo clone. If this is not
provided, the function assumes the repo clone is meant to be the current
directory. 

.EXAMPLE
BranchCleanup 'F:\STASH\db_salesforcebackups_repo'

sets the location to the path provided and runs the compare and options
to delete branches if applicable.

.NOTES
Author: GreyOrGray
Requires: Out-HostColored


#>
function BranchCleanup
{

	[CmdletBinding()] 
    param ( 
        [String] $path = $(get-location).path
    ) 

	write-host ("***********************************************************************************" ) -f green
	write-host ("Branch Cleanup Starting" ) -f green
	write-host ("***********************************************************************************`n" ) -f green
	write-host ("Changing directory to {0}`n" -f ($path)) -f yellow
	set-location $path
	
	write-host ("Collecting local branch info`n") -f yellow
	try{
			$local=git branch -l
			if (-not $?) {throw 'error with git connection'}
		} catch { write-host  ("Error collecting local branch info`n`n") -f red; RETURN}
	write-host ("Collecting remote branch info`n") -f yellow
	try{
			$remote=git branch -r
			if (-not $?) {throw 'error with git connection'}
		} catch { write-host  ("Error collecting remote branch info`n`n") -f red; RETURN}
	write-host ("Comparing branches`n") -f yellow
	$comparisonValues = $local | %{$_.Trim()}|?{-not ($remote -like '*' + ($_ -replace "^[\\* ]",'').trim()) }|?{-not($_ -match "master")}
	
 
	$branchTable = New-Object system.Data.DataTable "BranchTable"
	$col1 = New-Object system.Data.DataColumn ID,([int])
	$col2 = New-Object system.Data.DataColumn Branch,([string])
	$col3 = New-Object system.Data.DataColumn DELETE,([bool])
	$branchTable.columns.add($col1)
	$branchTable.columns.add($col2)
	$branchTable.columns.add($col3)
	foreach ($value in $comparisonValues)
	{
		$row = $branchTable.NewRow()
		$row.ID = $branchTable.rows.count +1
		$row.Branch = $value
		$row.DELETE = $False
		$branchTable.Rows.Add($row)	
	}
	
	if ($branchTable.rows.count -eq 0)
	{ 
		write-host ("No local branches have been identified as not existing on the remote`n`n") -f green 
		return
	}
	
	$Accept = $False
	while ($Accept -eq $false)
	{
		$Confirm = $False
		write-host ("***The following local branches have been identified as not existing on the remote***") -f yellow
		#$hash.keys | select @{l='ID';e={$_}},@{l='Branch';e={$hash.$_}} | sort ID
		$branchTable | ft -auto | out-hostcolored 'True' red
		
		write-host ("***********************************************************************************`n" ) -f green
		Write-Host 'Please provide one of the following' -ForegroundColor green
		Write-Host '    - A comma delimited list of Branch IDs for which to change the "DELETE" flag' -ForegroundColor green
		Write-Host '    - "A" to select all ' -ForegroundColor green
		Write-Host '    - "Q" to quit: ' -ForegroundColor green -NoNewline
		$userInput = Read-Host
		
		$splitInput = $userInput.trim() -split(',')
		
		
		Write-Host "`n`n"
		if ($splitInput -notmatch '^[aq0-9]+$')
		{
			write-host ("***********************************************************************************`n" ) -f red
			Write-Host 'Your input contains an invalid value.' -ForegroundColor red
			Write-Host "Please try again.`n`n" -ForegroundColor red
		} elseif ($splitInput -match '[qQ]')
		{
			Write-Host 'You have chosen to quit.' -ForegroundColor red
			Write-Host 'Goodbye.' -ForegroundColor red
			RETURN			
		} elseif ($splitInput -match '[aA]')
		{
			Write-Host 'You have chosen to select all.' -ForegroundColor yello
			$branchTable |  foreach {$_.DELETE = !$_.DELETE}
			$Confirm = $True
		} else
		{
			foreach ($splitVal in $splitInput)
			{
				$branchTable | where {$_.ID -eq $splitVal}  | foreach {$_.DELETE = !$_.DELETE}
			}
			$Confirm = $True
		}
		if ($Confirm -eq $True)
		{
			
			write-host ("***********************************************************************************`n" ) -f green
			Write-Host 'Your current selection...' -ForegroundColor green
			$branchTable | ft -auto | out-hostcolored 'True' red
			Write-Host 'Enter "Y" to procede with the chosen branch deletion or any other value to go back and change your choice.' -ForegroundColor green
			$userInput = Read-Host
			Write-Host "`n`n`n"

			if ($userInput -match '[y]')
			{
				$Accept = $True
			}
		}
	}
	
	write-host 'Accepted...' -f yellow

	foreach ($row in $branchTable.rows | ?{$_.DELETE -eq $True})
	{
		write-host ('Deleting branch : {0}' -f ($row.Branch)) -f yellow
		git branch -D $row.Branch
	}
	
	write-host ("Re-collecting local branch info`n") -f yellow
	try{
			$local=git branch -l
			if (-not $?) {throw 'error with git connection'}
		} catch { write-host  ("Error collecting local branch info`n`n") -f red; RETURN}
	write-host ("Re-collecting remote branch info`n") -f yellow
	try{
			$remote=git branch -r
			if (-not $?) {throw 'error with git connection'}
		} catch { write-host  ("Error collecting remote branch info`n`n") -f red; RETURN}
	write-host ("Re-comparing branches`n") -f yellow
	$comparisonValues = $local | %{$_.Trim()}|?{-not ($remote -like '*' + $_) }|?{-not($_ -match "master")}

	$branchTable = New-Object system.Data.DataTable "BranchTable"
	$col1 = New-Object system.Data.DataColumn ID,([int])
	$col2 = New-Object system.Data.DataColumn Branch,([string])
	$branchTable.columns.add($col1)
	$branchTable.columns.add($col2)
	foreach ($value in $comparisonValues)
	{
		$row = $branchTable.NewRow()
		$row.ID = $branchTable.rows.count +1
		$row.Branch = $value
		$branchTable.Rows.Add($row)	
	}
	
	if ($branchTable.rows.count -gt 0)
	{
		write-host ("The following local branches have been identified as not existing on the remote") -f yellow
		$branchTable | ft -auto
	} else { write-host ("No local branches have been identified as not existing on the remote") -f green }
	
	
} 

