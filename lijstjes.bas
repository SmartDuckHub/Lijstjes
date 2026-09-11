#lang "fblite"

' ==========================================================================
'  Lijstjes 0.1  --  lijstjes & notities, in een grafisch venster
'  In de stijl van de Turbo Pascal editor (FreeBASIC / fblite dialect)
'
'  Copyright 2026 door Marcel "SmartDuck" Beekman
' 
'  Licentie : 	BSD 3-Clause
' 
'  Compilen :  fbc -lang fblite lijstjes.bas
'				of in Geany
'				fbc -lang fblite  "%f"
'
'  Starten :   lijstjes [map] [-zN] [-wBxH] [-a|-c]
'                map = map met .md bestanden (standaard: <exepad>/lijstjes)
'                -zN = tekens N keer zo groot (1..6); anders de laatst gekozen
'                      schaal uit lijstjes.cfg. Tijdens het draaien met + en -.
'                -wBxH = venster nooit groter dan B bij H pixels, bv. -w640x480
'                -a  = ASCII-randen  (standaard: CP437-randen)
'                -c  = CP437-randen  (standaard)
'
'  Bestandsformaat: Markdown, 1 bestand per lijstje, dus ook buiten Lijstjes
'  te lezen en te bewerken:
'
'      # Boodschappen
'      <!-- lijstjes kleur=14 -->
'      - [ ] Melk
'      - [x] Brood
'        - [ ] volkoren
'      Gewone tekstregel zonder vinkje
'
'  Taal: het programma volgt de OS-taalinstelling (LANG/LC_ALL e.d.), met
'  Engels als terugvaltaal wanneer die niet is te bepalen of niet wordt
'  ondersteund. De teksten zelf staan in lijstjes_taal_en.txt naast het
'  programma; Nederlands is de brontaal en heeft geen bestand nodig. Wil
'  je een taal forceren, zet dan in lijstjes.cfg (in de gegevensmap) de
'  regel taal=nl of taal=en (in plaats van taal=auto).
' ==========================================================================

Const MAX_LISTS = 64
Const MAX_ITEMS = 400
Const MAX_HITS  = 200
Const MAX_TXT   = 200
Const TAAL_MAX  = 200      '' max. aantal regels in een vertaalbestand
Const APP_NAAM  = "Lijstjes"
Const APP_VER   = "0.1"
Const SEP       = "/"

'' --- grafische modus -----------------------------------------------------
''  Lijstjes draait altijd via de gfxlib-driver van FB: die vangt op elk
''  platform betrouwbaar alle speciale toetsen af en levert overal
''  Chr(255) + scancode. Bovendien heeft gfxlib een compleet CP437-font, dus
''  de lijntekens werken ook buiten Windows. We kiezen 32 bpp en geven het
''  palet zelf op: in de oude 4-bpp modi (Screen 8 en verwanten) zijn kleuren
''  palet-indices die onderling kunnen samenvallen, en dat is precies de
''  overlap die je zag.
''
''  De vensterafmeting volgt uit de indeling:
''      pixels = kolommen * 8 * schaal  bij  rijen * 16 * schaal
''  Bij schaal 1 tekent FB zelf met het ingebouwde 8x16 font (snel); bij een
''  hogere schaal tekenen we de tekens zelf, vergroot.
''
''  SetScale() past de schaal tijdens het draaien aan. Standaard blijft de
''  indeling 80 x 30 en groeit het venster mee. Is er een harde vensterlimiet
''  gezet (-wBxH, of het bureaublad is te klein), dan blijft het venster gelijk
''  en krimpt het aantal cellen. Dus met -w640x480:
''      schaal 1  ->  640 x 480, 80 x 30 cellen, tekens  8 x 16
''      schaal 2  ->  640 x 480, 40 x 15 cellen, tekens 16 x 32
Const VEN_KOL   = 80      '' gewenst aantal tekstkolommen
Const VEN_RIJ   = 30      '' gewenst aantal tekstrijen
Const MIN_KOL   = 38      '' hieronder is de indeling niet meer bruikbaar
Const MIN_RIJ   = 12
Const MAX_SCH   = 6       '' hoogste schaalfactor

'' --- kleuren (indices in het zelf ingestelde palet) ----------------------
Const C_BALK_FG = 0     : Const C_BALK_BG = 7     '' titel- en helpbalk
Const C_BG      = 1                               '' achtergrond werkvlak
Const C_RAND    = 7                               '' randen
Const C_TXT     = 15                              '' open item
Const C_NOTE    = 7                               '' tekstregel
Const C_KLAAR   = 2                               '' afgevinkt item
Const C_LINK    = 11                              '' regel met [[link]]
Const C_SEL_FG  = 15  : Const C_SEL_BG = 3        '' selectie in actief paneel
Const C_SEL2_FG = 14                              '' selectie in inactief paneel
Const C_DLG_FG  = 0   : Const C_DLG_BG = 7        '' dialoogvenster

'' --- gegevensstructuren --------------------------------------------------
Type ItemType
    txt      As String
    klaar    As Integer      '' 0 = open, -1 = afgevinkt
    diepte   As Integer      '' 0..3 inspringniveau
    soort    As Integer      '' 0 = vinkje, 1 = gewone tekstregel
End Type

Type LijstType
    titel    As String
    bestand  As String
    kleur    As Integer
    aantal   As Integer
    cur      As Integer      '' cursorpositie in dit lijstje
    top      As Integer      '' bovenste zichtbare regel
    item(1 To MAX_ITEMS) As ItemType
End Type

Dim Shared lijst(1 To MAX_LISTS) As LijstType
Dim Shared nLijsten   As Integer
Dim Shared curL       As Integer
Dim Shared lTop       As Integer
Dim Shared paneel     As Integer          '' 0 = lijstenpaneel, 1 = itemspaneel
Dim Shared dataMap    As String
Dim Shared melding    As String
Dim Shared scrW       As Integer
Dim Shared scrH       As Integer
Dim Shared pal(0 To 15) As UInteger       '' index -> exacte RGB-waarde
Dim Shared fontSchaal As Integer          '' 1 = ingebouwd font, >1 = zelf vergroten
Dim Shared celB       As Integer          '' celbreedte in pixels
Dim Shared celH       As Integer          '' celhoogte in pixels
Dim Shared venMaxB    As Integer          '' harde grens vensterbreedte (0 = geen)
Dim Shared venMaxH    As Integer          '' harde grens vensterhoogte  (0 = geen)
Dim Shared bureauB    As Integer          '' bureaubladafmeting, eenmalig opgevraagd
Dim Shared bureauH    As Integer

'' De bitmap van het ingebouwde 8x16 font. We halen die niet uit een intern
'' symbool (fb_font_8x16 is niet in elke gfxlib-build geëxporteerd, en dat geeft
'' een linkerfout), maar lezen hem bij het opstarten zelf uit: alle 256 tekens
'' één keer met Draw String neerzetten en met Point aftasten. Puur gedocumenteerde
'' API's, en we bepalen zo zelf de bitvolgorde -- hoogste bit is de linkerpixel.
'' Buffer voor het terugdraaien van de laatste reset: welk lijstje, hoeveel
'' items het toen had, en de vinkjes zoals ze waren.
Dim Shared undoL As Integer               '' 0 = niets te herstellen
Dim Shared undoN As Integer
Dim Shared undoKlaar(1 To MAX_ITEMS) As Integer

Dim Shared fontBits(0 To 255, 0 To 15) As UByte
Dim Shared fontOk As Integer              '' -1 zodra de tabel gevuld is
Dim Shared LP         As Integer          '' breedte linkerpaneel
Dim Shared rTop       As Integer          '' eerste inhoudsregel
Dim Shared rBot       As Integer          '' laatste inhoudsregel
Dim Shared schaalGezet As Integer         '' -1 als de schaal al via -z is vastgezet

'' --- vertaling --------------------------------------------------------
Dim Shared As String VertaalSleutel(1 To TAAL_MAX)
Dim Shared As String VertaalWaarde(1 To TAAL_MAX)
Dim Shared As Integer AantalVertalingen
Dim Shared As String GeladenTaalcode   '' welke taal er nu in het geheugen staat
Dim Shared As String TaalInstelling    '' ruwe cfg-waarde: "auto", "nl", "en", ...
Dim Shared As String HuidigeTaal       '' effectief actieve taal ("nl", "en", ...)

'' randtekens (enkel + dubbel)
Dim Shared gTL As String, gTR As String, gBL As String, gBR As String
Dim Shared gH  As String, gV  As String, gTd As String, gBd As String
Dim Shared dbTL As String, dbTR As String, dbBL As String, dbBR As String
Dim Shared dbH  As String, dbV  As String
Dim Shared gVink As String, gPijl As String, gPunt As String

'' --- declaraties ---------------------------------------------------------
Declare Sub ZetGlyphs(ByVal asciiModus As Integer)
Declare Sub ZetPalet()
Declare Sub Indeling()
Declare Function SetScale(ByVal nieuw As Integer) As Integer
Declare Sub SchaalWijzig(ByVal delta As Integer)
Declare Sub LaadInstellingen()
Declare Sub BewaarInstellingen()
Declare Function DetecteerTaal() As String
Declare Sub LaadVertaalTabel(ByRef code As String)
Declare Function vertaalTekst(ByRef tekst As String, ByRef taalcode As String) As String
Declare Function Vt(ByRef tekst As String) As String
Declare Function VervangEerste(ByRef bron As String, ByRef patroon As String, ByRef vervang As String) As String
Declare Function Tn(ByRef sjabloon As String, ByRef a1 As String, ByRef a2 As String, ByRef a3 As String) As String
Declare Sub LeesFont()
Declare Sub TekenCellen(ByVal r As Integer, ByVal c As Integer, ByRef s As String, ByVal fgc As UInteger, ByVal bgc As UInteger)
Declare Function SchermInit() As Integer
Declare Function Pad(ByRef s As String, ByVal n As Integer) As String
Declare Function Kort(ByRef s As String, ByVal n As Integer) As String
Declare Sub PutStr(ByVal r As Integer, ByVal c As Integer, ByRef s As String, ByVal fg As Integer, ByVal bg As Integer)
Declare Function LeesTeken(ByVal msWacht As Integer) As String
Declare Function AnsiNaarScan(ByRef reeks As String) As Integer
Declare Function WachtToets(ByRef ext As Integer) As Integer
Declare Sub Venster(ByVal r As Integer, ByVal c As Integer, ByVal h As Integer, ByVal w As Integer, ByRef titel As String)
Declare Sub Melden(ByRef tekst As String)
Declare Function Bevestig(ByRef vraag As String) As Integer
Declare Function RegelEdit(ByVal r As Integer, ByVal c As Integer, ByVal w As Integer, ByRef start As String, ByRef ok As Integer) As String
Declare Function VraagTekst(ByRef titel As String, ByRef prompt As String, ByRef start As String, ByRef ok As Integer) As String
Declare Sub ToonHelp()

