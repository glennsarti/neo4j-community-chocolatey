$PackageName = 'neo4j-community'
try {

  $neoHome = $Env:NEO4J_HOME

  # Uninstall the Neo4j Service
  $UninstallBatch = "$($neoHome)\bin\Neo4jInstaller.bat"
  if (!(Test-Path $UninstallBatch)) { throw "Could not find the Neo4j Uninstaller Batch file at $UninstallBatch" }
  
  # Need to use a new environment as the NEO4J_HOME may not have been set correctly
  $args = "remove"
  $results = (Start-Process -FilePath $UninstallBatch -ArgumentList $args -Wait -PassThru -NoNewWindow -UseNewEnvironment)

  # Remove the install folder
  Remove-Item -Path $neoHome -Recurse -Force | Out-Null

  Write-ChocolateySuccess $PackageName
} catch {
  Write-ChocolateyFailure $PackageName "$($_.Exception.Message)"
  throw
}

