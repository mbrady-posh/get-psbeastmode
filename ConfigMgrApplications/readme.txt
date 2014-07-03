ConfigMgrApplications Readme

Before utilizing this module, the directory structure of your software repository and your collections should be set up as follows (which isn't bad practice anyway:)

Files:
\\repo
	\softwarename
			\softwareversion
					\softwarename_autoinstall.ps1, softwarename_wqldetection.txt, softwarename_detection.ps1 (these can be changed in the script if desired)

Collections:
	Prefix* - softwarename softwareversion Installed (Limited to #3, has a query rule to detect specific version's install state)
	Prefix* - softwarename Install (Limited to #3, excluding #1, is deployed to)
	Prefix* - softwarename Limiting (Limiting collection, typically with a query rule set up to detect any version of the software)
		* Note: the prefixes are handy in a ConfigMgr environment with many disparate groups but aren't necessary

I created the functions with the script deployment type in mind (it's flexible and allows for more customization than using .msi or .exe, even when those are available.) however any deployment type can be used with little modification of the script.
