[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [System.String]
    $snmp_community_string = {2} ,

    [Parameter(Mandatory=$false)]
    [System.Object]
    $snmp_allowed_hosts = {3} ,

    [Parameter(Mandatory=$false)]
    [System.Boolean]
    $snmp_configuration_enabled = {1}
)

# Define logging function
function Write-Log {
  param (
      [Parameter(Mandatory=$true)]
      [string]$Message,

      [Parameter(Mandatory=$false)]
      [ValidateSet('Error', 'Warning', 'Information', 'Verbose')]
      [string]$Level = 'Information',

      [Parameter(Mandatory=$false)]
      [string]$Path = "C:\Windows\Logs\default_settings.log"
  )

  Add-Content -Path $Path -Value (" $(Get-Date) ; $Level ; $Message")
}

try {
  # Test if the DefaultSettings registry key exists and if not, set the default settings.
  if(-not(test-path 'HKLM:\Software\DefaultSettings')){

    # Set Windows System Locale
    Write-Log -Message 'Setting Windows System Locale' -Level 'Information'
    Set-WinSystemLocale 'de-CH'
    Write-Log -Message 'Successfully set Windows System Locale' -Level 'Information'

    # Set Windows Time Zone
    Write-Log -Message 'Setting Windows Timezone' -Level 'Information'
    Set-TimeZone -id 'W. Europe Standard Time'
    Write-Log -Message 'Successfully set Windows Timezone' -Level 'Information'

    # Set Windows UI Language
    Write-Log -Message 'Installing SNMP-Service' -Level 'Information'
    Install-WindowsFeature -Name 'SNMP-Service' -IncludeAllSubFeature -IncludeManagementTools
    Write-Log -Message 'Successfully installed SNMP-Service' -Level 'Information'

    # Configure SNMP-Service
    if($snmp_configuration_enabled -eq $true){
      Write-Log -Message 'Configuring SNMP-Service' -Level 'Information'

      # Set SNMP Community String
      Write-Log -Message 'Setting SNMP Community String' -Level 'Information'
      Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities' -Name $snmp_community_string -Type DWord -Value 4
      Write-Log -Message 'Successfully set SNMP Community String' -Level 'Information'

      # Set SNMP Allowed Hosts
      Write-Log -Message 'Setting SNMP Allowed Hosts' -Level 'Information'
      $i = 0
      foreach($allowed_host in $snmp_allowed_hosts){
        $i++
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers' -Name $i -Value $allowed_host
      }
      Write-Log -Message 'Successfully set SNMP Allowed Hosts' -Level 'Information'

      # Enable SNMP Authentication Trap
      Write-Log -Message 'Enabling SNMP Trap' -Level 'Information'
      Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\' -Name 'EnableAuthenticationTraps' -Value 1
      Write-Log -Message 'Successfully enabled SNMP Trap' -Level 'Information'

      # Enable SNMP Service
      Write-Log -Message 'Enabling SNMP Service' -Level 'Information'
      Set-Service -Name 'SNMP' -StartupType 'Automatic'
      Write-Log -Message 'Successfully enabled SNMP Service' -Level 'Information'
    }

    # Set Windows UI Language
    $xmlFile = @"
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
    <gs:UserList>
        <gs:User UserID="Current" CopySettingsToSystemAcct="true" CopySettingsToDefaultUserAcct="true"/>
    </gs:UserList>
    <gs:UserLocale>
        <gs:Locale Name="de-CH" SetAsCurrent="true"/>
    </gs:UserLocale>
    <gs:InputPreferences>
        <gs:InputLanguageID Action="add" ID="0807:00000807" Default="true"/>
    </gs:InputPreferences>
    <gs:MUILanguagePreferences>
        <gs:MUILanguage Value="de-CH"/>
        <gs:MUIFallback Value="en-US"/>
    </gs:MUILanguagePreferences>
    <gs:LocationPreferences>
        <gs:GeoID Value="223"/>
    </gs:LocationPreferences>
  <gs:SystemLocale Name="de-CH"/>
</gs:GlobalizationServices>
"@
    $xmlFileFilePath = Join-Path -Path $env:TEMP -ChildPath ((New-Guid).Guid + '.xml')

    # Create the XML file.
    Write-Log -Message 'Creating XML file' -Level 'Information'
    Set-Content -LiteralPath $xmlFileFilePath -Encoding UTF8 -Value $xmlFile
    Write-Log -Message 'Successfully created XML file' -Level 'Information'

    # Copy the current user language settings to the default user account and system user account.
    Write-Log -Message 'Setting current user language settings and copy to the default user account and system user account' -Level 'Information'
    $procStartInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo' -ArgumentList 'C:\Windows\System32\control.exe', ('intl.cpl,,/f:"{0}"' -f $xmlFileFilePath)
    $procStartInfo.UseShellExecute = $false
    $procStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
    $proc = [System.Diagnostics.Process]::Start($procStartInfo)
    $proc.WaitForExit()
    $proc.Dispose()
    Write-Log -Message 'Successfully set and copied current user language settings to the default user account and system user account' -Level 'Information'

    # Delete the XML file.
    Write-Log -Message 'Deleting XML file' -Level 'Information'
    Remove-Item -LiteralPath $xmlFileFilePath -Force
    Write-Log -Message 'Successfully deleted XML file' -Level 'Information'
    # Remove the NTUSER.DAT file from all user profiles.
    Write-Log -Message 'Removing NTUSER.DAT files from all user profiles' -Level 'Information'
    $ntuserDatFiles = Join-Path -Path $env:SystemDrive -ChildPath 'Users\*\NTUSER.DAT'
    foreach ($ntuserDatFilePath in (Get-ChildItem -LiteralPath $ntuserDatFiles -Force -ErrorAction SilentlyContinue -Recurse -File -ErrorAction SilentlyContinue).FullName) {
      Write-Log -Message "Removing NTUSER.DAT file from user profile '$ntuserDatFilePath'"
      Remove-Item -LiteralPath $ntuserDatFilePath -Force -ErrorAction SilentlyContinue
    }
    Write-Log -Message 'Successfully removed NTUSER.DAT files from all user profiles' -Level 'Information'

    # Create the DefaultSettings registry key.
    Write-Log -Message 'Creating DefaultSettings registry key' -Level 'Information'
    New-Item -Path 'HKLM:\Software\DefaultSettings' -Force
    Write-Log -Message 'Successfully created DefaultSettings registry key' -Level 'Information'
  }
}
catch {
  Write-Log -Message $_.Exception.Message -Level 'Error'
}
