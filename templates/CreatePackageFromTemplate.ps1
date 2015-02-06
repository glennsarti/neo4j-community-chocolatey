Param([string]$PackageName = "")

# Init
$ErrorActionPreference = "Stop"
$thisDirectoy = $PSScriptRoot
$srcDirectory = "$($PSScriptRoot)\.."

# Sanity Checks
if ($PackageName -eq "") {
  Write-Host "Missing -PackageName"
  Throw "Missing -PackageName"
}

# Get the package definition
$filename = Join-Path -Path $thisDirectoy -ChildPath "package-$($PackageName).ps1"
if (!(Test-Path -Path $filename)) {
  Throw "Could not find package definition $filename"
}
# Execute the package definition
. $filename

# More sanity checks
$templatePath = Join-Path -Path $thisDirectoy -ChildPath ($PackageDefinition.TemplateName)
if (!(Test-Path -Path $templatePath)) {
  Throw "Could not find template $templatePath"
}
Write-Host "Using template $($PackageDefinition.TemplateName)..."

# Create directory for the package
$pkgDirectory = Join-Path -Path $srcDirectory -ChildPath $PackageName
if (Test-Path $pkgDirectory) {
  Write-Host "Removing previous directory..."
  Remove-Item -Path $pkgDirectory -Recurse -Force -Confirm:$false | Out-Null
}

Write-Host "Creating the package directory..."
xcopy "$templatePath" "$pkgDirectory" /s /e /i /t

Write-Host "Parsing template..."
Get-ChildItem -Path $templatePath -Recurse | ? { !$_.psiscontainer } | % {
  $srcFilename = $_.Fullname  
  $dstFilename = $pkgDirectory + $srcFilename.SubString($templatePath.Length)
  
  $content = [System.IO.File]::ReadAllText($srcFilename)

  # Replace the tokens in the template  
  $PackageDefinition.Keys | % { 
    $content = $content -replace "{{$($_)}}",$PackageDefinition[$_]
  }
    
  [System.IO.File]::WriteAllText($dstFilename,$content)
  
  Write-Host $dstFilename
}
