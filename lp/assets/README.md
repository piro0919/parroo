# assets

`NotoSansJP-Bold-subset.ttf` is the face drawn into the Open Graph card
(`src/app/[locale]/opengraph-image.tsx`). The site itself uses the system face
(SF Pro and Hiragino on a Mac) with Noto Sans JP as the fallback, so the card
uses Noto Sans JP Bold, cut down to the characters the card actually shows.

Any character missing from it silently falls back to a different face, so when
the card's copy changes, rebuild the subset:

```sh
curl -sL -o /tmp/NotoSansJP.ttf \
  "https://github.com/google/fonts/raw/main/ofl/notosansjp/NotoSansJP%5Bwght%5D.ttf"

python3 -m fontTools.varLib.instancer /tmp/NotoSansJP.ttf wght=700 -o /tmp/NotoSansJP-Bold.ttf

pyftsubset /tmp/NotoSansJP-Bold.ttf \
  --text="Parroo When does my week reset? 週の枠、いつリセット？" \
  --unicodes="U+0020-007E" \
  --output-file=assets/NotoSansJP-Bold-subset.ttf \
  --no-hinting --desubroutinize --layout-features=''
```
