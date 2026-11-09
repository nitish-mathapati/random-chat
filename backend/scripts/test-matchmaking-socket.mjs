
import { io } from 'socket.io-client';

const BASE_URL = 'http://localhost:3000';

async function createGuest() {
  const response = await fetch(`${BASE_URL}/api/guest/session`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({}),
  });

  const result = await response.json();

  if (!response.ok) {
    throw new Error(`Guest creation failed: ${JSON.stringify(result)}`);
  }

  return result.data;
}

async function joinQueue(token) {
  const response = await fetch(`${BASE_URL}/api/matchmaking/join`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: '{}',
  });

  const result = await response.json();

  if (!response.ok) {
    throw new Error(`Matchmaking failed: ${JSON.stringify(result)}`);
  }

  return result;
}

async function cancelQueue(token) {
  const response = await fetch(`${BASE_URL}/api/matchmaking/cancel`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  const result = await response.json();

  if (!response.ok) {
    throw new Error(`Queue cancellation failed: ${JSON.stringify(result)}`);
  }

  return result;
}

function connectGuest(guest, label) {
  return new Promise((resolve, reject) => {
    const socket = io(BASE_URL, {
      transports: ['websocket'],
      auth: { token: guest.sessionToken },
      reconnection: false,
      timeout: 10000,
    });

    socket.on('connect', () => {
      console.log(`[${label}] Socket connected: ${socket.id}`);
      resolve(socket);
    });

    socket.on('connect_error', (error) => {
      reject(new Error(`[${label}] Connection failed: ${error.message}`));
    });
  });
}

function waitForMatch(socket, label) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error(`[${label}] Timed out waiting for match_found`));
    }, 10000);

    socket.once('match_found', (data) => {
      clearTimeout(timeout);
      console.log(`[${label}] Received match_found:`, data);
      resolve(data);
    });
  });
}

async function main() {
  let socketA;
  let socketB;

  try {
    console.log('\nCreating two fresh guest sessions...');

    const guestA = await createGuest();
    const guestB = await createGuest();

    console.log('Guest A:', guestA.guestId);
    console.log('Guest B:', guestB.guestId);

    console.log('\nConnecting both guests...');

    socketA = await connectGuest(guestA, 'Guest A');
    socketB = await connectGuest(guestB, 'Guest B');

    // Register listeners before matchmaking starts.
    const eventA = waitForMatch(socketA, 'Guest A');
    const eventB = waitForMatch(socketB, 'Guest B');

    console.log('\nGuest A joining the queue...');

    const resultA = await joinQueue(guestA.sessionToken);
    console.log('Guest A result:', resultA);

    if (resultA.data.status !== 'waiting') {
      throw new Error(
        `Guest A was expected to wait, but received: ${resultA.data.status}`
      );
    }

    console.log('\nGuest B joining the queue...');

    const resultB = await joinQueue(guestB.sessionToken);
    console.log('Guest B result:', resultB);

    if (resultB.data.status !== 'matched') {
      throw new Error('Guest B was expected to be matched.');
    }

    console.log('\nWaiting for both real-time events...');

    const [matchA, matchB] = await Promise.all([eventA, eventB]);

    if (
      matchA.matchId !== matchB.matchId ||
      matchA.partnerGuestId !== guestB.guestId ||
      matchB.partnerGuestId !== guestA.guestId
    ) {
      throw new Error('The two guests received inconsistent match information.');
    }

    console.log('\nSUCCESS: Both guests received the correct match event.');
    console.log('Match ID:', matchA.matchId);
  } finally {
    socketA?.disconnect();
    socketB?.disconnect();
  }
}

main().catch((error) => {
  console.error('\nTEST FAILED:', error.message);
  process.exitCode = 1;
});
