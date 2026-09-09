# Video de la presentación

Un solo video, elegido para dar el golpe visual de apertura y conectar con
la ciencia del proyecto. La idea es el **arco narrativo tipo OpenAI**:
primero asombro, después el giro con nuestros datos.

## Elegido: "The ν2GC Simulations — Largest supercomputer simulation of the Universe"

- **URL:** https://www.youtube.com/watch?v=kndzioHG8Uc
- **Embed:** `https://www.youtube.com/embed/kndzioHG8Uc`
- **Qué es:** simulación gravitacional **N-body** de la formación de la
  estructura a gran escala del universo, con 8192³ (≈550 mil millones) de
  partículas de materia oscura. Investigador líder: Tomoaki Ishiyama.

### Por qué este y no otro

1. **Es el mismo FENÓMENO FÍSICO que nuestra app.** El video es una simulación
   **N-body gravitacional**: la misma física (gravedad de N cuerpos) que
   `apps/nbody.c`. Ojo con la precisión: nuestra app es *directa,
   todos-contra-todos* (O(n²)); las simulaciones científicas usan **TreePM**
   (árbol + malla de partículas) para escalar. Por eso en vivo se dice *"el
   mismo fenómeno físico, otra escala"*, **no** "el mismo algoritmo". Frase:
   *"esto es la misma gravedad que corrimos en una laptop; aquí, con medio
   billón de cuerpos."*
2. **Respaldo de hardware real.** El video ν²GC fue producido por el proyecto
   4D2U del **NAOJ**; el cómputo gravitacional corrió en el supercomputador
   **ATERUI** (y el K computer de RIKEN). Como dato adicional, el grupo de
   Ishiyama **más tarde** ejecutó otras simulaciones N-body en **Fugaku**
   (HPC Asia 2022). No confundir: el video NO es de Fugaku.
3. **Estética correcta.** Cinematográfico, oscuro, científico: encaja con la
   página tipo OpenAI que vamos a construir (loop silencioso de fondo en el
   hero).
4. **Respaldo académico.** No es una animación de fantasía; hay paper revisado
   por pares detrás (ver fuentes).

### Cómo usarlo en la web (Etapa 4)

- **Hero de apertura:** el video como fondo (o tarjeta grande), silenciado y
  en loop, con el titular encima: *"La máquina más rápida del mundo… al 1% de
  su potencia."*
- **Giro:** justo después del asombro cósmico, entra nuestra gráfica
  `hpl_vs_hpcg.png` y el Roofline. El contraste emocional (belleza infinita →
  cuello de botella real) es el efecto WOW.

## Respaldo (fuentes del video)

- Ishiyama, T. et al. (2015). *The ν2GC Simulations: Quantifying the Dark Side
  of the Universe in the Planck Cosmology.* Publications of the Astronomical
  Society of Japan, 67(4), 61.
  [Oxford Academic](https://academic.oup.com/pasj/article/67/4/61/1535923)
- Hardware del video: proyecto **4D2U del NAOJ**; cómputo en el supercomputador
  **ATERUI** (NAOJ / CfCA) y el **K computer** (RIKEN).
  [ATERUI II — NAOJ](https://www.nao.ac.jp/en/research/telescope/aterui2.html)
- Trabajo POSTERIOR (distinto al video) en Fugaku: Ishiyama, T. et al. (2022).
  *High Performance Gravitational N-body Simulations on Supercomputer Fugaku.*
  HPC Asia 2022. [ACM DL](https://dl.acm.org/doi/10.1145/3492805.3492816)
- Cobertura: [HPCwire — "Supercomputer Generates Largest Virtual Universe"](https://www.hpcwire.com/off-the-wire/supercomputer-generates-largest-virtual-universe-open-for-anyone-to-explore/)

## Alternativas (por si se quiere cambiar el tono)

- **Más cinematográfico / avalado por NASA:** "Simulation TNG50: A Galaxy
  Cluster Forms" (IllustrisTNG, viz. Dylan Nelson), destacado en NASA APOD.
  https://www.youtube.com/watch?v=cNT5yAqpBmI — incluye gas/MHD, no solo
  gravedad, así que es más vistoso pero un poco menos "puro N-body".
- **Máxima autoridad (para citar, no para embeber):** charla del Turing Award
  de **Jack Dongarra**, co-creador de LINPACK y TOP500: *"A Not So Simple
  Matter of Software"*, donde argumenta que LINPACK perdió valor y HPCG mide
  mejor. Es nuestra tesis, dicha por la máxima autoridad del área.
  https://www.youtube.com/watch?v=cSO0Tc2w5Dg
