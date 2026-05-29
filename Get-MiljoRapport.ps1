#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Miljoerapport-script til elev-servere (AD, DHCP, DNS, GPO, Shares m.m.)
.DESCRIPTION
    Koersel: iwr -useb https://raw.githubusercontent.com/tpbillund/sde-server-audit/main/Get-MiljoRapport.ps1 | iex
    Eller lokalt: .\Get-MiljoRapport.ps1
#>

# ===============================================================================
# OUTPUT-SYSTEM - skaerm MED farver, fil med REN tekst
# ===============================================================================

# Global buffer til ren tekst (bruges til .txt filen)
$script:RapportBuffer = [System.Collections.Generic.List[string]]::new()

function Out-Linje {
    # Skriver til BAaDE skaerm (med farve) og buffer (uden farve)
    param(
        [string]$Tekst,
        [string]$Farve = "White",
        [switch]$IngenBuffer   # brug kun til tom Write-Host spacing
    )
    Write-Host $Tekst -ForegroundColor $Farve
    if (-not $IngenBuffer) {
        $script:RapportBuffer.Add($Tekst)
    }
}

function Write-Header {
    param([string]$Titel)
    $linje = "#" * 62
    Out-Linje "" -IngenBuffer
    $script:RapportBuffer.Add("")
    Out-Linje $linje                          "Cyan"
    Out-Linje "#  $Titel"                     "White"
    Out-Linje $linje                          "Cyan"
}

function Write-SubHeader {
    param([string]$Titel)
    Out-Linje "" -IngenBuffer
    $script:RapportBuffer.Add("")
    Out-Linje "  -- $Titel --" "Yellow"
}

function Write-Ok {
    param([string]$Besked)
    Out-Linje "  [OK]  $Besked" "Green"
}

function Write-Advarsel {
    param([string]$Besked)
    Out-Linje "  [!]   $Besked" "Red"
}

function Write-Springer {
    param([string]$Besked)
    Out-Linje "  [-]   $Besked" "DarkGray"
}

function Write-Info {
    param([string]$Besked)
    Out-Linje "        $Besked" "Gray"
}

function Write-Item {
    param([string]$Label, [string]$Vaerdi)
    $pad = $Label.PadRight(25)
    Out-Linje "        $pad : $Vaerdi" "White"
}

function Write-Seperator {
    Out-Linje "  $("-" * 56)" "DarkGray"
}

function Write-LogonStatus {
    # Sidst logon - groen/gul paa skaerm, neutral i fil
    param([string]$Tekst, [bool]$AldrigLoggetPaa)
    $farve = if ($AldrigLoggetPaa) { "Yellow" } else { "Green" }
    Write-Host "         Sidst logon : $Tekst" -ForegroundColor $farve
    $script:RapportBuffer.Add("         Sidst logon : $Tekst")
}

function Write-TjenesteStatus {
    # Tjenestestatus - groen/roed paa skaerm, med tekst-markering i fil
    param([string]$Navn, [string]$Status, [bool]$Koerer)
    $farve  = if ($Koerer) { "Green" } else { "Red" }
    $marker = if ($Koerer) { "[OK]" } else { "[!] " }
    Write-Host "        $($Navn.PadRight(30)) $Status" -ForegroundColor $farve
    $script:RapportBuffer.Add("        $($Navn.PadRight(30)) $marker $Status")
}

# --- Kontroller moduler --------------------------------------------------------

function Test-Modul {
    param([string]$Navn)
    if (-not (Get-Module -ListAvailable -Name $Navn)) {
        Write-Springer "Modul '$Navn' ikke tilgaengeligt - springer over."
        return $false
    }
    Import-Module $Navn -ErrorAction SilentlyContinue
    return $true
}

# ===============================================================================
# SEKTIONER
# ===============================================================================

