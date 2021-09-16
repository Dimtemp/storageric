# uitwerken: trusted hosts, zodat VM niet in domain hoeft

### STARTER ##############################################
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-Module -Name xPSDesiredStateConfiguration -RequiredVersion 3.13.0.0



### Create pull server

configuration Sample_xDscWebService 
{ 
    param  
    ( 
            [string[]]$NodeName = 'localhost', 

            [Parameter(HelpMessage='Use AllowUnencryptedTraffic for setting up a non SSL based endpoint (Recommended only for test purpose)')]
            [ValidateNotNullOrEmpty()] 
            [string] $certificateThumbPrint,

            [Parameter(HelpMessage='This should be a string with enough entropy (randomness) to protect the registration of clients to the pull server.  We will use new GUID by default.')]
            [ValidateNotNullOrEmpty()]
            [string] $RegistrationKey = ([guid]::NewGuid()).Guid
     ) 


     Import-DSCResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 3.13.0.0
     Import-DSCResource -ModuleName PSDesiredStateConfiguration 

     Node $NodeName 
     { 
         WindowsFeature DSCServiceFeature 
         { 
             Ensure = "Present" 
             Name   = "DSC-Service"             
         } 


         xDscWebService PSDSCPullServer 
         { 
             Ensure                  = "Present" 
             EndpointName            = "PSDSCPullServer" 
             Port                    = 8086 
             PhysicalPath            = "$env:SystemDrive\inetpub\PSDSCPullServer" 
             CertificateThumbPrint   = "AllowUnencryptedTraffic"          
             ModulePath              = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules" 
             ConfigurationPath       = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"             
             State                   = "Started" 
             DependsOn               = "[WindowsFeature]DSCServiceFeature"                         
         } 

        File RegistrationKeyFile
        {
            Ensure          ='Present'
            Type            = 'File'
            DestinationPath = "$env:ProgramFiles\WindowsPowerShell\DscService\RegistrationKeys.txt"
            Contents        = $RegistrationKey
        }
    }
}

Sample_xDscWebService -certificateThumbPrint "AllowUnencryptedTraffic" -OutputPath C:\Demo\NoCert
Start-DscConfiguration -Path C:\Demo\NoCert -Wait -Verbose -Force


# optionally surf to mentioned URL



### KEYS ##############################################
Get-DscLocalConfigurationManager # Verify RefreshMode: Push
Get-Content $env:ProgramFiles\WindowsPowerShell\DscService\RegistrationKeys.txt | Set-Clipboard




###################################################
# Setting up a Pull Client 

[DSCLocalConfigurationManager()]      
configuration LocalHostLCMConfig
{
    Node StudentServer2
    {
        Settings
        {
            RefreshMode          = 'Pull'
            RefreshFrequencyMins = 30 
            RebootNodeIfNeeded   = $true
        }

        ConfigurationRepositoryWeb StudentServer2    # Use the name of your server                       
        {
            ServerURL          = 'http://StudentServer2:8086/PSDSCPullServer.svc'
            RegistrationKey    = '83f5a404-5fa2-43b2-adda-13b0a7df3a79'      # REPLACE
            ConfigurationNames = @('StudentServer2')
            AllowUnsecureConnection = $true
        }   

        ReportServerWeb StudentServer2    # Use the name of your server                                  
        {
            ServerURL       = 'http://StudentServer2:8086/PSDSCPullServer.svc'
            RegistrationKey = '83f5a404-5fa2-43b2-adda-13b0a7df3a79'         # REPLACE
            AllowUnsecureConnection = $true
        }
    }
}

LocalHostLCMConfig  -OutputPath c:\Configs\TargetNodes  

Set-DscLocalConfigurationManager -Path C:\Configs\TargetNodes\ -Verbose -Force
Get-DscLocalConfigurationManager






### DISTRIBUTE ##############################################

$configData = @{
    AllNodes = @(
        @{
            NodeName = 'StudentServer2'                      
        }
    )    
}


Configuration SampleLog {
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    node $AllNodes.Nodename
    {
        Log SampleMessage
        {
            Message = "Another Sample Message" 
        }

        File SampleFile
        {
        Ensure = "Present"
        Type = "Directory"
        DestinationPath = "C:\MyDemoDirectory\"
        }
    }
}

SampleLog -ConfigurationData $configData -outputpath C:\Holding\Configurations\
New-DscChecksum -Path C:\Holding\Configurations\ -Force
Move-Item C:\Holding\Configurations\ $env:ProgramFiles\WindowsPowerShell\DscService\Configuration
Update-DscConfiguration -Verbose -Wait   # review sample message
Update-DscConfiguration -Verbose -Wait
Notice: Updated configuration not found on pull server so no action taken.
New-DscChecksum -Path C:\Holding\Configurations\

Get-ChildItem C:\Holding\Configurations\   # Notice folder is empty

Update-DscConfiguration -Wait -Verbose
Modify: "Another Sample Message"
New-DscChecksum -Path C:\Holding\Configurations\ -Force
New-DscChecksum -Path C:\Holding\Configurations\ -Force


Get-ChildItem C:\Holding\Configurations\   # Notice MOF and Checksum files
Move-Item C:\Holding\Configurations\ $env:ProgramFiles\WindowsPowerShell\DscService\Configuration
Update-DscConfiguration -Verbose -Wait









### DEBUG ###########################################################

Enable-DscDebug -BreakAll
$MyLcm = Get-DscLocalConfigurationManager
$MyLcm.DebugMode

#Test Configuration 
Configuration PSEngine2
    {
    Import-DscResource -ModuleName 'PsDesiredStateConfiguration'
    Node localhost
        {
        WindowsFeature PSv2
            {
            Name = 'PowerShell-v2'
            Ensure = 'Present'
            }}}
PSEngine2 -outputpath 'C:\Demo\Debug'
Start-DscConfiguration -Path C:\Demo\Debug -Wait  -Verbose -Force # Using -Force because LCM is configured for Pull


