// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import {convertDOCX} from './docx-adapter';
let consumed=false;
window.PDFnoDOCXEngine={async convert(message){
  if(consumed||!message||message.v!==1||typeof message.session!=='string'||typeof message.data!=='string'||message.data.length>28*1024*1024)throw Error('Invalid DOCX bridge');
  consumed=true;
  const bytes=Uint8Array.from(atob(message.data),x=>x.charCodeAt(0));
  const converted=await convertDOCX(bytes.buffer);
  return JSON.stringify({v:1,session:message.session,bookID:message.bookID,editionID:message.editionID,fileSHA256:message.fileSHA256,...converted});
}};
