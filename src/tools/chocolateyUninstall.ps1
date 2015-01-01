$PackageName = 'neo4j-community'
try {

  $neoHome = $Env:NEO4J_HOME

  # Uninstall the Neo4j Service
  $UninstallBatch = "$($neoHome)\bin\Neo4jInstaller.bat"
  if (!(Test-Path $UninstallBatch)) { throw "Could not find the Neo4j Uninstaller Batch file at $UninstallBatch" }
  $RefreshEnv = "$($Env:ChocolateyInstall)\bin\RefreshEnv.cmd"
  if (!(Test-Path $RefreshEnv)) { throw "Could not find the RefreshEnv Batch file at $RefreshEnv" }
  
  # Need to use a new environment as the NEO4J_HOME may not have been set correctly
  $args = "remove"
  $results = (Start-Process -FilePath $UninstallBatch -ArgumentList $args -Wait -PassThru -NoNewWindow -UseNewEnvironment)

  # Remove the install folder
  [void] (Remove-Item -Path $neoHome -Recurse -Force)

  Write-ChocolateySuccess $PackageName
} catch {
  Write-ChocolateyFailure $PackageName "$($_.Exception.Message)"
  throw
}