function Get-SystemInfo {
    Write-Header "SYSTEMINFO"

    $cs   = Get-CimInstance Win32_ComputerSystem
    $os   = Get-CimInstance Win32_OperatingSystem
    $net  = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled }
    $disk = Get-PSDrive C | Select-Object Used, Free

    Write-Item "Computernavn"   $cs.Name
    Write-Item "Domaene"         $cs.Domain
    Write-Item "OS"             $os.Caption
    Write-Item "OS Build"       $os.BuildNumber
    Write-Item "RAM (GB)"       ([math]::Round($cs.TotalPhysicalMemory / 1GB, 1))
    Write-Item "Disk C: Brugt"  "$([math]::Round($disk.Used / 1GB, 1)) GB"
    Write-Item "Disk C: Fri"    "$([math]::Round($disk.Free / 1GB, 1)) GB"

    foreach ($n in $net) {
        Write-Seperator
        Write-Item "Netvaerksadapter"  $n.Description
        Write-Item "IPv4 Adresse"     ($n.IPAddress -join ", ")
        Write-Item "Subnet Mask"      ($n.IPSubnet -join ", ")
        Write-Item "Gateway"          ($n.DefaultIPGateway -join ", ")
        Write-Item "DNS Servere"      ($n.DNSServerSearchOrder -join ", ")
    }
}

