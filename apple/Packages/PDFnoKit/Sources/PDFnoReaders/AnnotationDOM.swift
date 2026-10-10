// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
/// Trusted native bridge helper. Empty, pointer-transparent rectangles never
/// enter canonical text or intercept author text selection.
public enum AnnotationDOM {
    public static let semantic = #"""
      if(!window.pdfnoAnnotationState){
        window.pdfnoAnnotationState={items:[]};
        const style=document.createElement('style');style.textContent='::highlight(pdfnoAnnotations){background:#ffe285}';document.head.appendChild(style);
        window.pdfnoRefreshAnnotations=()=>{
          document.querySelectorAll('[data-pdfno-annotation-overlay]').forEach(n=>n.remove());
          const highlights=[];
          for(const item of window.pdfnoAnnotationState.items){
            if(canonical.slice(item.anchor.start,item.anchor.end)!==item.anchor.quote)continue;
            const range=rangeFor(item.anchor);if(!range)continue;
            if(item.kind!=='underline')highlights.push(range);
            if(item.kind==='underline'||!window.Highlight||!window.CSS?.highlights){
              for(const r of range.getClientRects()){
                if(r.width<=0||r.height<=0||r.bottom<0||r.top>innerHeight)continue;
                const n=document.createElement('div');n.dataset.pdfnoAnnotationOverlay='';
                const vertical=getComputedStyle(range.startContainer.parentElement).writingMode.startsWith('vertical');
                n.style.cssText=`position:fixed;pointer-events:none;z-index:4;left:${r.left}px;top:${r.top}px;width:${r.width}px;height:${r.height}px;`+(item.kind==='underline'?(vertical?'border-left:2px solid #b67a00':'border-bottom:2px solid #b67a00'):'background:#ffe28588');document.body.appendChild(n);
              }
            }
          }
          if(window.Highlight&&window.CSS?.highlights)CSS.highlights.set('pdfnoAnnotations',new Highlight(...highlights));
        };
        let frame;const refresh=()=>{cancelAnimationFrame(frame);frame=requestAnimationFrame(window.pdfnoRefreshAnnotations)};
        addEventListener('scroll',refresh,{passive:true});addEventListener('resize',refresh);new ResizeObserver(refresh).observe(document.querySelector('main'));
      }
      window.pdfnoAnnotationState.items=items;window.pdfnoRefreshAnnotations();return true;
      """#
}
