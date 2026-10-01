import { spawn } from 'node:child_process';
import path from 'node:path';
const suffix = process.platform === 'win32' ? '.cmd' : '';
const vite = spawn(
  path.join('node_modules', '.bin', 'vite' + suffix),
  ['--host', '127.0.0.1'],
  { stdio: 'inherit' },
);
let electron;
let stopping = false;
const stop = () => {
  if (stopping) return;
  stopping = true;
  vite.kill();
  electron?.kill();
};
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, stop);
for (let i = 0; i < 100 && !stopping; i++) {
  try {
    const response = await fetch('http://127.0.0.1:5173');
    if (response.ok) {
      electron = spawn(
        path.join('node_modules', '.bin', 'electron' + suffix),
        ['.', '--dev'],
        { stdio: 'inherit' },
      );
      electron.on('exit', stop);
      break;
    }
  } catch {
    /* local dev server is starting */
  }
  await new Promise((resolve) => setTimeout(resolve, 100));
}
if (!electron) {
  stop();
  process.exitCode = 1;
}
vite.on('exit', stop);
