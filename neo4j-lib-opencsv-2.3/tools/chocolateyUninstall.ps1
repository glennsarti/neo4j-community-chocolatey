$PackageName = 'neo4j-lib-opencsv'
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

  $jarFile = "opencsv-2.3.jar"
  $srcFile = "$($neoHome)\lib\$($jarFile)"
  if (!(Test-Path -Path $srcFile))
  {
    Write-Debug "Library doesn't exist.  Uninstall is succesful"
  }
  else
  {
    $serviceName = 'Neo4j-Server'
    Write-Debug "Stopping Neo4j..."
    Get-Service $serviceName | Stop-Service -Force | Out-Null
    
    Write-Debug "Removing file..."
    Remove-Item -Path $srcFile -Confirm:$false -Force | Out-Null

    Write-Debug "Starting Neo4j..."
    Get-Service $serviceName | Start-Service | Out-Null
  }

  Write-ChocolateySuccess $PackageName
} catch {
  Write-ChocolateyFailure $PackageName "$($_.Exception.Message)"
  throw
}

