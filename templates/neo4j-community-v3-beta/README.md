{{PackageName}}
==========================

## What is this?
This project is a Chocolatey package to install the **Beta** Neo4j Community Edition onto a Windows based computer.

The chocolate package can be found at https://chocolatey.org/packages/neo4j-community-beta

https://chocolatey.org

http://neo4j.com/

## How do I install it?
1. Install Chocolatey https://chocolatey.org/
2. Install OpenJDK 7 or Oracle Java 7 http://neo4j.com/docs/stable/deployment-requirements.html#_software
3. Install this package.  This package requried the -prelease flag
```powershell
choco install {{PackageName}} -version {{PackageVersion}} -prerelease
```
4. Open a browser to http://localhost:7474

## What package parameters can I use?
The package supports the following parameters;

```
/Install:<Install Path>
```
Installs Neo4j to the specified directory.  The default is to install to `<Chocolatey Bin Root>\{{PackageName}}` which is typically `C:\tools\Neo4jCommunity`

```
/ImportNeoProperties:<Path to file>
```
Copies the file specified to `<Install Path>\conf\neo4j.conf`.  This is a quick way to configure the Neo4j server prior to service start.  Information about the configuration file can be found at http://neo4j.com/docs/stable/server-configuration.html

```
/ImportServiceProperties:<Path to file>
```
Copies the file specified to `<Install Path>\conf\neo4j-wrapper.conf`.  This is a quick way to configure the Neo4j Windows Service prior to service start.  Information about the configuration file can be found at http://neo4j.com/docs/stable/server-performance.html

```
/WindowsServiceName:<Name of Windows Service>
```
The name of the windows service which will be installed.

Note - This setting overrides the ServiceProperties file

```
/HTTPEndpoint:<IP Address or hostname>:<Port>
```
The HTTP Endpoint that will be used by the Neo4j server e.g. localhost:7474

Note - This setting overrides the NeoProperties file

```
/HTTPSEndpoint:<IP Address or hostname>:<Port>
```
The HTTPS Endpoint that will be used by the Neo4j server e.g. 0.0.0.0:7473

Note - This setting overrides the NeoProperties file

Example usage;
``` powershell
choco install {{PackageName}} -version {{PackageVersion}} -prerelease -packageParameters "/Install:C:\Apps\Neo /ImportNeoProperties:C:\Config\MyNeoProperites.txt /ImportNeoServerProperties:C:\Config\MyNeoServerProperites.txt"
```
This command will install Neo4j to `C:\Apps\Neo`, import the *neo4j.properties* file from `C:\Config\MyNeoProperites.txt` and the *neo4j-server.properties* file from `C:\Config\MyNeoServerProperites.txt`
