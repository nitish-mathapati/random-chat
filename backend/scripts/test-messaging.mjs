
import { io } from 'socket.io-client';

const BASE_URL = 'http://localhost:3000';

const waitForEvent = (socket, eventName, timeoutMs = 15000) => {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      socket.off(eventName, handler);
      reject(new Error(`Timed out waiting for ${eventName}.`));
    }, timeoutMs);

    const handler = (data) => {
      clearTimeout(timeout);
      resolve(data);
    };

    socket.once(eventName, handler);
  });
};

async function createGuest() {
  const response = await fetch(
    `${BASE_URL}/api/guest/session`,
    { method: 'POST' }
  );

  const result = await response.json();

  if (!response.ok) {
    throw new Error(JSON.stringify(result));
  }

  return {
    guestId: result.data.guestId,
    token: result.data.sessionToken,
  };
}

async function connectGuest(token) {
  const socket = io(BASE_URL, {
    transports: ['websocket'],
    auth: { token },
    reconnection: false,
  });

  await new Promise((resolve, reject) => {
    socket.once('connect', resolve);
    socket.once('connect_error', reject);
  });

  return socket;
}

async function joinQueue(token) {
  const response = await fetch(
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

  const result = await response.json();

  if (!response.ok) {
    throw new Error(JSON.stringify(result));
  }

  return result.data;
}

async function main() {
  let socketA;
  let socketB;

  try {
    console.log('Creating two guest sessions...');

    const guestA = await createGuest();
    const guestB = await createGuest();

    console.log('Guest A:', guestA.guestId);
    console.log('Guest B:', guestB.guestId);

    console.log('\nConnecting both guests...');

    socketA = await connectGuest(guestA.token);
    socketB = await connectGuest(guestB.token);

    console.log('Guest A connected.');
    console.log('Guest B connected.');

    // Register match listeners before joining queues.
    const matchAEvent = waitForEvent(socketA, 'match_found');
    const matchBEvent = waitForEvent(socketB, 'match_found');

    console.log('\nGuest A joining matchmaking...');

    const joinA = await joinQueue(guestA.token);
    console.log('Guest A queue status:', joinA.status);

    if (joinA.status !== 'waiting') {
      throw new Error(
        'Guest A was not waiting. Check for existing queue entries.'
      );
    }

    console.log('\nGuest B joining matchmaking...');

    const joinB = await joinQueue(guestB.token);
    console.log('Guest B queue status:', joinB.status);

    if (joinB.status !== 'matched') {
      throw new Error(
        'Guest B did not create a new match. Check matchmaking state.'
      );
    }

    const [matchA, matchB] = await Promise.all([
      matchAEvent,
      matchBEvent,
    ]);

    if (matchA.matchId !== matchB.matchId) {
      throw new Error('Guests received different match IDs.');
    }

    const matchId = matchA.matchId;

    console.log('\nSUCCESS: Both guests matched.');
    console.log('Match ID:', matchId);

    // Listen for the message before sending it.
    const receivedMessageEvent = waitForEvent(
      socketB,
      'new_message'
    );

    const testMessage =
      'Hello! This is a real-time messaging test.';

    console.log('\nGuest A sending message:', testMessage);

    socketA.emit('send_message', {
      matchId,
      message: testMessage,
    });

    const receivedMessage = await receivedMessageEvent;

    console.log('\nSUCCESS: Guest B received the message.');
    console.log(JSON.stringify(receivedMessage, null, 2));

    if (
      receivedMessage.message !== testMessage ||
      receivedMessage.senderGuestId !== guestA.guestId
    ) {
      throw new Error('Received message content or sender is incorrect.');
    }

    // Request chat history from Guest B.
    const historyEvent = waitForEvent(socketB, 'chat_history');

    console.log('\nGuest B requesting chat history...');

    socketB.emit('get_chat_history', {
      matchId,
      limit: 50,
    });

    const history = await historyEvent;

    console.log('\nSUCCESS: Chat history received.');
    console.log(JSON.stringify(history, null, 2));

    const savedMessage = history.messages.find(
      (item) => item.id === receivedMessage.id
    );

    if (!savedMessage) {
      throw new Error('Sent message was not found in chat history.');
    }

    console.log('\nALL MESSAGING TESTS PASSED.');

  } catch (error) {
    console.error('\nTEST FAILED:', error);
    process.exitCode = 1;
  } finally {
    if (socketA) socketA.disconnect();
    if (socketB) socketB.disconnect();
  }
}

main();
