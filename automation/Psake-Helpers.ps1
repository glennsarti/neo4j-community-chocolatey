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
  Get-ChildItem -Path $srcDirectory | Where-Object { $_.PSIsContainer } |
    Where-Object { Test-Path -Path (Join-Path -Path $_.Fullname -ChildPath 'PackageTemplate.nuspec') } |
    ForEach-Object {
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
  Get-ChildItem -Path $templatePath -Recurse | Where-Object { !$_.psiscontainer } | ForEach-Object {
    $srcFilename = $_.Fullname
    $dstFilename = $pkgDirectory + $srcFilename.SubString($templatePath.Length)

    $content = [System.IO.File]::ReadAllText($srcFilename)

    # Replace the tokens in the template
    $PackageDefinition.Keys | ForEach-Object {
      $content = $content -replace "{{$($_)}}",$PackageDefinition[$_]
    }

    [System.IO.File]::WriteAllText($dstFilename,$content)

    Write-Host $dstFilename
  }
}

Function Invoke-BuildAll {
  $pkgList = Get-ChildItem -Path $templateDir |
    Sort-Object -Property Name |
    where-Object { !$_.PSIsContainer } |
    where-Object { $_.Name -match '^package-' } | ForEach-Object {
      # Quick and dirty way to get the package name
      Invoke-Build -PkgName ($_.Name.ToLower().Replace('package-','').Replace('.ps1',''))
  }
}

Function Invoke-CreateNewPackageProcess($RootDir) {
  $pkglist = Invoke-CreateMissingTemplates -RootDir $RootDir

  if ($pkgList -eq $null) { Write-Host "No new packages"; return }

  # Build out the package
  $pkgList | ForEach-Object {
    Invoke-Build -PkgName $_
  }

  # Regenerate the README
  Invoke-GenerateReadMe -RootDir $RootDir | Out-Null

  Return $pkgList
}

Function Invoke-SubmitMissingPackages($pkgDir,$locallist) {
  # The LocalList is a text file of packages that have been submitted
  # This stops the automation continually trying to upload packages
  if (-not (Test-Path -Path $locallist)) { '' | Out-File -FilePath $locallist -Encoding ASCII }

  # Automated package list
  'neo4j-community' | ForEach-Object {
    $pkgName = $_

    # Get the list from chocolatey
    Write-Host "Getting list of packages for $pkgName"
    $result = (& choco search $pkgName --all-versions --exact --prerelease --limit-output --page-size 100)
    if ($LASTEXITCODE -ne 0) { throw "Could not get list of chocolatey packages for $pkgName" }

    $chocoPkgList = ($result | ForEach-Object {
      $version = ($_.split('|')[1])
      Write-Host "Chocolatey has $pkgName-$version"
      Write-Output $version
    })

    # Get the list of packages previously submitted
    Write-Host "Getting local package list"
    $localPkgList = (Get-Content -Path $locallist | Where-Object { $_.StartsWith($pkgName + '.') } | ForEach-Object {
      if ($_.Trim() -ne '') { Write-Output $_.Trim() }
    })

    Write-Host "Parsing package directory..."
    # Find the local packages
    Get-ChildItem "$($pkgDir)\*.nupkg" | Where-Object { $_.Name.StartsWith($pkgName + '.')} | ForEach-Object {
      $thisFile = $_
      $thisVersion = $_.Name.Substring($pkgName.Length + 1).Replace('.nupkg','')

      if ($chocoPkgList -notcontains $thisVersion) {
        Write-Host "Local package $($_.Name) is missing from Chocolatey"

        if ($localPkgList -notcontains $thisFile.BaseName) {
          Write-Host "Pushing into chocolatey..."
          & choco push ($thisFile.FullName) --source https://chocolatey.org/
          if ($LASTEXITCODE -ne 0) { Throw "Failed to push $($thisFile.FullName) to Chocolatey with error $LASTEXITCODE"}

          Write-Host "Adding package to submitted list"
          $thisFile.Name.Replace('.nupkg','') | Out-File -Append -NoClobber -FilePath $locallist -Encoding ASCII
          & git add ($locallist)
          & git commit -m "New package $($thisFile.Name.Replace('.nupkg','')) published by Appveyor $((Get-Date).ToString("yyyy-MM-dd-HH:mm:sszzz"))"
          & git push origin
        } else {
          Write-Host "Local package $($thisFile.Name) has been submitted previously"
        }
      } else {
        Write-Host "Local package $($thisFile.Name) is already in Chocolatey"
      }
    }
  }
}