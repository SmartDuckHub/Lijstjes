# Changelog

Alle noemenswaardige wijzigingen in Lijstjes staan in dit bestand.

## [1.0]

### Toegevoegd
- Vertaling: alle teksten in het programma lopen via `Vt()` en `Tn()`, op
  dezelfde manier als in Kalender. Nederlands is de brontaal, Engels staat in
  `lijstjes_taal_en.txt`.
- De taal wordt herkend aan de OS-instelling (`LC_ALL`, `LC_MESSAGES`, `LANG`,
  `LANGUAGE`), met Engels als terugvaltaal.
- `lijstjes.cfg` kent nu ook `taal=auto|nl|en`, naast `schaal=`.
- Ctrl+N loopt de tekengrootte rond (1x tot 6x en dan weer 1x). Past een schaal
  niet op het bureaublad met de volledige indeling van 80 x 30 tekens, dan
  gaat het programma meteen terug naar 1x.

- Over-pagina op Ctrl+Z, zoals in Rekenblad: naam en versie, auteur, licentie,
  gegevensmap, aantal lijstjes en regels, actieve taal en schaal. Elke toets
  sluit hem weer. Staat ook in het F1-hulpscherm en is vertaald.

### Gewijzigd
- F11, F12, `+` en `-` voor de tekengrootte zijn vervangen door Ctrl+N.
- Het schaalverloop volgt het bureaublad: een schaal waarbij het venster alleen
  nog met minder tekencellen zou passen, wordt overgeslagen. Met een vaste
  vensterlimiet (`-wBxH`) blijft het oude gedrag gelden.
- De helpregel voor de tekengrootte in het F1-scherm (en de Engelse vertaling
  daarvan) is aangepast.
- Het programma laadt de instellingen nu altijd, ook met `-z`, zodat de taal
  uit `lijstjes.cfg` ook dan wordt gelezen. De schaal uit `-z` blijft voorgaan.
- Commentaar bovenin: de standaardmap voor de gegevens is `<exepad>/data` (dat
  deed de code al) en de schaal wissel je met Ctrl+N.

## [0.1]

Eerste versie: lijstjes en notities als Markdown-bestanden, met een lijstjes-
en een itemspaneel, zoeken, sorteren, inspringen, verwijzingen tussen
lijstjes, een reset voor herbruikbare lijstjes, en een instelbare tekengrootte.
