# Lijstjes

Versie 0.1

**Lijstjes** is een klein, snel programma voor to-do-lijstjes en notities,
geschreven in FreeBASIC (fblite-dialect). Het draait in een grafisch venster
en bewaart elk lijstje als een gewoon Markdown-bestand — dus ook prima te
lezen en te bewerken buiten het programma om.

De stijl is geïnspireerd op klassieke tekst-UI's zoals MS Edit. Er zijn twee 
panelen naast elkaar (lijstjes links, items rechts), volledig met het 
toetsenbord te bedienen.

## Kenmerken

- Meerdere lijstjes, elk met eigen kleur en eigen `.md`-bestand
- Items met een vinkje (afgevinkt / open) of gewone tekstregels zonder vinkje
- Inspringen tot 3 niveaus, voor subitems
- Verwijzingen tussen lijstjes met `[[Naam van lijstje]]`
- Zoeken door alle lijstjes heen
- Sorteren (open items boven, afgevinkte onderaan)
- Een lijstje "resetten" (alle vinkjes uit) met undo
- Grafisch venster met een zelf uitgelezen 8x16-font, opschaalbaar tot 6x,
  en met ASCII- of CP437-randen
- Venstergrootte en tekengrootte zijn aanpasbaar tijdens het draaien en
  worden onthouden in een instellingenbestand

## Bouwen

Vereist de FreeBASIC-compiler (`fbc`).

```
fbc lijstjes.bas
```

Dit levert een uitvoerbaar bestand `lijstjes` (of `lijstjes.exe` op Windows) op.

## Starten

```
lijstjes [map] [-zN] [-wBxH] [-a|-c]
```

| Optie      | Betekenis                                                                 |
|------------|----------------------------------------------------------------------------|
| `map`      | Map met `.md`-bestanden (standaard: `<exepad>/data`)                     |
| `-zN`      | Tekens N keer zo groot (1 t/m 6); anders de laatst gekozen schaal uit `lijstjes.cfg` |
| `-wBxH`    | Venster nooit groter dan B bij H pixels, bijvoorbeeld `-w640x480`          |
| `-a`       | ASCII-randen                                                              |
| `-c`       | CP437-randen (standaard)                                                  |

Tijdens het draaien kun je de tekengrootte aanpassen met `+` en `-` (of
F11/F12); de keuze wordt bewaard voor de volgende keer.

## Bestandsformaat

Elk lijstje is één Markdown-bestand in de gegevensmap:

```markdown
# Boodschappen
<!-- lijstjes kleur=14 -->
- [ ] Melk
- [x] Brood
  - [ ] volkoren
Gewone tekstregel zonder vinkje
```

- De eerste regel `# Titel` bepaalt de titel van het lijstje (anders wordt
  de bestandsnaam gebruikt).
- Een HTML-commentaarregel `<!-- lijstjes kleur=N -->` legt de kleur vast
  (1 t/m 15).
- `- [ ] tekst` is een open item, `- [x]` of `- [X]` een afgevinkt item.
- Elke 2 spaties of een tab vooraan is één inspringniveau (tot 3 niveaus).
- Een regel die niet met `- [ ]`, `- [x]` of `- `/`* ` begint, is een gewone
  tekstregel zonder vinkje.
- Verwijs naar een ander lijstje met `[[Naam van dat lijstje]]`; met de
  toets `g` spring je er direct naartoe.

Omdat het gewoon Markdown-bestanden zijn, kun je ze ook prima met een
andere editor bewerken — Lijstjes leest ze bij de volgende start gewoon weer in.

## Sneltoetsen

**Algemeen**

| Toets                | Werking                                              |
|-----------------------|-------------------------------------------------------|
| Tab                   | Wissel tussen lijsten- en itemspaneel                |
| F1                    | Hulpscherm                                            |
| F9 / Ctrl+F           | Zoeken in alle lijstjes                              |
| Ctrl+S                | Alles opslaan                                        |
| `+` / `-` (F12 / F11) | Tekens groter / kleiner (keuze blijft bewaard)       |
| Ctrl+Q                | Afsluiten (alles is al opgeslagen)                   |
| Esc / F10             | Afsluiten, met bevestiging vooraf                    |

**Lijstenpaneel (links)**

| Toets            | Werking                          |
|-------------------|-----------------------------------|
| Pijl op/neer      | Ander lijstje kiezen             |
| Enter / pijl rechts | Naar het itemspaneel            |
| F2                | Lijstje hernoemen                |
| `~`               | Kleur wisselen                   |
| F3 / F4 / Insert  | Nieuw lijstje                    |
| F5 / Delete       | Lijstje verwijderen              |

**Itemspaneel (rechts)**

| Toets              | Werking                                  |
|---------------------|--------------------------------------------|
| Spatie / Enter      | Item afvinken of vinkje weghalen          |
| F3 / Insert         | Nieuw item onder de cursor                |
| F2 / `e`            | Item bewerken                             |
| `t`                 | Wissel vinkje ↔ gewone tekstregel         |
| F5 / Delete         | Item verwijderen                          |
| `s`                 | Sorteren (afgevinkt onderaan)             |
| F6 / F7             | Item omhoog / omlaag verplaatsen          |
| `c`                 | Afgevinkte items wissen                   |
| Pijl links/rechts   | Minder / meer inspringen                  |
| `g`                 | Volg `[[verwijzing]]` naar ander lijstje  |
| Home/End/PgUp/PgDn  | Snel navigeren                            |

**Lijstje opnieuw gebruiken**

| Toets | Werking                                    |
|-------|----------------------------------------------|
| `r`   | Alle vinkjes van dit lijstje uitzetten       |
| `u`   | Die reset weer ongedaan maken                |

Dit hulpscherm is ook in het programma zelf te bekijken met **F1**.

## Grafisch venster

Lijstjes gebruikt altijd een grafisch venster (via de gfxlib-driver van
FreeBASIC), omdat die op alle platformen betrouwbaar functietoetsen afvangt
en een compleet CP437-font meelevert voor de lijntekens.

Het ingebouwde 8x16-font wordt bij het opstarten zelf
pixel voor pixel uitgelezen, zodat het ook vergroot getekend kan worden bij
een hogere schaalfactor (tot 6x). Past de gevraagde schaal niet op het
scherm (of binnen een `-w`-limiet), dan valt het programma automatisch terug
op de grootste schaal die wel past.

## Instellingen

De gekozen tekengrootte wordt bewaard in `lijstjes.cfg` in de gegevensmap,
en bij de volgende start weer toegepast (tenzij `-zN` die keuze overschrijft).

## Eerste keer starten

Als de gegevensmap geen lijstjes bevat, maakt Lijstjes automatisch twee
demo-lijstjes aan ("Welkom bij Lijstjes" en "Boodschappen") die de
belangrijkste functies laten zien, inclusief een voorbeeld van een
`[[verwijzing]]` naar een ander lijstje.
