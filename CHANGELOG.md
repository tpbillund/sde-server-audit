# Changelog

Alle væsentlige ændringer til dette projekt dokumenteres her.

Format følger [Keep a Changelog](https://keepachangelog.com/da/1.0.0/).

---

## [1.1.0] – 2025

### Tilføjet
- `LastLogonDate` på alle AD-brugere – vises med dato og antal dage siden, eller "Aldrig logget paa"
- Sidst logon på lokale konti

### Rettet
- Txt-fil indeholder nu ren tekst uden farvekoder – scriptet bruger en parallel tekstbuffer
- Statusmarkører i txt-filen: `[OK]`, `[!]`, `[-]` erstatter farveindikationer
- Filnavn på rapport bruger nu domænets FQDN (fx `G3TBP.local_ServerRapport.txt`)
- Manglende GPO'er, OU'er, shares m.m. viser nu neutral grå `[-]` besked i stedet for rød fejl
- Specielle Unicode-tegn (`├─`, `➜`, `✓`) erstattet med ASCII-alternativer for bred kompatibilitet

---

## [1.0.0] – 2025

### Tilføjet
- Systeminfo: OS, RAM, disk, netværksadaptere
- Active Directory: domæneinfo, OU-hierarki, brugere med Home Folder/Profile Path, grupper, GPO'er med links
- DHCP: scopes, ranges, lease-statistik, optioner, reservationer, aktive leases
- DNS: zoner og poster (A, AAAA, CNAME, MX, PTR, NS)
- SMB Shares med NTFS- og SMB-rettigheder
- Home Folder oversigt fra AD
- Lokale brugere og grupper
- Tjenestestatus (AD, DNS, DHCP, Netlogon m.fl.)
- Firewall-profiler og brugerdefinerede regler
- Netværksscanning (ping-sweep med hostname-opslag)
- Gem rapport som .txt på skrivebordet
- Dansk sprog i hele scriptet
