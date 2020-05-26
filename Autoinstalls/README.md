# Install Program Setup and Scripts
## Contents
 - [Description](#description)
 - [Usage](#Usage)
 - [Setup](#Setup)
 - [JsonTemplate](#JsonTemplate)
 - [ScriptTemplate](#ScriptTemplate)
 - [AddingDepartment](#AddingDepartment)
 - [AddingProgramCheck](#AddingProgramCheck)
 - [AddingProgramInstall](#AddingProgramInstall)



&nbsp;

## Description

This is a PowerShell script for automation of installing programs on Windows 10.

## Usage
The installers follow a basic template and anyone can create a fully functioning script that has logging built in.

Reason for creating this: To mass install programs
Almost all software install scripts have been moved over to a new template and single configuration file.
The template for the script follows these basic items:

	1. Validate the given config files path
	2. Take input for process name to kill, name of program, destination, and excluded items to not search for or download
	3. Start script logging
	4. Import path
	5. Figure out if msi or exe provider
	6. Grab nearest domain by importing a JSON file [DCList.json]
	7. Test if the mutex, install availability, is open
	8. Add a wait condition of up to 600 seconds for the mutex
	9. Create download folder path
	10. Clear any old logs pertaining to the chosen install
	11. Copy down via robocopy the program and keep a log
	12. Check exit code of the copy to make sure it went alright
	13. Do any pre-install work
	14. Grab the current directory of copied program and grab latest item
	15. Build the install arguments
	16. Try to install the program and let you know the exit code and if any errors and log the install
	17. Do any post-install work
	18. Remove download folder
	19. End logging for script
 
## Setup
You will need to change the intial logger loading path for almost all scripts.
Starting path is `."\\Server\Path\Here\Logging.ps1"` and this will not work of course. So go ahead and change that to where you want to store it. You will need to change all the spots of `\\Server\Path\Here` that are throught any scripts. Mostly this will be the logging script path but there are some areas where these are placed. Remember to read through the entire script before using it.

You will need to find all `Some NonDomain User` or `NonDomain User` in any of the scripts as its checking to make sure the current logged on user is a domain user. We use a specified username so I always knew what it was but you may not and may need to write or tweak that code a little.

`Logger` - This piece is interesting as I have it setup so that the calling script will get a log file named after it and Logger will continue to use that log file to log to, until you stop the logger or end the script and then call it in a new script, which then it will create a new log with that name instead.

**Some scripts will not have this block of code because they are helper functions that are in the main script or called and so its a guaranteed thing that the logger is already running. But for you it may differ**

```Powershell
if (!("PSLogger" -as [type])) {
	$callingSCript = ($MyInvocation.MyCommand.Name) -split ('.ps1')
	."\\Server\Path\Here\Logging.ps1"
	$logger = [PSLogger]::new($logPath, $callingScript)
}

```

Then for all Install-* scripts make sure to change the path for `Get-NearestDomain` so grabs a json that has a list of the DC's you want to ping. I just have a script that runs on the network once a week to update my json.
```Powershell
if (!(Get-Variable -Name nearestDomain -ErrorAction SilentlyContinue)) {
	$nearestDomain = (Get-NearestDomain -Path "\\Server\Path\Here\Settings\JSON\DCList.json")
}
```
All JSON's and XML's and Reg files and such are in the `Settings` folder. This should give you a good idea of what you need to do or you can take them and tweak them as needed. Most should be of use already and be a good
template.

&nbsp;

### **Compare-ProgramList**
------
Under General-->Install
Compare-ProgramList – this will compare the list of programs that are installed to what they should have either for their department where listed or the default "Renaissance" department.

This cmdlet will grab the current department automatically for you and check that. If the department doesn’t exist then the default is chosen instead.

You can add any program name or random name to the program
No code change is needed to update the list. Just the json file needs to be updated and the script will handle it.

This is the code where it will try and grab the department path, if it comes back as null then it will default to the default path

`Name` - Name of program its looking for

`Installed` - If its installed or not

`AutoInstallSupport` - If there is a script or not for it by looking at the "program section". More on that below



```Powershell
try {
	$searcher = [adsisearcher]"(samaccountname=$env:USERNAME)"
	$department = $searcher.FindOne().Properties.department
	$logger.Informational("Department: $department")
}
catch [System.Management.Automation.MethodInvocationException] {
	$logger.Informational("Department does not exist in the Json. Defaulting to Default.")
	$department = $null
} 

if (!($null -eq $installationList.$department)) {
	$departmentPrograms = $installationList.department.$department
}
else {
	$departmentPrograms = $installationList.department.Default
}
```

```PowerShell
PS C:\Users\Username> Compare-ProgramList -Path "\\Server\\Path\\Here\Settings\JSON\Applications.json"

Name                            Installed AutoInstallSupport
----                            --------- ------------------
Adobe Acrobat Reader DC              True               True
Adobe Flash Player                   True               True
Dell Command | Update                True               True
Dot. Net Installers                 False               True
Google Chrome                        True               True
Java                                 True               True
Kaspersky                            True               True
Lenovo System Update                False               True
Malwarebytes                        False               True
Office 16 Click-to-Run               True               True
ManageEngine Patch Manager Plus     False               True
Solarwinds                           True               True
Zoom                                 True               True
Zoom Outlook Plugin                  True               True
```
 

&nbsp;

### **Install-ProgramList**
------
`Install-ProgramList` does the install of the programs that are not currently installed but support autoinstall. This will basically invoke the separate scripts for each program.

**You will need to give the path of the Applications JSON at the top of the dynamic parameter**

```PowerShell
# Generate and set the ValidateSet
$fname = "\\Server\Path\Here\Settings\JSON\Applications.json" 
```

You can save the output of the Compare-ProgramList to a variable and the use the Install-ProgramList To accept the input:
```powershell
$list = Compare-ProgramList -Path "\\server\path\here\Applications.json"
Install-ProgramList -InputObject $list
```
 
You can pipe Compare-ProgramList to Install-ProgramList
```powershell
Compare-ProgramList -Path "\\server\path\here\Applications.json" | Install-ProgramList
```
 
Under General-->Install
You can also run the function Install-ProgramList by itself and it will dynamically update its table of listed programs for installing, every time you update the json.
So once again no code change is needed for this. It also handles .bat or .ps1 files automatically and starts them.
```Powershell
Install-ProgramList -Program '7-Zip'
```
 

### **Functions Inside the Template and are also under the General folder**
------

`Grant-Admin` - Checks if the current script is running as Admin

`Get-NearestDomain` - Grabs the nearest domain by using a json that contains a list. Expressed in scripts as $nearestDomain and contains only the Domain Controllers name nearest via ping check.
	Example is in the settings-->JSON folder under `DCList.json` So if DC01 was closest then $nearestDomain = DC01 and the path would be like this in string when you need to use it `\\$nearestDomain\Server\Path\Here`
	And really if your work place allows the install of AD cmdlets on user computers then you don't need this and can use the built in AD cmdlet.

`Test-IsMutexAvailable` - Checks if the mutex is available so the program can install.

`Wait-Condition` - Place as a wait condition with a timeout for the mutex.

  
&nbsp;

### **Config file**
------

This is the central piece that gives each install its own specific instructions. [`\\Server\Path\Here\Settings\JSON\Applications.json`]
You will see programs and departments listed inside. The point of this file is to create a central area to change  or add installation scripts.
Any programs that are listed in this section and that have a filename of *.ps1 or *.bat are considered finished scripts to the framework.
 
You can add departments at anytime and add programs at any time.
 
The only caveat is that you would need to follow the schema that I have set. 
 
Departments are easy enough because it’s the name and list of programs as shown for network services.
How the department section looks:
```JSON
 "Network Services": [
	"Adobe Acrobat Reader DC",
	"Adobe Flash Player",
	"Dell Command | Update",
	"Dot. Net Installers",
	"Google Chrome",
	"Java",
	"Kaspersky",
	"Lenovo System Update",
	"Malwarebytes",
	"Office 16 Click-to-Run",
	"ManageEngine Patch Manager Plus",
	"Solarwinds",
	"Zoom",
	"Zoom Outlook Plugin"
]
```
 
 
Program sections takes a little more knowledge on how programs are installed.
So we need the program name as the starting point then 
You need name again, version is optional, source, filename, filepath, and argument list.
 
Basically any .EXE installer will look like adobe acrobat reader dc while almost all .MSI installers will look like 7-zip.
 

How the program section looks:
```JSON
"Program": {
	"7-Zip": {
		"name": "7-Zip",
		"version": "19.00",
		"Source": "\\Server\\Path\\Here\\7-Zip",
		"filename": "Install-7Zip.ps1",
		"filepath": "msiexec.exe",
		"argumentlist": [
			"/i",
			"$app",
			"/QB",
			"/lv $LogPath\\Install-7-Zip.log"
		]
	},
	"Adobe Acrobat Reader DC": {
		"name": "Adobe Acrobat Reader DC",
		"version": "",
		"Source": "\\Server\\Path\\Here\\AdobeAcrobatReaders",
		"filename": "Install-AdobeReader.ps1",
		"filepath": "$filePath",
		"argumentlist": [
			"/sPB",
			"/rs",
			"/l",
			"/msi EULA_ACCEPT=YES /L*v $LogPath\\Install-AdobeDC.log"
		]
	},
	"Adobe Flash Player": {
		"name": "Adobe Flash Player",
		"version": "",
		"Source": "\\Server\\Path\\Here\\AdobeFlashPlayer",
		"filename": "Install-AdobeFlash.ps1",
		"filepath": "msiexec.exe",
		"argumentlist": [
			"/i",
			"$app",
			"/QB",
			"/lv $LogPath\\Install-AdobeFlashPlayer.log"
		]
	}
}
```
 
**IMPORTANT NOTE**
The file share where the EXE or MSI is stored, needs to have a folder called MSI or EXE with the respected installer in the correct folder. Currently the install-softwaretemplate.ps1 only supports one type of installer per script template but you can have multiples of that one installer. A Good example is Zoom. Just remember, its a template, it does it's best.

Also its important that the share retains the current setup that I have going forward as this makes the code faster, but also keeps it straight. And helps everyone know what they are looking for as well. I have made exceptions for some of the programs but I tweaked the template a little to allow for it. That's pretty much what the pre- and post- checks are for the script.
Pretty much needs to be either msi or exe or pkg and optionally settings folder. This is a clean layout and users or others just need to know to use the script instead of doing stuff manually.
 
Examples:
```PowerShell
\\Server\Path\GOOGLECHROME
|   Install-GoogleChrome.ps1
|   
+---MSI
|       GoogleChromeStandaloneEnterprise64.msi
|       
\---PKG
		GoogleChrome.dmg
		

\\Server\Path\ADOBEACROBATREADERS
|   Install-AdobeReader.ps1
|   
\---EXE
        AcroRdrDC2000620034_en_US.exe


\\Server\Path\CISCOJABBER
|   Install-CiscoJabber.ps1
|   
\---MSI
        CiscoJabberSetup.msi


\\Server\Path\ZOOM
|   Install-Zoom.ps1
|   
+---MSI
|       ZoomInstallerFull.msi
|       ZoomOutlookPluginSetup.msi
|       
+---PKG
|       us.zoom.config.plist
|       ZoomMacOutlookPlugin.pkg
|       zoomusInstallerIT.pkg
|       
+---Settings
|       CleanZoom.exe
|       ZoomOutlookAdd-in.reg
|       
\---Sip Logging Zoom
        ReadMe.txt
        ZoomFull_Sip.EXE

```
 
&nbsp;


### **JsonTemplate**
------
Go to  `\\Server\\Path\\Here\Settings\JSON`. or the JSON Folder.

Make a copy of `Applications.json` onto your desktop first for first time use or setup

&nbsp;

### **ScriptTemplate**
------
Go to `\\Server\\Path\\Here\Templates` or the Template Folder.

Make a copy of `Install-Template.ps1` onto your desktop first.

&nbsp;

### **AddingDepartment**
------
Open the `Applications.json` in Visual Studio Code.
Copy a department and then paste the new department  and paste it to where it will be alphabetical when you rename it in the department section.

Example: I copied the network services department and pasted the copy below it and renamed it 'Fake Department' Notice the comma after it? That is because there are more items below it so it needs the comma. If it were the last department and nothing was after it then no comma is needed.
```JSON
 "Fake Department": [
	"Adobe Acrobat Reader DC",
	"Adobe Flash Player",
	"Dell Command | Update",
	"Dot. Net Installers",
	"Google Chrome",
	"Java",
	"Kaspersky",
	"Lenovo System Update",
	"Malwarebytes",
	"Office 16 Click-to-Run",
	"ManageEngine Patch Manager Plus",
	"Solarwinds",
	"Zoom",
	"Zoom Outlook Plugin"
]
```

&nbsp;

### **AddingProgramCheck**
------
Open the `Applications.json` in Visual Studio Code.
I went back to the 'Fake Department' but you can do this for any department at any time.
Adding a program to a department only checks to see if its installed or not. You will need the correct program name.
```JSON
 "Fake Department": [
	"Adobe Acrobat Reader DC",
	"Adobe Flash Player",
	"Dell Command | Update",
	"Dot. Net Installers",
	"Google Chrome",
	"Java",
	"Kaspersky",
	"Lenovo System Update",
	"Malwarebytes",
	"Office 16 Click-to-Run",
	"ManageEngine Patch Manager Plus",
	"Solarwinds",
	"Fake Program Name",
	"Zoom",
	"Zoom Outlook Plugin"
]
```

```Powershell
PS C:\Users\Username> Compare-ProgramList -Path "\\Server\\Path\\Here\Settings\JSON\Applications.json"

Name                            Installed AutoInstallSupport
----                            --------- ------------------
Adobe Acrobat Reader DC              True               True
Adobe Flash Player                   True               True
Dell Command | Update                True               True
Dot. Net Installers                 False               True
Google Chrome                        True               True
Java                                 True               True
Kaspersky                            True               True
Lenovo System Update                False               True
Malwarebytes                        False               True
Office 16 Click-to-Run               True               True
ManageEngine Patch Manager Plus     False               True
Solarwinds                           True               True
Fake Program Name                   False              False
Zoom                                 True               True
Zoom Outlook Plugin                  True               True
```

If you have VS Code setup you can type in the PowerShell integrated console, otherwise open PowerShell.

Example finding a program name:
Type into the console Get-Package -Name "Google*"
```Powershell
PS C:\Users\Username> Get-Package -Name "Google*"

Name                           Version          Source                           ProviderName                                                                            
----                           -------          ------                           ------------                                                                            
Google Update Helper           1.3.35.451                                        msi                                                                                     
Google Chrome                  81.0.4044.138                                     msi 
```

You can see above that the "Name" field has 'Google Chrome'. You can use this to have the script tell you if something is installed or not

&nbsp;

### **AddingProgramInstall**
------
Open the `Applications.json` in Visual Studio Code.
Go to the top of the Json and copy a program and paste it to where it will be alphabetical when you rename it.

EXE example:
```Json
 "Cisco AnyConnect": {
	"name": "Cisco AnyConnect",
	"version": "",
	"Source": "\\Server\\Path\\Here\\CiscoAnyConnect",
	"filename": "Install-CiscoAnyConnect.ps1",
	"filepath": "msiexec.exe",
	"argumentlist": [
		"/i",
		"$app",
		"/QB",
		"/lv $LogPath\\Install-CiscoAnyConnect.log"
	]
},
```


MSI Example:
```Json
"Adobe Acrobat Reader DC": {
	"name": "Adobe Acrobat Reader DC",
	"version": "",
	"Source": "\\Server\\Path\\Here\\AdobeAcrobatReaders",
	"filename": "Install-AdobeReader.ps1",
	"filepath": "$filePath",
	"argumentlist": [
		"/sPB",
		"/rs",
		"/l",
		"/msi EULA_ACCEPT=YES /L*v $LogPath\\Install-AdobeDC.log"
	]
}
```

Bat Example:
```Json
"Office 16 Click-to-Run": {
	"name": "Office 365 Pro-Plus",
	"version": "",
	"Source": "\\Server\\Path\\Here\\Office365Install",
	"filename": "Install-Office365.bat",
	"filepath": "",
	"argumentlist": [
		
	]
}
```



The first  'Fake Program Name' needs to be what you see installed on the computer. Refer to 'Example finding a program name:' up above.

`Name` - This is what is written for the user to see in the ScriptTemplate

`Version` - Optional and could used later in the scripts for strict version control. No code has been written for this yet.

`Source` - Needs to be the path right before the powershell script or known as the parent folder.
	Example: If my normal path is "\\\DC\Server\Path\Here" Then it would be "\\\Server\\\\Path\\\\Here" in the json because the script uses a function called Get-
	You can change this however you want if you are not using the Get-NearestDomain Function

`Filename` - Needs to be the powershell file name or bat file name that will be executed.

`Filepath` - This needs to be either $filePath for EXE's OR msiexec.exe for MSI's OR Blank if calling a bat file as seen above in screenshotted examples.

`Argumentlist` - EXE's and MSI's will have their arguments or known as switches here.

1. EXE's just need their switches added but nothing special.

2. MSI's will need to start with /i and $app as the first and second switches and then logging at the end just as I have it and you can have all the other switches you want.

3. Bat Files do not need anything added to them

Fake Program Added to the list
```Json
 "Fake Program Name": {
	"name": "Fake Program Name",
	"version": "",
	"Source": "\\Server\\Path\\Here\\FakeProgramName",
	"filename": "Install-FakeProgramName.ps1",
	"filepath": "msiexec.exe",
	"argumentlist": [
		"/i",
		"$app",
		"/QB",
		"/lv $LogPath\\Install-FakeProgramName.log"
	]
},
```

Open the `Install-Template.ps1` in Visual Studio Code.
Change the name of the file and function name at both the top and bottom of the script.


Next You will need to change the Name, Process, and ExcludedItems and LogPath.

`Name` - This is the name of the program that is listed in the json. 'Example finding a program name:' up above.

`Process` - This is the process in task manager that you wish to kill

`ExcludedItems` - These are the directories or folders or files that you wish to exclude

`LogPath` - This should always be C:\Temp\ and then the name that you have above and it can't have spaces in it. Otherwise Robocopy has an issue with it.

Example Parameter Layout:
```PowerShell
 [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {
                if (-Not ($_ | Test-Path) ) {
                    throw "File does not exist"
                }
                if (-Not ($_ | Test-Path -PathType Leaf) ) {
                    throw "The path argument must be a file. Folder paths are not allowed."
                }
                if ($_ -notmatch "(\.json)") {
                    throw "The file specified in the path argument must be .json"
                }
                return $true 
            })]
        [string]$Path,

        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [String]$Name = "Fake Program Name",

        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [String]$Process = "FakeProcess Name",

        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [String]$Destination = "$home\Downloads",

        [Parameter(Mandatory = $false)]
        [String[]]$ExcludedItems = @("FakeExtraProgramName.msi","FakeFolderName"),

        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath = "C:\Temp\FakeProgramName",
        
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Switch]$Clean
    )
```

```PowerShell
# Pre setup software checks here
 
################################
```
 and
```PowerShell
# Post setup software checks here
 
################################
```


If you want more information then you should be able to look at the help section at the top of the script.