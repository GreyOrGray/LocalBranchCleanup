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

.PARAMETER Path
String representing the local path for the repo clone. If this is not
provided, the function assumes the repo clone is meant to be the current
directory. 

.NOTES
Dependent on the function Out-HostColored

If the directory chosen is NOT a valid repo clone, the script should return
an error message saying as much and quit out. 

If there are no differences, the function will say as much and exit.

.EXAMPLE
BranchCleanup 'F:\STASH\db_salesforcebackups_repo'

sets the location to the path provided and runs the compare and options
to delete branches if applicable.

#>
function BranchCleanup
{

	[CmdletBinding()] 
    param ( 
        [String] $path = $(get-location).path
    ) 

	$lineBreak = "***********************************************************************************"
	
	write-host ("`n{0}`nBranch Cleanup Starting`n{1}`n" -f ($linebreak, $linebreak)) -f cyan
	
	write-host ("Changing directory to {0}`n" -f ($path)) -f green
	set-location $path
	
	write-host ("Collecting local branch info: ") -f green -nonewline
	try{
			$local=git branch -l
			if (-not $?) {throw 'error with git connection'}
			write-host ("{0} local branch{1} found`n" -f ($local.count, $(if ($local.count -gt 1){'es'}else{''}))) -f yellow 
			} catch { write-host  ("Error collecting local branch info`n`n") -f red; RETURN}
		
	write-host ("Collecting remote branch info: ") -f green -nonewline
	try{
			$remote=git branch -r
			if (-not $?) {throw 'error with git connection'}
			write-host ("{0} remote branch{1} found`n" -f ($remote.count, $(if ($remote.count -gt 1){'es'}else{''}))) -f yellow 
		} catch { write-host  ("Error collecting remote branch info`n`n") -f red; RETURN}
	write-host ("Comparing branches`n") -f green
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
		write-host ("`n{0}`nNo local branches have been identified as not existing on the remote`n`nGoodbye.`n{1}`n" -f ($linebreak, $linebreak)) -f cyan
		return
	}
	
	$Accept = $False
	
	do {
		$Confirm = $False
		write-host ("***The following local branches have been identified as not existing on the remote***") -f yellow
		$branchTable | ft -auto | out-hostcolored 'True' red
		
		write-host ("`n{0}`nPlease provide one of the following" -f ($linebreak)) -f cyan
		Write-Host '    - A comma delimited list of Branch IDs for which to change the "DELETE" flag' -ForegroundColor cyan
		Write-Host '    - "A" to select all ' -ForegroundColor cyan
		Write-Host '    - "Q" to quit' -ForegroundColor cyan 
		Write-Host 'Your Choice: ' -ForegroundColor green -NoNewline
		
		$userInput = Read-Host
		
		
		
		switch -regex ($userInput)
		{
			'[^aq0-9,]+$'
			{
				write-host ("`n{0}`nYour input contains an invalid value.`nPlease try again.`n`n{1}`n" -f ($linebreak, $linebreak)) -ForegroundColor red
			}
			'q'
			{
				write-host ("`n{0}`nYou have chosen to quit.`n`nGoodbye.`n{1}`n" -f ($linebreak, $linebreak)) -ForegroundColor cyan
				return
			}
			'a'
			{
				Write-Host ("`n{0}`nYou have chosen to select all.`n{1}`n" -f ($linebreak, $linebreak)) -ForegroundColor cyan
				$branchTable |  foreach {$_.DELETE = !$_.DELETE}
				$Confirm = $True
			}
			default
			{
				Write-Host ("`n{0}`nYou have chosen: {1} `n{2}`n" -f ($linebreak,  $userInput.trim(), $linebreak)) -ForegroundColor cyan
				$splitInput = $userInput.trim() -split(',')
				foreach ($splitVal in $splitInput)
				{
					$branchTable | where {$_.ID -eq $splitVal}  | foreach {$_.DELETE = !$_.DELETE}
				}
				$Confirm = $True
			}
			
		}
		if ($Confirm -eq $True)
			{
				
				Write-Host "`nYour current selection..." -ForegroundColor yellow
				$branchTable | ft -auto | out-hostcolored 'True' red
				write-host ("`n{0}`nEnter ""Y"" to procede with the chosen branch deletion or enter any other value to go back and change your choice." -f ($linebreak)) -f cyan
				$userInput = Read-Host
				Write-Host "`n`n`n"

				if ($userInput -match '[y]')
				{
					$Accept = $True
				}
			}
	} while ($Accept -eq $false)
	
	write-host ("`n{0}`nACCEPTED`n{1}`n" -f ($linebreak, $linebreak)) -ForegroundColor cyan

	foreach ($row in $branchTable.rows | ?{$_.DELETE -eq $True})
	{
		write-host ('Deleting branch : {0}' -f ($row.Branch)) -ForegroundColor cyan
		git branch -D $row.Branch
		write-host "`n"
	}
	
	write-host ("Re-collecting local branch info: ") -ForegroundColor green -nonewline
	try{
			$local=git branch -l
			if (-not $?) {throw 'error with git connection'}
			write-host ("{0} local branch{1} found`n" -f ($local.count, $(if ($local.count -gt 1){'es'}else{''}))) -ForegroundColor yellow 
		} catch { write-host  ("Error collecting local branch info`n`n") -ForegroundColor red; RETURN}
	
	write-host ("Re-collecting remote branch info: ") -ForegroundColor green -nonewline
	try{
			$remote=git branch -r
			if (-not $?) {throw 'error with git connection'}
			write-host ("{0} remote branch{1} found`n" -f ($remote.count, $(if ($remote.count -gt 1){'es'}else{''}))) -ForegroundColor yellow 
		} catch { write-host  ("Error collecting remote branch info`n`n") -ForegroundColor red; RETURN}
	write-host ("Re-comparing branches`n") -ForegroundColor green
	$comparisonValues = $local | %{$_.Trim()}|?{-not ($remote -like '*' + ($_ -replace "^[\\* ]",'').trim()) }|?{-not($_ -match "master")}

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
		write-host ("***The following local branches have been identified as not existing on the remote***") -ForegroundColor yellow
		$branchTable | ft -auto
		write-host ("`n{0}`nEnd of Branch Cleanup.`n`nGoodbye.`n{1}`n" -f ($linebreak, $linebreak)) -ForegroundColor cyan 
	} else { write-host ("`n{0}`nNo local branches have been identified as not existing on the remote`n`nGoodbye.`n{1}`n" -f ($linebreak, $linebreak)) -ForegroundColor cyan }
	
	
	
} 

