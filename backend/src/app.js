import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import mongoose from 'mongoose';
import 'dotenv/config';

import authRoutes from './routes/auth.routes.js';
import expenseRoutes from './routes/expense.routes.js';
import journeyRoutes from './routes/journey.routes.js';
import { errorHandler } from './middleware/errorHandler.js';

const app = express();

// Middleware
app.use(helmet());
// Trust proxy (for ngrok and other reverse proxies)
app.set('trust proxy', 1);
app.use(cors({ origin: process.env.ALLOWED_ORIGINS?.split(',') ?? '*' }));
app.use(express.json());

// Request logger middleware - logs incoming requests and responses
app.use((req, res, next) => {
  const start = Date.now();
  console.log(`[API] ${req.method} ${req.path} - Body:`, req.body);
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`[API] ${req.method} ${req.path} - Status: ${res.statusCode} - ${duration}ms`);
  });
  
  next();
});

app.use(rateLimit({ windowMs: 15 * 60 * 1000, max: 100, skip: (req) => req.path === '/health' }));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/expenses', expenseRoutes);
app.use('/api/journeys', journeyRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Error handler
app.use(errorHandler);

// Connect to MongoDB & Start Server
mongoose
  .connect(process.env.MONGO_URI)
  .then(() => {
    console.log(' MongoDB connected');
    app.listen(process.env.PORT ?? 3000, '0.0.0.0', () => {
      console.log(` Server running on port ${process.env.PORT ?? 3000}`);
      console.log(` Listening on 0.0.0.0 - Should be reachable from emulator at http://10.0.2.2:${process.env.PORT ?? 3000}`);
      console.log(` Test /health endpoint: http://localhost:${process.env.PORT ?? 3000}/health`);
    });
  })
  .catch((err) => {
    console.error(' MongoDB connection failed:', err);
    process.exit(1);
  });

export default app;
