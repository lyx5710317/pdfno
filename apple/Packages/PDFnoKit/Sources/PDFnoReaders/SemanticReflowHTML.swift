// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Opt-in for validated ebook/text readers. DOCX never opts in, even when a
/// text reader reuses its escaped semantic HTML builder.
public enum SemanticReflowHTML {
    public static var script: String {
        guard let root=Bundle.module.url(forResource: "Reflow",withExtension: nil),let value=try? String(contentsOf: root.appendingPathComponent("layout.js"),encoding: .utf8) else { return "" }
        return value
    }
    public static func enable(_ html: String,bridge: String,sessionID: UUID) -> String {
        var s=html
        s=s.replacingOccurrences(of: "'use strict';",with: "'use strict';\nlet reflow=null,reflowPosition=null;"+script)
        s=s.replacingOccurrences(of: "function offset(node,local)",with: "function originalOffset(node,local)")
        s=s.replacingOccurrences(of: "function point(position)",with: "function originalPoint(position)")
        let wrappers="""
        function offset(node,local){return reflow?reflow.offset(node,local):originalOffset(node,local);}
        function point(position){return reflow?reflow.point(position):originalPoint(position);}
        """
        s=s.replacingOccurrences(of: "function selectedRange()",with: wrappers+"\nfunction selectedRange()")
        s=s.replacingOccurrences(of: "install(html,expected){",with: "install(html,expected){reflow=null;reflowPosition=null;")
        for kind in ["DOCX","Ebook"] {
            s=s.replacingOccurrences(of: "throw Error('Canonical "+kind+" DOM mismatch');}return true;",with: "throw Error('Canonical "+kind+" DOM mismatch');}reflow=new PDFnoReflow.Layout(main,n=>originalOffset(n,0));return true;")
        }
        s=s.replacingOccurrences(of: "r.startContainer.parentElement?.scrollIntoView({block:'center'});",with: "reflowPosition=a;if(reflow?.paged)reflow.navigate(r.startContainer);else r.startContainer.parentElement?.scrollIntoView({block:'center'});")
        s=s.replacingOccurrences(of: "CSS.highlights.set('pdfnoReturn',new Highlight(r));return true;",with: "CSS.highlights.set('pdfnoReturn',new Highlight(r));if(reflow)post('layout',reflow.state());window.pdfnoRefreshAnnotations?.();return true;")
        let hook="""
        const reflowBridge=window.\(bridge);
        reflowBridge.configureReflow=(settings,position=null,selected=null)=>{
          if(!reflow)throw Error('Reflow document not ready');
          const start=position?.start??(explicitNavigation?reflowPosition?.start:null)??reflow.visibleStart()??0;
          const preserved=position??{start,end:start+(canonical.codePointAt(start)>65535?2:1),quote:canonical.slice(start,start+(canonical.codePointAt(start)>65535?2:1))};
          const chosen=selected??latestSelection??selectedRange();
          if(chosen&&canonical.slice(chosen.start,chosen.end)!==chosen.quote)throw Error('Reflow selection mismatch');
          document.documentElement.style.overflow=settings.mode==='scroll'?'':'hidden';
          document.body.style.margin=settings.mode==='scroll'?'32px':'0';
          reflow.configure(settings,innerWidth||640,innerHeight||480);
          if(settings.mode==='scroll'&&settings.vertical){
            reflow.root.style.width=Math.max(80,innerWidth-64)+'px';reflow.root.style.height=Math.max(100,innerHeight-64)+'px';
            reflow.root.style.columnWidth=Math.max(52,innerHeight-104)+'px';reflow.root.style.columnGap='48px';
          }
          explicitNavigation=true;clearTimeout(scrollTimer);reflowPosition=preserved;
          const r=rangeFor(preserved);if(r){if(reflow.paged)reflow.navigate(r.startContainer);else r.startContainer.parentElement?.scrollIntoView({block:'center'});}
          getSelection()?.removeAllRanges();if(chosen){const r=rangeFor(chosen);if(r)getSelection().addRange(r);}
          latestSelection=chosen;window.pdfnoRefreshAnnotations?.();
          const state=reflow.state();post('layout',state);return state;
        };
        reflowBridge.turnReflow=delta=>{
          if(!reflow?.turn(delta))return false;
          getSelection()?.removeAllRanges();latestSelection=null;explicitNavigation=false;
          const start=reflow.visibleStart();reflowPosition=start===null?null:{start,end:start+(canonical.codePointAt(start)>65535?2:1),quote:canonical.slice(start,start+(canonical.codePointAt(start)>65535?2:1))};
          if(start!==null)post('progress',{start});window.pdfnoRefreshAnnotations?.();post('layout',reflow.state());return true;
        };
        reflowBridge.reflowState=()=>reflow?.state()??null;
        let reflowResize;
        addEventListener('resize',()=>{clearTimeout(reflowResize);reflowResize=setTimeout(()=>{
          if(reflow)reflowBridge.configureReflow(reflow.settings,explicitNavigation?reflowPosition:null,latestSelection);
        },80);});
        """
        s=s.replacingOccurrences(of: "post('ready',{highlights:",with: hook+"\npost('ready',{highlights:")
        return s
    }
}
