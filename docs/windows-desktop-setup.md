# Odysseus en Windows — Instalación de escritorio (con icono y ventana propia)

Esta guía describe una **capa de comodidad para Windows nativo** construida sobre
Odysseus: un instalador de un comando que deja la app lista con **memoria y RAG
funcionando**, **embeddings multilingües**, **navegación web del agente**, y un
**icono de escritorio** que abre Odysseus en su **propia ventana** (modo app PWA),
sin consola negra y esperando a que el servidor esté listo antes de abrir.

> ℹ️ **Esto NO modifica el comportamiento interno de Odysseus.** Son scripts y
> archivos *añadidos* alrededor de la app (instalador, lanzador, icono). El
> código original de Odysseus queda intacto, así que puedes seguir actualizando
> con `git pull` con normalidad.

---

## ¿Qué mejora respecto a la instalación base?

La instalación nativa por defecto (`launch-windows.ps1`) arranca el servidor en
una consola y abre el navegador. Esta capa añade, encima de eso:

| Mejora | Qué resuelve |
|---|---|
| **Servidor ChromaDB local automático** | Sin Docker, la memoria vectorial y el RAG quedaban en estado `DEGRADED`. Ahora arrancan solos. |
| **Modelo de embeddings multilingüe** | El modelo por defecto (`all-MiniLM-L6-v2`) es flojo en español. Se usa `paraphrase-multilingual-mpnet-base-v2`. |
| **Browser MCP preinstalado** | Habilita la navegación web / capturas del agente (Playwright). |
| **Icono de escritorio (el barquito)** | Acceso directo con el logo de Odysseus, generado localmente. |
| **Lanzador con splash** | Pantalla de carga con estado en vivo, **sin consola negra**. |
| **Espera de readiness** | El navegador abre **solo cuando el servidor responde** (adiós al "no se puede conectar"). |
| **Ventana independiente (modo app)** | Odysseus abre en su propia ventana, sin pestañas ni barra de direcciones. |
| **Icono en la bandeja del sistema** | Menú para *Abrir* o *Detener* Odysseus (incluido ChromaDB). |

---

## ¿De dónde viene cada pieza? (créditos)

- **Odysseus** — la app base. Proyecto original: <https://github.com/pewdiepie-archdaemon/odysseus> (licencia MIT).
- **ChromaDB** — base de datos vectorial que Odysseus ya usa para memoria/RAG; aquí solo se levanta como servicio local. <https://www.trychroma.com>
- **FastEmbed (ONNX)** + modelo `paraphrase-multilingual-mpnet-base-v2` (sentence-transformers) — embeddings locales.
- **Playwright MCP** (`@playwright/mcp`) — servidor MCP de navegador que Odysseus reconoce de fábrica.
- **El instalador, el lanzador, el icono y esta guía** — añadidos de esta capa de comodidad para Windows (no forman parte del Odysseus original).

El icono reproduce el **logo de marca de Odysseus** (el velero salmón `#e06c75`
que la app usa como favicon), dibujado a un `.ico` para el escritorio.

---

## Requisitos

- **Windows 10/11**
- **Python 3.11+** — <https://www.python.org/downloads/>
- **LM Studio** (u Ollama, u otro proveedor) con un modelo cargado, para chatear — <https://lmstudio.ai>
- **Node.js** (opcional) — solo si quieres la navegación web del agente (Browser MCP). <https://nodejs.org>

---

## Instalación (un comando)

Abre **PowerShell** en la carpeta del repo y ejecuta:

```powershell
git clone https://github.com/pewdiepie-archdaemon/odysseus.git
cd odysseus
powershell -ExecutionPolicy Bypass -File .\install-windows-desktop.ps1
```

El instalador (seguro de re-ejecutar) hace:

