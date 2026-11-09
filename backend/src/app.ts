import express, {
  type Express,
  type Request,
  type Response,
} from 'express';

import healthRoutes from './routes/health.routes.js';
import userRoutes from './routes/user.routes.js';
import guestRoutes from './routes/guest.routes.js';
import matchmakingRoutes from './routes/matchmaking.routes.js';

const app: Express = express();

app.use(express.json());

app.get('/', (request: Request, response: Response) => {
  response.status(200).json({
    application: 'UserChat Backend',
    message: 'Welcome to the UserChat API!',
  });
});

app.use('/health', healthRoutes);
app.use('/api/users', userRoutes);
app.use('/api/guest', guestRoutes);
app.use('/api/matchmaking', matchmakingRoutes);

app.use((request: Request, response: Response) => {
  response.status(404).json({
    status: 'error',
    message: 'Route not found',
    path: request.originalUrl,
  });
});

export default app;