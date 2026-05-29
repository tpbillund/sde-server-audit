# 🖥️ Get-MiljoRapport

> PowerShell-script til automatisk gennemgang og rapport af et Windows Server-miljø med Active Directory, DHCP, DNS, GPO, Shares og meget mere.

---

## 📋 Hvad gør scriptet?

Scriptet er designet til undervisningsbrug, hvor elever selv opsætter et servermiljø via vSphere med følgende komponenter:

- 2× Windows 11 klienter
- 1× Linux maskine
- 1× Windows Server 2022/2025

Når eleverne kører scriptet på deres Windows Server, genereres en komplet og overskuelig rapport over hele miljøet.

---

## 📦 Hvad rapporten indeholder

| Sektion | Indhold |
|---|---|
| 🖥️ **Systeminfo** | Computernavn, OS, RAM, disk, IP, gateway, DNS |
| 🏢 **Active Directory** | Domæneinfo, OU'er (med hierarki), brugere, grupper, GPO'er |
| 📡 **DHCP** | Scopes, ranges, optioner, reservationer, aktive leases |
| 🌐 **DNS** | Zoner, A/CNAME/MX/PTR/NS-poster |
| 📁 **Shares** | SMB-shares med NTFS- og SMB-rettigheder, Home Folders |
| 👤 **Lokale konti** | Lokale brugere og grupper med medlemmer |
| ⚙️ **Tjenester** | Status på AD, DNS, DHCP, Netlogon, filesharing m.fl. |
| 🔥 **Firewall** | Profiler og brugerdefinerede regler |
| 📶 **Netværksscanning** | Pinger hele subnettet og viser online hosts med hostname |

---

## 🚀 Sådan kører du scriptet

### Krav
- Windows Server 2022 eller 2025
- Køres som **Administrator**
- PowerShell 5.1 eller nyere (indbygget i Windows Server)

### Kør direkte fra GitHub (anbefalet)

Åbn PowerShell som Administrator og indsæt:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process -Force
iwr -useb https://raw.githubusercontent.com/tpbillund/sde-server-audit/main/Get-MiljoRapport.ps1 | iex
```

### Kør lokalt

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process -Force
.\Get-MiljoRapport.ps1
```

---

## 💬 Hvad sker der når scriptet kører?

1. Du bliver spurgt om dit **DHCP Scope IP** (fx `192.168.10.0`) – valgfrit
2. Du bliver spurgt om **Subnet Mask** (fx `255.255.255.0`) – valgfrit
3. Rapporten køres og udskrives i terminalen med farver og tydelig formatering
4. Til sidst kan du vælge at **gemme rapporten som .txt** på dit skrivebord

---

## 🖼️ Eksempel på output

```
############################################################
#  ACTIVE DIRECTORY
############################################################

  ── Organisationsenheder (OU) ──

  [OK]  OU'er fundet: 3
  ────────────────────────────────────────────────────────
        +-- Elever
              OU=Elever,DC=skole,DC=local
        +-- Laerere
              OU=Lærere,DC=skole,DC=local
            +-- Administration
                OU=Administration,OU=Lærere,DC=skole,DC=local

  ── AD Brugere ──

  [OK]  Brugere fundet: 5
  ────────────────────────────────────────────────────────
        [AKTIV] jsmith
                 Navn        : John Smith
                 Home Folder : \\SERVER01\Users\jsmith
                 Profile     : \\SERVER01\Profiles\jsmith
                 Grupper     : Elever, Domain Users
```

---

## ⚠️ Sikkerhed og ansvarsfraskrivelse

- Scriptet **ændrer intet** i dit miljø – det er udelukkende til læsning og rapportering.
- Scriptet kræver domæneadministratorrettigheder for at hente alle oplysninger.
- Brug kun scriptet i dit **eget lukkede testmiljø** – aldrig på produktionssystemer du ikke ejer.
- Rapporten kan indeholde følsomme oplysninger (brugernavne, IP-adresser, mappestrukturer). Del den kun med relevante parter.

---

## 🔧 Moduler scriptet bruger

Scriptet benytter følgende PowerShell-moduler, som alle er indbygget i Windows Server med de relevante roller installeret:

- `ActiveDirectory` – kræver RSAT/AD DS rollen
- `DhcpServer` – kræver DHCP Server rollen
- `DnsServer` – kræver DNS Server rollen
- `GroupPolicy` – kræver Group Policy Management
- `SmbShare` – indbygget i Windows Server

Mangler et modul, springer scriptet blot den pågældende sektion over og viser en advarsel.

---

## 🏫 Til underviseren

Scriptet er udviklet til brug i undervisning, hvor elever opsætter et komplet servermiljø fra bunden. Det kan bruges som:

- **Selvevaluering** – eleven kører scriptet og ser om alt er sat korrekt op
- **Aflevering** – rapporten gemmes som .txt og afleveres
- **Fejlfinding** – hurtig overblik over hvad der mangler eller er forkert konfigureret

---

## 📄 Licens

Dette projekt er udgivet under [MIT-licensen](LICENSE) – frit at bruge, kopiere og tilpasse.
