$PackageName = '{{PackageName}}'
# Per-package parameters
$downloadUrl = '{{DownloadURL}}'
$md5Checksum = '{{MD5Checksum}}'
$neozipSubdir = '{{NeoZipSubdir}}'
# major.minor.update.build
# Build is always 14
$privateJavaVersion = "{{PrivateJavaVersion}}"
$privateJreChecksumMD5 = "{{PrivateJreChecksumMD5}}"

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
function Invoke-ModifyConfig($File,$Key,$Value) {
  Write-Verbose "Setting $($Key)=$($Value) in file $File"
  $RegexKey = $Key.Replace('.','\.')
    
  $fileContent = [IO.File]::ReadAllText($File)
  
  $found = $false
  if ($fileContent -match "(?mi)^$($RegexKey)=") {
    Write-Verbose "Found $Key"
    $fileContent = $fileContent -replace "(?mi)^$($RegexKey)=.+$","$($Key)=$($Value)"
    $found = $true
  }

  if ($fileContent -match "(?mi)^#$($RegexKey)=") {
    Write-Verbose "Found $Key in a comment"   
    $fileContent = $fileContent -replace "(?mi)^#$($RegexKey)=.+$","$($Key)=$($Value)"
    $found = $true    
  }
  
  if (-not $found) {
    Write-Verbose "Adding $key"
    $fileContent += "`n$($Key)=$($Value)"
  }

  $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
  [IO.File]::WriteAllText($File,$fileContent,$Utf8NoBomEncoding) | Out-NUll
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

  $url = "http://download.oracle.com/otn-pub/java/jdk/$($majorVersion)u$($updateVersion)-b$buildNumber/{{PrivateJavaURIDir}}$fileName"

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

  # Default the install root
  try {
    $InstallDir = Get-ToolsLocation -ErrorAction Stop
  } catch {
    # On older chocolatey versions Get-ToolsLocation may not exist as a function.
    #  Fall back to Get-BinRoot
    $InstallDir = Get-BinRoot
  }
  # Default the values
  $InstallDir = Join-Path -Path $InstallDir -ChildPath $PackageName
  $ImportNeoProperties = ""
  $ImportServiceProperties = ""
  $WindowsServiceName = ""
  $HTTPEndpoint = ""
  $HTTPSEndpoint = ""
    
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
          Write-Verbose "Install Argument Found";
          $InstallDir = $arguments["install"];
      }

      if($arguments.ContainsKey("importneoproperties")) {
          Write-Verbose "ImportNeoProperties Argument Found";
          $ImportNeoProperties = $arguments["importneoproperties"];
      }

      if($arguments.ContainsKey("importserviceproperties")) {
          Write-Verbose "ImportServiceProperties Argument Found";
          $ImportServiceProperties = $arguments["importserviceproperties"];
      }

      if($arguments.ContainsKey("servicename")) {
          Write-Verbose "ServiceName Argument Found";
          $WindowsServiceName = $arguments["servicename"];
      }

      if($arguments.ContainsKey("httpendpoint")) {
          Write-Verbose "HTTPEndPoint Argument Found";
          $HTTPEndpoint = $arguments["httpendpoint"];
      }

      if($arguments.ContainsKey("httpsendpoint")) {
          Write-Verbose "HTTPSEndpoint Argument Found";
          $HTTPSEndpoint = $arguments["httpsendpoint"];
      }
  } else {
      Write-Verbose "No Package Parameters Passed in";
  }

  $silentArgs = "/install:" + $InstallDir
  if ($WindowsServiceName -ne "") {
    $silentArgs += " /servicename:" + $WindowsServiceName
  }
  if ($HTTPEndpoint -ne "") {
    $silentArgs += " /httpendpoint:" + $HTTPEndpoint
  }
  if ($HTTPSEndpoint -ne "") {
    $silentArgs += " /httpsendpoint:" + $HTTPSEndpoint
  }
  if ($ImportNeoProperties -ne "") {
    $silentArgs += " /importneoproperties:" + $ImportNeoProperties
  }
  if ($ImportServiceProperties -ne "") {
    $silentArgs += " /importserviceproperties:" + $ImportServiceProperties
  }
  Write-Verbose "This would be the Chocolatey Silent Arguments: $silentArgs"

  # Sanity Checks
  If ($ImportNeoProperties -ne "") {
    If (!(Test-Path -Path $ImportNeoProperties)) { Throw "Could not find the NeoProperties file to import. $ImportNeoProperties" }
  }
  If ($ImportServiceProperties -ne "") {
    If (!(Test-Path -Path $ImportServiceProperties)) { Throw "Could not find the ServiceProperties file to import. $ImportServiceProperties" }
  }

  # Install Neo4j
  Install-ChocolateyZipPackage -PackageName $PackageName -URL $downloadUrl -UnzipLocation $InstallDir -CheckSum $md5Checksum -CheckSumType 'md5'
  $neoHome = "$($InstallDir)\$($neozipSubdir)"
  Install-ChocolateyEnvironmentVariable "NEO4J_HOME" "$neoHome" "Machine"

  # Import config files if required
  If ($ImportNeoProperties -ne "") {
    Write-Verbose "Importing the neo4j.conf from $ImportNeoProperties"
    [void] (Copy-Item -Path $ImportNeoProperties -Destination "$($neoHome)\conf\neo4j.conf" -Force -Confirm:$false)
  }
  If ($ImportServiceProperties -ne "") {
    Write-Verbose "Importing the neo4j-wrapper.conf from $ImportServiceProperties"
    [void] (Copy-Item -Path $ImportServiceProperties -Destination "$($neoHome)\conf\neo4j-wrapper.conf" -Force -Confirm:$false)
  }
    
  # Override with package params
  if ($HTTPEndpoint -ne "") {
    Invoke-ModifyConfig -File "$($neoHome)\conf\neo4j.conf" -Key "dbms.connector.http.address" -Value $HTTPEndpoint | Out-Null
  }
  if ($HTTPSEndpoint -ne "") {
    Invoke-ModifyConfig -File "$($neoHome)\conf\neo4j.conf" -Key "dbms.connector.https.address" -Value $HTTPSEndpoint | Out-Null
  }
  if ($WindowsServiceName -ne "") {
    Invoke-ModifyConfig -File "$($neoHome)\conf\neo4j-wrapper.conf" -Key "dbms.windows_service_name" -Value $WindowsServiceName | Out-Null
  }

  # Check if Java is available
  # This check will not be required once a suitable Java SDK 8 chocolatey package is available in the public feed.
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
  $InstallBatch = "$($neoHome)\bin\Neo4j.bat"
  if (!(Test-Path $InstallBatch)) { throw "Could not find the Neo4j Installer Batch file at $InstallBatch" }
  
  Write-Verbose "Installing Neo4j Service..."
  $args = "install-service"
  $result = Start-Process -FilePath $InstallBatch -ArgumentList $args -Wait -PassThru -NoNewWindow
  
  if ($result.ExitCode -ne 0) { Throw "Neo4j installation returned exit code $($result.ExitCode)"}
  
  Write-Verbose "Starting Neo4j Service..."
  $args = "start"
  $result = Start-Process -FilePath $InstallBatch -ArgumentList $args -Wait -PassThru -NoNewWindow
  
} catch {
  throw "$($_.Exception.Message)"
}
