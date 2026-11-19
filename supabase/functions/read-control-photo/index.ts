const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const runtime = globalThis as typeof globalThis & {
  Deno: {
    env: { get(name: string): string | undefined };
    serve(handler: (request: Request) => Response | Promise<Response>): void;
  };
};
const fieldNames = ["initial", "replenishment", "surplus", "waste"] as const;
const maxImageDataUrlLength = 7_000_000;

const outputSchema = {
  type: "object",
  properties: {
    rows: {
      type: "array",
      items: {
        type: "object",
        properties: {
          product_index: { type: "integer" },
          product_name: { type: "string" },
          initial: { type: ["integer", "null"] },
          replenishment: { type: ["integer", "null"] },
          surplus: { type: ["integer", "null"] },
          waste: { type: ["integer", "null"] },
          uncertain_fields: {
            type: "array",
            items: { type: "string", enum: fieldNames },
          },
        },
        required: [
          "product_index",
          "product_name",
          "initial",
          "replenishment",
          "surplus",
          "waste",
          "uncertain_fields",
        ],
        additionalProperties: false,
      },
    },
  },
  required: ["rows"],
  additionalProperties: false,
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function matchesSecret(candidate: string, expected: string): boolean {
  const encoder = new TextEncoder();
  const left = encoder.encode(candidate);
  const right = encoder.encode(expected);
  let difference = left.length ^ right.length;
  const length = Math.max(left.length, right.length);

  for (let index = 0; index < length; index++) {
    difference |= (left[index] ?? 0) ^ (right[index] ?? 0);
  }

  return difference === 0;
}

function getOutputText(response: Record<string, unknown>): string {
  if (typeof response.output_text === "string") return response.output_text;

  const output = Array.isArray(response.output) ? response.output : [];
  return output.flatMap((item) => {
    if (!item || typeof item !== "object") return [];
    const message = item as Record<string, unknown>;
    if (!Array.isArray(message.content)) return [];
    return message.content.flatMap((part) => {
      if (!part || typeof part !== "object") return [];
      const content = part as Record<string, unknown>;
      return content.type === "output_text" && typeof content.text === "string" ? [content.text] : [];
    });
  }).join("");
}

function validateRows(value: unknown, products: Array<{ index: number; name: string }>) {
  if (!value || typeof value !== "object" || !Array.isArray((value as { rows?: unknown }).rows)) {
    throw new Error("OpenAI devolvió una respuesta sin filas válidas.");
  }

  const rows = (value as { rows: unknown[] }).rows;
  if (rows.length !== products.length) throw new Error("OpenAI no devolvió todas las filas.");

  const expected = new Map(products.map((product) => [product.index, product.name]));
  const seen = new Set<number>();

  for (const row of rows) {
    if (!row || typeof row !== "object") throw new Error("OpenAI devolvió una fila inválida.");
    const candidate = row as Record<string, unknown>;
    const index = candidate.product_index;

    if (!Number.isInteger(index) || !expected.has(index as number) || seen.has(index as number)) {
      throw new Error("OpenAI devolvió un índice de producto inválido o repetido.");
    }
    if (candidate.product_name !== expected.get(index as number)) {
      throw new Error(`El producto de la fila ${(index as number) + 1} no coincide con la lista.`);
    }
    if (!Array.isArray(candidate.uncertain_fields) ||
      candidate.uncertain_fields.some((field) => !fieldNames.includes(field as typeof fieldNames[number]))) {
      throw new Error(`La fila ${(index as number) + 1} contiene avisos de lectura inválidos.`);
    }

    for (const field of fieldNames) {
      const count = candidate[field];
      if (count !== null && (!Number.isInteger(count) || (count as number) < 0 || (count as number) > 9999)) {
        throw new Error(`La cantidad de la fila ${(index as number) + 1} no es un entero válido.`);
      }
    }
    seen.add(index as number);
  }

  if (seen.size !== products.length) throw new Error("OpenAI omitió alguna fila.");
  return rows;
}

runtime.Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return jsonResponse({ error: "Usa una petición POST." }, 405);

  const openAiKey = runtime.Deno.env.get("OPENAI_API_KEY");
  const expectedAccessCode = runtime.Deno.env.get("OCR_ACCESS_CODE");
  if (!openAiKey || !expectedAccessCode || expectedAccessCode.length < 32) {
    return jsonResponse({ error: "La función no está configurada. Revisa sus secretos en Supabase." }, 503);
  }

  const contentLength = Number(request.headers.get("content-length") || 0);
  if (contentLength > maxImageDataUrlLength + 100_000) {
    return jsonResponse({ error: "La imagen es demasiado grande. Prueba con una foto de menor resolución." }, 413);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "La petición no contiene un JSON válido." }, 400);
  }

  const accessCode = body.accessCode;
  if (typeof accessCode !== "string" || !matchesSecret(accessCode, expectedAccessCode)) {
    return jsonResponse({ error: "El código de acceso al OCR no es válido." }, 401);
  }

  const imageDataUrl = body.imageDataUrl;
  if (typeof imageDataUrl !== "string" || imageDataUrl.length > maxImageDataUrlLength ||
    !/^data:image\/jpeg;base64,[A-Za-z0-9+/]+={0,2}$/.test(imageDataUrl)) {
    return jsonResponse({ error: "La imagen debe ser JPEG y tener un tamaño válido." }, 400);
  }

  const products = body.products;
  if (!Array.isArray(products) || products.length < 1 || products.length > 100) {
    return jsonResponse({ error: "La lista de productos no es válida." }, 400);
  }
  const normalizedProducts: Array<{ index: number; name: string }> = [];
  for (let index = 0; index < products.length; index++) {
    const product = products[index];
    if (!product || typeof product !== "object" || product.index !== index ||
      typeof product.name !== "string" || product.name.trim().length < 1 || product.name.length > 120) {
      return jsonResponse({ error: "La lista de productos contiene datos inválidos." }, 400);
    }
    normalizedProducts.push({ index, name: product.name });
  }

  const prompt = [
    "Lee la hoja de control de productos en la imagen. Devuelve todos los productos exactamente en el orden de la lista.",
    "Cada fila de la lista contiene un índice y el nombre esperado del producto. Asocia una fila de la foto solo cuando el nombre impreso coincida.",
    "Las columnas son INICIAL, REPOSICIÓN, SOBRANTE y MERMA. Extrae solo números manuscritos dentro de esas celdas.",
    "Una celda vacía, tapada o ilegible debe ser null; nunca la conviertas en cero ni deduzcas un valor.",
    "Si un número no se puede leer con seguridad, devuelve tu mejor lectura y añade el nombre de su campo a uncertain_fields. Si no hay una lectura razonable, usa null.",
    "No inventes, completes ni copies cantidades de otras filas. Devuelve exactamente una fila por producto, con el índice y el nombre tal como se proporcionaron.",
    `Lista de productos: ${JSON.stringify(normalizedProducts)}`,
  ].join("\n");

  let openAiResponse: Response;
  try {
    openAiResponse = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openAiKey}`,
        "Content-Type": "application/json",
      },
      signal: AbortSignal.timeout(90_000),
      body: JSON.stringify({
        model: "gpt-4.1-mini",
        store: false,
        max_output_tokens: 5000,
        input: [
          { role: "system", content: [{ type: "input_text", text: "Eres un lector de formularios. Prioriza la fidelidad visual; no completes datos ausentes." }] },
          {
            role: "user",
            content: [
              { type: "input_text", text: prompt },
              { type: "input_image", image_url: imageDataUrl, detail: "high" },
            ],
          },
        ],
        text: {
          format: {
            type: "json_schema",
            name: "control_sheet_reading",
            strict: true,
            schema: outputSchema,
          },
        },
      }),
    });
  } catch (error) {
    console.error("OpenAI request failed:", error instanceof Error ? error.message : "unknown error");
    return jsonResponse({ error: "No se pudo conectar con OpenAI. Comprueba la conexión e inténtalo de nuevo." }, 502);
  }

  if (!openAiResponse.ok) {
    if (openAiResponse.status === 401) {
      return jsonResponse({ error: "OpenAI no aceptó la clave API. Revísala en los secretos de Supabase." }, 502);
    }
    if (openAiResponse.status === 429) {
      return jsonResponse({ error: "OpenAI rechazó la petición por límite de uso o saldo. Comprueba tu cuenta de API." }, 429);
    }
    console.error("OpenAI returned HTTP", openAiResponse.status);
    return jsonResponse({ error: `OpenAI no pudo procesar la imagen (HTTP ${openAiResponse.status}).` }, 502);
  }

  let openAiResult: Record<string, unknown>;
  try {
    openAiResult = await openAiResponse.json();
  } catch {
    return jsonResponse({ error: "OpenAI devolvió una respuesta que no se pudo interpretar." }, 502);
  }

  const outputText = getOutputText(openAiResult);
  if (!outputText) return jsonResponse({ error: "OpenAI no devolvió una lectura completa para esta imagen." }, 502);

  let parsedOutput: unknown;
  try {
    parsedOutput = JSON.parse(outputText);
  } catch {
    return jsonResponse({ error: "OpenAI devolvió datos que no tienen un formato válido." }, 502);
  }

  try {
    return jsonResponse({ rows: validateRows(parsedOutput, normalizedProducts) });
  } catch (error) {
    return jsonResponse({
      error: error instanceof Error ? error.message : "OpenAI devolvió filas inválidas.",
    }, 502);
  }
});