function Get-ADRapport {
    Write-Header "ACTIVE DIRECTORY"

    if (-not (Test-Modul "ActiveDirectory")) { return }

    try {
        $domain = Get-ADDomain -ErrorAction SilentlyContinue
        if ($domain) {
            Write-Item "Domaene FQDN"   $domain.DNSRoot
            Write-Item "NetBIOS Navn"  $domain.NetBIOSName
            Write-Item "Forest"        $domain.Forest
            Write-Item "PDC Emulator"  $domain.PDCEmulator
        }
    } catch {
        Write-Springer "Kunne ikke hente domaeneinfo."
    }

    # -- OU'er ------------------------------------------------------------------
    Write-SubHeader "Organisationsenheder (OU)"
    try {
        $OUs = @(Get-ADOrganizationalUnit -Filter * -Properties DistinguishedName `
                 -ErrorAction SilentlyContinue | Sort-Object DistinguishedName)

        if ($OUs.Count -eq 0) {
            Write-Springer "Ingen OU'er oprettet endnu."
        } else {
            Write-Ok "OU'er fundet: $($OUs.Count)"
            Write-Seperator
            foreach ($ou in $OUs) {
                $dybde  = ($ou.DistinguishedName -split "OU=").Count - 2
                $indryk = "  " * $dybde
                $navn   = ($ou.DistinguishedName -split ",")[0] -replace "OU=", ""
                Out-Linje "        $indryk+-- $navn" "White"
                Write-Info "$indryk    $($ou.DistinguishedName)"
            }
        }
    } catch {
        Write-Springer "Ingen OU'er fundet eller AD ikke tilgaengeligt."
    }

    # -- Brugere ----------------------------------------------------------------
    Write-SubHeader "AD Brugere"
    try {
        $brugere = @(Get-ADUser -Filter * -Properties DisplayName, EmailAddress,
                      HomeDirectory, ProfilePath, ScriptPath, Enabled,
                      DistinguishedName, MemberOf, PasswordNeverExpires,
                      LastLogonDate, Created -ErrorAction SilentlyContinue |
                     Sort-Object SamAccountName)

        if ($brugere.Count -eq 0) {
            Write-Springer "Ingen brugere oprettet endnu."
        } else {
            Write-Ok "Brugere fundet: $($brugere.Count)"
            Write-Seperator

            foreach ($b in $brugere) {
                $statusTekst = if ($b.Enabled) { "[AKTIV]  " } else { "[DEAKTIV]" }
                $statusFarve = if ($b.Enabled) { "White" } else { "DarkGray" }
                Out-Linje "        $statusTekst $($b.SamAccountName)" $statusFarve

                if ($b.DisplayName)  { Write-Info "         Navn        : $($b.DisplayName)" }
                if ($b.EmailAddress) { Write-Info "         Email       : $($b.EmailAddress)" }
                if ($b.Created)      { Write-Info "         Oprettet    : $($b.Created.ToString('dd-MM-yyyy HH:mm'))" }

                # Sidst logget paa
                if ($b.LastLogonDate) {
                    $dagesiden  = (New-TimeSpan -Start $b.LastLogonDate -End (Get-Date)).Days
                    $logonTekst = "$($b.LastLogonDate.ToString('dd-MM-yyyy HH:mm'))  ($dagesiden dag(e) siden)"
                    Write-LogonStatus -Tekst $logonTekst -AldrigLoggetPaa $false
                } else {
                    Write-LogonStatus -Tekst "Aldrig logget paa" -AldrigLoggetPaa $true
                }

                if ($b.HomeDirectory)        { Write-Info "         Home Folder : $($b.HomeDirectory)" }
                if ($b.ProfilePath)          { Write-Info "         Profile     : $($b.ProfilePath)" }
                if ($b.ScriptPath)           { Write-Info "         Logon Script: $($b.ScriptPath)" }
                if ($b.PasswordNeverExpires) { Write-Info "         Kode udloeber: Aldrig" }

                $grupper = ($b.MemberOf | ForEach-Object {
                    ($_ -split ",")[0] -replace "CN=", ""
                }) -join ", "
                if ($grupper) { Write-Info "         Grupper     : $grupper" }

                Write-Seperator
            }
        }
    } catch {
        Write-Springer "Ingen brugere fundet eller AD ikke tilgaengeligt."
    }

    # -- Grupper ----------------------------------------------------------------
    Write-SubHeader "AD Grupper (oprettede)"
    try {
        $grupper = @(Get-ADGroup -Filter * -Properties Members, Description `
                     -ErrorAction SilentlyContinue |
                    Where-Object {
                        $_.DistinguishedName -notlike "*CN=Builtin*" -and
                        $_.DistinguishedName -notlike "*CN=Users*"
                    } | Sort-Object Name)

        if ($grupper.Count -eq 0) {
            Write-Springer "Ingen brugerdefinerede grupper oprettet endnu."
        } else {
            Write-Ok "Grupper fundet: $($grupper.Count)"
            Write-Seperator
            foreach ($g in $grupper) {
                $antal = ($g.Members | Measure-Object).Count
                Out-Linje "        $($g.Name)  [$($g.GroupCategory) / $($g.GroupScope)]  - $antal medlem(mer)" "White"
                if ($g.Description) { Write-Info "         Beskrivelse: $($g.Description)" }
                if ($g.Members.Count -gt 0) {
                    $navne = $g.Members | ForEach-Object { ($_ -split ",")[0] -replace "CN=", "" }
                    Write-Info "         Medlemmer  : $($navne -join ', ')"
                }
            }
        }
    } catch {
        Write-Springer "Ingen grupper fundet eller AD ikke tilgaengeligt."
    }

    # -- GPO'er -----------------------------------------------------------------
    Write-SubHeader "Group Policy Objects (GPO)"
    try {
        if (-not (Get-Module -ListAvailable -Name GroupPolicy)) {
            Write-Springer "GroupPolicy-modul ikke installeret - GPO'er springes over."
            return
        }
        Import-Module GroupPolicy -ErrorAction SilentlyContinue
        $gpos = @(Get-GPO -All -ErrorAction SilentlyContinue)

        if ($gpos.Count -eq 0) {
            Write-Springer "Ingen GPO'er oprettet endnu."
        } else {
            Write-Ok "GPO'er fundet: $($gpos.Count)"
            Write-Seperator
            foreach ($gpo in $gpos | Sort-Object DisplayName) {
                Out-Linje "        $($gpo.DisplayName)" "White"
                Write-Info "         ID       : $($gpo.Id)"
                Write-Info "         Status   : $($gpo.GpoStatus)"
                Write-Info "         Aendret  : $($gpo.ModificationTime.ToString('yyyy-MM-dd HH:mm'))"
                try {
                    $xml = Get-GPOReport -Guid $gpo.Id -ReportType XML -ErrorAction SilentlyContinue
                    if ($xml) {
                        $matches = [regex]::Matches($xml, 'SOMPath="([^"]+)"')
                        foreach ($m in $matches) {
                            Write-Info "         Linket til: $($m.Groups[1].Value)"
                        }
                    }
                } catch { }
            }
        }
    } catch {
        Write-Springer "Kunne ikke hente GPO-information."
    }
}

