
import { io } from 'socket.io-client';
import readline from 'node:readline';

const BASE_URL = 'http://localhost:3000';

let socket;
let matchId = null;
let partnerGuestId = null;
let isMatched = false;

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

async function createGuestSession() {
  console.log('Creating laptop guest session...');

  const response = await fetch(`${BASE_URL}/api/guest/session`, {
    method: 'POST',
  });

  const result = await response.json();

  if (!response.ok) {
    throw new Error(JSON.stringify(result));
  }

  console.log('Laptop Guest ID:', result.data.guestId);

  return result.data.sessionToken;
}

async function connectSocket(token) {
  console.log('\nConnecting to Socket.IO...');

  socket = io(BASE_URL, {
    transports: ['websocket'],
    auth: { token },
    reconnection: true,
  });

  await new Promise((resolve, reject) => {
    socket.once('connect', resolve);
    socket.once('connect_error', reject);
  });

  console.log('Connected successfully:', socket.id);

  // Listen for successful matchmaking.
  socket.on('match_found', (data) => {
    matchId = data.matchId;
    partnerGuestId = data.partnerGuestId;
    isMatched = true;

    console.log('\n====================================');
    console.log('       MATCH FOUND!');
    console.log('====================================');
    console.log('Match ID:', matchId);
    console.log('Phone Guest ID:', partnerGuestId);
    console.log('\nYou can now exchange messages.');
    console.log('Type your message and press Enter.');
    console.log('Type /exit to disconnect.\n');

    socket.emit('get_chat_history', {
      matchId,
      limit: 50,
    });

    showPrompt();
  });

  // Receive messages from the phone.
  socket.on('new_message', (data) => {
    if (data.matchId !== matchId) return;

    const isOwnMessage = data.senderGuestId !== partnerGuestId;

    console.log('\n');
    console.log(
      isOwnMessage ? '[YOU]' : '[VIVO PHONE]',
      data.message
    );

    showPrompt();
  });

  // Receive previous messages.
  socket.on('chat_history', (data) => {
    if (data.matchId !== matchId) return;

    console.log('\n========== CHAT HISTORY ==========');

    if (data.messages.length === 0) {
      console.log('No previous messages.');
    } else {
      for (const message of data.messages) {
        const sender =
          message.senderGuestId === partnerGuestId
            ? 'VIVO PHONE'
            : 'YOU';

        console.log(`[${sender}] ${message.message}`);
      }
    }

    console.log('==================================\n');
  });

  socket.on('message_error', (data) => {
    console.log('\n[MESSAGE ERROR]', data.message);
    showPrompt();
  });

  socket.on('disconnect', (reason) => {
    console.log('\n[Socket] Disconnected:', reason);
  });

  socket.on('connect_error', (error) => {
    console.log('\n[Socket] Connection error:', error.message);
  });
}

async function joinMatchmaking(token) {
  console.log('\nJoining matchmaking queue...');

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

  console.log('Queue response:', result.data.status);

  if (result.data.status === 'matched') {
    matchId = result.data.matchId;
    partnerGuestId = result.data.partnerGuestId;
    isMatched = true;

    console.log('\nAlready matched!');
    console.log('Match ID:', matchId);

    socket.emit('get_chat_history', {
      matchId,
      limit: 50,
    });

    showPrompt();
  } else if (result.data.status === 'already_matched') {
    throw new Error(
      'This guest already has an active match. Please inspect the queue state.'
    );
  } else {
    console.log('\nWaiting for your vivo phone to connect...');
  }
}

function showPrompt() {
  if (!isMatched) return;

  rl.setPrompt('You: ');
  rl.prompt();
}

rl.on('line', (input) => {
  const message = input.trim();

  if (message === '/exit') {
    console.log('\nDisconnecting laptop guest...');

    if (socket) {
      socket.disconnect();
    }

    rl.close();
    process.exit(0);
  }

  if (!message) {
    showPrompt();
    return;
  }

  if (!isMatched || !matchId) {
    console.log('Not matched yet. Please wait.');
    return;
  }

  socket.emit('send_message', {
    matchId,
    message,
  });

  showPrompt();
});

async function main() {
  try {
    const token = await createGuestSession();

    await connectSocket(token);

    await joinMatchmaking(token);
  } catch (error) {
    console.error('\nTEST CLIENT FAILED:', error.message);

    if (socket) {
      socket.disconnect();
    }

    rl.close();
    process.exitCode = 1;
  }
}

main();
