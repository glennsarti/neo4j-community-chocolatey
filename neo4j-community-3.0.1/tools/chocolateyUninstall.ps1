$PackageName = 'neo4j-community'
try {
  # Get the NeoHome Dir
  #   Try the local environment
  $neoHome = [string] (Get-EnvironmentVariable -Name 'NEO4J_HOME' -Scope 'Machine')
  # Failing that, try a registry hack
  if ($neoHome -eq '')
  {
    $neoHome = [string] ( (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -ErrorAction Continue).'NEO4J_HOME' )
  }
  if ($neoHome -eq '') { throw "Could not find the Neo4j installation via the NEO4J_HOME environment variable" }

  # Uninstall the Neo4j Service
  $UninstallBatch = "$($neoHome)\bin\Neo4j.bat"
  if (!(Test-Path $UninstallBatch)) { throw "Could not find the Neo4j Uninstaller Batch file at $UninstallBatch" }
  
  Write-Verbose "Uninstalling Neo4j Service..."
  $args = "uninstall-service"
  $result = Start-Process -FilePath $UninstallBatch -ArgumentList $args -Wait -PassThru -NoNewWindow

  if ($result.ExitCode -ne 0) { Throw "Neo4j uninstallation returned exit code $($result.ExitCode)"}

  # Remove the install folder
  Remove-Item -Path $neoHome -Recurse -Force | Out-Null
  
  # Remove the environment variable
  Install-ChocolateyEnvironmentVariable "NEO4J_HOME" '' "Machine"
} catch {
  throw "$($_.Exception.Message)"
}