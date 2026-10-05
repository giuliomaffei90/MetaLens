# MetaLens

Visualizzatore ed editor di metadati per file audio, video e immagini. App macOS nativa in
SwiftUI; legge e scrive tramite FFmpeg, così restano supportati MKV, sottotitoli e capitoli.

## Requisiti

- macOS 14 o successivo (su macOS 26+ l'interfaccia adotta Liquid Glass; sui sistemi
  precedenti gli stessi comandi usano l'aspetto classico)
- Xcode (o le Command Line Tools) per compilare
- FFmpeg (`ffprobe` e `ffmpeg`) nel PATH: `brew install ffmpeg`

## Sviluppo

```bash
swift build                 # compila
swift test                  # test di lettura/scrittura metadati (richiede FFmpeg)
Scripts/bundle.sh           # crea .build/MetaLens.app
open .build/MetaLens.app    # avvia
```

Puoi anche aprire `Package.swift` con Xcode.

`Scripts/bundle.sh` marchia il binario con l'SDK reale (`-platform_version`): senza, SwiftPM
registra come SDK il target minimo e macOS disegnerebbe l'app con l'aspetto di macOS 14.
La soglia minima è in `MIN_MACOS` nello script, in `Package.swift` e in `Resources/Info.plist`:
vanno cambiate insieme.

Da terminale l'app accetta un file: `.build/MetaLens.app/Contents/MacOS/MetaLens video.mkv`.

## Struttura

- `Sources/MetaLensKit` — FFmpeg, modello dati e formattazione (testabile, senza interfaccia)
- `Sources/MetaLens` — interfaccia SwiftUI (NavigationSplitView + Form nativi)
- `AppIcon.icon` — progetto Icon Composer (Liquid Glass); aprilo con
  `open -a "Icon Composer" AppIcon.icon`. `Scripts/bundle.sh` lo compila con `actool`
  in `Assets.car` + `AppIcon.icns`.
- `Resources` — Info.plist e traduzioni: le stringhe nel codice sono in italiano e fanno da chiave,
  `en.lproj` contiene l'inglese (le lingue non tradotte ricadono sull'inglese)