function Get-DHCPRapport {
    Write-Header "DHCP SERVER"

    if (-not (Test-Modul "DhcpServer")) { return }

    try {
        $scopes = @(Get-DhcpServerv4Scope -ErrorAction SilentlyContinue)

        if ($scopes.Count -eq 0) {
            Write-Springer "Ingen DHCP-scopes oprettet endnu."
            return
        }

        Write-Ok "Scopes fundet: $($scopes.Count)"
        Write-Seperator

        foreach ($scope in $scopes) {
            Out-Linje "        Scope: $($scope.Name)" "White"
            Write-Item "Scope ID"        $scope.ScopeId
            Write-Item "Subnet Mask"     $scope.SubnetMask
            Write-Item "Start IP"        $scope.StartRange
            Write-Item "Slut IP"         $scope.EndRange
            Write-Item "Lease Duration"  $scope.LeaseDuration
            Write-Item "Status"          $scope.State

            try {
                $stats = Get-DhcpServerv4ScopeStatistics -ScopeId $scope.ScopeId -ErrorAction SilentlyContinue
                if ($stats) {
                    Write-Item "Ledige adresser"  $stats.Free
                    Write-Item "I brug"            $stats.InUse
                    Write-Item "Reserverede"       $stats.Reserved
                }
            } catch { }

            Write-SubHeader "  DHCP Optioner (Scope: $($scope.Name))"
            try {
                $opts = @(Get-DhcpServerv4OptionValue -ScopeId $scope.ScopeId -ErrorAction SilentlyContinue)
                if ($opts.Count -eq 0) {
                    Write-Info "  Ingen scope-optioner konfigureret"
                } else {
                    foreach ($opt in $opts) {
                        Write-Info "  Option $($opt.OptionId.ToString().PadLeft(3)): $($opt.Name.PadRight(20)) = $($opt.Value -join ', ')"
                    }
                }
            } catch { Write-Info "  Ingen scope-optioner fundet" }

            Write-SubHeader "  DHCP Reservationer (Scope: $($scope.Name))"
            try {
                $res = @(Get-DhcpServerv4Reservation -ScopeId $scope.ScopeId -ErrorAction SilentlyContinue)
                if ($res.Count -eq 0) {
                    Write-Info "  Ingen reservationer oprettet"
                } else {
                    foreach ($r in $res) {
                        Write-Info "  $($r.IPAddress.ToString().PadRight(18)) MAC: $($r.ClientId.PadRight(20)) - $($r.Name)"
                    }
                }
            } catch { Write-Info "  Ingen reservationer" }

            Write-SubHeader "  Aktive leases (Scope: $($scope.Name))"
            try {
                $leases = @(Get-DhcpServerv4Lease -ScopeId $scope.ScopeId -ErrorAction SilentlyContinue |
                            Where-Object { $_.AddressState -eq "Active" })
                Write-Info "  Aktive leases: $($leases.Count)"
                foreach ($l in $leases | Sort-Object IPAddress) {
                    Write-Info "  $($l.IPAddress.ToString().PadRight(18)) $($l.HostName.PadRight(25)) $($l.ClientId)"
                }
            } catch { Write-Info "  Kunne ikke hente leases" }

            Write-Seperator
        }

        Write-SubHeader "Globale DHCP Server Optioner"
        try {
            $globalOpts = @(Get-DhcpServerv4OptionValue -ErrorAction SilentlyContinue)
            if ($globalOpts.Count -eq 0) {
                Write-Info "Ingen globale optioner konfigureret"
            } else {
                foreach ($opt in $globalOpts) {
                    Write-Info "Option $($opt.OptionId.ToString().PadLeft(3)): $($opt.Name.PadRight(20)) = $($opt.Value -join ', ')"
                }
            }
        } catch { Write-Info "Ingen globale optioner" }

    } catch {
        Write-Springer "DHCP-rolle ikke installeret eller ingen scopes oprettet."
    }
}

