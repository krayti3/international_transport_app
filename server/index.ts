import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { createClient } from '@supabase/supabase-js';

const app = express();
app.use(cors());
app.use(express.json());

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SECRET_KEY ?? process.env.SUPABASE_PUBLISHABLE_KEY!
);

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.get('/todos', async (_req, res) => {
  const { data, error } = await supabase.from('todos').select('*');
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
});

app.post('/todos', async (req, res) => {
  const { name } = req.body;
  if (!name) return res.status(400).json({ error: 'name is required' });
  const { data, error } = await supabase.from('todos').insert([{ name }]).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.status(201).json(data);
});

const port = process.env.PORT ?? 3000;
app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});
