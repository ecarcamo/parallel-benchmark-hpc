# Presentación web — Caso 4

Página única, animada y autocontenida (`index.html`). Sin build, sin
dependencias que instalar. Narrativa cinematográfica tipo landing científica:
asombro → la brecha del 1% → Roofline → apps propias → ciencia → cuellos de
botella.

## Cómo abrirla

**Opción A (recomendada para presentar):** servirla desde la raíz del repo
para que tome las gráficas de `analysis/`:

```bash
python3 -m http.server 8000
# luego abrir en el navegador:  http://localhost:8000/presentacion/
```

**Opción B (rápida):** doble clic en `presentacion/index.html`. Funciona igual;
solo el video de YouTube necesita conexión a internet.

> Presentar en **pantalla completa** (F11 en Chrome/Firefox) para el efecto
> máximo. Usar un navegador actual (Chrome, Firefox o Edge).

## De dónde salen los datos

- Las 4 gráficas se leen de `../analysis/*.png`. Si el equipo regenera los
  resultados en la Mac (`python3 analysis/roofline.py`), la web se actualiza
  sola: mismos nombres de archivo.
- Los números duros (1,809 PFlop/s, 17.41, 0.96%, etc.) están respaldados en
  [`../docs/fundamentos-y-fuentes.md`](../docs/fundamentos-y-fuentes.md).
- El video elegido y su justificación: [`../docs/video-presentacion.md`](../docs/video-presentacion.md).

## Detalles técnicos

- **Animaciones:** aparición al hacer scroll (IntersectionObserver) y
  contadores numéricos. El fondo del hero es una simulación de partículas
  N-body en `<canvas>` — temáticamente, nuestra propia app.
- **Robustez:** si el JS falla o está deshabilitado, el contenido se muestra
  igual (nunca queda en blanco); respeta `prefers-reduced-motion`; y hay una
  red de seguridad que revela cualquier bloque que no se haya animado.
- **Un solo archivo:** todo el CSS y JS va inline en `index.html`.

## Guion de quién dice qué

El diálogo narrativo por presentador está en
[`../docs/guion-presentacion.md`](../docs/guion-presentacion.md).