function Get-DNSRapport {
    Write-Header "DNS SERVER"

    if (-not (Test-Modul "DnsServer")) { return }

    try {
        $zoner = @(Get-DnsServerZone -ErrorAction SilentlyContinue |
                   Where-Object { -not $_.IsAutoCreated })

        if ($zoner.Count -eq 0) {
            Write-Springer "Ingen DNS-zoner oprettet endnu."
            return
        }

        Write-Ok "DNS Zoner fundet: $($zoner.Count)"
        Write-Seperator

        foreach ($zone in $zoner) {
            Out-Linje "        Zone: $($zone.ZoneName)" "White"
            Write-Item "Type"         $zone.ZoneType
            Write-Item "Dynamisk"     $zone.DynamicUpdate
            Write-Item "Replication"  $zone.ReplicationScope

            try {
                $poster = @(Get-DnsServerResourceRecord -ZoneName $zone.ZoneName -ErrorAction SilentlyContinue |
                            Where-Object { $_.RecordType -in @("A","AAAA","CNAME","MX","PTR","NS","SRV") } |
                            Sort-Object RecordType, HostName)

                if ($poster.Count -eq 0) {
                    Write-Info "  Ingen poster fundet"
                } else {
                    $typer = $poster | Group-Object RecordType
                    foreach ($type in $typer) {
                        Write-Info "  $($type.Name) poster ($($type.Count)):"
                        foreach ($post in $type.Group) {
                            $data = switch ($post.RecordType) {
                                "A"     { $post.RecordData.IPv4Address }
                                "AAAA"  { $post.RecordData.IPv6Address }
                                "CNAME" { $post.RecordData.HostNameAlias }
                                "MX"    { $post.RecordData.MailExchange }
                                "PTR"   { $post.RecordData.PtrDomainName }
                                "NS"    { $post.RecordData.NameServer }
                                default { "-" }
                            }
                            Write-Info "    $($post.HostName.PadRight(30)) ->  $data"
                        }
                    }
                }
            } catch { }
            Write-Seperator
        }
    } catch {
        Write-Springer "DNS-rolle ikke installeret eller ingen zoner fundet."
    }
}

