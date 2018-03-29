$PackageName = 'neo4j-community'
# Per-package parameters
$downloadUrl = 'http://neo4j.com/artifact.php?name=neo4j-community-2.3.12-windows.zip'
$md5Checksum = '33874a5e61c701e45c8fbbb9798089a7'
$neozipSubdir = 'neo4j-community-2.3.12'
$neoServerApiJarSuffix = '2.3.12'
# major.minor.update.build
# Build is always 14
$privateJavaVersion = "8.0.131.11"
$privateJreChecksumMD5 = "9458b62000daac0f48155323185f1c4c"

# START Helper Functions
Function Get-IsJavaInstalled
{
  [cmdletBinding(SupportsShouldProcess=$false,ConfirmImpact='Low',DefaultParameterSetName='Default')]
  param ()
  
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

    if ($javaPath -eq '') { Write-Host "Unable to determine the path to java.exe"; return $false }
    if ($javaCMD -eq '') { $javaCMD = "$javaPath\bin\java.exe" }
    if (-not (Test-Path -Path $javaCMD)) { Write-Error "Could not find java at $javaCMD"; return $false }
 
    return $true
  }
}
function Invoke-InstallPrivateJRE($Destination) {
  # Adpated from the server-jre8 chocolatey package
  # https://github.com/rgra/choco-packages/tree/master/server-jre8

  Write-Host "Installing Server JRE $privateJavaVersion to $Destination"

  #8.0.xx to jdk1.8.0_xx
  $versionArray = $privateJavaVersion.Split(".")
  $majorVersion = $versionArray[0]
  $minorVersion = $versionArray[1]
  $updateVersion = $versionArray[2]
  $buildNumber = $versionArray[3]
  $folderVersion = "jdk1.$majorVersion.$($minorVersion)_$updateVersion"

  $fileNameBase = "server-jre-$($majorVersion)u$($updateVersion)-windows-x64"
  $fileName = "$fileNameBase.tar.gz"

  $url = "http://download.oracle.com/otn-pub/java/jdk/$($majorVersion)u$($updateVersion)-b$buildNumber/d54c1d3a095b4ff2b6607d096fa80163/$fileName"

  # Download location info
  $tempDir = Join-Path -Path $ENV:Temp -ChildPath "choco_jre_$PackageName"
  $tarGzFile = "$tempDir\$fileName"
  $tarFile = "$tempDir\$fileNameBase.tar"

  # Cleanup
  if (Test-Path -Path $tempDir) { Remove-Item -Path $tempDir -Force -Recurse -Confirm:$false | Out-Null }

  New-Item -Path $tempDir -ItemType 'Directory' | Out-Null

  $webClient = New-Object System.Net.WebClient
  $result = $webClient.headers.Add('Cookie','gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie')
  Write-Host "Downloading $url ..."
  $result = $webClient.DownloadFile($url, $tarGzFile)
  Get-ChecksumValid $tarGzFile $privateJreChecksumMD5 | Out-Null

  #Extract gz to .tar File
  Get-ChocolateyUnzip $tarGzFile $tempDir | Out-Null
  #Extract tar to destination
  Get-ChocolateyUnzip $tarFile $Destination | Out-Null

  # Cleanup
  if (Test-Path -Path $tempDir) { Remove-Item -Path $tempDir -Force -Recurse -Confirm:$false | Out-Null }

  # return the JAVA_HOME path
  Write-Output (Get-ChildItem -Path $Destination | Select -First 1).FullName
}
# END Helper Functions


