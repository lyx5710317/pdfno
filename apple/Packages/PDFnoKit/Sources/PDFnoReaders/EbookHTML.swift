// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// Only PDFno-authored HTML/JS/CSS and escaped text. Original XML/URLs never enter the page.
public enum EbookHTML {
    public static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;").replacingOccurrences(of: "\r", with: "&#13;")
    }
    public static func body(_ document: EbookDocument) -> String {
        func paragraph(_ block: EbookBlock) -> String {
            let tag = block.headingLevel.map { "h\(min(6, $0))" } ?? "p"
            let runs = block.runs.map { run in
                let base = escape(run.text)
                let value = run.ruby.map { "<ruby>\(base)<rt>\(escape($0))</rt></ruby>" } ?? base
                let italic = run.italic ? "<em>\(value)</em>" : value
                return run.bold ? "<strong>\(italic)</strong>" : italic
            }.joined()
            let list = block.listLevel.map { " class='list' style='margin-left:\($0 * 20)px'" } ?? ""
            return "<\(tag) id='b\(block.id)' data-block='\(block.id)' data-start='\(block.start)'\(list)>\(runs)</\(tag)>"
        }
        var body = "", table: Int?, row: Int?, cell: Int?
        for block in document.blocks {
            if block.table != table {
                if table != nil { body += "</td></tr></tbody></table>" }
                table = block.table; row = nil; cell = nil
                if table != nil { body += "<table><tbody>" }
            }
            if table != nil {
                if block.row != row {
                    if row != nil { body += "</td></tr>" }
                    body += "<tr><td>"; row = block.row; cell = block.cell
                } else if block.cell != cell { body += "</td><td>"; cell = block.cell }
            }
            body += paragraph(block)
        }
        if table != nil { body += "</td></tr></tbody></table>" }
        return body
    }
    public static func render(_ document: EbookDocument, sessionID: UUID, usesEngine: Bool = false) -> String {
        let nonce = sessionID.uuidString
        let body = self.body(document)
        let engineScript = usesEngine ? "<script nonce=\"\(nonce)\" src=\"pdfno-ebook://app/engine.js\"></script>" : ""
        return """
        <!doctype html><html lang="zh"><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'nonce-\(nonce)'; style-src 'unsafe-inline'; connect-src 'none'; img-src 'none'; font-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>body{font:18px/1.8 -apple-system,system-ui;margin:32px;color:CanvasText;background:Canvas}main{max-width:850px;margin:auto}p,h1,h2,h3,h4,h5,h6{white-space:pre-wrap;overflow-wrap:anywhere}p{min-height:1em}h1,h2,h3,h4,h5,h6{line-height:1.35}table{border-collapse:collapse;max-width:100%;margin:1em 0}td{border:1px solid gray;padding:.5em;vertical-align:top}.list:before{content:'• ';user-select:none}::selection{background:#ffe285}::highlight(pdfnoNotes){background:#ffe285}::highlight(pdfnoReturn){background:#ffb565}</style></head>
        <body><main>\(body)</main>\(engineScript)<script nonce="\(nonce)">
        'use strict';
        const session='\(nonce)'; let blocks=Array.from(document.querySelectorAll('[data-block]'));
        function textNodes(root){const w=document.createTreeWalker(root,NodeFilter.SHOW_TEXT,{acceptNode:n=>n.parentElement?.closest('rt,rp')?NodeFilter.FILTER_REJECT:NodeFilter.FILTER_ACCEPT});return w;}
        function canonicalText(root){const w=textNodes(root);let n,s='';while((n=w.nextNode()))s+=n.nodeValue;return s;}
        let canonical=blocks.map(b=>canonicalText(b)).join('\\n');
        function post(action, data={}) { window.webkit?.messageHandlers.ebook.postMessage({session,action,...data}); }
        function offset(node,local) {
          const element=node.nodeType===3?node.parentElement:node;if(element?.closest?.('rt,rp'))return null;
          const block=element?.closest?.('[data-block]'); if(!block)return null;
          const range=document.createRange();range.selectNodeContents(block);range.setEnd(node,local);
          return Number(block.dataset.start)+canonicalText(range.cloneContents()).length;
        }
        function selectedRange() {
          const s=getSelection();if(!s||s.isCollapsed||!s.rangeCount)return null;
          const r=s.getRangeAt(0),start=offset(r.startContainer,r.startOffset),end=offset(r.endContainer,r.endOffset);
          if(start===null||end===null||end<=start||end-start>16000)return null;
          return {start,end,quote:canonical.slice(start,end)};
        }
        let selectionTimer,latestSelection=null;
        document.addEventListener('selectionchange',()=>{
          const selected=selectedRange();
          // Native toolbar focus must not erase a genuine text selection or
          // replace its pending snapshot with the subsequently collapsed DOM.
          if(!selected&&!document.hasFocus())return;
          latestSelection=selected;clearTimeout(selectionTimer);
          selectionTimer=setTimeout(()=>selected?post('selection',selected):post('clear'),80);
        });
        function point(position) {
          for(const block of blocks){const start=Number(block.dataset.start),length=canonicalText(block).length;
            if(position<start||position>start+length)continue;
            let left=position-start, walker=textNodes(block),node;
            while((node=walker.nextNode())){if(left<=node.length)return [node,left];left-=node.length;}
            if(length===0)return [block,0];
          }return null;
        }
        function rangeFor(a){const s=point(a.start),e=point(a.end);if(!s||!e)return null;
          const r=document.createRange();r.setStart(...s);r.setEnd(...e);return r;}
        let explicitNavigation=false,scrollTimer;
        for(const event of ['wheel','pointerdown','keydown'])
          document.addEventListener(event,()=>{explicitNavigation=false;},{passive:true});
        window.pdfnoEbook={
          install(html,expected){const main=document.querySelector('main');main.innerHTML=html;
            latestSelection=null;clearTimeout(selectionTimer);
            blocks=Array.from(document.querySelectorAll('[data-block]'));canonical=blocks.map(b=>canonicalText(b)).join('\\n');
            if(canonical!==expected){main.textContent='';throw Error('Canonical Ebook DOM mismatch');}return true;},
          captureSelection(){const selected=selectedRange();
            if(selected||document.hasFocus())latestSelection=selected;
            clearTimeout(selectionTimer);
            latestSelection?post('selection',latestSelection):post('clear');return latestSelection;},
          navigate(a){const r=rangeFor(a);if(!r||canonical.slice(a.start,a.end)!==a.quote)return false;
            // Native navigation owns the exact anchor until a real user scroll
            // or input; its own scroll event must not replace it with the first
            // visible block (which can be a different, already visible heading).
            explicitNavigation=true;clearTimeout(scrollTimer);
            r.startContainer.parentElement?.scrollIntoView({block:'center'});
            if(window.Highlight&&CSS.highlights)CSS.highlights.set('pdfnoReturn',new Highlight(r));return true;},
          notes(items){if(!window.Highlight||!CSS.highlights)return;const ranges=items.map(rangeFor).filter(Boolean);
            CSS.highlights.set('pdfnoNotes',new Highlight(...ranges));}
        };
        window.addEventListener('scroll',()=>{clearTimeout(scrollTimer);if(explicitNavigation)return;
          scrollTimer=setTimeout(()=>{
          if(explicitNavigation)return;
          const block=blocks.find(b=>canonicalText(b).length&&b.getBoundingClientRect().bottom>0);
          if(block)post('progress',{start:Number(block.dataset.start)});
        },400);});
        post('ready',{highlights:!!(window.Highlight&&window.CSS?.highlights)});
        </script></body></html>
        """
    }
}
