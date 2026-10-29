# Contra 4 jugadores: notas técnicas

Hack de Contra (USA) para 4 jugadores con el adaptador **Four Score**, hecho sobre
el desensamblado `vermiceli/nes-contra-us`. Las rutinas tocadas llevan el
comentario `4-player hack`. La descripción del juego para jugadores está en [README.md](README.md).

## Compilar

1. `build.ps1` una vez (extrae los assets de `baserom.nes`; avisará de que el hash no coincide, es normal).
2. Después basta con `test\build-quiet.ps1`, que genera `contra4p.nes` y `obj\contra4p.map`.
3. `test\make-ips.ps1` genera `release\Contra4P-by-Killerz.ips` (de `baserom.nes` a `contra4p.nes`),
   lo verifica aplicándolo y muestra el CRC32/SHA-1 de las ROMs sin cabecera.

cc65 se puede dejar en `tools-cc65\bin` (ignorado por git) en vez de instalarlo en el sistema.

## Jugar

- En FCEUX: **Config → Input → marcar "Attach four-score"** y asignar los mandos 1-4.
- En el título, SELECT recorre 1 / 2 / 3 / 4 PLAYERS (2 líneas que se desplazan como una lista).
- Sin Four Score el juego funciona igual que el original en 1P y 2P.
- `test\fceux-input-4p.ps1 -Cfg <fceux.cfg>` escribe (con FCEUX cerrado) una configuración de ejemplo:
  mando 2 = mando Xbox Bluetooth, mando 3 = WASD + J/K, mando 4 = flechas + Num1/Num2.

## Qué cambia

**Entrada**
- Con 3-4 jugadores se leen 8 bits más por puerto (P3/P4) y la firma del Four Score (`$10`/`$20`)
  solo en la primera de las 2 lecturas por frame. Con 1-2 jugadores y en la demo se leen solo
  los 8 bits originales.

**Jugadores**
- Arrays de jugador de 4 entradas (18 en zero page `$90-$DB`, 19 en `$075F+`); vidas, game over y
  mandos también con 4 entradas.
- Bucles de jugador hasta `MAX_PLAYER_INDEX` (#$01 en 1-2P, igual que el original): estado,
  colisiones, scroll (la pantalla no avanza si alguien está en el borde izquierdo), final de nivel,
  transferencia de vidas (A en game over).
- Puntuación y vidas extra para los 4 (`$07E6-$07E9` para P3/P4, umbral en `EXTRA_LIFE_SCORE_4P`).
- El código Konami (30 vidas) se aplica a todos los jugadores de la partida.

**Enemigos**
- Apuntan al jugador más cercano de los 4; los jefes eligen al azar entre los vivos
  (`random_active_player`); la torreta roja apunta al más cercano dentro de su rango de disparo.

**Balas**
- Con 3-4 jugadores los 16 slots se comparten: hasta 6 balas por jugador, buscando primero en sus
  4 slots (el láser usa siempre sus 4 slots). Se dibujan 6 sprites de bala por frame con rotación.

**Gráficos**
- Colores sin paletas nuevas (la NES solo tiene 4 de sprites): P1 torso piel/pantalón azul, P2 todo
  rojo, P3 todo azul (fuerza la paleta 0), P4 torso azul/pantalón rojo (el renderizador invierte las
  2 paletas de jugador en el slot de sprite 3).
- Con 3-4 jugadores se dibujan primero los 4 jugadores: si la OAM se llena se pierden enemigos o
  balas, no jugadores.
- HUD: medallas de P3/P4 en una segunda fila. Pantalla de inicio de nivel con "3P REST"/"4P REST".
- Título: menú de 2 líneas que se desplaza y crédito "4 PLAYERS BY KILLERZ" (`text_by_killerz`, `$20A6`).

**Rendimiento**
- Bucle rápido de copia de tiles a la OAM para sprites sin volteo vertical (misma salida que el
  original, verificado con la OAM en `test\regress2p.ps1`).
- Con 3-4 jugadores, tras un frame de lag los sprites se redibujan uno sí y uno no durante 16 frames
  (`LAG_SKIP_SPRITES`, `$07EE`), la lógica sigue a 60 Hz.

**Demo del título**
- Juega con 4 jugadores: P3 repite la grabación de P1 y P4 la de P2 con ~1 s y ~1,6 s de retraso
  (estado en `$07E6-$07EB`, que en la demo no se usa). P3/P4 disparan cada 32 frames para no
  cargar la CPU.

## Limitaciones conocidas

- La pantalla de puntuación entre niveles solo muestra 1P/2P.
- En la base, P3 comparte ascensor con P1 y P4 con P2.
- Más parpadeo con 4 jugadores (límite de 8 sprites por línea de la NES).
- Frames lentos en la demo (medido con `test\profile.ps1`): jungla ~5 %, base ~1 %, cascada ~9 %
  (el original con 2 jugadores: ~0 %). En partidas de 4 jugadores de prueba: ~0,1 %.
- Solo se probaron a fondo los niveles 1-3.
- `CPU_GRAPHICS_BUFFER` (80 bytes) llega a ~73 en la pantalla de inicio de nivel con 4 jugadores;
  hay 15 bytes de margen antes de los datos de jugador.

## Pruebas

- `test\regress2p.ps1`: misma partida 2P en la ROM original y en la hackeada, comparando RAM y OAM
  tick a tick (con `RANDOM_NUM` fijado). Coincide hasta que el juego original lee un temporal sin
  inicializar (`$06`) que contiene una dirección de ROM, que cambia al mover código.
- `test\play4p.ps1` (con `$env:FCEUX4P` apuntando a un FCEUX con Four Score): partida automática de
  4 jugadores; log y capturas en `test\out_4p*`. `$env:PLAY_LEVEL` empieza en otro nivel.
- `test\profile.ps1`: ciclos de CPU por sección y frames de lag (`$env:PROF_DEMO` = nivel de la demo).
- `test\hotspots.ps1`: instrucciones ejecutadas por rutina durante la demo.
