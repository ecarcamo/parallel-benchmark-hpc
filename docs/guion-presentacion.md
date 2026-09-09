# Guion de la presentación — "La misma máquina, dos verdades"

Guion narrativo por presentador, sincronizado con las **ocho escenas** de la
web (`presentacion/index.html`). No es "yo hice esto": es **una sola historia**
que se pasa de mano en mano. Versión visual (libreto) publicada como Artifact.

- **Tema:** Benchmark y Rendimiento de Aplicaciones Paralelas · Caso 4
- **Duración:** ~12 min + preguntas
- **Máquina de referencia:** Apple M4 Pro (dentro de Docker)

## Orden de intervención

| Bloque | Presentador | Escenas | Tiempo |
| --- | --- | --- | --- |
| 1 | **Esteban** | 00–01 (caso + objetivo) | ~2.5′ |
| 2 | **Luis Palacios** | 02 (lo reproducimos) | ~1.5′ |
| 3 | **Diego** | 03–04 (Roofline + escala) | ~3′ |
| 4 | **Nico** | 05–06 (universo + acciones) | ~3′ |
| 5 | **Esteban** | 07 (cierre + preguntas) | ~2′ |

## Números clave (memorizarlos)

- **0.96 %** — lo que rinde El Capitan en HPCG (carga real).
- **104×** — más lento consigo mismo, El Capitan (1809 / 17.41).
- **19×** — la misma brecha en nuestra Mac (122 / 6.5).
- **5.6×** — escala el N-body (compute) de 1→8 hilos.
- **3.6×** — se estanca el stencil (memory) tras 4 hilos.
- **273 GB/s** — techo de memoria (pico M4 Pro); el stencil sostiene ~58 %.

---

## Bloque 1 — Esteban (abre: el caso y el objetivo · escenas 00–01)

**Escena 00 · Tesis** *(en pantalla: "El pico es una mentira")*

> Cuando ustedes leen que una supercomputadora rompió un récord mundial, les
> están contando una verdad… a medias. Porque ese número —el de los titulares—
> casi nunca es el rendimiento que la máquina entrega cuando hace trabajo real.
>
> Nuestro caso es Benchmark y Rendimiento de Aplicaciones Paralelas, y el
> objetivo fue concreto: correr varios benchmarks en un sistema paralelo,
> encontrar el cuello de botella y proponer cómo atacarlo. Hoy les vamos a
> mostrar exactamente dónde está.

▶ *Avanza a la Escena 01 al decir "dónde está".*

**Escena 01 · La promesa** *(en pantalla: barras Rpeak → HPL → HPCG y el 0.96 %)*

> Miren a El Capitan: en **noviembre de 2025**, la computadora más rápida del
> planeta. Su hardware promete 2,821 petaflops teóricos —el Rpeak. En HPL, el
> benchmark de los titulares, entrega 1,809. Pero con una carga realista, HPCG,
> cae a 17.41.
>
> Eso es menos del 1 % de su propio pico. La misma máquina, 104 veces más lenta
> consigo misma. Y esa es la pregunta que guía todo el proyecto: ¿por qué?

⚠️ *104× es El Capitan (1809/17.41). El 19× es nuestra Mac — no mezclar.*

→ **Entrega a Luis:** *"Lo primero que hicimos fue comprobar que esto no es cosa
de una sola máquina gigante. Luis."*

---

## Bloque 2 — Luis Palacios (lo reproducimos, con método · escena 02)

**Escena 02 · Lo reproducimos** *(en pantalla: gráfica HPL vs HPCG en la Mac)*

> Nos preguntamos: ¿esto solo pasa en una máquina de 30 megavatios, o es
> universal? Así que lo reprodujimos nosotros. Todo lo que van a ver corre dentro
> de un contenedor Docker, en una sola máquina de referencia —una MacBook con
> chip M4 Pro— para que cada número sea comparable.
>
> Y miren: la misma forma. En nuestra laptop, HPL entrega 122 gigaflops; HPCG,
> apenas 6.5. Diecinueve veces más lento. El fenómeno no depende de la escala:
> depende de la arquitectura. La pregunta es contra qué está chocando.

⚠️ *Si preguntan por Docker en Mac: corre en una VM ligera, no es 100 %
bare-metal; documentado como nota de método. La comparación interna sigue válida.*

→ **Entrega a Diego:** *"Diego lo vuelve visible con el modelo que usa la industria."*

---

## Bloque 3 — Diego (el Roofline y el precio de más núcleos · escenas 03–04)

**Escena 03 · El modelo** *(en pantalla: el Roofline con los cuatro puntos)*

> Contra un techo. Esto es el modelo Roofline, la herramienta que usan Intel y
> NVIDIA para diagnosticar rendimiento. El eje horizontal es cuántas operaciones
> haces por cada byte que traes de memoria.
>
> Hay dos límites: la rampa, que es el ancho de banda de la memoria, y la meseta,
> que es la potencia de cálculo. Toda carga cae de un lado. HPL y nuestra N-body
> viven pegadas al techo de cómputo: son puro cálculo. Pero HPCG y nuestro
> stencil caen del lado de la memoria. Ese es el cuello de botella. No es el
> cómputo. Es la memoria.

▶ *Avanza a la Escena 04 al decir "es la memoria".*

