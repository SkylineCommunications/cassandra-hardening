# Cassandra Hardening

 > [!WARNING]  
> This repository has been archived.
> All Cassandra versions that support windows installations are end-of-life. Since the scripts within this repository are specific for these Windows installations of Cassandra, they will no longer be updated.

This repository contains a collection of PowerShell scripts to easily secure the Cassandra database used by DataMiner.

# Scripts

## Edit-CassandraServiceUser.ps1
A Powershell script that will update the Cassandra service to run as a non-SYSTEM user.

The script will create a new local Windows user (default name: cassandra_service) with a password of your choosing. Then it will grant the new user modify permissions on the required Cassandra folders and update the Cassandra service to logon as said user.

### Usage

Execute the script from an Administrator PowerShell console.

`.\Edit-CassandraServiceUser.ps1`

For more usage info, execute:

`Get-Help .\Edit-CassandraServiceUser.ps1 -Detailed`

## Update-CassandraVersion.ps1

A PowerShell script that will update the Cassandra version. Any version of Apache Cassandra can be downloaded from the [Apache Archive Distribution Directory](https://archive.apache.org/dist/cassandra/3.11.9/). Make sure to download the Cassandra version that ends in "-bin.tar.gz" and extract it to use as your path.

### Usage

Execute the script from an Administrator PowerShell console.

`.\Update-CassandraVersion.ps1 -binaries "C:\Users\John\Download\apache-cassandra-3.11.12"`

For more usage info, execute:

`Get-Help .\Update-CassandraVersion.ps1 -Detailed`

## Update-CassandraJavaVersion.ps1

A PowerShell script that will update the Java OpenJDK version used by Cassandra. The latest Java OpenJDK version can be downloaded from [wiki.openjdk.java.net](https://wiki.openjdk.java.net/display/jdk8u/Main). For example: *OpenJDK8U-jre_x64_windows_8u322b06.zip*.

### Usage

Execute the script from an Administrator PowerShell console.

`.\Update-CassandraJavaVersion.ps1 -binaries "C:\Users\John\Download\openjdk-8u322-b06-jre"`

For more usage info, execute:

`Get-Help .\Update-CassandraJavaVersion.ps1 -Detailed`