1. Busca Python 3.11+.
2. Crea `venv`, instala dependencias y corre `setup.py` (te pedirá un usuario y contraseña de admin).
3. Instala el servidor **ChromaDB** en un venv aparte (`venv-chroma`).
4. Configura y descarga el **modelo de embeddings multilingüe**.
5. Instala el **Browser MCP** si detecta Node/npx.
6. Genera el **icono** del barquito.
7. Crea el **lanzador silencioso** y el **acceso directo en tu escritorio**.

Al terminar: **doble clic en "Odysseus"** del escritorio.

### Opciones del instalador
```powershell
# Sin descargar el modelo de embeddings (se descargará al primer arranque):
.\install-windows-desktop.ps1 -SkipEmbedDownload

# Sin instalar el Browser MCP:
.\install-windows-desktop.ps1 -SkipBrowserMcp
```

---

## Cómo funciona el lanzador

Al hacer doble clic en el icono:

1. Aparece un **splash** con el barquito y el estado: *Iniciando memoria → Arrancando servidor → Cargando módulos → Listo*.
2. Arranca **ChromaDB** (si no estaba) y el **servidor de Odysseus**, ambos ocultos.
3. **Sondea** `http://127.0.0.1:7000` hasta que responde.
4. Abre Odysseus en una **ventana independiente** (Chrome o Edge en modo `--app`; si no hay ninguno, usa el navegador por defecto).
5. Deja un **icono del barquito en la bandeja del sistema** (junto al reloj):
   - **Abrir Odysseus** (o doble clic en el icono)
   - **Detener Odysseus** — apaga el servidor y ChromaDB de forma limpia.

> Como la consola queda oculta, **la forma correcta de apagar Odysseus es**
> *Detener Odysseus* desde el icono de la bandeja.

### Archivos que componen la capa
- `install-windows-desktop.ps1` — instalador portable (usa su propia ruta, sin rutas fijas).
- `scripts/make_icon.py` — dibuja `odysseus.ico` y el PNG del splash.
- `Odysseus-launcher.ps1` — splash + readiness + ventana app + bandeja.
- `Odysseus-silent.vbs` — lanza el script anterior sin parpadeo de consola (lo genera el instalador con tu ruta).

---

## Uso diario

1. Abre **LM Studio** con tu modelo cargado (contexto ≥ 16K recomendado; modelos de razonamiento como Qwen3 necesitan suficientes *max tokens* para responder).
2. En Odysseus, añade el endpoint local: **Settings → Add Models → LOCAL →** `http://127.0.0.1:1234/v1` (o el comando `/setup local http://127.0.0.1:1234/v1`).
3. **Doble clic** en el icono del escritorio cuando quieras abrirlo.

---

## Desinstalar / revertir

- **Quitar el icono:** borra `Odysseus.lnk` de tu escritorio.
- **Quitar la memoria local:** borra la carpeta `venv-chroma/` (ChromaDB dejará de arrancar; la app vuelve a `DEGRADED` pero funciona).
- **Volver al arranque básico:** usa `launch-windows.ps1` del repo original en lugar del icono.
- Tus datos viven en `data/` (chats, memorias, config) y no se tocan al revertir.

---

## Solución de problemas

| Síntoma | Causa / arreglo |
|---|---|
| El icono abre y "no se puede conectar" un instante | El servidor aún arranca; el splash espera, recarga si hace falta. |
| `error 10048 / bind on 7000` | Ya hay una instancia abierta. Usa *Detener Odysseus* en la bandeja, o reinicia. |
| Memoria/RAG en `DEGRADED` | ChromaDB no arrancó: confirma que existe `venv-chroma/` y vuelve a ejecutar el instalador. |
| Respuestas vacías del chat | El modelo (p. ej. Qwen3) gastó los tokens "razonando". Sube *Max Tokens* y el contexto en LM Studio. |
| El agente no usa el correo | Cambia a **modo Agente** (en Chat normal el modelo no tiene herramientas). |
| El correo de Outlook/Microsoft 365 falla | Microsoft requiere OAuth; aún no soportado. Usa Gmail/IMAP con contraseña de aplicación. |