**Escena 04 · Ocho núcleos** *(en pantalla: curvas de escalamiento)*

> Y esto se siente al agregar cores. Escribimos dos apps: una compute-bound y una
> memory-bound. La compute-bound, el N-body, escala 5.6 veces de 1 a 8 hilos
> —casi perfecto. La memory-bound, el stencil, se estanca en 3.6 y deja de
> mejorar después de 4 hilos. Los cores extra no sirven: el camino a la memoria
> ya está saturado. Comprar más núcleos no arregla un problema de memoria.

⚠️ *Techo de 273 GB/s = pico publicado del M4 Pro (Apple), fuente independiente;
el stencil sostiene ~58 %.*

→ **Entrega a Nico:** *"¿Y por qué nos importa una carga que se ahoga en la
memoria? Nico lo lleva a escala del universo."*

---

## Bloque 4 — Nico (del laptop al universo, y a la acción · escenas 05–06)

**Escena 05 · La escala** *(en pantalla: video ν²GC)*

> Esto que corrimos en una laptop… es la misma física que mueve al universo. Lo
> que van a ver es una simulación cosmológica real, ν²GC, del Observatorio
> Astronómico de Japón: la formación de la estructura del universo con 550 mil
> millones de partículas.

⏵ *Dale PLAY al video; déjalo correr ~15–20 s de fondo mientras hablas.*

> Es exactamente el mismo fenómeno físico de nuestra app N-body —gravedad de N
> cuerpos— solo que a escala planetaria. La ciencia real usa algoritmos más
> astutos que el nuestro para escalar, pero persiguen lo mismo: cómo la gravedad
> organiza el cosmos. Un benchmark deja de ser una cifra cuando entiendes qué
> ciencia hace posible.

⚠️ *Decir "mismo fenómeno físico", NO "mismo algoritmo" (la nuestra es directa
O(n²); la ciencia usa TreePM). El video corrió en ATERUI/K, no en Fugaku.*

**Escena 06 · Del diagnóstico a la acción** *(en pantalla: tarjetas de optimización)*

> Y como diagnosticamos el cuello, podemos proponer cómo atacarlo. Si el límite
> es la memoria: mejorar la localidad de datos con blocking y reuso, y no lanzar
> más hilos de los que el ancho de banda aguanta. Si el límite es la comunicación
> entre procesos: solapar cómputo con comunicación. Y en general, preferir
> algoritmos y librerías que hagan más cálculo por cada byte —subir la intensidad
> aritmética para correr el techo a nuestro favor.

→ **Entrega a Esteban:** *"Esteban cierra la idea."*

---

## Bloque 5 — Esteban (cierra y abre preguntas · escena 07)

**Escena 07 · Conclusión** *(en pantalla: "Comprar más núcleos no elimina el cuello de botella")*

> Cerramos el círculo. Medimos la brecha —del 1 % en la máquina más rápida del
> mundo. Encontramos el límite —con el Roofline, es la memoria. Y diseñamos la
> respuesta.
>
> Si algo se llevan hoy, que sea esto: **comprar más núcleos no elimina el cuello
> de botella. Primero hay que saber contra qué techo está chocando el código.**
> Gracias.

▶ *Pulsa "Abrir respaldo para preguntas" para el apéndice (instrumentos, NPB,
cronología, fuentes).*

---

## Preguntas probables (respuestas listas)

- **¿El Capitan sigue siendo el #1?** No. En **junio de 2026**, LineShine (China,
  2.198 EFlop/s) tomó el #1; El Capitan es #2. Por eso decimos "#1 en noviembre
  de 2025", la lista que analizamos.
- **¿HPL es el pico teórico?** No. HPL es rendimiento **medido (Rmax)**. El pico
  teórico es **Rpeak** (2,821 PFlop/s). Secuencia: Rpeak → HPL → HPCG.
- **¿El video es su simulación / corre en Fugaku?** Es ν²GC del NAOJ (proyecto
  4D2U); corrió en **ATERUI** y el K computer, no en Fugaku. Mismo **fenómeno
  físico** que nuestra app, pero ellos usan **TreePM**; la nuestra es directa,
  O(n²).
- **¿De dónde sale el techo de 273 GB/s?** Ancho de banda **pico publicado del
  M4 Pro** (Apple), fuente **independiente** para no derivar el techo del propio
  stencil (evitar circularidad). El stencil sostiene ~58 %. STREAM directo lo
  confirmaría (mejora pendiente).
- **¿Por qué NPB y no SPEC?** SPEC es de licencia paga; NPB (NASA) es el proxy
  estándar gratuito para las mismas cargas.

## Precisión bajo presión

| No digan | Digan |
| --- | --- |
| "El Capitan es el #1 del mundo" | "El Capitan, #1 en noviembre de 2025" |
| "HPL es el pico teórico" | "HPL es rendimiento medido (Rmax); el teórico es Rpeak" |
| "El mismo algoritmo que el video" | "El mismo fenómeno físico (gravedad N-body)" |
| "La simulación corre en Fugaku" | "El video corrió en ATERUI / K computer" |
| Mezclar el 104× con el 19× | "104× es El Capitan; 19× es nuestra Mac" |

Respaldo completo en [`fundamentos-y-fuentes.md`](fundamentos-y-fuentes.md) y
[`video-presentacion.md`](video-presentacion.md).