try {
  # Taken from https://github.com/chocolatey/chocolatey/wiki/How-To-Parse-PackageParameters-Argument
  $arguments = @{};
  
  # Now, we can use the $env:chocolateyPackageParameters inside the Chocolatey package
  $packageParameters = $env:chocolateyPackageParameters;

  # Default the values
  $InstallDir = Get-BinRoot
  $InstallDir = Join-Path -Path $InstallDir -ChildPath $PackageName
  $ImportNeoProperties = ""
  $ImportNeoServerProperties = ""
  $ImportServiceProperties = ""
  
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

      if($arguments.ContainsKey("importserviceproperties")) {
          Write-Host "ImportServiceProperties Argument Found";
          $ImportServiceProperties = $arguments["importserviceproperties"];
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
  if ($ImportServiceProperties -ne "") {
    $silentArgs += " /importserviceproperties:" + $ImportServiceProperties
  }
  Write-Debug "This would be the Chocolatey Silent Arguments: $silentArgs"

  # Sanity Checks
  If ($ImportNeoProperties -ne "") {
    If (!(Test-Path -Path $ImportNeoProperties)) { Throw "Could not find the NeoProperties file to import. $ImportNeoProperties" }
  }
  If ($ImportNeoServerProperties -ne "") {
    If (!(Test-Path -Path $ImportNeoServerProperties)) { Throw "Could not find the NeoServerProperties file to import. $ImportNeoServerProperties" }
  }
  If ($ImportServiceProperties -ne "") {
    If (!(Test-Path -Path $ImportServiceProperties)) { Throw "Could not find the ServiceProperties file to import. $ImportServiceProperties" }
  }

  # Check if Neo is already installed
  $RunNeo4jInstall = $true
  $existingNeoHome = [string] (Get-EnvironmentVariable -Name 'NEO4J_HOME' -Scope 'Machine')
  if ($existingNeoHome -eq '')
  {
    $existingNeoHome = [string] ( (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -ErrorAction Continue).'NEO4J_HOME' )
  }
  if ($existingNeoHome -ne '') {
    Write-Debug 'The NEO4J_HOME environment variable is set.  Checking the version of Neo4j...'
    
    Get-ChildItem -Path (Join-Path -Path $existingNeoHome -ChildPath 'lib') | Where-Object { $_.Name -match 'server-api-.+\.jar' } | ForEach-Object {
      if ($_.Name.ToLower() -eq "server-api-$($neoServerApiJarSuffix).jar")
      {
        $RunNeo4jInstall = $false
        Write-Host "$PackageName version $neoServerApiJarSuffix is already installed"
      }
      else
      {
        Write-Debug "$PackageName has been installed but found an unexpected version of the server-api jar file $($_.Name)"
        Throw "$PackageName is installed but is not the correct version.  Expected version $neoServerApiJarSuffix"
      }
    }
  }

  if ($RunNeo4jInstall) {    
    # Install Neo4j
    Install-ChocolateyZipPackage -PackageName $PackageName -URL $downloadUrl -UnzipLocation $InstallDir -CheckSum $md5Checksum -CheckSumType 'md5'
  
    # Set the Home Environment Variable
    $neoHome = "$($InstallDir)\$($neozipSubdir)"
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
    If ($ImportServiceProperties -ne "") {
      Write-Host "Importing the neo4j-wrapper.conf from  $ImportServiceProperties"
      [void] (Copy-Item -Path $ImportServiceProperties -Destination "$($neoHome)\conf\neo4j-wrapper.conf" -Force -Confirm:$false)
    }

    # Check if Java is available
    # This check will not be required once a suitable Java SDK 8 chocolatey package is available in the public feed
    if (-not (Get-IsJavaInstalled) ) {
      Write-Host "Java was not detected.  Installing a private JRE for Neo4j"
      $privatePath = Invoke-InstallPrivateJRE -Destination "$($neoHome)\java"
      Write-Host "--------------------"
      Write-Host "Before using Neo4j tools, ensure you have set the JAVA_HOME"
      Write-Host "environment variable to $($privatePath)"
      Write-Host ""
      Write-Host "For example, in a command prompt:"
      Write-Host "SET JAVA_HOME=$($privatePath)"
      Write-Host ""
      Write-Host "For example, in a PowerShell console:"
      Write-Host "`$ENV:JAVA_HOME = '$($privatePath)'"
      Write-Host ""
      Write-Host "--------------------"
      $ENV:JAVA_HOME = $privatePath
    }
    
    # Install the Neo4j Service
    $InstallBatch = "$($neoHome)\bin\Neo4jInstaller.bat"
    if (!(Test-Path $InstallBatch)) { throw "Could not find the Neo4j Installer Batch file at $InstallBatch" }
    
    $args = "install"
    Start-Process -FilePath $InstallBatch -ArgumentList $args -Wait -PassThru -NoNewWindow | Out-Null
    
    $neoService = Get-Service -Name "Neo4j-Server" -ErrorAction Continue
    if ($neoService -eq $null) {
      Throw "The Neo4j Sever Service failed to install"
    }
  }
} catch {
  throw "$($_.Exception.Message)"
}