Declare Function MaakBestandsnaam(ByRef t As String, ByVal negeer As Integer) As String
Declare Sub LaadAlles()
Declare Sub LaadLijst(ByVal idx As Integer, ByRef bn As String)
Declare Sub SlaLijstOp(ByVal idx As Integer)
Declare Sub SlaAllesOp()
Declare Sub MaakDemo()
Declare Sub NieuweLijst()
Declare Sub HernoemLijst()
Declare Sub VerwijderLijst()

Declare Function OpenAantal(ByVal idx As Integer) As Integer
Declare Sub ZorgZichtbaar()
Declare Sub NieuwItem()
Declare Sub BewerkItem()
Declare Sub VerwijderItem()
Declare Sub VinkItem()
Declare Sub VerplaatsItem(ByVal richting As Integer)
Declare Sub ZetDiepte(ByVal delta As Integer)
Declare Sub WisselSoort()
Declare Sub SorteerLijst()
Declare Sub WisAfgevinkt()
Declare Sub ResetLijst()
Declare Sub ResetTerug()
Declare Sub VolgLink()
Declare Sub KiesKleur()

Declare Sub Redraw()
Declare Sub TekenKader()
Declare Sub TekenLijsten()
Declare Sub TekenItems()
Declare Sub TekenStatus()
Declare Sub TekenHelp()
Declare Sub Zoek()

'' ==========================================================================
''  Hulpjes
'' ==========================================================================

Sub ZetGlyphs(ByVal asciiModus As Integer)
    If asciiModus Then
        gTL = "+" : gTR = "+" : gBL = "+" : gBR = "+"
        gH  = "-" : gV  = "|" : gTd = "+" : gBd = "+"
        dbTL = "+" : dbTR = "+" : dbBL = "+" : dbBR = "+"
        dbH  = "=" : dbV  = "|"
        gVink = "x" : gPijl = ">" : gPunt = "-"
    Else
        gTL = Chr(218) : gTR = Chr(191) : gBL = Chr(192) : gBR = Chr(217)
        gH  = Chr(196) : gV  = Chr(179) : gTd = Chr(194) : gBd = Chr(193)
        dbTL = Chr(201) : dbTR = Chr(187) : dbBL = Chr(200) : dbBR = Chr(188)
        dbH  = Chr(205) : dbV  = Chr(186)
        gVink = Chr(251) : gPijl = Chr(16) : gPunt = Chr(250)
    End If
End Sub

'' Het klassieke VGA-16 palet, expliciet als RGB. Omdat we in 32 bpp werken zijn
'' dit echte kleurwaarden en geen palet-indices meer, dus overlap is uitgesloten.
Sub ZetPalet()
    pal(0)  = RGB(  0,   0,   0)    '' zwart
    pal(1)  = RGB(  0,   0, 160)    '' blauw        (achtergrond werkvlak)
    pal(2)  = RGB(  0, 150,   0)    '' groen        (afgevinkt)
    pal(3)  = RGB(  0, 140, 150)    '' cyaan        (selectiebalk)
    pal(4)  = RGB(170,   0,   0)    '' rood
    pal(5)  = RGB(170,   0, 170)    '' magenta
    pal(6)  = RGB(170,  85,   0)    '' bruin
    pal(7)  = RGB(180, 180, 180)    '' lichtgrijs   (randen, balken)
    pal(8)  = RGB( 90,  90,  90)    '' donkergrijs
    pal(9)  = RGB( 85,  85, 255)    '' lichtblauw
    pal(10) = RGB( 85, 255,  85)    '' lichtgroen
    pal(11) = RGB(120, 235, 255)    '' lichtcyaan   ([[verwijzing]])
    pal(12) = RGB(255,  95,  95)    '' lichtrood
    pal(13) = RGB(255, 120, 255)    '' lichtmagenta
    pal(14) = RGB(255, 230, 120)    '' geel         (lijsttitel)
    pal(15) = RGB(255, 255, 255)    '' wit          (open item)
End Sub

'' Herberekent de paneelindeling uit scrW/scrH. Wordt na elke schaalwijziging
'' opnieuw aangeroepen.
Sub Indeling()
    LP = 26
    If LP > scrW \ 3 Then LP = scrW \ 3
    If LP < 12 Then LP = 12

    rTop = 3
    rBot = scrH - 3
End Sub

'' Zet de schaal tijdens het draaien. Geeft -1 bij succes en 0 als de gevraagde
'' schaal niet past; in dat laatste geval blijft de oude toestand ongemoeid.
''
'' Het venster wordt opnieuw opgezet met ScreenRes. Dat maakt bij de meeste
'' drivers een nieuw venster aan en wist de inhoud, dus daarna moeten kleur,
'' indeling en scherm opnieuw worden gezet -- vandaar de Cls hier.
Function SetScale(ByVal nieuw As Integer) As Integer
    Dim kol As Integer, rij As Integer
    Dim nb As Integer, nh As Integer
    Dim grensB As Integer, grensH As Integer

    SetScale = 0

    If nieuw < 1 Then nieuw = 1
    If nieuw > MAX_SCH Then nieuw = MAX_SCH
    If nieuw > 1 And fontOk = 0 Then Exit Function   '' geen fonttabel: alleen 1x

    nb = 8  * nieuw
    nh = 16 * nieuw

    '' Hoeveel pixels mogen we gebruiken? Een expliciete limiet gaat voor,
    '' anders houden we marge tot de rand van het bureaublad.
    grensB = venMaxB
    grensH = venMaxH
    If grensB <= 0 Then
        If bureauB > 0 Then grensB = bureauB - bureauB \ 20 Else grensB = 0
    End If
    If grensH <= 0 Then
        If bureauH > 0 Then grensH = bureauH - bureauH \ 12 Else grensH = 0
    End If

    kol = VEN_KOL
    rij = VEN_RIJ
    If grensB > 0 Then
        If kol * nb > grensB Then kol = grensB \ nb
    End If
    If grensH > 0 Then
        If rij * nh > grensH Then rij = grensH \ nh
    End If

    If kol < MIN_KOL Or rij < MIN_RIJ Then Exit Function

    ScreenRes kol * nb, rij * nh, 32
    WindowTitle APP_NAAM + " " + APP_VER

    fontSchaal = nieuw
    celB = nb
    celH = nh
    scrW = kol
    scrH = rij

    If fontSchaal = 1 Then
        '' Bij schaal 1 kiest FB zelf het 8x16 font en blijft Print bruikbaar.
        Width scrW, scrH
    End If

    Indeling
    Color pal(C_RAND), pal(C_BG)
    Cls
    Locate , , 0
    SetScale = -1
End Function

'' Past de schaal een stap aan en onthoudt de keuze voor de volgende keer.
Sub SchaalWijzig(ByVal delta As Integer)
    Dim gevraagd As Integer

    gevraagd = fontSchaal + delta
    If gevraagd < 1 Or gevraagd > MAX_SCH Then
        melding = Vt("Schaal") + " " + Trim(Str(fontSchaal)) + "x " + Vt("is al de grens.")
        Exit Sub
    End If

    If SetScale(gevraagd) Then
        BewaarInstellingen
        melding = Vt("Schaal") + " " + Trim(Str(fontSchaal)) + "x  " + gPunt + "  " + _
                  Trim(Str(scrW)) + "x" + Trim(Str(scrH)) + " " + Vt("tekens van") + " " + _
                  Trim(Str(celB)) + "x" + Trim(Str(celH)) + " " + Vt("pixels")
    Else
        melding = Vt("Schaal") + " " + Trim(Str(gevraagd)) + "x " + Vt("past niet op dit scherm.")
    End If
End Sub

