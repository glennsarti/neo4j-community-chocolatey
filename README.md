neo4j-community-chocolatey
==========================

## What is this?
This project is a Chocolatey package to install Neo4j Community Edition onto a Windows based computer.

The chocolate package can be found at https://chocolatey.org/packages/neo4jcommunity

https://chocolatey.org

http://neo4j.com/

## How do I install it?
1. Install Chocolatey https://chocolatey.org/
2. Install OpenJDK 7 or Oracle Java 7 http://neo4j.com/docs/stable/deployment-requirements.html#_software
3. Install this package
```powershell
choco install neo4jcommunity
```
4. Open a browser to http://localhost:7474

## What package parameters can I use?
The package supports the following parameters;

```
/Install:<Install Path>
```
Installs Neo4j to the specified directory.  The default is to install to `%SYSTEMDRIVE%:\Neo4jCommunity` which is typically `C:\Neo4jCommunity`

```
/ImportNeoProperties:<Path to file>
```
Copies the file specified to `%NEO4J_HOME%\conf\neo4j.properties`.  This is a quick way to configure the Neo4j server prior to service start.  Information about the configuration file can be found at http://neo4j.com/docs/stable/server-configuration.html

```
/ImportNeoServerProperties:<Path to file>
```
Copies the file specified to `%NEO4J_HOME%\conf\neo4j-server.properties`.  This is a quick way to configure the Neo4j server prior to service start.  Information about the configuration file can be found at http://neo4j.com/docs/stable/server-performance.html

Example usage;
```powershell
choco install neo4jcommunity -packageParameters "/Install:C:\Apps\Neo /ImportNeoProperties:C:\Config\MyNeoProperites.txt /ImportNeoServerProperties:C:\Config\MyNeoServerProperites.txt"
```
This command will install Neo4j to `C:\Apps\Neo`, import the *neo4j.properties* file from `C:\Config\MyNeoProperites.txt` and the *neo4j-server.properties* file from `C:\Config\MyNeoServerProperites.txt`
