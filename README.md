# Cassandra Hardening

This repository contains a collection of PowerShell scripts to easily secure the Cassandra database used by DataMiner.

# Scripts

## Edit-CassandraServiceUser.ps1
A Powershell script that will update the Cassandra service to run as a non-SYSTEM user.

The script will create a new local Windows user (default name: cassandra_service) with a password of your choosing. Then it will grant the new user modify permissions on the required Cassandra folders and update the Cassandra service to logon as said user.

### Usage

Execute the script from an Administrator PowerShell console.

`.\Edit-CassandraServiceUser.ps1`

## Update-CassandraVersion.ps1

A PowerShell script that will update the Cassandra version. The latest version of Apache Cassandra can be downloaded from [cassandra.apache.org](https://cassandra.apache.org/_/download.html).

### Usage

Execute the script from an Administrator PowerShell console.

`.\Update-CassandraVersion.ps1 -binaries "C:\Users\John\Download\apache-cassandra-3.11.12"`

## Update-CassandraJavaVersion.ps1

A PowerShell script that will update the Java OpenJDK version used by Cassandra. The latest Java OpenJDK version can be downloaded from [wiki.openjdk.java.net](https://wiki.openjdk.java.net/display/jdk8u/Main). For example: *OpenJDK8U-jre_x64_windows_8u322b06.zip*.

### Usage

Execute the script from an Administrator PowerShell console.

`.\Update-CassandraJavaVersion.ps1 -binaries "C:\Users\John\Download\openjdk-8u322-b06-jre"`