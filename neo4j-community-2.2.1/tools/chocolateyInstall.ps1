$PackageName = 'neo4j-community'
# Per-package parameters
$downloadUrl = 'http://neo4j.com/artifact.php?name=neo4j-community-2.2.1-windows.zip'
$md5Checksum = 'b5441c0d1d6223b5facad609f934bc1d'
$neozipSubdir = 'neo4j-community-2.2.1'
$neoServerApiJarSuffix = '2.2.1'

try {
  # Taken from https://github.com/chocolatey/chocolatey/wiki/How-To-Parse-PackageParameters-Argument
  $arguments = @{};
  
  # Now, we can use the $env:chocolateyPackageParameters inside the Chocolatey package
  $packageParameters = $env:chocolateyPackageParameters;

  # Default the values
  $InstallDir = Get-BinRoot
  $InstallDir = Join-Path -Path $InstallDir -ChildPath $PackageName
  $ImportNeoProperties = ""
  $ImportNeoServerProperties = ""
  $ImportServiceProperties = ""
  
  # Now, let’s parse the packageParameters using good old regular expression
  if($packageParameters) {
      $MATCH_PATTERN = "\/([a-zA-Z]+):([`"'])?([a-zA-Z0-9- _\\:\.]+)([`"'])?"
      $PARAMATER_NAME_INDEX = 1
      $VALUE_INDEX = 3

      if($packageParameters -match $MATCH_PATTERN ){
          $results = $packageParameters | Select-String $MATCH_PATTERN -AllMatches
          $results.matches | % {
            $arguments.Add(
                $_.Groups[$PARAMATER_NAME_INDEX].Value.Trim(),
                $_.Groups[$VALUE_INDEX].Value.Trim())
        }
      }
      else
      {
        Throw "Package Parameters were found but were invalid (REGEX Failure)";
      }

      if($arguments.ContainsKey("install")) {
          Write-Host "Install Argument Found";
          $InstallDir = $arguments["install"];
      }

      if($arguments.ContainsKey("importneoproperties")) {
          Write-Host "ImportNeoProperties Argument Found";
          $ImportNeoProperties = $arguments["importneoproperties"];
      }

      if($arguments.ContainsKey("importneoserverproperties")) {
          Write-Host "ImportNeoServerProperties Argument Found";
          $ImportNeoServerProperties = $arguments["importneoserverproperties"];
      }

      if($arguments.ContainsKey("importserviceproperties")) {
          Write-Host "ImportServiceProperties Argument Found";
          $ImportServiceProperties = $arguments["importserviceproperties"];
      }
  } else {
      Write-Host "No Package Parameters Passed in";
  }

  $silentArgs = "/install:" + $InstallDir
  if ($ImportNeoProperties -ne "") {
    $silentArgs += " /importneoproperties:" + $ImportNeoProperties
  }
  if ($ImportNeoServerProperties -ne "") {
    $silentArgs += " /importneoserverproperties:" + $ImportNeoServerProperties
  }
  if ($ImportServiceProperties -ne "") {
    $silentArgs += " /importserviceproperties:" + $ImportServiceProperties
  }
  Write-Debug "This would be the Chocolatey Silent Arguments: $silentArgs"

  # Sanity Checks
  If ($ImportNeoProperties -ne "") {
    If (!(Test-Path -Path $ImportNeoProperties)) { Throw "Could not find the NeoProperties file to import. $ImportNeoProperties" }
  }
  If ($ImportNeoServerProperties -ne "") {
    If (!(Test-Path -Path $ImportNeoServerProperties)) { Throw "Could not find the NeoServerProperties file to import. $ImportNeoServerProperties" }
  }
  If ($ImportServiceProperties -ne "") {
    If (!(Test-Path -Path $ImportServiceProperties)) { Throw "Could not find the ServiceProperties file to import. $ImportServiceProperties" }
  }

  # Check if Neo is already installed
  $RunNeo4jInstall = $true
  $existingNeoHome = [string] (Get-EnvironmentVariable -Name 'NEO4J_HOME' -Scope 'Machine')
  if ($existingNeoHome -eq '')
  {
    $existingNeoHome = [string] ( (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -ErrorAction Continue).'NEO4J_HOME' )
  }
  if ($existingNeoHome -ne '') {
    Write-Debug 'The NEO4J_HOME environment variable is set.  Checking the version of Neo4j...'
    
    Get-ChildItem -Path (Join-Path -Path $existingNeoHome -ChildPath 'lib') | Where-Object { $_.Name -match 'server-api-.+\.jar' } | ForEach-Object {
      if ($_.Name.ToLower() -eq "server-api-$($neoServerApiJarSuffix).jar")
      {
        $RunNeo4jInstall = $false
        Write-Host "$PackageName version $neoServerApiJarSuffix is already installed"
      }
      else
      {
        Write-Debug "$PackageName has been installed but found an unexpected version of the server-api jar file $($_.Name)"
        Throw "$PackageName is installed but is not the correct version.  Expected version $neoServerApiJarSuffix"
      }
    }
  }

  if ($RunNeo4jInstall) {
    # Check if Java is available
    # This check will not be required once a suitable Java SDK 7 chocolatey package is available in the public feed. This is expected in Feb 2015 sometime.
    $javaResponse = ''
    try {
      Write-Debug 'Testing Java...'
      & java.exe -version
    } catch {
      Throw 'Java is not installed in the PATH.  This is required for a Neo4j installation'
    }
    
    # Install Neo4j
    Install-ChocolateyZipPackage -PackageName $PackageName -URL $downloadUrl -UnzipLocation $InstallDir -CheckSum $md5Checksum -CheckSumType 'md5'
  
    # Set the Home Environment Variable
    $neoHome = "$($InstallDir)\$($neozipSubdir)"
    Install-ChocolateyEnvironmentVariable "NEO4J_HOME" "$neoHome" "Machine"
  
    # Import config files if required
    If ($ImportNeoProperties -ne "") {
      Write-Host "Importing the neo4jproperties from  $ImportNeoProperties"
      [void] (Copy-Item -Path $ImportNeoProperties -Destination "$($neoHome)\conf\neo4j.properties" -Force -Confirm:$false)
    }
    If ($ImportNeoServerProperties -ne "") {
      Write-Host "Importing the neo4j-server.properties from  $ImportNeoServerProperties"
      [void] (Copy-Item -Path $ImportNeoServerProperties -Destination "$($neoHome)\conf\neo4j-server.properties" -Force -Confirm:$false)
    }
    If ($ImportServiceProperties -ne "") {
      Write-Host "Importing the neo4j-wrapper.conf from  $ImportServiceProperties"
      [void] (Copy-Item -Path $ImportServiceProperties -Destination "$($neoHome)\conf\neo4j-wrapper.conf" -Force -Confirm:$false)
    }
    
    # Install the Neo4j Service
    $InstallBatch = "$($neoHome)\bin\Neo4jInstaller.bat"
    if (!(Test-Path $InstallBatch)) { throw "Could not find the Neo4j Installer Batch file at $InstallBatch" }
    
    $args = "install"
    Start-Process -FilePath $InstallBatch -ArgumentList $args -Wait -PassThru -NoNewWindow | Out-Null
    
    $neoService = Get-Service -Name "Neo4j-Server" -ErrorAction Continue
    if ($neoService -eq $null) {
      Throw "The Neo4j Sever Service failed to install"
    }
  }
  
  Write-ChocolateySuccess $PackageName
} catch {
  Write-ChocolateyFailure $PackageName "$($_.Exception.Message)"
  throw
}
