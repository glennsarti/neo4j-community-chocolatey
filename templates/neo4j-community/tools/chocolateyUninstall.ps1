$PackageName = '{{PackageName}}'
try {
  # Get the NeoHome Dir
  #   Try the local environment
  $neoHome = [string] (Get-EnvironmentVariable -Name 'NEO4J_HOME' -Scope 'Machine')  
  # Failing that, try a registry hack
  if ($neoHome -eq '')
  {
    $neoHome = [string] ( (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -ErrorAction Continue).'NEO4J_HOME' )
  }
  if ($neoHome -eq '') { throw "Could not find the Neo4jHome directory" }

  # Uninstall the Neo4j Service
  $UninstallBatch = "$($neoHome)\bin\Neo4jInstaller.bat"
  if (!(Test-Path $UninstallBatch)) { throw "Could not find the Neo4j Uninstaller Batch file at $UninstallBatch" }
  
  # Uninstall the service
  $args = "remove"
  $results = (Start-Process -FilePath $UninstallBatch -ArgumentList $args -Wait -PassThru -NoNewWindow)

  # Remove the install folder
  Remove-Item -Path $neoHome -Recurse -Force | Out-Null
  
  # Remove the environment variable
  Install-ChocolateyEnvironmentVariable "NEO4J_HOME" '' "Machine"

  Write-ChocolateySuccess $PackageName
} catch {
  Write-ChocolateyFailure $PackageName "$($_.Exception.Message)"
  throw
}

