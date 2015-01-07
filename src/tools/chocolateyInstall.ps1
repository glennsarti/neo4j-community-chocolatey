$PackageName = 'neo4j-community'
try {

  # Taken from https://github.com/chocolatey/chocolatey/wiki/How-To-Parse-PackageParameters-Argument
  $arguments = @{};
  
  # Now, we can use the $env:chocolateyPackageParameters inside the Chocolatey package
  $packageParameters = $env:chocolateyPackageParameters;

  # Default the values
  # $port = 7474
  $InstallDir = "$($Env:SystemDrive)\Neo4jCommunity";
  $ImportNeoProperties = ""
  $ImportNeoServerProperties = ""
  
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
  Write-Host "This would be the Chocolatey Silent Arguments: $silentArgs"

  # Sanity Checks
  If ($ImportNeoProperties -ne "") {
    If (!(Test-Path -Path $ImportNeoProperties)) { Throw "Could not find the NeoProperties file to import. $ImportNeoProperties" }     
  }
  If ($ImportNeoServerProperties -ne "") {
    If (!(Test-Path -Path $ImportNeoServerProperties)) { Throw "Could not find the NeoServerProperties file to import. $ImportNeoServerProperties" }     
  }

  # Install Neo4j
  Install-ChocolateyZipPackage $PackageName 'http://neo4j.com/artifact.php?name=neo4j-community-2.1.6-windows.zip' $InstallDir

  # Set the Home Environment Variable
  $neoHome = "$($InstallDir)\neo4j-community-2.1.6"
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
  
  # Install the Neo4j Service
  $InstallBatch = "$($neoHome)\bin\Neo4jInstaller.bat"
  if (!(Test-Path $InstallBatch)) { throw "Could not find the Neo4j Installer Batch file at $InstallBatch" }
  $RefreshEnv = "$($Env:ChocolateyInstall)\bin\RefreshEnv.cmd"
  if (!(Test-Path $RefreshEnv)) { throw "Could not find the RefreshEnv Batch file at $RefreshEnv" }
  
  # Need to use a new environment as the NEO4J_HOME may not have been set correctly
  $args = "install"
  $results = (Start-Process -FilePath $InstallBatch -ArgumentList $args -Wait -PassThru -NoNewWindow -UseNewEnvironment)

  # Should I put this in?
  # If NoStartService is set...Stop the Service
  #[void](Get-Service 'Neo4j-Server' | Stop-Service -Force)

  Write-ChocolateySuccess $PackageName
} catch {
  Write-ChocolateyFailure $PackageName "$($_.Exception.Message)"
  throw
}

