# Local Inter faces

FLEX uses Inter at optical size 14, with separate 400, 600 and 700 faces for
Flutter, PDF export and UI tests. No runtime font service is required.

Source: [Google Fonts Inter](https://github.com/google/fonts/tree/main/ofl/inter).
License: [SIL Open Font License 1.1](Inter-OFL.txt).

The source `Inter[opsz,wght].ttf`, downloaded on 2026-11-10, has SHA-256
`29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031`.
Static faces were generated with fontTools 4.61.1:

```python
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

for weight, name in [(400, 'Regular'), (600, 'Semibold'), (700, 'Bold')]:
    font = TTFont('Inter[opsz,wght].ttf')
    instantiateVariableFont(
        font, {'opsz': 14, 'wght': weight},
        inplace=True, updateFontNames=True,
    )
    font.save(f'Inter-{name}.ttf')
```

Keep `updateFontNames=True`: each face needs its own internal name for correct
weight selection in CanvasKit. The app's `FlexSans` alias is declared in
`pubspec.yaml`; tests load the same files via `test/support/app_test_fonts.dart`.
