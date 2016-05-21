get-psbeastmode
===============

Description
---------------

This repository is all about automation, specifically automation of tasks in the world of Microsoft products. This includes Windows, Windows Server, Active Directory, System Center Configuration Manager, and so on, including combinations of these.

Usage/Installation
----------------

PS1 files can simply be downloaded to your local machine and run in a powershell prompt as normal. Help is available via Get-Help .\(scriptname).ps1 -Full in some cases.

PSM1 files are modules containing multiple functions that can be placed either somewhere in your $env:PSModulePath or in a path of your choosing if you wish, keeping in mind that when you use Import-Module you will need to provide a full path. Individual functions should have their own help, available via Get-Help (Function-name) -Full.
