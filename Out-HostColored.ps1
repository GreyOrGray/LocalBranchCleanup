<#
.SYNOPSIS
Colors portions of the default host output that match a pattern.

.DESCRIPTION
Colors portions of the default-formatted host output based on either a
regular expression or a literal substring, assuming the host is a console or
supports colored output using console colors.

Matching is restricted to a single line at a time, but coloring multiple
matches on a given line is supported.

.PARAMETER Pattern
The regular expression specifying what portions of the input should be
colored. Do not use named capture groups in the regular expression, unless you
also specify -WholeLine.
If -SimpleMatch is also specified, the pattern is interpreted as a literal
substring to match.

.PARAMETER ForegroundColor
The foreground color to use for the matching portions.
Defaults to green.

.PARAMETER BackgroundColor
The optional background color to use for the matching portions.

.PARAMETER WholeLine
Specifies that the entire line containing a match should be colored, 
not just the matching portion.

.PARAMETER SimpleMatch
Interprets the -Pattern argument as a literal substring to match rather than
as a regular expression.

.PARAMETER InputObject
Specifies what to output. Typically, the output form a command provided
via the pipeline.

.NOTES
Requires PSv2 or above.
All pipeline input is of necessity collected first before output is produced.

.EXAMPLE
Get-Date | Out-HostColored '\bSeptember\b' red white

Outputs the current date with the word 'September' printed in red on a white background, if present.
#>
Function Out-HostColored {
  # Note: The [CmdletBinding()] and param() block are formatted to be PSv2-compatible.
  [CmdletBinding()]
  param(
    [Parameter(Position=0, Mandatory=$True)] [string] $Pattern,
    [Parameter(Position=1)] [ConsoleColor] $ForegroundColor = 'Green',
    [Parameter(Position=2)] [ConsoleColor] $BackgroundColor,
    [switch] $WholeLine,
    [switch] $SimpleMatch,
    [Parameter(Mandatory=$True, ValueFromPipeline=$True)] $InputObject
  )

  # Wrap the pattern / literal in an explicit capture group.
  try { 
    $re = [regex] ('(?<sep>{0})' -f $(if ($SimpleMatch) { [regex]::Escape($Pattern) } else { $Pattern }))
  } catch { Throw }

  # Build a parameters hashtable specifying the colors, to be use via
  # splatting with Write-Host later.
  $htColors = @{
    ForegroundColor = $ForegroundColor
  }
  if ($BackgroundColor) {
    $htColors.Add('BackgroundColor', $BackgroundColor)
  }  

  # Use pipeline input, if provided.
  if ($MyInvocation.ExpectingInput) { $InputObject = $Input }

  # Apply default formatting to each input object, and look for matches to
  # color line by line.
  $InputObject | Out-String -Stream | ForEach-Object {
    $line = $_
    if ($WholeLine){ # Color the whole line in case of match.
      if ($havePattern -and $line -match $re) {
        Write-Host @htColors $line
      } else {
        Write-Host $line
      }
    } else {
      # Split the line by the regex and include what the regex matched.
      $segments = $line -split $re, 0, 'ExplicitCapture'
      if ($segments.Count -eq 1) { # no matches -> output line as-is
        Write-Host $line
      } else { # at least 1 match, as a repeating sequence of <pre-match> - <match> pairs
        $i = 0
        foreach ($segment in $segments) {
          if ($i++ % 2) { # matching part
            Write-Host -NoNewline @htColors $segment
          } else { # non-matching part
            Write-Host -NoNewline $segment
          }
        }
        Write-Host '' # Terminate the current output line with a newline.
      }
    }
  }
}