Sub LaadInstellingen()
    Dim fnum As Integer
    Dim s As String
    Dim p As Integer
    Dim sleutel As String, waarde As String
    Dim schaalUitCfg As Integer

    TaalInstelling = "auto"
    schaalUitCfg = 0

    fnum = FreeFile
    If Open(dataMap + SEP + "lijstjes.cfg" For Input As #fnum) <> 0 Then
        HuidigeTaal = DetecteerTaal()
        Exit Sub
    End If
    Do While Not EOF(fnum)
        Line Input #fnum, s
        If Right(s, 1) = Chr(13) Then s = Left(s, Len(s) - 1)
        p = InStr(s, "=")
        If p > 0 Then
            sleutel = LCase(Trim(Left(s, p - 1)))
            waarde  = Trim(Mid(s, p + 1))
            If sleutel = "schaal" Then
                schaalUitCfg = Val(waarde)
            ElseIf sleutel = "taal" Then
                TaalInstelling = waarde
            End If
        End If
    Loop
    Close #fnum

    If schaalGezet = 0 And schaalUitCfg > 0 Then
        fontSchaal = schaalUitCfg
        If fontSchaal < 1 Then fontSchaal = 1
        If fontSchaal > MAX_SCH Then fontSchaal = MAX_SCH
    End If

    If LCase(Trim(TaalInstelling)) = "auto" Or Len(Trim(TaalInstelling)) = 0 Then
        HuidigeTaal = DetecteerTaal()
    Else
        HuidigeTaal = LCase(Trim(TaalInstelling))
    End If
End Sub

Sub BewaarInstellingen()
    Dim fnum As Integer

    fnum = FreeFile
    If Open(dataMap + SEP + "lijstjes.cfg" For Output As #fnum) <> 0 Then Exit Sub
    Print #fnum, "'' instellingen van " + APP_NAAM + " -- met de hand aanpassen mag"
    Print #fnum, "schaal=" + Trim(Str(fontSchaal))
    Print #fnum, "taal=" + Trim(TaalInstelling)
    Close #fnum
End Sub

'' --- vertaling ------------------------------------------------------------
''  Nederlands is de brontaal: alle teksten in de programmacode staan in
''  het Nederlands en dienen als sleutel. vertaalTekst(tekst, taalcode)
''  zoekt "tekst" op in lijstjes_taal_<taalcode>.txt en geeft de vertaling
''  terug; is er geen bestand of geen match, dan komt gewoon de Nederlandse
''  tekst terug. Vt() is de korte vorm die altijd naar de actieve taal
''  vertaalt; Tn() doet hetzelfde voor een sjabloon met %1/%2/%3 erin, zodat
''  de woordvolgorde per taal kan verschillen (bijv. "Lijstje '%1' verwijderen?"
''  wordt "Delete list '%1'?").

Function DetecteerTaal() As String
    Dim As String v

    v = Environ("LC_ALL")
    If Len(v) = 0 Then v = Environ("LC_MESSAGES")
    If Len(v) = 0 Then v = Environ("LANG")
    If Len(v) = 0 Then v = Environ("LANGUAGE")

    v = LCase(v)
    If Left(v, 2) = "nl" Then
        DetecteerTaal = "nl"
    ElseIf Left(v, 2) = "en" Then
        DetecteerTaal = "en"
    Else
        '' Engels is de terugvaltaal wanneer de OS-taal niet is te bepalen
        '' (bijv. op Windows, waar deze omgevingsvariabelen vaak ontbreken)
        '' of niet wordt ondersteund. Forceer zo nodig met taal=nl/taal=en
        '' in lijstjes.cfg.
        DetecteerTaal = "en"
    End If
End Function

Sub LaadVertaalTabel(ByRef code As String)
    Dim As Integer f, p
    Dim As String s, bestandspad, sleutel, waarde

    AantalVertalingen = 0
    GeladenTaalcode = LCase(Trim(code))

    If GeladenTaalcode = "" Or GeladenTaalcode = "nl" Then
        '' Nederlands is de brontaal: geen bestand nodig, vertaalTekst
        '' geeft dan gewoon de originele tekst terug
        Exit Sub
    End If

    bestandspad = ExePath + SEP + "lijstjes_taal_" + GeladenTaalcode + ".txt"
    If Len(Dir(bestandspad)) = 0 Then Exit Sub  '' bestand ontbreekt: val terug op NL

    f = FreeFile
    If Open(bestandspad For Input As #f) <> 0 Then Exit Sub
    Do While Not EOF(f) And AantalVertalingen < TAAL_MAX
        Line Input #f, s
        If Right(s, 1) = Chr(13) Then s = Left(s, Len(s) - 1)
        If Len(s) > 0 And Left(s, 1) <> "'" Then
            '' let op: " => " (met spaties), niet kaal "=" -- sommige
            '' sleutels bevatten zelf een "=" of een dubbele punt
            p = InStr(s, " => ")
            If p > 0 Then
                sleutel = Left(s, p - 1)
                waarde  = Mid(s, p + 4)
                AantalVertalingen += 1
                VertaalSleutel(AantalVertalingen) = sleutel
                VertaalWaarde(AantalVertalingen) = waarde
            End If
        End If
    Loop
    Close #f
End Sub

Function vertaalTekst(ByRef tekst As String, ByRef taalcode As String) As String
    Dim As Integer i
    Dim code As String

    code = LCase(Trim(taalcode))
    If code = "" Then code = "nl"

    If code <> GeladenTaalcode Then LaadVertaalTabel code

    If code = "nl" Then
        vertaalTekst = tekst
        Exit Function
    End If

    For i = 1 To AantalVertalingen
        If VertaalSleutel(i) = tekst Then
            vertaalTekst = VertaalWaarde(i)
            Exit Function
        End If
    Next i

    '' geen vertaling gevonden: val terug op de Nederlandse brontekst
    vertaalTekst = tekst
End Function

Function Vt(ByRef tekst As String) As String
    Vt = vertaalTekst(tekst, HuidigeTaal)
End Function

Function VervangEerste(ByRef bron As String, ByRef patroon As String, ByRef vervang As String) As String
    Dim p As Integer
    p = InStr(bron, patroon)
    If p > 0 Then
        VervangEerste = Left(bron, p - 1) + vervang + Mid(bron, p + Len(patroon))
    Else
        VervangEerste = bron
    End If
End Function

Function Tn(ByRef sjabloon As String, ByRef a1 As String, ByRef a2 As String, ByRef a3 As String) As String
    Dim vert As String
    vert = Vt(sjabloon)
    vert = VervangEerste(vert, "%1", a1)
    vert = VervangEerste(vert, "%2", a2)
    vert = VervangEerste(vert, "%3", a3)
    Tn = vert
End Function

Function SchermInit() As Integer
    ZetPalet

    If fontSchaal < 1 Then fontSchaal = 1
    If fontSchaal > MAX_SCH Then fontSchaal = MAX_SCH

    '' Zolang er nog geen modus is gezet geeft ScreenInfo de afmeting van het
    '' bureaublad; daarna die van het venster. Dus nu opvragen en bewaren.
    ScreenInfo bureauB, bureauH

    '' Fonttabel vullen zolang er nog geen echt venster staat.
    LeesFont
    If fontOk = 0 Then fontSchaal = 1

    If SetScale(fontSchaal) = 0 Then
        '' gevraagde schaal past niet: terugvallen naar de grootste die past
        Do
            fontSchaal = fontSchaal - 1
            If fontSchaal < 1 Then
                SchermInit = 0
                Exit Function
            End If
        Loop Until SetScale(fontSchaal) <> 0
    End If
    SchermInit = -1
End Function

'' Vult fontBits() met het ingebouwde 8x16 font. Zet zelf een klein tijdelijk
'' venster op van 32 x 8 tekens (256 x 128 pixels), waarin met Width het 8x16
'' font wordt gekozen, drukt alle tekens af en tast ze pixel voor pixel af.
'' Wordt één keer bij het opstarten aangeroepen, vóór het echte venster.
Sub LeesFont()
    Dim code As Integer, x As Integer, y As Integer
    Dim cx As Integer, cy As Integer, b As Integer
    Dim wit As UInteger

    fontOk = 0
    For code = 0 To 255
        For y = 0 To 15
            fontBits(code, y) = 0
        Next
    Next

    wit = RGB(255, 255, 255)

    ScreenRes 32 * 8, 8 * 16, 32
    Width 32, 8                     '' 256\8 = 32 en 128\16 = 8, dus het 8x16 font
    Color wit, RGB(0, 0, 0)
    Cls

    '' Teken voor teken, zodat een eventueel eigenzinnig behandeld stuurteken
    '' alleen zijn eigen vakje beïnvloedt.
    For code = 1 To 255
        cx = (code Mod 32) * 8
        cy = (code \ 32) * 16
        Draw String (cx, cy), Chr(code), wit
    Next

    For code = 0 To 255
        cx = (code Mod 32) * 8
        cy = (code \ 32) * 16
        For y = 0 To 15
            b = 0
            For x = 0 To 7
                '' alleen de kleurbits vergelijken; de alfabits kunnen gezet zijn
                If (Point(cx + x, cy + y) And &hFFFFFF) <> 0 Then
                    b = b Or (1 Shl (7 - x))
                End If
            Next
            fontBits(code, y) = b
        Next
    Next

    '' Controle: de "A" moet pixels hebben. Zo niet, dan legde Draw String de
    '' tekens anders neer dan verwacht en is de tabel onbruikbaar -- dan liever
    '' terugvallen op schaal 1 dan een venster vol onzichtbare tekst.
    b = 0
    For y = 0 To 15
        b = b Or fontBits(65, y)
    Next
    If b = 0 Then Exit Sub

    fontOk = -1
End Sub

'' Tekent een tekst zelf, teken voor teken, met het uitgelezen 8x16 font
'' vergroot met fontSchaal. Alleen nodig zodra fontSchaal > 1; bij schaal 1
'' doet Print het sneller.
Sub TekenCellen(ByVal r As Integer, ByVal c As Integer, ByRef s As String, ByVal fgc As UInteger, ByVal bgc As UInteger)
    Dim i As Integer, x As Integer, y As Integer
    Dim px As Integer, py As Integer, x0 As Integer
    Dim bits As Integer, code As Integer, sch As Integer

    sch = fontSchaal
    py  = (r - 1) * celH
    x0  = (c - 1) * celB

    '' achtergrond van de hele tekst in één keer
    Line (x0, py)-(x0 + Len(s) * celB - 1, py + celH - 1), bgc, bf

    For i = 1 To Len(s)
        code = Asc(Mid(s, i, 1))
        If code <> 32 Then                      '' spaties hebben geen pixels
            px = x0 + (i - 1) * celB
            For y = 0 To 15
                bits = fontBits(code, y)
                If bits <> 0 Then
                    For x = 0 To 7
                        If (bits And (1 Shl (7 - x))) <> 0 Then
                            Line (px + x * sch, py + y * sch)- _
                                 (px + x * sch + sch - 1, py + y * sch + sch - 1), fgc, bf
                        End If
                    Next
                End If
            Next
        End If
    Next
End Sub

Function Pad(ByRef s As String, ByVal n As Integer) As String
    If n <= 0 Then
        Pad = ""
    ElseIf Len(s) >= n Then
        Pad = Left(s, n)
    Else
        Pad = s + Space(n - Len(s))
    End If
End Function

'' Kort een string af en zet een markering aan het eind.
Function Kort(ByRef s As String, ByVal n As Integer) As String
    If n <= 0 Then
        Kort = ""
    ElseIf Len(s) <= n Then
        Kort = s
    ElseIf n < 2 Then
        Kort = Left(s, n)
    Else
        Kort = Left(s, n - 1) + gPijl
    End If
End Function

'' Schrijf tekst op het scherm, veilig geclipt. De laatste cel van het
'' scherm blijft altijd leeg, anders scrollt de console weg.
Sub PutStr(ByVal r As Integer, ByVal c As Integer, ByRef s As String, ByVal fg As Integer, ByVal bg As Integer)
    Dim t As String
    Dim ruimte As Integer

    If r < 1 Then Exit Sub
    If r > scrH Then Exit Sub
    If c < 1 Then Exit Sub
    If c > scrW Then Exit Sub

    ruimte = scrW - c + 1
    If r = scrH Then ruimte = ruimte - 1
    If ruimte <= 0 Then Exit Sub

    t = s
    If Len(t) > ruimte Then t = Left(t, ruimte)
    If Len(t) = 0 Then Exit Sub

    If fontSchaal > 1 Then
        TekenCellen r, c, t, pal(fg And 15), pal(bg And 15)
        Exit Sub
    End If
    Color pal(fg And 15), pal(bg And 15)
    Locate r, c
    Print t;
End Sub

'' Leest een teken uit de invoerbuffer en wacht daarop maximaal msWacht
'' milliseconden. Geeft "" terug als er niets kwam.
Function LeesTeken(ByVal msWacht As Integer) As String
    Dim k As String
    Dim n As Integer

    LeesTeken = ""
    n = 0
    Do
        k = Inkey
        If Len(k) > 0 Then
            LeesTeken = k
            Exit Function
        End If
        If n >= msWacht Then Exit Function
        Sleep 5, 1
        n = n + 5
    Loop
End Function

'' Zet een ANSI-escapereeks (zonder de ESC zelf) om naar de DOS-scancode die
'' de rest van het programma verwacht. 0 = onbekend.
Function AnsiNaarScan(ByRef reeks As String) As Integer
    Dim kern As String, laatste As String
    Dim p As Integer, n As Integer

    AnsiNaarScan = 0
    If Len(reeks) < 2 Then Exit Function

    '' Linux-tekstconsole: ESC [ [ A..E  =  F1..F5
    If Left(reeks, 2) = "[[" Then
        Select Case Mid(reeks, 3, 1)
        Case "A" : AnsiNaarScan = 59
        Case "B" : AnsiNaarScan = 60
        Case "C" : AnsiNaarScan = 61
        Case "D" : AnsiNaarScan = 62
        Case "E" : AnsiNaarScan = 63
        End Select
        Exit Function
    End If

    kern    = Mid(reeks, 2)          '' de "[" of "O" eraf
    laatste = Right(kern, 1)

    '' vorm  <getal>~   (eventueel  <getal>;<modifier>~ )
    If laatste = "~" Then
        p = InStr(kern, ";")
        If p > 0 Then
            kern = Left(kern, p - 1)
        Else
            kern = Left(kern, Len(kern) - 1)
        End If
        n = Val(kern)
        Select Case n
        Case 1, 7 : AnsiNaarScan = 71    '' Home
        Case 2    : AnsiNaarScan = 82    '' Insert
        Case 3    : AnsiNaarScan = 83    '' Delete
        Case 4, 8 : AnsiNaarScan = 79    '' End
        Case 5    : AnsiNaarScan = 73    '' PgUp
        Case 6    : AnsiNaarScan = 81    '' PgDn
        Case 11   : AnsiNaarScan = 59    '' F1
        Case 12   : AnsiNaarScan = 60
        Case 13   : AnsiNaarScan = 61
        Case 14   : AnsiNaarScan = 62
        Case 15   : AnsiNaarScan = 63    '' F5
        Case 17   : AnsiNaarScan = 64    '' F6
        Case 18   : AnsiNaarScan = 65
        Case 19   : AnsiNaarScan = 66
        Case 20   : AnsiNaarScan = 67    '' F9
        Case 21   : AnsiNaarScan = 68    '' F10
        Case 23   : AnsiNaarScan = 133   '' F11
        Case 24   : AnsiNaarScan = 134   '' F12
        End Select
        Exit Function
    End If

    '' vorm die op een letter eindigt:  [A  [1;5A  OP  OH ...
    Select Case laatste
    Case "A" : AnsiNaarScan = 72         '' pijl omhoog
    Case "B" : AnsiNaarScan = 80         '' pijl omlaag
    Case "C" : AnsiNaarScan = 77         '' pijl rechts
    Case "D" : AnsiNaarScan = 75         '' pijl links
    Case "H" : AnsiNaarScan = 71         '' Home
    Case "F" : AnsiNaarScan = 79         '' End
    Case "P" : AnsiNaarScan = 59         '' F1  (ESC O P)
    Case "Q" : AnsiNaarScan = 60
    Case "R" : AnsiNaarScan = 61
    Case "S" : AnsiNaarScan = 62         '' F4
    End Select
End Function

'' Wacht op een toets. ext = -1 bij een uitgebreide toets (pijlen, F-toetsen);
'' de teruggegeven waarde is dan de DOS-scancode, anders de ASCII-code.
''
'' Er zijn twee leveringsvormen: Windows/DOS geven Chr(255) + scancode, terwijl
'' Unix-terminals losse ANSI-escapereeksen sturen. Beide worden hier afgehandeld,
'' zodat de rest van het programma alleen scancodes hoeft te kennen.
Function WachtToets(ByRef ext As Integer) As Integer
    Dim k As String, reeks As String, ch As String
    Dim sc As Integer, a As Integer

    ext = 0

    Do
        k = LeesTeken(1000)
        If Len(k) > 0 Then Exit Do
    Loop

    '' 1) Windows/DOS-vorm: Chr(255) of Chr(0), gevolgd door de scancode
    If Len(k) = 2 Then
        a = Asc(Left(k, 1))
        If a = 255 Or a = 0 Then
            ext = -1
            WachtToets = Asc(Right(k, 1))
            Exit Function
        End If
    End If

    '' 2) Unix-vorm: ESC gevolgd door "[" of "O" en de rest van de reeks.
    ''    Afhankelijk van de build komt die reeks in één keer binnen of teken
    ''    voor teken. Komt er niets achter de ESC, dan was het echt de Esc-toets.
    If Asc(Left(k, 1)) = 27 Then
        reeks = Mid(k, 2)
        Do
            If Len(reeks) >= 2 Then
                a = Asc(Right(reeks, 1))
                If (a >= 65 And a <= 90) Or (a >= 97 And a <= 122) Or a = 126 Then Exit Do
            End If
            If Len(reeks) >= 8 Then Exit Do
            ch = LeesTeken(40)
            If Len(ch) = 0 Then Exit Do
            reeks = reeks + ch
        Loop

        If Len(reeks) = 0 Then
            WachtToets = 27
            Exit Function
        End If

        sc = AnsiNaarScan(reeks)
        If sc > 0 Then
            ext = -1
            WachtToets = sc
        Else
            WachtToets = 0               '' onbekende reeks: negeren
        End If
        Exit Function
    End If

    WachtToets = Asc(k)
End Function

'' ==========================================================================
''  Vensters en dialogen
'' ==========================================================================

Sub Venster(ByVal r As Integer, ByVal c As Integer, ByVal h As Integer, ByVal w As Integer, ByRef titel As String)
    Dim i As Integer
    Dim s As String

    s = dbTL + String(w - 2, dbH) + dbTR
    PutStr r, c, s, C_DLG_FG, C_DLG_BG

    If Len(titel) > 0 Then
        s = " " + Kort(titel, w - 6) + " "
        PutStr r, c + 2, s, C_DLG_FG, C_DLG_BG
    End If

    For i = 1 To h - 2
        s = dbV + Space(w - 2) + dbV
        PutStr r + i, c, s, C_DLG_FG, C_DLG_BG
    Next

    s = dbBL + String(w - 2, dbH) + dbBR
    PutStr r + h - 1, c, s, C_DLG_FG, C_DLG_BG
End Sub

Sub Melden(ByRef tekst As String)
    Dim w As Integer, r As Integer, c As Integer
    Dim ext As Integer
    Dim s As String

    w = Len(tekst) + 8
    If w < 30 Then w = 30
    If w > scrW - 4 Then w = scrW - 4
    r = (scrH - 6) \ 2
    c = (scrW - w) \ 2 + 1

    Venster r, c, 6, w, APP_NAAM
    s = Kort(tekst, w - 4)
    PutStr r + 2, c + 2, s, C_DLG_FG, C_DLG_BG
    s = "[ Enter ]"
    PutStr r + 4, c + (w - Len(s)) \ 2, s, C_DLG_FG, C_DLG_BG

    Do
        ext = 0
        Select Case WachtToets(ext)
        Case 13, 27, 32
            If ext = 0 Then Exit Do
        End Select
    Loop
    Redraw
End Sub

Function Bevestig(ByRef vraag As String) As Integer
    Dim w As Integer, r As Integer, c As Integer
    Dim ext As Integer, t As Integer
    Dim s As String

    w = Len(vraag) + 8
    If w < 34 Then w = 34
    If w > scrW - 4 Then w = scrW - 4
    r = (scrH - 7) \ 2
    c = (scrW - w) \ 2 + 1

    Venster r, c, 7, w, Vt("Bevestigen")
    s = Kort(vraag, w - 4)
    PutStr r + 2, c + 2, s, C_DLG_FG, C_DLG_BG
    s = Vt("J = ja      N = nee (Esc)")
    PutStr r + 4, c + (w - Len(s)) \ 2, s, C_DLG_FG, C_DLG_BG

    Bevestig = 0
    Do
        ext = 0
        t = WachtToets(ext)
        If ext = 0 Then
            Select Case t
            Case Asc("j"), Asc("J"), Asc("y"), Asc("Y")
                Bevestig = -1 : Exit Do
            Case Asc("n"), Asc("N"), 27
                Bevestig = 0 : Exit Do
            End Select
        End If
    Loop
    Redraw
End Function

'' Eenregelige editor op een vaste schermpositie, met horizontaal schuiven.
Function RegelEdit(ByVal r As Integer, ByVal c As Integer, ByVal w As Integer, ByRef start As String, ByRef ok As Integer) As String
    Dim txt As String
    Dim vis As String
    Dim cch As String
    Dim cpos As Integer, off As Integer
    Dim t   As Integer, ext As Integer

    txt = start
    cpos = Len(txt) + 1
    off = 0
    ok  = 0
    If w < 4 Then w = 4

    Do
        If cpos - off > w Then off = cpos - w
        If cpos - off < 1 Then off = cpos - 1
        If off < 0 Then off = 0

        vis = Pad(Mid(txt, off + 1, w), w)
        PutStr r, c, vis, 0, 7
        '' Eigen blokcursor. In grafische modus tekent FB geen tekstcursor, dus
        '' keren we de kleuren van het teken onder de cursor om.
        cch = Mid(vis, cpos - off, 1)
        If Len(cch) = 0 Then cch = " "
        PutStr r, c + (cpos - off - 1), cch, 7, 0

        ext = 0
        t = WachtToets(ext)

        If ext Then
            Select Case t
            Case 75                             '' pijl links
                If cpos > 1 Then cpos = cpos - 1
            Case 77                             '' pijl rechts
                If cpos <= Len(txt) Then cpos = cpos + 1
            Case 71                             '' Home
                cpos = 1
            Case 79                             '' End
                cpos = Len(txt) + 1
            Case 83                             '' Delete
                If cpos <= Len(txt) Then txt = Left(txt, cpos - 1) + Mid(txt, cpos + 1)
            End Select
        Else
            Select Case t
            Case 13                             '' Enter
                ok = -1 : Exit Do
            Case 27                             '' Esc
                ok = 0 : Exit Do
            Case 8                              '' Backspace
                If cpos > 1 Then
                    txt = Left(txt, cpos - 2) + Mid(txt, cpos)
                    cpos = cpos - 1
                End If
            Case 21                             '' Ctrl+U: regel leegmaken
                txt = "" : cpos = 1 : off = 0
            Case Else
                If t >= 32 Then
                    If Len(txt) < MAX_TXT Then
                        txt = Left(txt, cpos - 1) + Chr(t) + Mid(txt, cpos)
                        cpos = cpos + 1
                    End If
                End If
            End Select
        End If
    Loop

    Locate , , 0
    RegelEdit = txt
End Function

Function VraagTekst(ByRef titel As String, ByRef prompt As String, ByRef start As String, ByRef ok As Integer) As String
    Dim w As Integer, r As Integer, c As Integer
    Dim res As String

    w = 56
    If w > scrW - 4 Then w = scrW - 4
    r = (scrH - 7) \ 2
    c = (scrW - w) \ 2 + 1

    Venster r, c, 7, w, titel
    PutStr r + 2, c + 2, Kort(prompt, w - 4), C_DLG_FG, C_DLG_BG
    PutStr r + 5, c + 2, Kort(Vt("Enter = ok   Esc = annuleren   Ctrl+U = leegmaken"), w - 4), C_DLG_FG, C_DLG_BG

    res = RegelEdit(r + 3, c + 2, w - 4, start, ok)
    Redraw
    VraagTekst = res
End Function

Sub ToonHelp()
    Const HELP_N = 32
    Dim r As Integer, c As Integer, w As Integer, h As Integer
    Dim i As Integer, ext As Integer, t As Integer
    Dim hTop As Integer, rijen As Integer
    Dim h1(1 To HELP_N) As String
    Dim s As String

    h1(1)  = Vt("ALGEMEEN")
    h1(2)  = Vt("  Tab .............. wissel tussen lijsten- en itemspaneel")
    h1(3)  = Vt("  F1 ............... deze hulp")
    h1(4)  = Vt("  F9 / Ctrl+F ...... zoeken in alle lijstjes")
    h1(5)  = Vt("  Ctrl+S ........... alles opslaan")
    h1(6)  = Vt("  + / -  (F12/F11) . tekens groter / kleiner, keuze blijft bewaard")
    h1(7)  = Vt("  Ctrl+Q ........... afsluiten (alles is al opgeslagen)")
    h1(8)  = Vt("  Esc .............. afsluiten, met bevestiging vooraf")
    h1(9)  = Vt("                     F10 werkt hier ook, behalve op Windows:")
    h1(10) = Vt("                     daar is het een systeemtoets")
    h1(11) = ""
    h1(12) = Vt("LIJSTENPANEEL (links)")
    h1(13) = Vt("  Pijl op/neer ..... ander lijstje kiezen")
    h1(14) = Vt("  Enter / pijl re... naar het itemspaneel")
    h1(15) = Vt("  F2 ............... lijstje hernoemen        ~  kleur wisselen")
    h1(16) = Vt("  F3 / F4 .......... nieuw lijstje")
    h1(17) = Vt("  F5 / Del ......... lijstje verwijderen")
    h1(18) = ""
    h1(19) = Vt("ITEMSPANEEL (rechts)")
    h1(20) = Vt("  Spatie / Enter ... afvinken of vinkje weghalen")
    h1(21) = Vt("  F3 / Insert ...... nieuw item onder de cursor")
    h1(22) = Vt("  F2 ............... item bewerken            t  vinkje <-> tekst")
    h1(23) = Vt("  F5 / Del ......... item verwijderen         s  sorteren")
    h1(24) = Vt("  F6 / F7 .......... item omhoog / omlaag     c  afgevinkte wissen")
    h1(25) = Vt("  Pijl li/re ....... minder / meer inspringen g  volg [[verwijzing]]")
    h1(26) = Vt("  Home/End/PgUp/Dn . snel navigeren")
    h1(27) = ""
    h1(28) = Vt("LIJSTJE OPNIEUW GEBRUIKEN")
    h1(29) = Vt("  r ................ alle vinkjes van dit lijstje uitzetten")
    h1(30) = Vt("  u ................ die reset weer ongedaan maken")
    h1(31) = ""
    h1(32) = Vt("Elk lijstje is een los Markdown-bestand in de gegevensmap.")

    '' Het venster past zich aan de beschikbare ruimte aan: bij een grote schaal
    '' zijn er minder cellen, dus dan wordt de hulp schuifbaar.
    w = 70
    If w > scrW - 2 Then w = scrW - 2
    h = HELP_N + 4
    If h > scrH - 2 Then h = scrH - 2
    rijen = h - 4
    If rijen < 3 Then rijen = 3
    r = (scrH - h) \ 2 + 1
    c = (scrW - w) \ 2 + 1
    hTop = 1

    Do
        If hTop > HELP_N - rijen + 1 Then hTop = HELP_N - rijen + 1
        If hTop < 1 Then hTop = 1

        Venster r, c, h, w, Vt("Hulp")
        For i = 0 To rijen - 1
            If hTop + i <= HELP_N Then
                PutStr r + 1 + i, c + 2, Kort(h1(hTop + i), w - 4), C_DLG_FG, C_DLG_BG
            End If
        Next

        If rijen >= HELP_N Then
            s = Vt("Druk op een toets...")
        Else
            s = Vt("Pijl op/neer schuift") + " " + gPunt + " " + Vt("regel") + " " + Trim(Str(hTop)) + _
                "-" + Trim(Str(hTop + rijen - 1)) + " " + Vt("van") + " " + Trim(Str(HELP_N)) + _
                " " + gPunt + " " + Vt("Esc sluit")
        End If
        PutStr r + h - 2, c + 2, Kort(s, w - 4), C_DLG_FG, C_DLG_BG

        If rijen >= HELP_N Then
            ext = 0
            WachtToets ext
            Exit Do
        End If

        ext = 0
        t = WachtToets(ext)
        If ext Then
            Select Case t
            Case 72 : hTop = hTop - 1
            Case 80 : hTop = hTop + 1
            Case 73 : hTop = hTop - rijen
            Case 81 : hTop = hTop + rijen
            Case 71 : hTop = 1
            Case 79 : hTop = HELP_N
            Case Else
                Exit Do
            End Select
        Else
            If t <> 0 Then Exit Do
        End If
    Loop

    Redraw
End Sub

'' ==========================================================================
''  Bestanden
'' ==========================================================================

'' Maak een veilige bestandsnaam uit een titel. "negeer" is de index van een
'' lijstje dat bij de uniekheidscontrole wordt overgeslagen (bij hernoemen).
Function MaakBestandsnaam(ByRef t As String, ByVal negeer As Integer) As String
    Dim basis As String, kand As String, ch As String
    Dim i As Integer, a As Integer, n As Integer, botsing As Integer

    basis = ""
    For i = 1 To Len(t)
        ch = Mid(t, i, 1)
        a = Asc(ch)
        If (a >= 48 And a <= 57) Or (a >= 65 And a <= 90) Or (a >= 97 And a <= 122) Then
            basis = basis + ch
        ElseIf a = 32 Or a = 45 Or a = 95 Then
            basis = basis + "_"
        End If
    Next
    Do While Left(basis, 1) = "_"
        basis = Mid(basis, 2)
    Loop
    Do While Right(basis, 1) = "_"
        basis = Left(basis, Len(basis) - 1)
    Loop
    If Len(basis) = 0 Then basis = "lijstje"
    If Len(basis) > 40 Then basis = Left(basis, 40)

    kand = basis + ".md"
    n = 1
    Do
        botsing = 0
        For i = 1 To nLijsten
            If i <> negeer Then
                If LCase(lijst(i).bestand) = LCase(kand) Then botsing = -1
            End If
        Next
        If botsing = 0 Then Exit Do
        n = n + 1
        kand = basis + "_" + Trim(Str(n)) + ".md"
    Loop

    MaakBestandsnaam = kand
End Function

Sub LaadLijst(ByVal idx As Integer, ByRef bn As String)
    Dim fnum As Integer
    Dim s As String, ruw As String
    Dim d As Integer, p As Integer, eerste As Integer

    lijst(idx).bestand = bn
    lijst(idx).titel   = Left(bn, Len(bn) - 3)
    lijst(idx).kleur   = C_TXT
    lijst(idx).aantal  = 0
    lijst(idx).cur     = 1
    lijst(idx).top     = 1

    fnum = FreeFile
    If Open(dataMap + SEP + bn For Input As #fnum) <> 0 Then Exit Sub

    eerste = -1
    Do While Not EOF(fnum)
        Line Input #fnum, ruw
        If Right(ruw, 1) = Chr(13) Then ruw = Left(ruw, Len(ruw) - 1)

        If eerste And Left(ruw, 2) = "# " Then
            lijst(idx).titel = Trim(Mid(ruw, 3))
            eerste = 0
        ElseIf Left(ruw, 4) = "<!--" Then
            p = InStr(ruw, "kleur=")
            If p > 0 Then
                lijst(idx).kleur = Val(Mid(ruw, p + 6))
                If lijst(idx).kleur < 1 Or lijst(idx).kleur > 15 Then lijst(idx).kleur = C_TXT
            End If
        Else
            eerste = 0
            If lijst(idx).aantal < MAX_ITEMS Then
                s = ruw
                '' inspringniveau bepalen (2 spaties = 1 niveau, tab = 1 niveau)
                d = 0
                Do
                    If Left(s, 2) = "  " Then
                        s = Mid(s, 3) : d = d + 1
                    ElseIf Left(s, 1) = Chr(9) Then
                        s = Mid(s, 2) : d = d + 1
                    Else
                        Exit Do
                    End If
                    If d >= 3 Then Exit Do
                Loop
                Do While Left(s, 1) = " "
                    s = Mid(s, 2)
                Loop

                lijst(idx).aantal = lijst(idx).aantal + 1
                p = lijst(idx).aantal
                lijst(idx).item(p).diepte = d
                lijst(idx).item(p).klaar  = 0
                lijst(idx).item(p).soort  = 0

                If Left(s, 6) = "- [ ] " Then
                    lijst(idx).item(p).txt = Mid(s, 7)
                ElseIf Left(s, 6) = "- [x] " Or Left(s, 6) = "- [X] " Then
                    lijst(idx).item(p).txt   = Mid(s, 7)
                    lijst(idx).item(p).klaar = -1
                ElseIf Left(s, 2) = "- " Or Left(s, 2) = "* " Then
                    lijst(idx).item(p).txt = Mid(s, 3)
                Else
                    lijst(idx).item(p).txt   = s
                    lijst(idx).item(p).soort = 1
                End If
            End If
        End If
    Loop
    Close #fnum

    '' lege tekstregels aan het eind weglaten
    Do While lijst(idx).aantal > 0
        p = lijst(idx).aantal
        If lijst(idx).item(p).soort = 1 And Len(Trim(lijst(idx).item(p).txt)) = 0 Then
            lijst(idx).aantal = lijst(idx).aantal - 1
        Else
            Exit Do
        End If
    Loop
End Sub

Sub LaadAlles()
    Dim namen(1 To MAX_LISTS) As String
    Dim n As Integer, i As Integer, j As Integer
    Dim bn As String, tmp As String

    nLijsten = 0
    n = 0

    bn = Dir(dataMap + SEP + "*.md")
    Do While Len(bn) > 0
        If n < MAX_LISTS Then
            n = n + 1
            namen(n) = bn
        End If
        bn = Dir()
    Loop

    '' alfabetisch sorteren (eenvoudige insertion sort)
    For i = 2 To n
        tmp = namen(i)
        j = i - 1
        Do While j >= 1
            If LCase(namen(j)) > LCase(tmp) Then
                namen(j + 1) = namen(j)
                j = j - 1
            Else
                Exit Do
            End If
        Loop
        namen(j + 1) = tmp
    Next

    For i = 1 To n
        nLijsten = nLijsten + 1
        LaadLijst nLijsten, namen(i)
    Next
End Sub

Sub SlaLijstOp(ByVal idx As Integer)
    Dim fnum As Integer
    Dim i As Integer
    Dim s As String

    If idx < 1 Then Exit Sub
    If idx > nLijsten Then Exit Sub

    fnum = FreeFile
    If Open(dataMap + SEP + lijst(idx).bestand For Output As #fnum) <> 0 Then
        melding = Tn("Kan %1 niet schrijven!", lijst(idx).bestand, "", "")
        Exit Sub
    End If

    Print #fnum, "# " + lijst(idx).titel
    Print #fnum, "<!-- lijstjes kleur=" + Trim(Str(lijst(idx).kleur)) + " -->"

    For i = 1 To lijst(idx).aantal
        s = Space(lijst(idx).item(i).diepte * 2)
        If lijst(idx).item(i).soort = 0 Then
            If lijst(idx).item(i).klaar Then
                s = s + "- [x] "
            Else
                s = s + "- [ ] "
            End If
        End If
        Print #fnum, s + lijst(idx).item(i).txt
    Next

    Close #fnum
End Sub

Sub SlaAllesOp()
    Dim i As Integer
    For i = 1 To nLijsten
        SlaLijstOp i
    Next
End Sub

Sub MaakDemo()
    nLijsten = 2

    lijst(1).titel   = "Welkom bij Lijstjes"
    lijst(1).bestand = "welkom.md"
    lijst(1).kleur   = 14
    lijst(1).cur     = 1
    lijst(1).top     = 1
    lijst(1).aantal  = 7
    lijst(1).item(1).txt = "Druk op F1 voor alle sneltoetsen." : lijst(1).item(1).soort = 1
    lijst(1).item(2).txt = "Tab wisselt tussen de twee panelen."
    lijst(1).item(3).txt = "Spatie vinkt een item af."
    lijst(1).item(4).txt = "F3 maakt een nieuw item, F4 een nieuw lijstje."
    lijst(1).item(5).txt = "Pijl rechts laat een item inspringen:"
    lijst(1).item(6).txt = "zo wordt het een subitem" : lijst(1).item(6).diepte = 1
    lijst(1).item(7).txt = "Verwijs naar een ander lijstje met [[Boodschappen]] en druk op g."

    lijst(2).titel   = "Boodschappen"
    lijst(2).bestand = "boodschappen.md"
    lijst(2).kleur   = 10
    lijst(2).cur     = 1
    lijst(2).top     = 1
    lijst(2).aantal  = 4
    lijst(2).item(1).txt = "Brood" : lijst(2).item(1).klaar = -1
    lijst(2).item(2).txt = "Melk"
    lijst(2).item(3).txt = "Kaas"
    lijst(2).item(4).txt = "jong belegen" : lijst(2).item(4).diepte = 1

    SlaAllesOp
End Sub

Sub NieuweLijst()
    Dim ok As Integer
    Dim t As String

    If nLijsten >= MAX_LISTS Then
        Melden Tn("Maximaal %1 lijstjes.", Trim(Str(MAX_LISTS)), "", "")
        Exit Sub
    End If

    ok = 0
    t = VraagTekst(Vt("Nieuw lijstje"), Vt("Titel van het lijstje:"), "", ok)
    If ok = 0 Then Exit Sub
    t = Trim(t)
    If Len(t) = 0 Then Exit Sub

    nLijsten = nLijsten + 1
    lijst(nLijsten).titel   = t
    lijst(nLijsten).bestand = MaakBestandsnaam(t, nLijsten)
    lijst(nLijsten).kleur   = C_TXT
    lijst(nLijsten).aantal  = 0
    lijst(nLijsten).cur     = 1
    lijst(nLijsten).top     = 1

    curL   = nLijsten
    paneel = 1
    SlaLijstOp curL
    melding = Tn("Lijstje '%1' aangemaakt.", t, "", "")
End Sub

Sub HernoemLijst()
    Dim ok As Integer
    Dim t As String, oud As String, nieuw As String

    If nLijsten = 0 Then Exit Sub
    ok = 0
    t = VraagTekst(Vt("Hernoemen"), Vt("Nieuwe titel:"), lijst(curL).titel, ok)
    If ok = 0 Then Exit Sub
    t = Trim(t)
    If Len(t) = 0 Then Exit Sub

    oud   = lijst(curL).bestand
    nieuw = MaakBestandsnaam(t, curL)
    lijst(curL).titel   = t
    lijst(curL).bestand = nieuw
    SlaLijstOp curL
    If LCase(oud) <> LCase(nieuw) Then Kill dataMap + SEP + oud
    melding = Tn("Hernoemd naar '%1'.", t, "", "")
End Sub

Sub VerwijderLijst()
    Dim i As Integer
    Dim bn As String

    If nLijsten = 0 Then Exit Sub
    If Bevestig(Tn("Lijstje '%1' verwijderen?", lijst(curL).titel, "", "")) = 0 Then Exit Sub

    bn = lijst(curL).bestand
    undoL = 0
    For i = curL To nLijsten - 1
        lijst(i) = lijst(i + 1)
    Next
    nLijsten = nLijsten - 1
    If curL > nLijsten Then curL = nLijsten
    If curL < 1 Then curL = 1
    Kill dataMap + SEP + bn
    paneel  = 0
    melding = Vt("Lijstje verwijderd.")
End Sub

'' ==========================================================================
''  Bewerkingen op items
'' ==========================================================================

Function OpenAantal(ByVal idx As Integer) As Integer
    Dim i As Integer, n As Integer
    n = 0
    For i = 1 To lijst(idx).aantal
        If lijst(idx).item(i).soort = 0 Then
            If lijst(idx).item(i).klaar = 0 Then n = n + 1
        End If
    Next
    OpenAantal = n
End Function

Sub ZorgZichtbaar()
    Dim hoog As Integer

    If nLijsten = 0 Then Exit Sub
    hoog = rBot - rTop + 1

    If lijst(curL).cur < 1 Then lijst(curL).cur = 1
    If lijst(curL).cur > lijst(curL).aantal Then lijst(curL).cur = lijst(curL).aantal
    If lijst(curL).cur < 1 Then lijst(curL).cur = 1

    If lijst(curL).top < 1 Then lijst(curL).top = 1
    If lijst(curL).cur < lijst(curL).top Then lijst(curL).top = lijst(curL).cur
    If lijst(curL).cur > lijst(curL).top + hoog - 1 Then lijst(curL).top = lijst(curL).cur - hoog + 1
    If lijst(curL).top < 1 Then lijst(curL).top = 1

    If curL < lTop Then lTop = curL
    If curL > lTop + hoog - 1 Then lTop = curL - hoog + 1
    If lTop < 1 Then lTop = 1
End Sub

Sub NieuwItem()
    Dim i As Integer, p As Integer, d As Integer
    Dim ok As Integer
    Dim leeg As String, res As String
    Dim r As Integer, c As Integer, w As Integer

    If nLijsten = 0 Then
        Melden Vt("Maak eerst een lijstje aan (F4).")
        Exit Sub
    End If
    If lijst(curL).aantal >= MAX_ITEMS Then
        Melden Tn("Dit lijstje is vol (%1 regels).", Trim(Str(MAX_ITEMS)), "", "")
        Exit Sub
    End If

    d = 0
    p = lijst(curL).cur
    If lijst(curL).aantal > 0 Then
        If p >= 1 And p <= lijst(curL).aantal Then d = lijst(curL).item(p).diepte
        p = p + 1
    Else
        p = 1
    End If

    For i = lijst(curL).aantal To p Step -1
        lijst(curL).item(i + 1) = lijst(curL).item(i)
    Next
    lijst(curL).aantal = lijst(curL).aantal + 1
    lijst(curL).item(p).txt    = ""
    lijst(curL).item(p).klaar  = 0
    lijst(curL).item(p).diepte = d
    lijst(curL).item(p).soort  = 0
    lijst(curL).cur = p

    ZorgZichtbaar
    Redraw

    r = rTop + (p - lijst(curL).top)
    c = LP + 2 + d * 2 + 4
    w = scrW - 1 - c + 1
    leeg = ""
    res = RegelEdit(r, c, w, leeg, ok)

    If ok = 0 Or Len(Trim(res)) = 0 Then
        For i = p To lijst(curL).aantal - 1
            lijst(curL).item(i) = lijst(curL).item(i + 1)
        Next
        lijst(curL).aantal = lijst(curL).aantal - 1
        If lijst(curL).cur > lijst(curL).aantal Then lijst(curL).cur = lijst(curL).aantal
    Else
        lijst(curL).item(p).txt = res
        SlaLijstOp curL
    End If
    Redraw
End Sub

Sub BewerkItem()
    Dim p As Integer, r As Integer, c As Integer, w As Integer
    Dim i As Integer, ok As Integer
    Dim res As String

    If nLijsten = 0 Then Exit Sub
    If lijst(curL).aantal = 0 Then Exit Sub

    p = lijst(curL).cur
    ZorgZichtbaar
    Redraw

    r = rTop + (p - lijst(curL).top)
    c = LP + 2 + lijst(curL).item(p).diepte * 2
    If lijst(curL).item(p).soort = 0 Then c = c + 4 Else c = c + 2
    w = scrW - 1 - c + 1

    res = RegelEdit(r, c, w, lijst(curL).item(p).txt, ok)
    If ok Then
        If Len(Trim(res)) = 0 Then
            If Bevestig(Vt("Regel is leeg. Item verwijderen?")) Then
                For i = p To lijst(curL).aantal - 1
                    lijst(curL).item(i) = lijst(curL).item(i + 1)
                Next
                lijst(curL).aantal = lijst(curL).aantal - 1
            End If
        Else
            lijst(curL).item(p).txt = res
        End If
        SlaLijstOp curL
    End If
    Redraw
End Sub

Sub VerwijderItem()
    Dim i As Integer, p As Integer

    If nLijsten = 0 Then Exit Sub
    If lijst(curL).aantal = 0 Then Exit Sub

    p = lijst(curL).cur
    If Bevestig(Tn("Item '%1' verwijderen?", Kort(lijst(curL).item(p).txt, 30), "", "")) = 0 Then Exit Sub

    For i = p To lijst(curL).aantal - 1
        lijst(curL).item(i) = lijst(curL).item(i + 1)
    Next
    lijst(curL).aantal = lijst(curL).aantal - 1
    If lijst(curL).cur > lijst(curL).aantal Then lijst(curL).cur = lijst(curL).aantal
    SlaLijstOp curL
End Sub

Sub VinkItem()
    Dim p As Integer

    If nLijsten = 0 Then Exit Sub
    If lijst(curL).aantal = 0 Then Exit Sub
    p = lijst(curL).cur
    If lijst(curL).item(p).soort <> 0 Then Exit Sub

    lijst(curL).item(p).klaar = Not lijst(curL).item(p).klaar
    SlaLijstOp curL
End Sub

Sub VerplaatsItem(ByVal richting As Integer)
    Dim p As Integer, q As Integer
    Dim tmp As ItemType

    If nLijsten = 0 Then Exit Sub
    If lijst(curL).aantal < 2 Then Exit Sub

    p = lijst(curL).cur
    q = p + richting
    If q < 1 Then Exit Sub
    If q > lijst(curL).aantal Then Exit Sub

    tmp = lijst(curL).item(p)
    lijst(curL).item(p) = lijst(curL).item(q)
    lijst(curL).item(q) = tmp
    lijst(curL).cur = q
    SlaLijstOp curL
End Sub

Sub ZetDiepte(ByVal delta As Integer)
    Dim p As Integer, d As Integer

    If nLijsten = 0 Then Exit Sub
    If lijst(curL).aantal = 0 Then Exit Sub

    p = lijst(curL).cur
    d = lijst(curL).item(p).diepte + delta
    If d < 0 Then d = 0
    If d > 3 Then d = 3
    lijst(curL).item(p).diepte = d
    SlaLijstOp curL
End Sub

Sub WisselSoort()
    Dim p As Integer

    If nLijsten = 0 Then Exit Sub
    If lijst(curL).aantal = 0 Then Exit Sub

    p = lijst(curL).cur
    If lijst(curL).item(p).soort = 0 Then
        lijst(curL).item(p).soort = 1
        lijst(curL).item(p).klaar = 0
    Else
        lijst(curL).item(p).soort = 0
    End If
    SlaLijstOp curL
End Sub

'' Afgevinkte items naar onderen, oorspronkelijke volgorde blijft behouden.
Sub SorteerLijst()
    Dim buf(1 To MAX_ITEMS) As ItemType
    Dim i As Integer, n As Integer

    If nLijsten = 0 Then Exit Sub
    If lijst(curL).aantal < 2 Then Exit Sub

    n = 0
    For i = 1 To lijst(curL).aantal
        If lijst(curL).item(i).klaar = 0 Then
            n = n + 1 : buf(n) = lijst(curL).item(i)
        End If
    Next
    For i = 1 To lijst(curL).aantal
        If lijst(curL).item(i).klaar <> 0 Then
            n = n + 1 : buf(n) = lijst(curL).item(i)
        End If
    Next
    For i = 1 To n
        lijst(curL).item(i) = buf(i)
    Next

    lijst(curL).cur = 1
    lijst(curL).top = 1
    SlaLijstOp curL
    melding = Vt("Gesorteerd: afgevinkte items onderaan.")
End Sub

Sub WisAfgevinkt()
    Dim i As Integer, n As Integer, weg As Integer

    If nLijsten = 0 Then Exit Sub
    weg = 0
    For i = 1 To lijst(curL).aantal
        If lijst(curL).item(i).klaar <> 0 Then weg = weg + 1
    Next
    If weg = 0 Then
        Melden Vt("Er zijn geen afgevinkte items.")
        Exit Sub
    End If
    If Bevestig(Tn("%1 afgevinkte item(s) definitief wissen?", Trim(Str(weg)), "", "")) = 0 Then Exit Sub

    n = 0
    For i = 1 To lijst(curL).aantal
        If lijst(curL).item(i).klaar = 0 Then
            n = n + 1
            If n <> i Then lijst(curL).item(n) = lijst(curL).item(i)
        End If
    Next
    lijst(curL).aantal = n
    lijst(curL).cur = 1
    lijst(curL).top = 1
    SlaLijstOp curL
    melding = Tn("%1 item(s) gewist.", Trim(Str(weg)), "", "")
End Sub

'' Zet alle vinkjes van het huidige lijstje uit, zodat je het opnieuw kunt
'' aflopen. Bewaart eerst de oude toestand, zodat ResetTerug het kan herstellen
'' -- daarom is hier geen bevestigingsvraag nodig en blijft het één toets.
Sub ResetLijst()
    Dim i As Integer, n As Integer

    If nLijsten = 0 Then Exit Sub
    If lijst(curL).aantal = 0 Then Exit Sub

    n = 0
    For i = 1 To lijst(curL).aantal
        If lijst(curL).item(i).klaar <> 0 Then n = n + 1
    Next
    If n = 0 Then
        melding = Vt("In dit lijstje staat niets aangevinkt.")
        Exit Sub
    End If

    undoL = curL
    undoN = lijst(curL).aantal
    For i = 1 To undoN
        undoKlaar(i) = lijst(curL).item(i).klaar
        lijst(curL).item(i).klaar = 0
    Next

    SlaLijstOp curL
    melding = Tn("%1 vinkje(s) gewist", Trim(Str(n)), "", "") + "  " + gPunt + "  " + Vt("u maakt dit ongedaan")
End Sub

'' Draait de laatste reset terug. Weigert als het lijstje sindsdien van lengte
'' is veranderd, want dan sluiten de posities niet meer aan.
Sub ResetTerug()
    Dim i As Integer

    If undoL = 0 Then
        melding = Vt("Er is geen reset om ongedaan te maken.")
        Exit Sub
    End If
    If undoL > nLijsten Then
        undoL = 0
        melding = Vt("Dat lijstje bestaat niet meer.")
        Exit Sub
    End If
    If lijst(undoL).aantal <> undoN Then
        undoL = 0
        melding = Vt("Het lijstje is sindsdien gewijzigd; niet teruggedraaid.")
        Exit Sub
    End If

    For i = 1 To undoN
        lijst(undoL).item(i).klaar = undoKlaar(i)
    Next
    curL = undoL
    SlaLijstOp curL
    undoL = 0
    melding = Vt("Reset teruggedraaid.")
End Sub

'' Volg een verwijzing [[Titel]] naar een ander lijstje.
Sub VolgLink()
    Dim s As String, doel As String
    Dim p As Integer, q As Integer, i As Integer

    If nLijsten = 0 Then Exit Sub
    If lijst(curL).aantal = 0 Then Exit Sub

    s = lijst(curL).item(lijst(curL).cur).txt
    p = InStr(s, "[[")
    If p = 0 Then
        Melden Vt("Geen verwijzing [[...]] op deze regel.")
        Exit Sub
    End If
    q = InStr(p + 2, s, "]]")
    If q = 0 Then
        Melden Vt("Onafgesloten verwijzing op deze regel.")
        Exit Sub
    End If

    doel = Trim(Mid(s, p + 2, q - p - 2))
    For i = 1 To nLijsten
        If LCase(lijst(i).titel) = LCase(doel) Then
            curL   = i
            paneel = 1
            melding = Tn("Gesprongen naar '%1'.", lijst(i).titel, "", "")
            Exit Sub
        End If
    Next
    Melden Tn("Geen lijstje met de titel '%1'.", doel, "", "")
End Sub

Sub KiesKleur()
    If nLijsten = 0 Then Exit Sub
    lijst(curL).kleur = lijst(curL).kleur + 1
    If lijst(curL).kleur > 15 Then lijst(curL).kleur = 9
    SlaLijstOp curL
End Sub

'' ==========================================================================
''  Zoeken
'' ==========================================================================

Sub Zoek()
    Dim hitL(1 To MAX_HITS) As Integer
    Dim hitI(1 To MAX_HITS) As Integer
    Dim n As Integer, l As Integer, i As Integer
    Dim ok As Integer, ext As Integer, t As Integer
    Dim term As String, s As String
    Dim sel As Integer, hTop As Integer
    Dim r As Integer, c As Integer, w As Integer, h As Integer, rijen As Integer
    Dim leeg As String

    leeg = ""
    ok = 0
    term = VraagTekst(Vt("Zoeken"), Vt("Zoek naar (in alle lijstjes):"), leeg, ok)
    If ok = 0 Then Exit Sub
    term = Trim(term)
    If Len(term) = 0 Then Exit Sub

    n = 0
    For l = 1 To nLijsten
        For i = 1 To lijst(l).aantal
            If InStr(LCase(lijst(l).item(i).txt), LCase(term)) > 0 Then
                If n < MAX_HITS Then
                    n = n + 1
                    hitL(n) = l
                    hitI(n) = i
                End If
            End If
        Next
    Next

    If n = 0 Then
        Melden Tn("Niets gevonden voor '%1'.", term, "", "")
        Exit Sub
    End If

    w = scrW - 10
    If w > 76 Then w = 76
    h = n + 6
    If h > scrH - 4 Then h = scrH - 4
    If h < 9 Then h = 9
    rijen = h - 5
    r = (scrH - h) \ 2 + 1
    c = (scrW - w) \ 2 + 1
    sel = 1
    hTop = 1

    Do
        If sel < hTop Then hTop = sel
        If sel > hTop + rijen - 1 Then hTop = sel - rijen + 1

        Venster r, c, h, w, Tn("Gevonden: %1", Trim(Str(n)), "", "")
        For i = 0 To rijen - 1
            If hTop + i <= n Then
                l = hitL(hTop + i)
                s = " " + Pad(Kort(lijst(l).titel, 16), 16) + " " + gPijl + " " + lijst(l).item(hitI(hTop + i)).txt
                If hTop + i = sel Then
                    PutStr r + 1 + i, c + 1, Pad(s, w - 2), C_SEL_FG, C_SEL_BG
                Else
                    PutStr r + 1 + i, c + 1, Pad(s, w - 2), C_DLG_FG, C_DLG_BG
                End If
            End If
        Next
        PutStr r + h - 2, c + 2, Vt("Enter = ga er naartoe   Esc = sluiten"), C_DLG_FG, C_DLG_BG

        ext = 0
        t = WachtToets(ext)
        If ext Then
            Select Case t
            Case 72 : If sel > 1 Then sel = sel - 1
            Case 80 : If sel < n Then sel = sel + 1
            Case 73
                sel = sel - rijen
                If sel < 1 Then sel = 1
            Case 81
                sel = sel + rijen
                If sel > n Then sel = n
            Case 71 : sel = 1
            Case 79 : sel = n
            End Select
        Else
            Select Case t
            Case 13
                curL = hitL(sel)
                lijst(curL).cur = hitI(sel)
                paneel = 1
                melding = Tn("Gevonden in '%1'.", lijst(curL).titel, "", "")
                Exit Do
            Case 27
                Exit Do
            End Select
        End If
    Loop

    ZorgZichtbaar
    Redraw
End Sub

'' ==========================================================================
''  Tekenen
'' ==========================================================================

Sub TekenKader()
    Dim i As Integer
    Dim s As String

    '' titelbalk
    s = " " + APP_NAAM + " " + APP_VER
    PutStr 1, 1, Pad(s, scrW), C_BALK_FG, C_BALK_BG

    '' bovenrand met paneelkoppen
    s = gTL + String(LP - 1, gH) + gTd + String(scrW - LP - 2, gH) + gTR
    PutStr 2, 1, s, C_RAND, C_BG
    PutStr 2, 3, " " + Vt("Lijstjes") + " ", C_RAND, C_BG
    If nLijsten > 0 Then
        s = " " + Kort(lijst(curL).titel, scrW - LP - 8) + " "
    Else
        s = " " + Vt("(geen lijstjes)") + " "
    End If
    PutStr 2, LP + 3, s, 14, C_BG

    '' zijranden
    For i = rTop To rBot
        PutStr i, 1, gV, C_RAND, C_BG
        PutStr i, LP + 1, gV, C_RAND, C_BG
        PutStr i, scrW, gV, C_RAND, C_BG
    Next

    '' onderrand
    s = gBL + String(LP - 1, gH) + gBd + String(scrW - LP - 2, gH) + gBR
    PutStr scrH - 2, 1, s, C_RAND, C_BG
End Sub

Sub TekenLijsten()
    Dim i As Integer, idx As Integer, rijen As Integer
    Dim s As String, telling As String
    Dim breed As Integer, fg As Integer, bg As Integer

    rijen = rBot - rTop + 1
    breed = LP - 1

    For i = 0 To rijen - 1
        idx = lTop + i
        If idx <= nLijsten Then
            telling = Trim(Str(OpenAantal(idx))) + "/" + Trim(Str(lijst(idx).aantal))
            s = " " + Pad(Kort(lijst(idx).titel, breed - Len(telling) - 3), breed - Len(telling) - 2) + telling + " "

            If idx = curL Then
                If paneel = 0 Then
                    fg = C_SEL_FG : bg = C_SEL_BG
                Else
                    fg = C_SEL2_FG : bg = C_BG
                End If
            Else
                fg = lijst(idx).kleur : bg = C_BG
            End If
            PutStr rTop + i, 2, Pad(s, breed), fg, bg
        Else
            PutStr rTop + i, 2, Space(breed), C_RAND, C_BG
        End If
    Next
End Sub

Sub TekenItems()
    Dim i As Integer, idx As Integer, rijen As Integer
    Dim breed As Integer, kol As Integer
    Dim s As String, vak As String
    Dim fg As Integer, bg As Integer

    kol   = LP + 2
    breed = scrW - 1 - kol + 1
    rijen = rBot - rTop + 1

    If nLijsten = 0 Then
        For i = 0 To rijen - 1
            PutStr rTop + i, kol, Space(breed), C_RAND, C_BG
        Next
        PutStr rTop + 1, kol + 2, Vt("Nog geen lijstjes. Druk op F4 om er een aan te maken."), C_NOTE, C_BG
        Exit Sub
    End If

    For i = 0 To rijen - 1
        idx = lijst(curL).top + i
        If idx <= lijst(curL).aantal Then
            If lijst(curL).item(idx).soort = 0 Then
                If lijst(curL).item(idx).klaar Then
                    vak = "[" + gVink + "] "
                Else
                    vak = "[ ] "
                End If
            Else
                vak = "  "
            End If
            s = " " + Space(lijst(curL).item(idx).diepte * 2) + vak + lijst(curL).item(idx).txt

            If lijst(curL).item(idx).klaar Then
                fg = C_KLAAR
            ElseIf lijst(curL).item(idx).soort = 1 Then
                fg = C_NOTE
            ElseIf InStr(lijst(curL).item(idx).txt, "[[") > 0 Then
                fg = C_LINK
            Else
                fg = C_TXT
            End If
            bg = C_BG

            If idx = lijst(curL).cur Then
                If paneel = 1 Then
                    fg = C_SEL_FG : bg = C_SEL_BG
                Else
                    fg = C_SEL2_FG
                End If
            End If
            PutStr rTop + i, kol, Pad(Kort(s, breed), breed), fg, bg
        Else
            PutStr rTop + i, kol, Space(breed), C_RAND, C_BG
        End If
    Next

    If lijst(curL).aantal = 0 Then
        PutStr rTop, kol + 2, Vt("Leeg lijstje") + " " + gPunt + " " + Vt("F3 voor een nieuw item"), C_NOTE, C_BG
    End If
End Sub

Sub TekenStatus()
    Dim s As String

    If Len(melding) > 0 Then
        s = " " + melding
        melding = ""
    ElseIf nLijsten = 0 Then
        s = " " + Vt("Geen lijstjes in") + " " + dataMap
    Else
        s = " " + Vt("Lijstje") + " " + Trim(Str(curL)) + "/" + Trim(Str(nLijsten)) + _
            "  " + gPunt + "  " + Vt("regel") + " " + Trim(Str(lijst(curL).cur)) + "/" + Trim(Str(lijst(curL).aantal)) + _
            "  " + gPunt + "  " + Trim(Str(OpenAantal(curL))) + " " + Vt("open") + _
            "  " + gPunt + "  " + lijst(curL).bestand
    End If
    PutStr scrH - 1, 1, Pad(s, scrW), 15, C_BG
End Sub

Sub TekenHelp()
    Dim s As String

    If paneel = 0 Then
        s = " " + Vt("F1 Hulp F2 Naam F4 Nieuw F5 Wis F9 Zoek r Reset ~ Kleur ^Q Stop Tab") + " " + gPijl + Vt("items")
    Else
        s = " " + Vt("F1 Hulp F2 Bewerk F3 Nieuw F5 Wis F6/F7 Schuif F9 Zoek r Reset u Terug ^Q Stop")
    End If
    PutStr scrH, 1, Pad(s, scrW), C_BALK_FG, C_BALK_BG
End Sub

Sub Redraw()
    ZorgZichtbaar
    ScreenLock
    TekenKader
    TekenLijsten
    TekenItems
    TekenStatus
    TekenHelp
    ScreenUnlock
    Locate , , 0
End Sub

'' ==========================================================================
''  Hoofdprogramma
'' ==========================================================================

Dim i As Integer, t As Integer, ext As Integer, p As Integer
Dim klaar As Integer, asciiModus As Integer
Dim arg As String, s As String

'' Grafisch venster: FB vangt daar de speciale toetsen op elk platform
'' betrouwbaar af, en alleen daar is het volledige CP437-font beschikbaar.
asciiModus = 0
fontSchaal = 1
venMaxB    = 0
venMaxH    = 0
schaalGezet = 0
dataMap    = ExePath + SEP + "data"

For i = 1 To 8
    arg = Command(i)
    If Len(arg) = 0 Then Exit For
    If LCase(arg) = "-a" Then
        asciiModus = -1
    ElseIf LCase(arg) = "-c" Then
        asciiModus = 0
    ElseIf LCase(Left(arg, 2)) = "-z" Then
        fontSchaal  = Val(Mid(arg, 3))
        If fontSchaal < 1 Then fontSchaal = 1
        schaalGezet = -1
    ElseIf LCase(Left(arg, 2)) = "-w" Then
        '' -wBREEDTExHOOGTE, bijvoorbeeld -w640x480
        s = LCase(Mid(arg, 3))
        p = InStr(s, "x")
        If p > 0 Then
            venMaxB = Val(Left(s, p - 1))
            venMaxH = Val(Mid(s, p + 1))
        End If
    ElseIf Left(arg, 1) <> "-" Then
        dataMap = arg
    End If
Next

ZetGlyphs asciiModus
MkDir dataMap

'' Instellingen (taal, en -- tenzij -z hem al vastzette -- ook de schaal)
'' weer oppakken.
LaadInstellingen

If SchermInit() = 0 Then
    Print Tn(APP_NAAM + ": er is te weinig ruimte (minimaal %1 x %2 tekens).", _
             Trim(Str(MIN_KOL)), Trim(Str(MIN_RIJ)), "")
    Print Vt("Maak het venster of de terminal groter, of kies een kleinere schaal.")
    End 1
End If

LaadAlles
If nLijsten = 0 Then MaakDemo

curL   = 1
lTop   = 1
paneel = 0
klaar  = 0
melding = Vt("Welkom") + " " + gPunt + " " + Vt("F1 voor hulp")

Redraw

Do
    ext = 0
    t = WachtToets(ext)

    If ext Then
        '' ---------------- uitgebreide toetsen ----------------
        Select Case t
        Case 59                                     '' F1
            ToonHelp
        Case 60                                     '' F2
            If paneel = 0 Then HernoemLijst Else BewerkItem
        Case 61                                     '' F3
            If paneel = 0 Then NieuweLijst Else NieuwItem
        Case 62                                     '' F4
            NieuweLijst
        Case 63                                     '' F5
            If paneel = 0 Then VerwijderLijst Else VerwijderItem
        Case 64                                     '' F6
            VerplaatsItem -1
        Case 65                                     '' F7
            VerplaatsItem 1
        Case 67                                     '' F9
            Zoek
        Case 68                                     '' F10
            klaar = -1
        Case 107                                    '' sluitknop van het venster
            klaar = -1
        Case 133                                    '' F11: kleiner
            SchaalWijzig -1
        Case 134                                    '' F12: groter
            SchaalWijzig 1
        Case 72                                     '' pijl omhoog
            If paneel = 0 Then
                If curL > 1 Then curL = curL - 1
            Else
                If lijst(curL).cur > 1 Then lijst(curL).cur = lijst(curL).cur - 1
            End If
        Case 80                                     '' pijl omlaag
            If paneel = 0 Then
                If curL < nLijsten Then curL = curL + 1
            Else
                If lijst(curL).cur < lijst(curL).aantal Then lijst(curL).cur = lijst(curL).cur + 1
            End If
        Case 75                                     '' pijl links
            If paneel = 1 Then
                If lijst(curL).aantal > 0 Then
                    If lijst(curL).item(lijst(curL).cur).diepte > 0 Then
                        ZetDiepte -1
                    Else
                        paneel = 0
                    End If
                Else
                    paneel = 0
                End If
            End If
        Case 77                                     '' pijl rechts
            If paneel = 0 Then
                paneel = 1
            Else
                ZetDiepte 1
            End If
        Case 73                                     '' PgUp
            If paneel = 0 Then
                curL = curL - (rBot - rTop)
                If curL < 1 Then curL = 1
            Else
                lijst(curL).cur = lijst(curL).cur - (rBot - rTop)
                If lijst(curL).cur < 1 Then lijst(curL).cur = 1
            End If
        Case 81                                     '' PgDn
            If paneel = 0 Then
                curL = curL + (rBot - rTop)
                If curL > nLijsten Then curL = nLijsten
            Else
                lijst(curL).cur = lijst(curL).cur + (rBot - rTop)
                If lijst(curL).cur > lijst(curL).aantal Then lijst(curL).cur = lijst(curL).aantal
            End If
        Case 71                                     '' Home
            If paneel = 0 Then curL = 1 Else lijst(curL).cur = 1
        Case 79                                     '' End
            If paneel = 0 Then curL = nLijsten Else lijst(curL).cur = lijst(curL).aantal
        Case 82                                     '' Insert
            If paneel = 1 Then NieuwItem Else NieuweLijst
        Case 83                                     '' Delete
            If paneel = 0 Then VerwijderLijst Else VerwijderItem
        End Select
    Else
        '' ---------------- gewone toetsen ----------------
        Select Case t
        Case 9                                      '' Tab
            If paneel = 0 Then paneel = 1 Else paneel = 0
        Case 13                                     '' Enter
            If paneel = 0 Then paneel = 1 Else VinkItem
        Case 32                                     '' spatie
            If paneel = 1 Then VinkItem Else paneel = 1
        Case 27                                     '' Esc
            If Bevestig(Tn("%1 afsluiten?", APP_NAAM, "", "")) Then klaar = -1
        Case 17                                     '' Ctrl+Q: stoppen
            '' Nodig omdat F10 op Windows een systeemtoets is: die activeert het
            '' venstermenu en bereikt Inkey daar niet.
            klaar = -1
        Case 6                                      '' Ctrl+F
            Zoek
        Case 19                                     '' Ctrl+S
            SlaAllesOp
            melding = Vt("Alle lijstjes opgeslagen in") + " " + dataMap
        Case Asc("s"), Asc("S")
            If paneel = 1 Then SorteerLijst
        Case Asc("c"), Asc("C")
            If paneel = 1 Then WisAfgevinkt
        Case Asc("t"), Asc("T")
            If paneel = 1 Then WisselSoort
        Case Asc("g"), Asc("G")
            If paneel = 1 Then VolgLink
        Case Asc("e"), Asc("E")
            If paneel = 1 Then BewerkItem
        Case Asc("n"), Asc("N")
            If paneel = 1 Then NieuwItem Else NieuweLijst
        Case Asc("r"), Asc("R")
            ResetLijst
        Case Asc("u"), Asc("U")
            ResetTerug
        Case Asc("~")
            KiesKleur
        Case 43, 61                                 '' + en =  : groter
            SchaalWijzig 1
        Case 45, 95                                 '' - en _  : kleiner
            SchaalWijzig -1
        End Select
    End If

    If klaar Then Exit Do
    Redraw
Loop

SlaAllesOp
Screen 0
Color 7, 0
Cls
Locate , , 1
Print APP_NAAM + " " + APP_VER + " - " + Vt("alles opgeslagen in") + " " + dataMap
Print Tn("%1 lijstje(s). Tot ziens!", Trim(Str(nLijsten)), "", "")
End
