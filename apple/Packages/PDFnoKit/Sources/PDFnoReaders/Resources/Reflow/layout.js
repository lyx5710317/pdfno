// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
// Original measured-page layout. Source text/ruby is retained in DOM order;
// physical pages are presentation, never stored source coordinates.
(() => {
  'use strict';
  const nodes = root => {
    const d=root.ownerDocument, result=[], walker=d.createTreeWalker(root,4,{acceptNode:n=>n.parentElement?.closest('rt,rp,script,style,noscript,[data-pdfno-annotation-overlay]')?2:1});
    while(walker.nextNode()) if(walker.currentNode.length) result.push(walker.currentNode);
    return result;
  };
  class Layout {
    constructor(root,offsetFor=null) {
      this.root=root;this.d=root.ownerDocument;this.offsetFor=offsetFor;
      this.original=root.innerHTML;this.settings={fontSize:20,mode:'scroll',vertical:false};
      this.mapping=new WeakMap();this.mapped=[];this.spreads=[];this.index=0;this.pageCount=1;
      this.originalStyle=root.getAttribute('style');this.captureOrigins();this.remap();
    }
    get paged(){return this.settings.mode!=='scroll';}
    captureOrigins(){
      let start=0;this.origins=nodes(this.root).map(n=>{const value={text:n.data,start:this.offsetFor?this.offsetFor(n):start};start+=n.length;return value;});
      this.source=this.origins.map(x=>x.text).join('');
    }
    restore(){
      this.root.innerHTML=this.original;
      if(this.originalStyle===null)this.root.removeAttribute('style');else this.root.setAttribute('style',this.originalStyle);
      this.mapping=new WeakMap();this.mapped=[];this.spreads=[];this.index=0;this.pageCount=1;
    }
    remap(){
      const list=nodes(this.root);if(list.map(n=>n.data).join('')!==this.source)throw Error('Reflow changed canonical text');
      let origin=0,used=0;this.mapping=new WeakMap();this.mapped=[];
      for(const n of list){
        while(origin<this.origins.length&&used===this.origins[origin].text.length){origin++;used=0;}
        const item=this.origins[origin];
        if(!item||n.length>item.text.length-used||item.text.slice(used,used+n.length)!==n.data)throw Error('Reflow source mapping failed');
        const start=item.start+used;this.mapping.set(n,start);this.mapped.push({node:n,start,end:start+n.length});used+=n.length;
      }
    }
    offset(n,local){
      if(n.nodeType===3){const start=this.mapping.get(n);return start===undefined?null:start+local;}
      const r=this.d.createRange();r.setStart(n,local);r.collapse(true);
      const following=this.mapped.find(x=>r.comparePoint(x.node,0)>=0);return following?.start??null;
    }
    point(position){
      const item=this.mapped.find(x=>x.start<=position&&position<=x.end);
      return item?[item.node,position-item.start]:null;
    }
    configure(settings,width,height){
      if(!Number.isSafeInteger(settings.fontSize)||settings.fontSize<12||settings.fontSize>36||!['single','double','scroll'].includes(settings.mode)||typeof settings.vertical!=='boolean')throw Error('Invalid reflow settings');
      this.restore();this.settings={...settings};this.width=Math.max(80,Math.floor(width));this.height=Math.max(100,Math.floor(height));
      try {
        if(!this.paged){
          this.root.style.fontSize=settings.fontSize+'px';
          this.root.style.writingMode=settings.vertical?'vertical-rl':'horizontal-tb';
          this.remap();return this.state();
        }
        const count=settings.mode==='double'?2:1,gap=count===2?24:0,pageWidth=(this.width-gap)/count;
        this.root.style.cssText=`width:${this.width}px!important;height:${this.height}px!important;max-width:none!important;margin:0!important;padding:0!important;writing-mode:horizontal-tb!important;overflow:hidden!important;column-count:auto!important;column-width:auto!important;`;
        let pending=this.d.createDocumentFragment();while(this.root.firstChild)pending.appendChild(this.root.firstChild);
        const pages=[];
        while(pending.childNodes.length){
          if(pages.length>=10000)throw Error('Reflow page limit');
          const page=this.d.createElement('div');page.dataset.pdfnoPage=String(pages.length);
          page.style.cssText=`box-sizing:border-box;flex:0 0 ${pageWidth}px;width:${pageWidth}px;height:${this.height}px;overflow:hidden;padding:20px 20px 46px;font:${settings.fontSize}px/1.85 system-ui;writing-mode:${settings.vertical?'vertical-rl':'horizontal-tb'};text-orientation:mixed;overflow-wrap:anywhere;`;
          page.appendChild(pending);this.root.appendChild(page);
          const text=nodes(page),total=text.reduce((n,x)=>n+x.length,0),bounds=page.getBoundingClientRect();
          const point=position=>{let offset=position;for(const n of text){if(offset<=n.length)return[n,offset];offset-=n.length;}return[page,page.childNodes.length];};
          const fits=position=>{
            if(!position)return true;const r=this.d.createRange();r.setStart(...point(0));r.setEnd(...point(position));
            return [...r.getClientRects()].every(x=>x.width===0&&x.height===0||x.left>=bounds.left+18-1&&x.right<=bounds.right-18+1&&x.top>=bounds.top+18-1&&x.bottom<=bounds.bottom-44+1);
          };
          let cut=total;
          if(total&&!fits(total)){
            let low=0,high=total;while(low<high){const middle=Math.ceil((low+high)/2);if(fits(middle))low=middle;else high=middle-1;}cut=low;
            const [n,offset]=point(cut);if(n.nodeType===3&&offset<n.length&&/[\uDC00-\uDFFF]/.test(n.data[offset]))cut--;
            const ruby=n.parentElement?.closest('ruby');
            if(ruby&&offset>0&&offset<n.length){const before=text.slice(0,text.indexOf(n)).reduce((v,x)=>v+x.length,0);cut=before;}
            if(cut<=0){const n=text[0];cut=n?.parentElement?.closest('ruby')?nodes(n.parentElement.closest('ruby')).reduce((v,x)=>v+x.length,0):(n?.data.codePointAt(0)>65535?2:1);}
          }
          pending=this.d.createDocumentFragment();
          if(cut<total){
            const r=this.d.createRange(),p=point(cut);let ruby=p[0].parentElement?.closest('ruby');
            if(ruby&&p[1]===p[0].length)r.setStartAfter(ruby);else r.setStart(...p);
            r.setEnd(page,page.childNodes.length);pending=r.extractContents();
          }
          pages.push(page);
        }
        this.pageCount=Math.max(1,pages.length);this.root.replaceChildren();
        for(let i=0;i<pages.length;i+=count){
          const spread=this.d.createElement('div');spread.dataset.pdfnoSpread=String(this.spreads.length);
          spread.style.cssText=`width:${this.width}px;height:${this.height}px;display:none;gap:${gap}px;flex-direction:${settings.vertical?'row-reverse':'row'};`;
          pages.slice(i,i+count).forEach(p=>spread.appendChild(p));this.spreads.push(spread);this.root.appendChild(spread);
        }
        this.remap();this.show(0);return this.state();
      }catch(error){this.restore();this.settings.mode='scroll';this.remap();throw error;}
    }
    show(index){
      if(!this.paged)return;this.index=Math.max(0,Math.min(this.spreads.length-1,index));
      this.spreads.forEach((s,i)=>s.style.display=i===this.index?'flex':'none');
    }
    navigate(node){
      if(!this.paged)return false;const spread=node.parentElement?.closest('[data-pdfno-spread]');if(!spread)return false;
      this.show(Number(spread.dataset.pdfnoSpread));return true;
    }
    turn(delta){if(!this.paged)return false;const next=this.index+delta;if(next<0||next>=this.spreads.length)return false;this.show(next);return true;}
    visibleStart(){
      const box=this.paged?this.spreads[this.index]?.getBoundingClientRect():{left:0,top:0,right:this.d.defaultView.innerWidth,bottom:this.d.defaultView.innerHeight};
      for(const item of this.mapped){const r=this.d.createRange();r.selectNodeContents(item.node);if([...r.getClientRects()].some(x=>x.width>0&&x.height>0&&x.left<box.right&&x.right>box.left&&x.top<box.bottom&&x.bottom>box.top))return item.start;}return null;
    }
    state(){return{...this.settings,page:this.paged?this.index*(this.settings.mode==='double'?2:1)+1:1,pageCount:this.pageCount,hasPrevious:this.paged&&this.index>0,hasNext:this.paged&&this.index<this.spreads.length-1,sourceStart:this.visibleStart()};}
  }
  window.PDFnoReflow={Layout,nodes};
})();
