// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld(
  'pdfno',
  Object.freeze({
    loadNotes: () => ipcRenderer.invoke('notes:load'),
    saveNote: (note) => ipcRenderer.invoke('notes:save', note),
    nativeCapabilities: () => ipcRenderer.invoke('native:capabilities'),
  }),
);
