$PackageName = 'neo4j-community'
try {

  # Taken from https://github.com/chocolatey/chocolatey/wiki/How-To-Parse-PackageParameters-Argument
  $arguments = @{};
  
  # Let's assume that the input string is something like this, and we will use a Regular Expression to parse the values
  # /Port:7474 /Install:C:\Neo4jCommunity
  
  # Now, we can use the $env:chocolateyPackageParameters inside the Chocolatey package
  $packageParameters = $env:chocolateyPackageParameters;
  
  # Default the values
  # $port = 7474
  $InstallDir = "$($Env:SystemDrive)\Neo4jCommunity";
  $ImportNeoProperties = ""
  $ImportNeoServerProperties = ""
  
  # Now, let’s parse the packageParameters using good old regular expression
  if($packageParameters) {
      $MATCH_PATTERN = "/([a-zA-Z]+):([`"'])?([a-zA-Z0-9- _]+)([`"'])?"
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
  
#       if($arguments.ContainsKey("Port")) {
#           Write-Host "Port Argument Found";
#           $port = $arguments["Port"];
#       }  
  
      if($arguments.ContainsKey("Install")) {
          Write-Host "Install Argument Found";
          $InstallDir = $arguments["Install"];
      }
  } else {
      Write-Host "No Package Parameters Passed in";
  }
  
  #$silentArgs = "/Port=" + $port + " /install=" + $InstallDir;  
  $silentArgs = "/install=" + $InstallDir
  if ($ImportNeoProperties -ne "") {
    $silentArgs += " /importneoproperties=" + $ImportNeoProperties
  }
  if ($ImportNeoServerProperties -ne "") {
    $silentArgs += " /importneoserverproperties=" + $ImportNeoServerProperties
  }
  Write-Host "This would be the Chocolatey Silent Arguments: $silentArgs"

  # Install Neo4j
  $InstallDir = Install-ChocolateyZipPackage $PackageName 'c:\temp\neo4j-community-2.1.6-windows.zip' $InstallDir

  # Set the Home Environment Variable
  $neoHome = "$($InstallDir)\neo4j-community-2.1.6"
  Install-ChocolateyEnvironmentVariable "NEO4J_HOME" "$neoHome" "Machine"
  
  # TODO Preconfigure the Neo4j Server config prior to service start
  # Use $ImportNeoServerProperties and $ImportNeoProperties
  
  # Install the Neo4j Service
  $InstallBatch = "$($neoHome)\bin\Neo4jInstaller.bat"
  if (!(Test-Path $InstallBatch)) { throw "Could not find the Neo4j Installer Batch file at $InstallBatch" }
  $RefreshEnv = "$($Env:ChocolateyInstall)\bin\RefreshEnv.cmd"
  if (!(Test-Path $RefreshEnv)) { throw "Could not find the RefreshEnv Batch file at $RefreshEnv" }
  
  # Need to use a new environment as the NEO4J_HOME may not have been set correctly
  $args = "install"
  $results = (Start-Process -FilePath $InstallBatch -ArgumentList $args -Wait -PassThru -NoNewWindow -UseNewEnvironment)

  # If NoStartService is set...Stop the Service
  [void](Get-Service 'Neo4j-Server' | Stop-Service -Force)

  Write-ChocolateySuccess $PackageName
} catch {
  Write-ChocolateyFailure $PackageName "$($_.Exception.Message)"
  throw
}

