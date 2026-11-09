
import { io } from 'socket.io-client';

const BASE_URL = 'http://localhost:3000';

async function main() {
  let socket;

  try {
    console.log('Creating a second guest session...');

    // 1. Create a new guest session
    const sessionResponse = await fetch(
      `${BASE_URL}/api/guest/session`,
      { method: 'POST' }
    );

    const sessionResult = await sessionResponse.json();

    if (!sessionResponse.ok) {
      throw new Error(JSON.stringify(sessionResult));
    }

    const guest = sessionResult.data;
    const token = guest.sessionToken;

    console.log('Second guest created:', guest.guestId);

    // 2. Connect the second guest to Socket.IO
    console.log('\nConnecting second guest to Socket.IO...');

    socket = io(BASE_URL, {
      transports: ['websocket'],
      auth: { token },
      reconnection: false,
    });

    await new Promise((resolve, reject) => {
      socket.once('connect', resolve);
      socket.once('connect_error', reject);
    });

    console.log('Second guest connected:', socket.id);

    // 3. Register listener before joining the queue
    const matchEvent = new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error('Timed out waiting for match_found.'));
      }, 30000);

      socket.once('match_found', (data) => {
        clearTimeout(timeout);
        resolve(data);
      });
    });

    // 4. Join matchmaking queue
    console.log('\nJoining matchmaking queue...');

    const joinResponse = await fetch(
      `${BASE_URL}/api/matchmaking/join`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({}),
      }
    );

    const joinResult = await joinResponse.json();

    console.log('Join response:', JSON.stringify(joinResult, null, 2));

    if (!joinResponse.ok) {
      throw new Error(JSON.stringify(joinResult));
    }

    // 5. Wait for match_found
    console.log('\nWaiting for match_found event...');

    const match = await matchEvent;

    console.log('\nSUCCESS! Match event received.');
    console.log('Match ID:', match.matchId);
    console.log('Partner Guest ID:', match.partnerGuestId);
    console.log('\nCheck your vivo phone now.');

  } catch (error) {
    console.error('\nTEST FAILED:', error);
    process.exitCode = 1;
  } finally {
    if (socket) {
      socket.disconnect();
    }
  }
}

main();
