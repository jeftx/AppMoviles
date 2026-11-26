import { createInterface } from 'node:readline';

// Prueba local, independiente de Flutter. Nunca guarda la clave ni datos personales.
async function readKey() {
  if (!process.stdin.isTTY) {
    throw new Error('Ejecuta esta prueba desde una terminal interactiva.');
  }
  const readline = createInterface({ input: process.stdin, output: process.stdout });
  process.stdout.write('Pega tu clave de OpenRouter y presiona Enter (no se mostrará): ');
  const originalWrite = readline._writeToOutput;
  readline._writeToOutput = () => {};
  try {
    return await new Promise((resolve) => readline.question('', resolve));
  } finally {
    readline._writeToOutput = originalWrite;
    readline.close();
    process.stdout.write('\n');
  }
}

async function main() {
  const key = (await readKey()).trim();
  if (!key) throw new Error('No ingresaste una clave.');

  const profile = {
    edad_anios: 30,
    peso_kg: 65,
    estatura_cm: 165,
    nivel_actividad: 'moderada',
    pais: 'Colombia',
    restricciones: [],
    objetivo: 'alimentación equilibrada',
  };
  const prompt = `Propón un desayuno para este perfil ficticio: ${JSON.stringify(profile)}.
Usa nombres naturales y cotidianos del país indicado. Para Colombia, evita
anglicismos como "bowl": describe la preparación por su nombre real, por ejemplo
"avena con fruta", "arepa con huevo" o "arroz con fríjoles" cuando corresponda.
No llames ensalada a un plato si no lo es. Usa ingredientes específicos disponibles
en ese país, con cantidades y unidades explícitas como "40 g", "200 ml" o "1 unidad".
Las calorías y nutrientes son estimaciones por porción, no datos verificados.
Los pasos deben incluir preparación, tiempos, temperatura o nivel de fuego y punto
de cocción cuando corresponda. Identifica alérgenos sin garantizar su ausencia.
Devuelve únicamente JSON con estas claves exactas, compatibles con la aplicación:
{
  "id": "prueba-desayuno", "type": "Desayuno", "name": "nombre del plato",
  "description": "descripción breve", "calories": 350,
  "proteinGrams": 15, "carbsGrams": 45, "fatGrams": 10, "fiberGrams": 5,
  "serving": "1 porción", "prepMinutes": 15,
  "ingredients": [{"name": "avena en hojuelas", "amount": "40 g"}],
  "steps": ["paso detallado con tiempo y fuego cuando aplique"],
  "vitamins": [{"name": "Vitamina C", "amount": "10 mg"}],
  "minerals": [{"name": "Hierro", "amount": "2 mg"}],
  "nutritionNotes": "Valores aproximados por porción.",
  "allergensAndPrecautions": "Alérgenos y precauciones de la receta."
}
Los valores del ejemplo muestran la estructura; calcula nuevas estimaciones para
la receta elegida. No des diagnósticos ni consejos médicos.`;

  console.log('Solicitando una comida de prueba a OpenRouter...');
  const start = performance.now();
  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: 'inclusionai/ling-3.2-flash:free',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 4096,
      reasoning: { enabled: false },
      response_format: { type: 'json_object' },
    }),
    signal: AbortSignal.timeout(90000),
  });
  const elapsed = ((performance.now() - start) / 1000).toFixed(1);
  if (!response.ok) {
    console.error(`OpenRouter respondió con código ${response.status} después de ${elapsed} segundos.`);
    if (response.status === 401) console.error('Revisa que la clave sea válida.');
    if (response.status === 429) {
      let source;
      let retrySeconds;
      try {
        const errorBody = await response.json();
        source = errorBody.error?.metadata?.limit_source;
        retrySeconds = errorBody.error?.metadata?.retry_after_seconds;
      } catch {
        // Algunos proveedores no devuelven detalles estructurados.
      }
      const knownSources = {
        upstream_provider_shared_pool: 'El proveedor del modelo gratuito no tiene capacidad disponible.',
        openrouter_free_tier_per_minute: 'La cuenta alcanzó el límite de solicitudes por minuto.',
        openrouter_free_tier_daily: 'La cuenta alcanzó el límite diario de modelos gratuitos.',
      };
      console.error(knownSources[source] ?? 'No se indicó si el límite corresponde a la cuenta o al proveedor.');
      if (Number.isFinite(retrySeconds) && retrySeconds > 0 && retrySeconds < 86400) {
        console.error(`Tiempo de espera sugerido: ${Math.ceil(retrySeconds)} segundos.`);
      } else {
        const retryHeader = response.headers.get('retry-after');
        if (retryHeader && /^\d{1,5}$/.test(retryHeader)) {
          console.error(`Tiempo de espera sugerido: ${retryHeader} segundos.`);
        }
      }
    }
    if (response.status >= 500) console.error('El proveedor no está disponible en este momento.');
    process.exitCode = 1;
    return;
  }
  const data = await response.json();
  const result = data.choices?.[0]?.message?.content;
  const model = typeof data.model === 'string' && /^[a-zA-Z0-9_./:-]{1,150}$/.test(data.model)
    ? data.model : 'no indicado';
  const finishReason = data.choices?.[0]?.finish_reason;
  const safeReason = typeof finishReason === 'string' && /^[a-zA-Z0-9_-]{1,40}$/.test(finishReason)
    ? finishReason : 'no indicado';
  const completionTokens = data.usage?.completion_tokens;
  const reasoningTokens = data.usage?.completion_tokens_details?.reasoning_tokens;
  console.log(`Respuesta recibida en ${elapsed} segundos. Modelo: ${model}`);
  if (typeof result !== 'string' || !result.trim()) {
    console.error(`El modelo no devolvió texto. Motivo de finalización: ${safeReason}.`);
    if (Number.isFinite(completionTokens)) console.error(`Tokens de salida: ${completionTokens}.`);
    if (Number.isFinite(reasoningTokens)) console.error(`Tokens de razonamiento: ${reasoningTokens}.`);
    if (safeReason === 'length') {
      console.error('La respuesta alcanzó el límite de salida antes de completar la comida.');
    }
    if (data.error) console.error('OpenRouter también informó un error en la respuesta.');
    process.exitCode = 1;
    return;
  }
  if (safeReason === 'length') {
    console.error('La respuesta quedó incompleta al alcanzar el límite de salida.');
    process.exitCode = 1;
    return;
  }
  try {
    const json = JSON.parse(result.replace(/^\s*```(?:json)?\s*/i, '').replace(/\s*```\s*$/, ''));
    console.log(JSON.stringify(json, null, 2));
    const missing = [];
    if (typeof json.name !== 'string' || !json.name.trim()) missing.push('nombre');
    if (!Number.isFinite(json.calories) || json.calories <= 0) missing.push('calorías');
    if (!Number.isFinite(json.prepMinutes) || json.prepMinutes <= 0) missing.push('tiempo');
    if (!Array.isArray(json.ingredients) || json.ingredients.length === 0 ||
        json.ingredients.some((item) => typeof item.name !== 'string' || !item.name.trim() ||
          typeof item.amount !== 'string' || !/\d/.test(item.amount) || !/[a-záéíóúñ]/i.test(item.amount))) {
      missing.push('ingredientes con cantidad y unidad');
    }
    if (!Array.isArray(json.steps) || json.steps.length === 0 ||
        json.steps.some((step) => typeof step !== 'string' || !step.trim())) missing.push('pasos');
    if (typeof json.allergensAndPrecautions !== 'string' || !json.allergensAndPrecautions.trim()) missing.push('alérgenos');
    if (missing.length) {
      console.error(`Respuesta incompleta: revisa ${missing.join(', ')}.`);
      process.exitCode = 1;
    } else {
      console.log('Estructura básica válida; los nutrientes y alérgenos requieren revisión.');
    }
  } catch {
    console.log('La respuesta no tenía formato JSON válido:');
    console.log(result);
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error.name === 'TimeoutError'
    ? 'La prueba superó los 90 segundos sin respuesta.'
    : `No se pudo completar la prueba: ${error.message}`);
  process.exitCode = 1;
});