function Get-SharesRapport {
    Write-Header "DELTE MAPPER (SHARES)"

    Write-SubHeader "Windows SMB Shares"
    try {
        $shares = @(Get-SmbShare -ErrorAction SilentlyContinue |
                    Where-Object {
                        $_.Name -notlike "*$" -and
                        $_.Name -ne "NETLOGON" -and
                        $_.Name -ne "SYSVOL"
                    })

        if ($shares.Count -eq 0) {
            Write-Springer "Ingen shares oprettet endnu (ekskl. admin-shares)."
        } else {
            Write-Ok "Shares fundet: $($shares.Count)"
            Write-Seperator
            foreach ($share in $shares) {
                Out-Linje "        [$($share.Name)]" "White"
                Write-Item "Sti"          $share.Path
                Write-Item "Beskrivelse"  $share.Description

                try {
                    $access = @(Get-SmbShareAccess -Name $share.Name -ErrorAction SilentlyContinue)
                    foreach ($a in $access) {
                        Write-Info "  SMB Ret: $($a.AccountName.PadRight(30)) $($a.AccessControlType.ToString().PadRight(6)) $($a.AccessRight)"
                    }
                } catch { }

                try {
                    if (Test-Path $share.Path) {
                        $acl = Get-Acl $share.Path -ErrorAction SilentlyContinue
                        foreach ($ace in $acl.Access | Where-Object { -not $_.IsInherited }) {
                            Write-Info "  NTFS:    $($ace.IdentityReference.ToString().PadRight(35)) $($ace.FileSystemRights) [$($ace.AccessControlType)]"
                        }
                    }
                } catch { }

                Write-Seperator
            }
        }
    } catch {
        Write-Springer "Kunne ikke hente SMB-shares."
    }

    Write-SubHeader "Bruger Home Folders (AD)"
    try {
        if (Get-Module -ListAvailable -Name ActiveDirectory) {
            $brugere = @(Get-ADUser -Filter { HomeDirectory -like "*" } `
                         -Properties HomeDirectory, HomeDrive -ErrorAction SilentlyContinue)
            if ($brugere.Count -eq 0) {
                Write-Springer "Ingen brugere har Home Folder sat endnu."
            } else {
                foreach ($b in $brugere) {
                    Write-Info "$($b.SamAccountName.PadRight(20)) $($b.HomeDrive)  ->  $($b.HomeDirectory)"
                }
            }
        }
    } catch {
        Write-Springer "Kunne ikke hente Home Folder info fra AD."
    }
}

function Get-LokaleKonti {
    Write-Header "LOKALE KONTI"

    try {
        $lokBrugere = @(Get-LocalUser -ErrorAction SilentlyContinue | Sort-Object Name)
        if ($lokBrugere.Count -eq 0) {
            Write-Springer "Ingen lokale brugere fundet."
        } else {
            Write-Ok "Lokale brugere: $($lokBrugere.Count)"
            Write-Seperator
            foreach ($lu in $lokBrugere) {
                $statusTekst = if ($lu.Enabled) { "[AKTIV]  " } else { "[DEAKTIV]" }
                $statusFarve = if ($lu.Enabled) { "White" } else { "DarkGray" }
                $sidstLogon  = if ($lu.LastLogon) {
                    $lu.LastLogon.ToString('dd-MM-yyyy HH:mm')
                } else { "Aldrig" }
                Out-Linje "        $statusTekst $($lu.Name.PadRight(25)) Sidst logon: $sidstLogon" $statusFarve
            }
        }
    } catch {
        Write-Springer "Kunne ikke hente lokale brugere."
    }

    try {
        Write-SubHeader "Lokale Grupper"
        $lokGrupper = @(Get-LocalGroup -ErrorAction SilentlyContinue | Sort-Object Name)
        foreach ($lg in $lokGrupper) {
            $members = try {
                (Get-LocalGroupMember $lg.Name -ErrorAction SilentlyContinue |
                 Select-Object -ExpandProperty Name) -join ", "
            } catch { "-" }
            Write-Info "$($lg.Name.PadRight(30)) <- $members"
        }
    } catch {
        Write-Springer "Kunne ikke hente lokale grupper."
    }
}

function Get-TjenesterRapport {
    Write-Header "RELEVANTE WINDOWS-TJENESTER"

    $tjenester = @(
        @{ Navn = "NTDS";              Vis = "Active Directory DS"   },
        @{ Navn = "DNS";               Vis = "DNS Server"            },
        @{ Navn = "DHCPServer";        Vis = "DHCP Server"           },
        @{ Navn = "Netlogon";          Vis = "Netlogon"              },
        @{ Navn = "W32Time";           Vis = "Windows Time"          },
        @{ Navn = "RpcSs";             Vis = "RPC"                   },
        @{ Navn = "LanmanServer";      Vis = "Server (Filesharing)"  },
        @{ Navn = "LanmanWorkstation"; Vis = "Workstation"           },
        @{ Navn = "wuauserv";          Vis = "Windows Update"        }
    )

    Write-Seperator
    foreach ($t in $tjenester) {
        try {
            $svc = Get-Service -Name $t.Navn -ErrorAction SilentlyContinue
            if ($svc) {
                $koerer = ($svc.Status -eq "Running")
                Write-TjenesteStatus -Navn $t.Vis -Status $svc.Status.ToString() -Korer $koerer
            } else {
                # Ikke installeret - neutral graa paa skaerm, tydelig i fil
                Write-Host "        $($t.Vis.PadRight(30)) Ikke installeret" -ForegroundColor DarkGray
                $script:RapportBuffer.Add("        $($t.Vis.PadRight(30)) [-]  Ikke installeret")
            }
        } catch { }
    }
}

function Get-FirewallRapport {
    Write-Header "FIREWALL STATUS"

    try {
        $profiles = @(Get-NetFirewallProfile -ErrorAction SilentlyContinue)
        foreach ($p in $profiles) {
            $farve  = if ($p.Enabled) { "Green" } else { "Red" }
            $marker = if ($p.Enabled) { "[OK]" } else { "[!] " }
            $status = if ($p.Enabled) { "AKTIV" } else { "DEAKTIVERET" }
            Write-Host "        $($p.Name.PadRight(15)) $status" -ForegroundColor $farve
            $script:RapportBuffer.Add("        $($p.Name.PadRight(15)) $marker $status")
        }

        Write-SubHeader "Brugerdefinerede indgaaende regler"
        $regler = @(Get-NetFirewallRule -ErrorAction SilentlyContinue |
                    Where-Object {
                        $_.Direction -eq "Inbound" -and
                        $_.Enabled -eq "True" -and
                        $_.DisplayGroup -eq ""
                    } | Sort-Object DisplayName)

        if ($regler.Count -eq 0) {
            Write-Springer "Ingen brugerdefinerede indgaaende regler fundet"
        } else {
            foreach ($r in $regler) { Write-Info $r.DisplayName }
        }
    } catch {
        Write-Springer "Kunne ikke hente firewall-info."
    }
}

function Get-NetvaerksPing {
    param([string]$Scope, [string]$SubnetMask)
    if (-not $Scope) { return }

    Write-Header "NETVAERKSSCANNING (PING)"

    try {
        $scopeParts = $Scope -split "\."
        $maskParts  = $SubnetMask -split "\."
        $netParts   = for ($i = 0; $i -lt 4; $i++) {
            [int]$scopeParts[$i] -band [int]$maskParts[$i]
        }

        Write-Info "Scanner netvaerk: $($netParts -join '.') / $SubnetMask"
        Write-Info "Dette kan tage op til et minut..."
        Write-Seperator

        $hostsOnline = @()
        1..254 | ForEach-Object {
            $ip = "$($netParts[0]).$($netParts[1]).$($netParts[2]).$_"
            if (Test-Connection -ComputerName $ip -Count 1 -Quiet -TimeoutSeconds 1) {
                $hostnavn = try { [System.Net.Dns]::GetHostEntry($ip).HostName } catch { "-" }
                $hostsOnline += [PSCustomObject]@{ IP = $ip; Navn = $hostnavn }
            }
        }

        Write-Ok "Online hosts: $($hostsOnline.Count)"
        foreach ($h in $hostsOnline | Sort-Object { [System.Version]$_.IP }) {
            Write-Info "$($h.IP.PadRight(18)) $($h.Navn)"
        }
    } catch {
        Write-Springer "Fejl under netvaerksscanning."
    }
}

# --- Filnavn efter domaene FQDN ------------------------------------------------

function Get-DomainFQDN {
    try {
        if (Get-Module -ListAvailable -Name ActiveDirectory) {
            Import-Module ActiveDirectory -ErrorAction SilentlyContinue
            $fqdn = (Get-ADDomain -ErrorAction SilentlyContinue).DNSRoot
            if ($fqdn) { return $fqdn }
        }
    } catch { }
    return $env:COMPUTERNAME
}

function Gem-Rapport {
    $fqdn    = Get-DomainFQDN
    $sikkert = $fqdn -replace '[\\/:*?"<>|]', '_'
    $filnavn = "${sikkert}_ServerRapport.txt"
    $sti     = "$env:USERPROFILE\Desktop\$filnavn"

    try {
        $script:RapportBuffer | Out-File -FilePath $sti -Encoding UTF8
        Write-Host ""
        Write-Host "  Rapport gemt: $sti" -ForegroundColor Green
        $script:RapportBuffer.Add("")
        $script:RapportBuffer.Add("Rapport gemt: $sti")
    } catch {
        Write-Advarsel "Kunne ikke gemme rapport: $_"
    }
}

# ===============================================================================
# HOVED
# ===============================================================================

Clear-Host

$velkomstLinjer = @(
    "",
    "  ##################################################",
    "  #                                                #",
    "  #       MILJO-RAPPORT  -  ELEV SERVER            #",
    "  #     Syddansk Erhvervsskole Vejle               #",
    "  #              IT & Data                         #",
    "  #                                                #",
    "  ##################################################",
    "",
    "  Dato  : $(Get-Date -Format 'dd-MM-yyyy HH:mm')",
    "  Server: $env:COMPUTERNAME",
    ""
)

foreach ($l in $velkomstLinjer) {
    Write-Host $l -ForegroundColor Cyan
    $script:RapportBuffer.Add($l)
}

$useScope = Read-Host "  Angiv dit DHCP Scope IP (fx 192.168.10.0) [Enter for at springe over]"
$useMask  = ""
if ($useScope) {
    $useMask = Read-Host "  Angiv Subnet Mask (fx 255.255.255.0)"
}

# Koer alle sektioner
Get-SystemInfo
Get-ADRapport
Get-DHCPRapport
Get-DNSRapport
Get-SharesRapport
Get-LokaleKonti
Get-TjenesterRapport
Get-FirewallRapport
if ($useScope) {
    Get-NetvaerksPing -Scope $useScope -SubnetMask $useMask
}

$slutLinjer = @(
    "",
    "  ##################################################",
    "  #           RAPPORT AFSLUTTET                   #",
    "  ##################################################",
    ""
)
foreach ($l in $slutLinjer) {
    Write-Host $l -ForegroundColor Cyan
    $script:RapportBuffer.Add($l)
}

$gem = Read-Host "  Vil du gemme rapporten som .txt fil paa skrivebordet? (J/N)"
if ($gem -match "^[JjYy]") {
    Gem-Rapport
}
