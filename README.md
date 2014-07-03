get-psbeastmode
===============

Description
---------------

This repository is all about automation, specifically automation of tasks in the world of Microsoft products. This includes Windows, Windows Server, Active Directory, System Center Configuration Manager, and so on, including combinations of these.

Usage/Installation
----------------

PS1 files can simply be downloaded to your local machine and run in a powershell prompt as normal. Help is available via Get-Help .\(scriptname).ps1 -Full for each. 

PSM1 files are modules containing multiple functions that can be placed either somewhere in your $env:PSModulePath or in a path of your choosing if you wish, keeping in mind that when you use Import-Module you will need to provide a full path. Individual functions each have their own help, available via Get-Help (Function-name) -Full.

A few notes about my design choices:

1. I often import an XML file within functions to populate static (but custom) variables rather than weighing the script down with many parameters. If desired, the XML portions can simply be replaced with what is needed in your environment. I like using an XML file so that the scripts can always be public while the potentially sensitive information can be kept under lock and key.

2. I highly suggest utilizing the -Verbose parameter for these; it will be chatty but I tried to make it useful while also updating the tool user at every step of the function.
