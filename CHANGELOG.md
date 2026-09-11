# Changelog

Alle noemenswaardige wijzigingen aan Lijstjes worden hier bijgehouden.

## [0.1]

### Verwijderd
- De tekstconsole-modus (`-t`) is verwijderd, omdat die niet werkte.
  Lijstjes draait nu uitsluitend in een grafisch venster (via de gfxlib-
  driver van FreeBASIC), die op alle platformen betrouwbaar functietoetsen
  afvangt en een compleet CP437-font meelevert.
- De ASCII-randen-fallback die automatisch werd geactiveerd bij `-t` buiten
  Windows is daarmee ook vervallen; `-a` en `-c` blijven wel gewoon werken
  om handmatig tussen ASCII- en CP437-randen te wisselen.

### Gewijzigd
- Versienummering start opnieuw bij 0.1.
- README bijgewerkt: geen verwijzingen meer naar de tekstconsole-modus, en
  het standaardpad voor de gegevensmap gecorrigeerd naar `<exepad>/data`.
