import type { RequestHandler } from 'express';

interface Window {
  count: number;
  resetAt: number;
}

// In-memory fixed-window limiter; use a shared store (e.g. Redis) when running multiple instances.
export const createRateLimiter = (
  maxRequests: number,
  windowMs: number
): RequestHandler => {
  const windows = new Map<string, Window>();

  setInterval(() => {
    const now = Date.now();
    for (const [key, window] of windows) {
      if (window.resetAt <= now) windows.delete(key);
    }
  }, windowMs).unref();

  return (request, response, next) => {
    const key = request.ip ?? 'unknown';
    const now = Date.now();
    const window = windows.get(key);

    if (!window || window.resetAt <= now) {
      windows.set(key, { count: 1, resetAt: now + windowMs });
      next();
      return;
    }

    window.count += 1;

    if (window.count > maxRequests) {
      response.setHeader(
        'Retry-After',
        Math.ceil((window.resetAt - now) / 1000).toString()
      );
      response.status(429).json({
        status: 'error',
        message: 'Too many requests. Please try again later.',
      });
      return;
    }

    next();
  };
};
