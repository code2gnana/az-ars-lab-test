locals {
  # DC1 creates a new AD DS forest and integrated DNS.
  dc1_ad_promotion_script = <<-EOT
    $ErrorActionPreference = 'Stop'
    Install-WindowsFeature AD-Domain-Services,DNS -IncludeManagementTools
    Import-Module ActiveDirectory

    $domainName = '${var.spoke_a_ad_domain_name}'
    $netbiosName = '${var.spoke_a_ad_netbios_name}'
    $safeModePassword = ConvertTo-SecureString '${var.spoke_a_ad_dsrm_password}' -AsPlainText -Force

    $domainExists = $false
    try {
      $null = Get-ADDomain -Identity $domainName -ErrorAction Stop
      $domainExists = $true
    } catch {
      $domainExists = $false
    }

    if (-not $domainExists) {
      Install-ADDSForest `
        -DomainName $domainName `
        -DomainNetbiosName $netbiosName `
        -InstallDNS:$true `
        -SafeModeAdministratorPassword $safeModePassword `
        -NoRebootOnCompletion:$true `
        -Force:$true
    }

    shutdown /r /t 15 /f
  EOT

  # DC2 joins as an additional domain controller and enables AD replication.
  dc2_ad_promotion_script = <<-EOT
    $ErrorActionPreference = 'Stop'
    Install-WindowsFeature AD-Domain-Services,DNS -IncludeManagementTools
    Import-Module ActiveDirectory

    $domainName = '${var.spoke_a_ad_domain_name}'
    $domainAdminUser = '${var.spoke_test_vm_admin_username}@${var.spoke_a_ad_domain_name}'
    $domainAdminPassword = ConvertTo-SecureString '${random_password.spoke_a_dc_admin_password.result}' -AsPlainText -Force
    $domainCredential = New-Object System.Management.Automation.PSCredential($domainAdminUser, $domainAdminPassword)
    $safeModePassword = ConvertTo-SecureString '${var.spoke_a_ad_dsrm_password}' -AsPlainText -Force
    $primaryDcHost = 'spokeadc1.${var.spoke_a_ad_domain_name}'

    # Wait for DC1 DNS/LDAP/ADWS readiness before replica promotion.
    $maxAttempts = 60
    $attempt = 0
    while ($attempt -lt $maxAttempts) {
      try {
        $dnsOk = [bool](Resolve-DnsName -Name $primaryDcHost -Server 10.3.0.10 -ErrorAction Stop)
        $ldapOk = Test-NetConnection -ComputerName $primaryDcHost -Port 389 -InformationLevel Quiet
        $adwsOk = Test-NetConnection -ComputerName $primaryDcHost -Port 9389 -InformationLevel Quiet
        if ($dnsOk -and $ldapOk -and $adwsOk) {
          break
        }
      } catch {
        # DC1 services may not be fully ready yet.
      }
      Start-Sleep -Seconds 15
      $attempt++
    }

    if ($attempt -ge $maxAttempts) {
      throw "Timed out waiting for domain $domainName to become available from DC2."
    }

    Install-ADDSDomainController `
      -DomainName $domainName `
      -Credential $domainCredential `
      -ReplicationSourceDC $primaryDcHost `
      -SafeModeAdministratorPassword $safeModePassword `
      -InstallDNS:$true `
      -SkipPreChecks `
      -NoRebootOnCompletion:$true `
      -Force:$true

    shutdown /r /t 15 /f
  EOT
}

resource "azurerm_virtual_machine_extension" "spoke_a_dc1_promote" {
  name                       = "promote-dc1-ad-dns"
  virtual_machine_id         = azurerm_windows_virtual_machine.spoke_a_dc["dc1"].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  protected_settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -EncodedCommand ${textencodebase64(local.dc1_ad_promotion_script, "UTF-16LE")}"
  })
}

resource "azurerm_virtual_machine_extension" "spoke_a_dc2_promote" {
  name                       = "promote-dc2-ad-replica"
  virtual_machine_id         = azurerm_windows_virtual_machine.spoke_a_dc["dc2"].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  protected_settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -EncodedCommand ${textencodebase64(local.dc2_ad_promotion_script, "UTF-16LE")}"
  })

  depends_on = [
    azurerm_virtual_machine_extension.spoke_a_dc1_promote
  ]
}
