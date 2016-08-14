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
$automationDir = Join-Path -Path $srcDirectory -ChildPath 'automation'


# Helper Functions
Get-ChildItem -Path $automationDir |
  ? { !$_.PSIsContainer } |
  ? { $_.Name -like '*Helper*.ps1' } |
  % {
    . ($_.FullName)
  }

Task Default -Depends Build_All,Pack_All

Task Pack_All -Depends Clean -Description 'Packs all nuget templates into packages' {
  Invoke-PackAll
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
  Invoke-BuildAll
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
  Invoke-Clean
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

Task Automate_NewNeo4jTemplates -Description 'Creates package templates for new Neo4j versions' {
  Invoke-CreateMissingTemplates -RootDir $srcDirectory | Out-Null
}

Task Automate_GenerateReadMe -Description 'Generates the README file from the current packages' {
  Invoke-GenerateReadMe -RootDir $srcDirectory | Out-Null
}

Task CreateNewPackages -Description 'Updates the repository with newly release Neo4j versions' {
  Invoke-CreateNewPackageProcess -RootDir $srcDirectory
}

# Appveyor Automation
Task AppVeyor -Description 'Automated task run by AppVeyor' {
  if ($ENV:APPVEYOR -eq $null) { Throw "Only run in AppVeyor!"; return }

  Write-Host "Running AppVeyor Task"

  if ($ENV:APPVEYOR_SCHEDULED_BUILD -eq "True") {
    Write-Host "*** This is a scheduled build"

    $pkgList = Invoke-CreateNewPackageProcess -RootDir $srcDirectory

    if ($pkgList -ne $null) {
      & git add --a
      & git commit -m "New Packages added by Appveyor $((Get-Date).ToString("yyyy-MM-dd-HH:mm:sszzz"))"

      Write-Host "Pushing to origin..."
      # & git push origin
    }

    Write-Host "Building all packages"
    Invoke-Clean
    Invoke-PackAll

    Write-Host "Publishing to Chocolatey..."
    Invoke-SubmitMissingPackages -pkgDir $artefactDir -locallist "$srcDirectory\submitted_pkgs.txt"
  } else {
    Write-Host "Not a scheduled build"

    Invoke-Clean
    Invoke-BuildAll
    Invoke-GenerateReadMe -RootDir $srcDirectory | Out-Null
    Invoke-PackAll
  }
}