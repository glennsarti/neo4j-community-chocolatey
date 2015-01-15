$PackageName = 'neo4j-lib-geoff'
$RemoveFileName = ''
try {
  # Get the NeoHome Dir
  #   Try the local environment
  $neoHome = [string] (Get-EnvironmentVariable -Name 'NEO4J_HOME' -Scope 'Machine')  
  # Failing that, try a registry hack
  if ($neoHome -eq '')
  {
    $neoHome = [string] ( (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -ErrorAction Ignore).'NEO4J_HOME' )
  }
  if ($neoHome -eq '') { throw "Could not find the Neo4jHome directory" }

  $InstallDir = "$($neoHome)\lib"
  
  # Check if we should restart Neo
  $packageParameters = ([string]($env:chocolateyPackageParameters)).Trim()
  $DoServiceRestart = ($packageParameters.ToUpper() -eq "RESTARTSERVICE")
  if ($DoServiceRestart) { Write-Debug 'Found RestartService package parameter.  Neo4j service will be restarted at the end of the installation' }

  $jarFile = "$($InstallDir)\geoff-0.5.0.jar"
  $RemoveFileName = $jarFile
  Get-ChocolateyWebFile -PackageName $PackageName -Url 'https://github.com/neo4j-contrib/m2/raw/master/releases/com/nigelsmall/geoff/0.5.0/geoff-0.5.0.jar' -FileFullPath $jarFile `
                        -CheckSum 'c75d8065b3190c1e1389dac44fec3694' -CheckSumType 'md5'
                       
  # Restart Neo
  if ($DoServiceRestart) 
  {
    Write-Debug "Restarting Neo4j..."
    Get-Service 'Neo4j-Server' -ErrorAction Ignore | Restart-Service -Force -ErrorAction Ignore | Out-Null
  }

  Write-ChocolateySuccess $PackageName
} catch {
  # Cleaning up - If checksum fails or partial download, need to delete the file
  if ($RemoveFileName -ne '') {
    Remove-Item -Path $RemoveFileName -Confirm:$false -Force -ErrorAction Ignore | Out-Null
  }
  Write-ChocolateyFailure $PackageName "$($_.Exception.Message)"

  Remove-Item -Path $TempDir -Force -Recurse -Confirm:$false -ErrorAction Ignore | Out-Null
  throw
}

