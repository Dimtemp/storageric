### STARTER ##############################################
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-Module -Name xPSDesiredStateConfiguration -RequiredVersion 3.13.0.0



### KEYS ##############################################
Get-DscLocalConfigurationManager # Verify RefreshMode: Pull
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
            RegistrationKey    = 'b6481af0-21c1-453e-bf1a-aa40bb20075d'      # REPLACE
            ConfigurationNames = @('StudentServer2')
            AllowUnsecureConnection = $true
        }   

        ReportServerWeb StudentServer2    # Use the name of your server                                  
        {
            ServerURL       = 'http://StudentServer2:8086/PSDSCPullServer.svc'
            RegistrationKey = 'b6481af0-21c1-453e-bf1a-aa40bb20075d'         # REPLACE
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


