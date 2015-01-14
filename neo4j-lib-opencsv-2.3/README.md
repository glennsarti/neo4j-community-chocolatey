neo4j-lib-opencsv
==========================

## What is this?
This project is a Chocolatey package to install a library file for the Neo4j Graph Database server onto a Windows based computer.

The chocolate package can be found at https://chocolatey.org/packages/neo4j-lib-opencsv

https://chocolatey.org

http://opencsv.sourceforge.net/

http://neo4j.com/

## How do I install it?
1. Install Chocolatey https://chocolatey.org/
2. Install a version of Neo4j Server
3. Install this package
```powershell
choco install neo4j-lib-opencsv
```
4. Optionally, restart the Neo4j windows service

## What package parameters can I use?
```
RestartService
```
The Neo4j windows service will be restarted after the library is installed.  By default the service is not restarted.  This is useful when installing a lot of libraries and plugins and only wish to restart Neo4j after the last item is installed.

When uninstalling the Neo4j service will **ALWAYS** be stopped and started.  Otherwise, it would not be possible to uninstall this package as it may be in use.

Example usage;
```powershell
choco install neo4j-lib-opencsv -packageParameters "RestartService"
```
This command will install the library and restart the Neo4j windows service.
