# Keytone

Sonidos de teclado mecánico para macOS. Vive en la barra de menús y hace que cada tecla que pulsas suene como un interruptor de verdad.

Inspirada en [Klack](https://tryklack.com/), con estas mejoras:

| | Klack | Keytone |
|---|---|---|
| Sonidos de serie | 6 interruptores | **18 perfiles** (clicky, táctiles, lineales, vintage y divertidos) |
| Packs de la comunidad | — | **Importa packs de Mechvibes** (cientos gratis) o carpetas con tus audios |
| Variación natural | Sí | Tono, fuerza y 6 variantes por tecla, sin repetir la misma muestra dos veces seguidas |
| Estéreo por posición | Sí | Sí, con amplitud ajustable |
| Sonido al soltar | Sí | Sí, con brillo propio de cada interruptor |
| Dinámica al escribir rápido | — | Las pulsaciones rápidas suenan más suaves, como en la realidad |
| Clics de ratón | — | Opcional |
| Silenciar por app | — | Lista de apps (Zoom, Teams…) + botón «Silenciar en esta app» |
| Atajo global | — | **⌥⇧⌘K** activa o silencia desde cualquier sitio |
| Estadísticas | — | Teclas de hoy, totales y palabras por minuto en directo |
| Limitador de picos | — | No satura aunque escribas muy rápido |
| Precio | De pago | Gratis |

## Interruptores incluidos

- **Clicky:** MX Blue, Box Jade, Alps Blue
- **Táctiles:** MX Brown, Holy Panda, Topre
- **Lineales:** MX Red, MX Black, Gateron Yellow, NK Cream, Aluminio Thock, Mármol, Silent Alpaca, Portátil
- **Vintage:** IBM Model M (buckling spring), Máquina de escribir (con retorno de carro y campanita en Enter)
- **Divertidos:** Burbujas, Arcade 8-bit

Los sonidos de serie se **sintetizan en tiempo real** a partir de la física del interruptor (clic, bache táctil, golpe contra el fondo, resonancias de carcasa, estabilizador y muelle). Espacio, Enter, Retroceso y modificadores suenan distinto, igual que en un teclado real.

Para sonidos **grabados** de teclados reales, importa packs de Mechvibes.

## Instalar

1. Descarga `Keytone.dmg` desde la pestaña **Actions** (último build en verde → *Artifacts*) o desde **Releases**.
2. Arrastra **Keytone** a **Aplicaciones**.
3. La primera vez: clic derecho sobre la app → **Abrir** (no está notarizada por Apple). Si macOS dice que está «dañada»:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Keytone.app
   ```
4. Concede **Ajustes del Sistema → Privacidad y seguridad → Monitorización de entrada** a Keytone. Si no empieza a sonar, pulsa «Reiniciar Keytone» en la ventana de bienvenida.

> Keytone solo escucha *qué* tecla se pulsa para reproducir el sonido. No guarda ni envía lo que escribes. En campos de contraseña macOS bloquea la escucha, así que ahí no suena.

Requiere macOS 13 Ventura o posterior. Binario universal (Apple Silicon e Intel).

## Importar packs de Mechvibes

1. Descarga un pack (carpeta con `config.json` y sus audios) y descomprímelo.
2. Ajustes → **Sonidos** → **Importar…** y elige la carpeta.

Formatos: WAV, MP3, M4A, AIFF, CAF y FLAC. Muchos packs usan `.ogg`, que macOS no lee; conviértelos antes con:

```bash
for f in *.ogg; do ffmpeg -i "$f" "${f%.ogg}.wav"; done
sed -i '' 's/\.ogg/.wav/g' config.json
```

También puedes importar una carpeta con tus propios audios. Keytone los clasifica por el nombre: `space`, `enter`, `backspace`, `shift`, `mouse` y, para soltar la tecla, `release` o `up` (por ejemplo `press1.wav`, `space.wav`, `enter_up.wav`).

## Compilar desde el código

Necesitas Xcode 15 o posterior.

```bash
swift test                    # tests del motor de sonido
./scripts/build-app.sh        # genera dist/Keytone.app, .zip y .dmg
open dist/Keytone.app
```

`ARCHS=arm64 ./scripts/build-app.sh` compila solo para Apple Silicon (más rápido). Con `SIGN_IDENTITY="Developer ID Application: …"` firma con tu certificado.

Cada vez que recompilas con firma ad-hoc, macOS trata la app como nueva y hay que volver a dar el permiso de Monitorización de entrada (quita la entrada antigua de la lista y añade la nueva).

## Estructura

```
Sources/KeytoneCore/   Motor de sonido sin dependencias de interfaz (síntesis, DSP, packs de Mechvibes)
Sources/Keytone/       App: captura de teclas, audio (AVAudioEngine), barra de menús y ajustes (SwiftUI)
Tests/                 Tests del motor
scripts/build-app.sh   Empaquetado de .app, .zip y .dmg
```
