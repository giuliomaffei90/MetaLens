# MetaLens

Visualizzatore ed editor di metadati per file audio, video e immagini. App macOS nativa in
SwiftUI; legge e scrive tramite FFmpeg, così restano supportati MKV, sottotitoli e capitoli.

## Requisiti

- macOS 14 o successivo, Xcode (o le Command Line Tools) per compilare
- FFmpeg (`ffprobe` e `ffmpeg`) nel PATH: `brew install ffmpeg`

## Sviluppo

```bash
swift build                 # compila
swift test                  # test di lettura/scrittura metadati (richiede FFmpeg)
Scripts/bundle.sh           # crea .build/MetaLens.app
open .build/MetaLens.app    # avvia
```

Puoi anche aprire `Package.swift` con Xcode.

Da terminale l'app accetta un file: `.build/MetaLens.app/Contents/MacOS/MetaLens video.mkv`.

## Struttura

- `Sources/MetaLensKit` — FFmpeg, modello dati e formattazione (testabile, senza interfaccia)
- `Sources/MetaLens` — interfaccia SwiftUI (NavigationSplitView + Form nativi)
- `AppIcon.icon` — progetto Icon Composer (Liquid Glass); aprilo con
  `open -a "Icon Composer" AppIcon.icon`. `Scripts/bundle.sh` lo compila con `actool`
  in `Assets.car` + `AppIcon.icns`.
- `Resources` — Info.plist
