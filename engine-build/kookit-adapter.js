// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
// Adapted from Kookit EpubRender 95f602e: replace fallback loaders and async Promise executor.
import GeneralRender from './vendor/kookit/src/renders/GeneralRender';
import GeneralParser from './vendor/kookit/src/utils/generalParser';
import {EPUB} from './vendor/kookit/src/libs/epub';
import {createIframe,handleLayout} from './vendor/kookit/src/utils/layoutUtil';
import {makeLoader} from './loader';
export class EpubRender extends GeneralRender {
  constructor(buffer,names) {
    super({format:'EPUB', readerMode:'single', textOrientation:'horizontal', isAllowScript:'no',
      isMobile:'no', animation:'none', isBionic:'no', isHyphenation:'no', convertChinese:'',
      bookLayout:'', codeHighlight:'', fullTranslationMode:'no', textRules:[]});
    this.buffer=buffer; this.names=names;
  }
  async renderTo(element) {
    this.element=element;
    this.book=await new EPUB(await makeLoader(this.buffer,this.names)).init();
    if (!this.book.sections.length || this.book.sections.some(x => !x)) throw Error('Empty or invalid spine');
    if (this.book.rendition?.layout === 'pre-paginated') throw Error('Fixed layout not accepted in this first EPUB slice');
    const parser=new GeneralParser(this.book);
    this.chapterList=await parser.getChapter(this.book.toc);
    this.chapterDocList=await parser.getChapterDoc();
    createIframe(element,'no');
    const doc=this.getDocument(); if (!doc) throw Error('Reader document unavailable');
    handleLayout(element,this.readerMode,doc);
  }
}
