require('dotenv').config();
const express = require('express');
const axios = require('axios');
const helmet = require('helmet');
const cors = require('cors');

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '1mb' }));

const PORT = process.env.PORT || 3000;
const GEMINI_KEY = process.env.GEMINI_API_KEY || '';
const MAX_DAILY = parseInt(process.env.MAX_DAILY_PER_INSTALLATION || '1000', 10);

if (!GEMINI_KEY) {
  console.warn('Warning: GEMINI_API_KEY not set in environment. Proxy will not be able to call the Gemini API.');
}

// Simple in-memory counters per installationKey with daily reset.
const usageMap = new Map();
function ensureUsageRecord(key) {
  const today = new Date().toISOString().slice(0, 10);
  const rec = usageMap.get(key);
  if (!rec || rec.date !== today) {
    usageMap.set(key, { date: today, count: 0 });
  }
}

app.post('/assistant/query', async (req, res) => {
  try {
    const { schema, userQuestion, conversationHistory = [], installationKey = '', functionResponses = [] } = req.body;

    // Enforce simple per-installation daily limit
    const key = installationKey || req.ip || 'anonymous';
    ensureUsageRecord(key);
    const rec = usageMap.get(key);
    if (rec.count >= MAX_DAILY) {
      return res.status(429).json({ error: 'Daily quota exceeded for this installation.' });
    }

    // Build system instructions
    const fullSystemInstruction = `You are an advanced AI Assistant for a School Management System.
You have direct read-only access to the local SQLite database via two tools that the client will execute: get_database_schema and execute_sql_query.
When you need the schema, request: CALL_FUNCTION:get_database_schema|{}
When you need data, request: CALL_FUNCTION:execute_sql_query|{"query": "SELECT ..."}
Return function calls formatted as CALL_FUNCTION:<function_name>|<json_args> when querying data.
Format final answers clearly, accurately, and politely.${schema ? `\n\nDatabase schema:\n${schema}` : ''}`;

    // Build contents for modern Gemini v1beta generateContent API
    const contents = [];

    // Replay conversation history
    for (const m of conversationHistory) {
      contents.push({
        role: m.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: m.content || '' }],
      });
    }

    // Add user question
    contents.push({
      role: 'user',
      parts: [{ text: userQuestion }],
    });

    // If functionResponses are supplied, add them as context
    for (const fr of functionResponses) {
      contents.push({
        role: 'user',
        parts: [{ text: `[Function Result for ${fr.name}]: ${JSON.stringify(fr.result)}` }],
      });
    }

    if (!GEMINI_KEY) {
      return res.status(500).json({ error: 'Server not configured with GEMINI_API_KEY' });
    }

    // Call Gemini Generative API with active model
    const model = process.env.GEMINI_MODEL || 'gemini-flash-latest';
    const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_KEY}`;
    const apiBody = {
      systemInstruction: {
        parts: [{ text: fullSystemInstruction }],
      },
      contents: contents,
      generationConfig: {
        maxOutputTokens: 2048,
        temperature: 0.2,
      },
    };

    const apiResp = await axios.post(apiUrl, apiBody, { timeout: 25000 });
    
    // Parse Gemini generateContent response
    let assistantText = '';
    const candidate = apiResp.data?.candidates?.[0];
    if (candidate?.content?.parts) {
      assistantText = candidate.content.parts.map(p => p.text || '').join('\n');
    }

    // Parse function calls if model requested one
    let functionCalls = [];
    if (assistantText && assistantText.includes('CALL_FUNCTION:')) {
      const lines = assistantText.split('\n');
      for (const line of lines) {
        if (line.includes('CALL_FUNCTION:')) {
          const cleanLine = line.substring(line.indexOf('CALL_FUNCTION:'));
          const rest = cleanLine.replace('CALL_FUNCTION:', '').trim();
          const idx = rest.indexOf('|');
          if (idx > 0) {
            const name = rest.substring(0, idx).trim();
            const argsJson = rest.substring(idx + 1).trim();
            try {
              const args = JSON.parse(argsJson);
              functionCalls.push({ name, args });
            } catch (e) {
              // ignore JSON parse error
            }
          }
        }
      }
    }

    // If no functionCalls detected, return final answer
    if (functionCalls.length === 0) {
      rec.count += 1;
      usageMap.set(key, rec);
      return res.json({ final: true, text: assistantText || 'No response generated.' });
    }

    // Otherwise return function calls to client
    rec.count += 1;
    usageMap.set(key, rec);
    return res.json({ final: false, functionCalls, conversationHistory: contents });
  } catch (err) {
    const errorDetails = err?.response?.data || err?.message || err?.toString();
    console.error('Proxy error:', errorDetails);
    return res.status(500).json({ error: 'Internal proxy error', details: errorDetails });
  }
});

app.listen(PORT, () => {
  console.log(`Assistant proxy listening on ${PORT}`);
});
