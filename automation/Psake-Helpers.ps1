Function Invoke-Clean() {
  if (Test-Path -Path $artefactDir) {
    "Cleaning $artefactDir ..."
    Remove-Item $artefactDir -Recurse -Force | Out-Null
  }
  New-Item -Path $artefactDir -ItemType Directory | Out-Null
}

Function Invoke-Pack($pkgName) {
  # Sanity Checks
  $pkgPath = Join-Path -Path $srcDirectory -ChildPath $pkgName
  $pkgNuspec = Join-Path -Path $pkgPath -ChildPath 'PackageTemplate.nuspec'
  if (!(Test-Path -Path $pkgPath)) { Throw "Could not find package at $pkgPath" }
  if (!(Test-Path -Path $pkgNuspec)) { Throw "Could not find package nuspec at $pkgNuspec" }

  "Packing $pkgName ..."
  $cwd = Get-Location
  Set-Location -Path $artefactDir | Out-Null
  &choco pack $pkgNuspec
  Set-Location -Path $cwd | Out-Null
}

Function Invoke-PackAll() {
  Get-ChildItem -Path $srcDirectory | ? { $_.PSIsContainer } |
    ? { Test-Path -Path (Join-Path -Path $_.Fullname -ChildPath 'PackageTemplate.nuspec') } | % {
      Invoke-Pack -PkgName $_.Name
  }
}

Function Invoke-Build($pkgName) {
  # Get the package definition
  $filename = Join-Path -Path $templateDir -ChildPath "package-$($pkgName).ps1"
  if (!(Test-Path -Path $filename)) {
    Throw "Could not find package definition $filename"
  }
  # Execute the package definition
  $PackageDefinition = @{}
  . $filename

  # More sanity checks
  $templatePath = Join-Path -Path $templateDir -ChildPath ($PackageDefinition.TemplateName)
  if (!(Test-Path -Path $templatePath)) {
    Throw "Could not find template $templatePath"
  }
  Write-Host "Using template $($PackageDefinition.TemplateName)..."

  # Create directory for the package
  $pkgDirectory = Join-Path -Path $srcDirectory -ChildPath $pkgName
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
}

Function Invoke-BuildAll {
  $pkgList = Get-ChildItem -Path $templateDir |
    Sort-Object -Property Name |
    ? { !$_.PSIsContainer } |
    ? { $_.Name -match '^package-' } | % {
      # Quick and dirty way to get the package name
      Invoke-Build -PkgName ($_.Name.ToLower().Replace('package-','').Replace('.ps1',''))
  }
}

Function Invoke-CreateNewPackageProcess($RootDir) {
  $pkglist = Invoke-CreateMissingTemplates -RootDir $RootDir

  if ($pkgList -eq $null) { Write-Host "No new packages"; return }

  # Build out the package
  $pkgList | % {
    Invoke-Build -PkgName $_
  }

  # Regenerate the README
  Invoke-GenerateReadMe -RootDir $RootDir | Out-Null

  Return $pkgList
}