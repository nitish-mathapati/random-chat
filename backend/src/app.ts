import express, {
  type Express,
  type Request,
  type Response,
} from 'express';

import healthRoutes from './routes/health.routes.js';
import guestRoutes from './routes/guest.routes.js';
import matchmakingRoutes from './routes/matchmaking.routes.js';
import { createRateLimiter } from './middleware/rate-limit.middleware.js';

const app: Express = express();

app.use(express.json({ limit: '10kb' }));

app.get('/', (request: Request, response: Response) => {
  response.status(200).json({
    application: 'UserChat Backend',
    message: 'Welcome to the UserChat API!',
  });
});

app.use('/health', healthRoutes);
// /api/users is not mounted: it has no authentication and the app does not use it.
app.use('/api/guest', createRateLimiter(20, 15 * 60 * 1000), guestRoutes);
app.use('/api/matchmaking', createRateLimiter(60, 60 * 1000), matchmakingRoutes);

app.use((request: Request, response: Response) => {
  response.status(404).json({
    status: 'error',
    message: 'Route not found',
    path: request.originalUrl,
  });
});

export default app;