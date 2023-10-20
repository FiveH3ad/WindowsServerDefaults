# Define logging function
function Write-Log {
  param (
      [Parameter(Mandatory=$true)]
      [string]$Message,

      [Parameter(Mandatory=$false)]
      [string]$Path = "C:\DefaultVMSettings\logs.txt"
  )

  Add-Content -Path $Path -Value ("[" + (Get-Date) + "] " + $Message)
}

if(-not(test-path 'HKLM:\Software\DefaultSettings')){

  Set-WinSystemLocale 'de-CH'
  Set-TimeZone -id 'W. Europe Standard Time'
  Install-WindowsFeature -Name 'SNMP-Service' -IncludeAllSubFeature -IncludeManagementTools
  
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
  Set-Content -LiteralPath $xmlFileFilePath -Encoding UTF8 -Value $xmlFile
  
  # Copy the current user language settings to the default user account and system user account.
  $procStartInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo' -ArgumentList 'C:\Windows\System32\control.exe', ('intl.cpl,,/f:"{0}"' -f $xmlFileFilePath)
  $procStartInfo.UseShellExecute = $false
  $procStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
  $proc = [System.Diagnostics.Process]::Start($procStartInfo)
  $proc.WaitForExit()
  $proc.Dispose()
  
  # Delete the XML file.
  Remove-Item -LiteralPath $xmlFileFilePath -Force
  # Remove the NTUSER.DAT file from all user profiles.
  $ntuserDatFiles = Join-Path -Path $env:SystemDrive -ChildPath 'Users\*\NTUSER.DAT'
  foreach ($ntuserDatFilePath in (Get-ChildItem -LiteralPath $ntuserDatFiles -Force -ErrorAction SilentlyContinue -Recurse -File -ErrorAction SilentlyContinue).FullName) {
    Remove-Item -LiteralPath $ntuserDatFilePath -Force -ErrorAction SilentlyContinue
  }
  New-Item -Path 'HKLM:\Software\DefaultSettings' -Force
}
