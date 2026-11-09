import type { Request, Response } from 'express';

import { getHealthStatus } from '../services/health.service.js';

export const checkHealth = (
  request: Request,
  response: Response
): void => {
  const healthStatus = getHealthStatus();

  response.status(200).json(healthStatus);
};