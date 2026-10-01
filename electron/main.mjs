// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import {
  app,
  BrowserWindow,
  ipcMain,
  protocol,
  net,
  session,
  Menu,
  shell,
} from 'electron';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { NoteStore } from './note-store.mjs';
import { allowedRenderer, resourcePath } from './security.mjs';
const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const dev = process.argv.includes('--dev');
app.setName('PDFno');
protocol.registerSchemesAsPrivileged([
  {
    scheme: 'pdfno',
    privileges: { standard: true, secure: true, supportFetchAPI: true },
  },
]);
let window;
function verify(event) {
  if (
    !window ||
    event.sender !== window.webContents ||
    event.senderFrame !== window.webContents.mainFrame ||
    !allowedRenderer(event.senderFrame.url, dev)
  )
    throw new Error('IPC_DENIED');
}
app.whenReady().then(() => {
  const store = new NoteStore(path.join(app.getPath('userData'), 'library'));
  protocol.handle('pdfno', async (request) => {
    try {
      return await net.fetch(
        pathToFileURL(resourcePath(request.url, path.join(root, 'dist'))).href,
      );
    } catch {
      return new Response('Unavailable', { status: 404 });
    }
  });
  session.defaultSession.setPermissionRequestHandler(
    (_contents, _permission, callback) => callback(false),
  );
  session.defaultSession.setPermissionCheckHandler(() => false);
  ipcMain.handle('notes:load', async (event, ...args) => {
    verify(event);
    if (args.length) throw new Error('IPC_INVALID');
    return store.load();
  });
  ipcMain.handle('notes:save', async (event, note, ...rest) => {
    verify(event);
    if (rest.length) throw new Error('IPC_INVALID');
    return store.save(note);
  });
  ipcMain.handle('native:capabilities', async (event, ...args) => {
    verify(event);
    if (args.length) throw new Error('IPC_INVALID');
    if (process.platform !== 'darwin') return { unavailable: true };
    try {
      const { stdout } = await promisify(execFile)(
        path.join(root, 'native/build/Build/Products/Release/PDFnoBridge'),
        ['capabilities'],
        { timeout: 3000, maxBuffer: 4096 },
      );
      const c = JSON.parse(stdout);
      if (
        c.schemaVersion !== 1 ||
        c.platform !== 'macOS' ||
        c.keychain !== 'not-integrated' ||
        c.iCloud !== 'disabled'
      )
        throw new Error('BRIDGE_INVALID');
      return c;
    } catch {
      return { unavailable: true };
    }
  });
  function createWindow() {
    window = new BrowserWindow({
      width: 1400,
      height: 920,
      minWidth: 680,
      minHeight: 620,
      title: 'PDFno',
      backgroundColor: '#141b1c',
      webPreferences: {
        preload: path.join(root, 'electron/preload.cjs'),
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: true,
        webSecurity: true,
      },
    });
    window.webContents.setWindowOpenHandler(({ url }) => {
      const sourceLinks = new Set([
        'https://github.com/lyx5710317/pdfno',
        'https://github.com/lyx5710317/pdfno/blob/main/LICENSE',
      ]);
      if (sourceLinks.has(url)) void shell.openExternal(url);
      return { action: 'deny' };
    });
    window.webContents.on('will-navigate', (event, url) => {
      if (!allowedRenderer(url, dev)) event.preventDefault();
    });
    if (dev) window.loadURL('http://127.0.0.1:5173');
    else window.loadURL('pdfno://app/index.html');
  }
  Menu.setApplicationMenu(
    Menu.buildFromTemplate([
      { label: 'PDFno', submenu: [{ role: 'about' }, { role: 'quit' }] },
      { role: 'editMenu' },
      { role: 'viewMenu' },
      { role: 'windowMenu' },
    ]),
  );
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
  app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
  });
});
