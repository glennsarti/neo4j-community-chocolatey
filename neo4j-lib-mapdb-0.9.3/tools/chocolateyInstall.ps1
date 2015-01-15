$PackageName = 'neo4j-lib-mapdb'
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

  $jarFile = "$($InstallDir)\mapdb-0.9.3.jar"
  $RemoveFileName = $jarFile
  Get-ChocolateyWebFile -PackageName $PackageName -Url 'http://search.maven.org/remotecontent?filepath=org/mapdb/mapdb/0.9.3/mapdb-0.9.3.jar' -FileFullPath $jarFile `
                        -CheckSum '656947ef6fdc20ef36661ac5a7353e80' -CheckSumType 'md5'
                       
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

