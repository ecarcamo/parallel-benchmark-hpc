# Presentación web — Caso 4

Presentación web en ocho escenas, sin build ni dependencias que instalar.
Combina un modo de exposición a pantalla completa con un apéndice separado
para responder preguntas sin interrumpir la narrativa principal.

## Cómo abrirla

**Opción A (recomendada para presentar):** servirla desde la raíz del repo
para que tome las gráficas de `analysis/`:

```bash
python3 -m http.server 8000
# luego abrir en el navegador:  http://localhost:8000/presentacion/
```

**Opción B (rápida):** doble clic en `presentacion/index.html`. Funciona igual;
solo el video de YouTube necesita conexión a internet.

## Controles durante la exposición

- `→`, `↓`, `Espacio` o `Page Down`: escena siguiente.
- `←`, `↑` o `Page Up`: escena anterior.
- `Home` / `End`: apertura / cierre.
- `F`: entrar o salir de pantalla completa.
- También se puede usar la barra de controles inferior o los puntos laterales.

En el cierre, **Abrir respaldo para preguntas** muestra instrumentos, NPB,
cronología y fuentes. Este contenido está deliberadamente fuera del recorrido
de ocho escenas.

Usar un navegador actual (Chrome, Firefox o Edge). Para el efecto completo,
presionar **Presentar** antes de comenzar.

## De dónde salen los datos

- Las 4 gráficas se leen de `../analysis/*.png`. Si el equipo regenera los
  resultados en la Mac (`python3 analysis/roofline.py`), la web se actualiza
  sola: mismos nombres de archivo.
- Los números duros (1,809 PFlop/s, 17.41, 0.96%, etc.) están respaldados en
  [`../docs/fundamentos-y-fuentes.md`](../docs/fundamentos-y-fuentes.md).
- El video elegido y su justificación: [`../docs/video-presentacion.md`](../docs/video-presentacion.md).

## Detalles técnicos

- **Animaciones:** entrada por escena, contadores, barras de rendimiento y una
  simulación N-body en `<canvas>` como fondo temático.
- **Narrativa:** promesa → caída → evidencia propia → Roofline → escalamiento →
  aplicación científica → acciones → conclusión.
- **Dos modos de uso:** navegación escénica para exponer y apéndice para la
  discusión técnica.
- **Robustez:** si el JS falla o está deshabilitado, el contenido se muestra
  igual (nunca queda en blanco); respeta `prefers-reduced-motion`; y hay una
  red de seguridad que revela cualquier bloque que no se haya animado.
- **Un solo archivo de presentación:** todo el CSS y JS va inline en
  `index.html`; las gráficas se leen de `analysis/` y el video requiere red.

## Guion de quién dice qué

El diálogo narrativo por presentador está en
[`../docs/guion-presentacion.md`](../docs/guion-presentacion.md).
