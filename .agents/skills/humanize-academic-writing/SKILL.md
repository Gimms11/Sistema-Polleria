---
name: humanize-academic-writing
description: Flujo de trabajo y técnicas avanzadas de redacción académica y técnica humanizada para mantener el índice de detección de IA (Turnitin, GPTZero, CopyLeaks) por debajo del 20%. Incluye auditoría sintáctica, erradicación de clichés de LLM y modificación quirúrgica de documentos Word (.docx).
---

# Humanize Academic Writing: Protocolo Anti-Detección y Flujo Editorial

> Diseñado para documentación universitaria y técnica (informes, tesis, requerimientos y diseño de software).
> **Objetivo:** Mantener el índice de detección sintética en Turnitin ≤ 20% sin degradar el rigor formal ni perder tablas o estilos en `.docx`.

---

## 1. Fundamento Estadístico de los Detectores (Turnitin / GPTZero)

Los detectores no entienden el contenido ni juzgan la calidad. Miden dos propiedades matemáticas de las cadenas de tokens:

1. **Perplejidad (Perplexity):** La probabilidad condicional de cada palabra dado el contexto previo.
   - *IA:* Tiende siempre a la palabra estadísticamente más probable (baja perplejidad).
   - *Humano:* Introduce elecciones léxicas no canónicas, tecnicismos del contexto operativo real, matices pragmáticos y excepciones empíricas (alta perplejidad).
2. **Ráfaga (Burstiness):** La variabilidad en la distribución de longitudes y sintaxis de las oraciones.
   - *IA:* Escribe con cadencia métrica monótona (oraciones de 16 a 24 palabras, estructura *Sujeto + Verbo + Conector + Predicado*).
   - *Humano:* Alterna ráfagas: una frase tajante de 4 palabras seguida de una construcción compleja de 45 palabras con incisos, dos puntos explicativos o subordinadas causales.

---

## 2. El Flujo de Trabajo Editorial en 4 Fases

```
[ Texto Crudo / Docx ]
         │
         ▼
[ Fase 1: Diagnóstico de Ráfaga & Clichés ] ──> python .agents/scripts/audit_ai_patterns.py
         │
         ▼
[ Fase 2: Poda de Inflación y Frases Bandera ] ──> Supresión de fórmulas y conectores artificiales
         │
         ▼
[ Fase 3: Inyección de Asimetría y Fricción ] ──> Fusión/corte de oraciones y detalles operativos
         │
         ▼
[ Fase 4: Reemplazo Quirúrgico en .docx ] ──> powershell .agents/scripts/docx_tool.ps1
```

---

## 3. Catálogo de Erradicación de Patrones de IA (Español)

### 3.1 Clichés de Apertura e Inflación de Importancia
*Eliminar sin sustituir o cambiar por el hecho concreto:*
- ❌ *"En el vertiginoso mundo actual..."* / *"En la era digital..."*
- ❌ *"Juega un papel crucial / fundamental / primordial / de suma importancia..."*
- ❌ *"Es importante destacar / cabe señalar / merece especial mención..."*
- ❌ *"Un amplio abanico de posibilidades..."* / *"Un tapiz de innovaciones..."*
- ❌ *"Sienta las bases para..."* / *"Marca un antes y un después..."*

### 3.2 Conectores Robóticos en Serie
La IA abusa de conectores de transición formales para aparentar cohesión.
- ❌ Evitar iniciar párrafos consecutivos con: *"Asimismo"*, *"Por consiguiente"*, *"En este orden de ideas"*, *"Por otra parte"*, *"En este sentido"*.
- **Regla humana:** Que la relación causal interna sostenga el argumento. Si una idea es causa de la anterior, no necesita un cartel luminoso que diga *"Por lo tanto"*.

### 3.3 El Bucle de Conclusión Típico de LLM
- ❌ *"En conclusión / En definitiva, X no solo representa una solución eficaz para Y, sino que además sienta las bases hacia un futuro prometedor..."*
- **Sustitución humana:** Cerrar con el estado operativo final o la métrica obtenida. Por ejemplo: *"La arquitectura desacopló el servicio de comandas y limitó la latencia de impresión a menos de 400 ms en pruebas de carga."*

### 3.4 Simetría de Listas y Viñetas
- ❌ La IA siempre genera listas de exactamente 3 a 5 viñetas, cada una con un título en negrita seguido de dos líneas de explicación idénticas.
- **Sustitución humana:** Romper el patrón. Si una viñeta requiere dos líneas, la siguiente puede ser un solo requisito técnico directo; la tercera puede ser una salvedad operativa.

---

## 4. Inyección de Fricción y Contexto Situacional (Perplejidad Alta)

El detector marca como IA los textos asépticos y neutrales. Para quebrar la detección:
1. **Mencionar la restricción o el problema real:** En vez de decir *"el sistema garantiza una gestión óptima de stock"*, escribir: *"cuando colapsaba la comanda manual en hora punta, las diferencias entre el inventario del horno y caja superaban el 12% semanal"*.
2. **Jerga operativa real:** Usar los términos propios del negocio o disciplina (ej. en pollería: *punto de marinado, rotación de espadas, merma de cocción, cuadre de caja ciega, latencia de comanda*).
3. **Números no redondeados y limitaciones asumidas:** Hablar de trade-offs, dependencias caídas y límites de diseño. La IA rara vez admite limitaciones técnicas salvo en fórmulas condescendientes.

---

## 5. Herramientas Integradas del Proyecto

### Auditoría Automatizada:
```bash
python .agents/scripts/audit_ai_patterns.py "ruta/archivo.md"
```
Evalúa la desviación estándar de longitud oracional (objetivo: σ ≥ 8.0) y detecta densidad de clichés.

### Edición Quirúrgica de `.docx`:
```bash
# Lectura estructurada
powershell -ExecutionPolicy Bypass -File .agents/scripts/docx_tool.ps1 -Action Read -FilePath "documento.docx"

# Reemplazo directo preservando formato original
powershell -ExecutionPolicy Bypass -File .agents/scripts/docx_tool.ps1 -Action Replace -FilePath "documento.docx" -FindText "texto original" -ReplaceText "texto humanizado"

# Exportar a PDF nativo
powershell -ExecutionPolicy Bypass -File .agents/scripts/docx_tool.ps1 -Action ExportPdf -FilePath "documento.docx"
```
