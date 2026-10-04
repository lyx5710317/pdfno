// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import {convertText} from './text-adapter';
let consumed=false;
window.PDFnoTextEngine={convert(message){
  if(consumed||!message||message.v!==1||typeof message.session!=='string'||typeof message.source!=='string')throw Error('Invalid text bridge');
  consumed=true;
  return JSON.stringify({v:1,session:message.session,bookID:message.bookID,editionID:message.editionID,fileSHA256:message.fileSHA256,...convertText(message.source,message.format)});
}};
