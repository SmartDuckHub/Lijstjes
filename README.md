# Lijstjes

Lijstjes en notities in een grafisch venster, in de stijl van de Turbo Pascal
editor. Geschreven in FreeBASIC (`fblite`-dialect), met de gfxlib-driver van
FreeBASIC en een CP437-font, zodat het er op elk platform hetzelfde uitziet.

Elk lijstje is een los Markdown-bestand. Je kunt ze dus ook buiten Lijstjes
lezen en bewerken.

## Compileren

```
fbc -lang fblite lijstjes.bas
```

In Geany kun je als compileercommando `fbc -lang fblite "%f"` gebruiken.

## Starten

```
lijstjes [map] [-zN] [-wBxH] [-a|-c]
```

| Optie   | Betekenis |
|---------|-----------|
| `map`   | Map met `.md`-bestanden. Standaard: je eigen gegevensmap, zie "Waar staan mijn gegevens?". |
| `-zN`   | Tekens N keer zo groot (1 t/m 6). Zonder deze optie geldt de laatst gekozen schaal uit `lijstjes.cfg`. |
| `-wBxH` | Venster nooit groter dan B bij H pixels, bijvoorbeeld `-w640x480`. |
| `-a`    | ASCII-randen. |
| `-c`    | CP437-randen (standaard). |

## Waar staan mijn gegevens?

Elke gebruiker heeft zijn eigen lijstjes, ook op een computer die door meer
mensen wordt gebruikt. De map wordt bij de eerste start automatisch aangemaakt,
inclusief de tussenmap `MarcelsOffice`.

| Systeem | Gegevensmap |
|---------|-------------|
| Windows | `%APPDATA%\MarcelsOffice\Lijstjes`, bijvoorbeeld `C:\Users\<naam>\AppData\Roaming\MarcelsOffice\Lijstjes` |
| Linux   | `$XDG_DATA_HOME/MarcelsOffice/Lijstjes`; is die niet gezet, dan `~/.local/share/MarcelsOffice/Lijstjes` |

Wat Windows of Linux is, wordt bij het compileren bepaald en niet tijdens het
draaien. Daardoor kiest een Windows-versie onder Wine ook de Windows-map.

In die map staan de lijstjes (`.md`) en `lijstjes.cfg`. Is de basismap niet te
bepalen (`APPDATA` of `HOME` ontbreekt), dan gebruikt het programma de map
`data` naast het programma. Met `lijstjes <map>` kies je zelf een andere map.

Het vertaalbestand `lijstjes_taal_en.txt` blijft naast het programma staan en
wordt alleen gelezen.

## Bediening

Druk in het programma op **F1** voor het hulpscherm. De belangrijkste toetsen:

**Algemeen**

| Toets | Actie |
|-------|-------|
| Tab | Wisselen tussen lijstjes- en itemspaneel |
| F1 | Hulp |
| F9 / Ctrl+F | Zoeken in alle lijstjes |
| Ctrl+S | Alles opslaan |
| Ctrl+N | Tekengrootte wisselen (zie hieronder) |
| Ctrl+Z | Over Lijstjes: versie, auteur, licentie en huidige instellingen |
| Ctrl+Q / F10 | Afsluiten (alles is dan al opgeslagen) |
| Esc | Afsluiten, met bevestiging vooraf |

F10 is op Windows een systeemtoets; gebruik daar Ctrl+Q.

**Lijstjespaneel (links)**

| Toets | Actie |
|-------|-------|
| Pijl op/neer | Ander lijstje kiezen |
| Enter / pijl rechts | Naar het itemspaneel |
| F2 | Lijstje hernoemen |
| `~` | Kleur wisselen |
| F3 / F4 | Nieuw lijstje |
| F5 / Del | Lijstje verwijderen |

**Itemspaneel (rechts)**

| Toets | Actie |
|-------|-------|
| Spatie / Enter | Afvinken of vinkje weghalen |
| F3 / Insert | Nieuw item onder de cursor |
| F2 | Item bewerken |
| F5 / Del | Item verwijderen |
| F6 / F7 | Item omhoog / omlaag |
| Pijl links/rechts | Minder / meer inspringen |
| `t` | Vinkje omzetten naar gewone tekst en terug |
| `s` | Sorteren (afgevinkte items onderaan) |
| `c` | Afgevinkte items wissen |
| `g` | Verwijzing `[[Lijstje]]` volgen |

**Een lijstje opnieuw gebruiken**

| Toets | Actie |
|-------|-------|
| `r` | Alle vinkjes van dit lijstje uitzetten |
| `u` | Die reset ongedaan maken |

### Tekengrootte (Ctrl+N)

Ctrl+N loopt de schaal rond: 1x, 2x, ... tot 6x en dan weer 1x. Past een
schaal niet op het bureaublad met de volledige indeling van 80 x 30 tekens,
dan gaat het programma meteen terug naar 1x. De laatst gekozen schaal wordt
bewaard in `lijstjes.cfg`.

Met een vaste vensterlimiet (`-wBxH`) krimpt het aantal tekencellen mee
zolang er minimaal 38 x 12 passen. Past zelfs dat niet, dan volgt weer 1x.

## Bestandsformaat

Een lijstje is een Markdown-bestand met een titel, een kleurregel en de items:

```markdown
# Boodschappen
<!-- lijstjes kleur=14 -->
- [ ] Melk
- [x] Brood
  - [ ] volkoren
Gewone tekstregel zonder vinkje
```

Een regel `[[Boodschappen]]` in een item verwijst naar het lijstje met die
titel; met `g` spring je erheen. Er passen maximaal 64 lijstjes in het
programma en 400 regels per lijstje.

## Taal

Lijstjes volgt de taal van het besturingssysteem (`LC_ALL`, `LC_MESSAGES`,
`LANG`, `LANGUAGE`). Nederlands is de brontaal; in alle andere gevallen
gebruikt het programma Engels. De Engelse teksten staan in
`lijstjes_taal_en.txt`, dat naast het programma moet staan.

Wil je een taal afdwingen, zet dan in `lijstjes.cfg` (in de gegevensmap) een
van deze regels:

```
taal=auto
taal=nl
taal=en
```

### Een vertaling toevoegen

Maak een bestand `lijstjes_taal_<code>.txt` (bijvoorbeeld `lijstjes_taal_de.txt`)
naast het programma, met per regel:

```
<Nederlandse brontekst> => <vertaling>
```

Regels die met `'` beginnen of leeg zijn, worden genegeerd. In teksten met
`%1`, `%2`, `%3` komen de waarden op die plek terecht; de volgorde mag per taal
verschillen. Een tekst zonder vertaling blijft Nederlands. Zet daarna
`taal=<code>` in `lijstjes.cfg`, of laat het programma de taal herkennen aan
de OS-instelling (alleen `nl` en `en` worden automatisch herkend).

Er worden maximaal 200 vertaalregels ingelezen.

## Instellingen

`lijstjes.cfg` staat in je eigen gegevensmap, dus elke gebruiker heeft eigen
instellingen, en mag met de hand worden aangepast:

```
schaal=1
taal=auto
```

## Licentie

BSD 3-Clause. Copyright 2026 Marcel "SmartDuck" Beekman.
