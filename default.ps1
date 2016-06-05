# PSake Configuration File
# https://github.com/psake/psake

# Init
Properties {
  [string]$pkgName = $Package
  [string]$pkgParams = $PackageParameters
}
$script:pkgName = $null

$ErrorActionPreference = "Stop"

$srcDirectory = $PSScriptRoot
$artefactDir = Join-Path -Path $srcDirectory -ChildPath 'artefacts'
$templateDir = Join-Path -Path $srcDirectory -ChildPath 'templates'

# Helper Functions
Function Invoke-Pack($pkgName) {
  # Sanity Checks
  $pkgPath = Join-Path -Path $PSScriptRoot -ChildPath $pkgName
  $pkgNuspec = Join-Path -Path $pkgPath -ChildPath 'PackageTemplate.nuspec'
  if (!(Test-Path -Path $pkgPath)) { Throw "Could not find package at $pkgPath" }
  if (!(Test-Path -Path $pkgNuspec)) { Throw "Could not find package nuspec at $pkgNuspec" }

  "Packing $pkgName ..."
  $cwd = Get-Location
  Set-Location -Path $artefactDir | Out-Null
  &choco pack $pkgNuspec
  Set-Location -Path $cwd | Out-Null
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

Task Default -Depends Build_All,Pack_All

Task Pack_All -Depends Clean -Description 'Packs all nuget templates into packages' {  
  Get-ChildItem -Path $PSScriptRoot | ? { $_.PSIsContainer } | 
    ? { Test-Path -Path (Join-Path -Path $_.Fullname -ChildPath 'PackageTemplate.nuspec') } | % {
      Invoke-Pack -PkgName $_.Name
  }  
}

Task Pack -Depends Clean -Description 'Packs a nuget template into a package' {
  if ($pkgName -eq '') { [string]$pkgName = $script:pkgName}
  if ($pkgname -eq '') {
    # Display a list of packages and select one
    $pkgList = Get-ChildItem -Path $srcDirectory |
      Sort-Object -Property Name |
      ? { $_.PSIsContainer } |
      ? { Test-Path -Path (Join-Path -Path $_.Fullname -ChildPath 'PackageTemplate.nuspec') } | % {
        Write-Output $_.Name
    }

    # Get the packagename
    do {
      $index = 1
      Write-Host "Select a package to build"
      $pkgList | % {
        Write-Host "$($index). $($_)"
        $index++
      }
      $misc = Read-Host -Prompt "Select a template (1..$($pkgList.Length))"
      try {
        $pkgName = $pkgList[$misc - 1]
      } catch { $pkgName = '' }
    } while ($pkgName -eq '')
  }
  
  # Sanity Checks
  $pkgPath = Join-Path -Path $PSScriptRoot -ChildPath $pkgName
  $pkgNuspec = Join-Path -Path $pkgPath -ChildPath 'PackageTemplate.nuspec'
  if (!(Test-Path -Path $pkgPath)) { Throw "Could not find package at $pkgPath" }
  if (!(Test-Path -Path $pkgNuspec)) { Throw "Could not find package nuspec at $pkgNuspec" }

  Invoke-Pack -PkgName $pkgName
}

Task Build_All -Description 'Creates all packages from package templates' {
  $pkgList = Get-ChildItem -Path $templateDir |
    Sort-Object -Property Name |
    ? { !$_.PSIsContainer } | 
    ? { $_.Name -match '^package-' } | % {
      # Quick and dirty way to get the package name
      Invoke-Build -PkgName  ($_.Name.ToLower().Replace('package-','').Replace('.ps1',''))
  }
}

Task Build -Description 'Creates a package from a package template' {
  if ($pkgName -eq '') { [string]$pkgName = $script:pkgName}
  if ($pkgName -eq '') {
    # Display a list of packages and select one
    $pkgList = Get-ChildItem -Path $templateDir |
      Sort-Object -Property Name |
      ? { !$_.PSIsContainer } | 
      ? { $_.Name -match '^package-' } | % {
        # Quick and dirty way to get the package name
        Write-Output ($_.Name.ToLower().Replace('package-','').Replace('.ps1',''))
    }
    
    # Get the packagename
    do {
      $index = 1
      Write-Host "Select a template to build"
      $pkgList | % {
        Write-Host "$($index). $($_)"
        $index++
      }
      $misc = Read-Host -Prompt "Select a template (1..$($pkgList.Length))"
      try {
        $pkgName = $pkgList[$misc - 1]
      } catch { $pkgName = '' }
    } while ($pkgName -eq '')
  }
  
  Invoke-Build -PkgName $pkgName
  
  $script:pkgName = $pkgName
}

Task Clean -Description 'Cleans artefact directory' {
  if (Test-Path -Path $artefactDir) {
    "Cleaning $artefactDir ..."
    Remove-Item $artefactDir -Recurse -Force | Out-Null
  }
  New-Item -Path $artefactDir -ItemType Directory | Out-Null
}

Task Install -Depend Build,Pack -Description 'Installs a built and packed template package' {
  if ($pkgName -eq '') { [string]$pkgName = $script:pkgName}
  if ($pkgname -eq '') { Throw "Install requires a 'package' parameter/property" }
  
  # Find the PackageTemplate.nuspec
  $nuspec = Join-Path -Path (Join-Path -Path $srcDirectory -ChildPath $pkgName) -ChildPath 'PackageTemplate.nuspec'
  if (!(Test-Path -Path $nuspec)) { Throw "Could not find package nuspec at $nuspec"}
  [xml]$nuDoc = Get-Content -Path $nuspec

  if ($pkgParams -ne '') { $pkgParams = "-packageParameters `"$pkgParams`"" }
  if ($pkgName -match 'beta') { $pkgPreRelease = '-PreRelease' }

  $args = @('Install',$nuDoc.package.metadata.id,
    '-Source',$artefactDir,
    '-Version',$nuDoc.package.metadata.version,
    '-Debug','-Y','-Force'
    $pkgParams,$pkgPreRelease)

  Write-Host "Installing with: choco $args"
  
  & choco @args
}

Task Uninstall -Depend Build,Pack -Description 'Uninstalls a built and packed template package' {
  if ($pkgName -eq '') { [string]$pkgName = $script:pkgName}
  if ($pkgname -eq '') { Throw "Install requires a 'package' parameter/property" }
  
  # Find the PackageTemplate.nuspec
  $nuspec = Join-Path -Path (Join-Path -Path $srcDirectory -ChildPath $pkgName) -ChildPath 'PackageTemplate.nuspec'
  if (!(Test-Path -Path $nuspec)) { Throw "Could not find package nuspec at $nuspec"}
  [xml]$nuDoc = Get-Content -Path $nuspec

  if ($pkgParams -ne '') { $pkgParams = "-packageParameters `"$pkgParams`"" }

  $args = @('Uninstall',$nuDoc.package.metadata.id,
    '-Version',$nuDoc.package.metadata.version,
    '-Debug','-Y','-Force'
    $pkgParams)

  Write-Host "Uninstalling with: choco $args"
  
  & choco @args
}

# TODO Publish to ChocoGallery if not exists (?)

# TODO Modify the root README