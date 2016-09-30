$PackageName = 'neo4j-community'

Function Get-IsJavaInstalled()
{
  [cmdletBinding(SupportsShouldProcess=$false,ConfirmImpact='Low',DefaultParameterSetName='Default')]
  param (
    $Neo4jHome
  )
  
  Process
  {
    $javaPath = ''
    $javaVersion = ''
    $javaCMD = ''
    
    $EnvJavaHome = "$($Env:JAVA_HOME)"
    
    # Is JAVA specified in an environment variable
    if (($javaPath -eq '') -and ($EnvJavaHome -ne $null))
    {
      $javaPath = $EnvJavaHome
      # Modify the java path if a JRE install is detected
      if (Test-Path -Path "$javaPath\bin\javac.exe") { $javaPath = "$javaPath\jre" }
    }

    # Attempt to find Java in registry
    $regKey = 'Registry::HKLM\SOFTWARE\JavaSoft\Java Runtime Environment'    
    if (($javaPath -eq '') -and (Test-Path -Path $regKey))
    {
      $javaVersion = ''
      try
      {
        $javaVersion = [string](Get-ItemProperty -Path $regKey -ErrorAction 'Stop').CurrentVersion
        if ($javaVersion -ne '')
        {
          $javaPath = [string](Get-ItemProperty -Path "$regKey\$javaVersion" -ErrorAction 'Stop').JavaHome
        }
      }
      catch
      {
        #Ignore any errors
        $javaVersion = ''
        $javaPath = ''
      }
    }

    # Attempt to find Java in registry (32bit Java on 64bit OS)
    $regKey = 'Registry::HKLM\SOFTWARE\Wow6432Node\JavaSoft\Java Runtime Environment'    
    if (($javaPath -eq '') -and (Test-Path -Path $regKey))
    {
      $javaVersion = ''
      try
      {
        $javaVersion = [string](Get-ItemProperty -Path $regKey -ErrorAction 'Stop').CurrentVersion
        if ($javaVersion -ne '')
        {
          $javaPath = [string](Get-ItemProperty -Path "$regKey\$javaVersion" -ErrorAction 'Stop').JavaHome
        }
      }
      catch
      {
        #Ignore any errors
        $javaVersion = ''
        $javaPath = ''
      }
    }
    
    # Attempt to find Java in the search path
    if ($javaPath -eq '')
    {
      $javaExe = (Get-Command 'java.exe' -ErrorAction SilentlyContinue)
      if ($javaExe -ne $null)
      {
        $javaCMD = $javaExe.Path
        $javaPath = Split-Path -Path $javaCMD -Parent
      }
    }

    # Attempt to private jre
    $privateJRE = Join-Path -Path $Neo4jHome -ChildPath 'java'
    if ( ($javaPath -eq '') -and (Test-Path -Path $privateJRE) )
    {
      $privateJRE = (Get-ChildItem -Path "$privateJRE" | Select -First 1).FullName

      if (Test-Path -Path "$privateJRE\bin\java.exe") {
        $javaCMD = "$privateJRE\bin\java.exe"
        $javaPath = $privateJRE
      }
    }

    if ($javaPath -eq '') { Write-Host "Unable to determine the path to java.exe"; return $false }
    if ($javaCMD -eq '') { $javaCMD = "$javaPath\bin\java.exe" }
    if (-not (Test-Path -Path $javaCMD)) { Write-Error "Could not find java at $javaCMD"; return $false }
 
    return $javaPath
  }
}

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

  $javaPath = (Get-IsJavaInstalled -Neo4jHome $neoHome)
  if ($javaPath -eq '') { throw "Could not find a Java installation" }
  # Temporarily set the JAVA_HOME environment variable
  $ENV:JAVA_HOME = $javaPath

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