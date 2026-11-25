import Foundation
import WebKit

/// Keyboard/mouse/lifecycle bridge into the GameMaker HTML5 runtime.
/// GameMaker's Emscripten runner listens on `document`/`window` and reads
/// `event.keyCode`, which is why the synthetic events define that property.
enum WebBridge {
    static func injectKey(_ webView: WKWebView, entry: TouchEntry, down: Bool) {
        let type = down ? "keydown" : "keyup"
        let js = """
        (function(){
          var c=document.getElementById('canvas');
          if (c && c.focus) { c.focus(); }
          var ev=new KeyboardEvent(\(q(type)),{
            key:\(q(entry.key)), code:\(q(entry.code)),
            bubbles:true, cancelable:true
          });
          try {
            Object.defineProperty(ev,'keyCode',{get:function(){return \(entry.keyCode)}});
            Object.defineProperty(ev,'which',{get:function(){return \(entry.keyCode)}});
          } catch (e) {}
          document.dispatchEvent(ev);
          window.dispatchEvent(ev);
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    static func injectMouse(_ webView: WKWebView, type: String, x: Int, y: Int) {
        let buttons = type == "mouseup" ? 0 : 1
        let js = """
        (function(){
          var x=\(x), y=\(y), type=\(q(type)), buttons=\(buttons);
          var canvas=document.getElementById('canvas');
          // GameMaker draws its UI on the canvas, but some prompts (including
          // scare-style fake system dialogs) are plain DOM buttons. Dispatch
          // to whichever element is actually under the tap.
          var target=document.elementFromPoint(x,y) || document.body;
          var onCanvas = canvas && (target===canvas || canvas.contains(target));
          var t = onCanvas ? canvas : target;
          var ev=new MouseEvent(type,{
            bubbles:true, cancelable:true,
            clientX:x, clientY:y,
            button:0, buttons:buttons, view:window
          });
          t.dispatchEvent(ev);
          // DOM buttons react to `click`, not just mouseup. The canvas is
          // exempt so a canvas-based OK button is not fired twice.
          if (type==='mouseup' && !onCanvas) {
            try {
              t.dispatchEvent(new MouseEvent('click',{
                bubbles:true, cancelable:true,
                clientX:x, clientY:y, button:0, buttons:0, view:window
              }));
            } catch (e) {}
          }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Must be called from a real user gesture: unlocks WebAudio and focuses
    /// the canvas so subsequent synthetic keys land on the right element.
    /// The page can still be booting when this fires, so keep retrying until
    /// the runner's helpers exist instead of missing them once.
    static func start(_ webView: WKWebView) {
        let js = """
        (function(){
          var c=document.getElementById('canvas');
          if (c && c.focus) { c.focus(); }
          var tries = 0;
          var announced = false;
          var timer = setInterval(function(){
            var ready = !!(window.__fb3_unlockAudio || window.__fb3_revealCanvas);
            if (ready && !announced) {
              announced = true;
              if (window.__fb3Log) window.__fb3Log('INFO', 'audio/canvas unlock helpers ready after ' + tries + ' retries');
            }
            if (window.__fb3_unlockAudio) { window.__fb3_unlockAudio(); }
            if (window.__fb3_revealCanvas) { window.__fb3_revealCanvas(); }
            if (++tries > 1200) clearInterval(timer);
          }, 25);
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    static func pause(_ webView: WKWebView) {
        webView.evaluateJavaScript(
            "if(typeof pause==='function'){pause();}else if(typeof GM_pause==='function'){GM_pause();}",
            completionHandler: nil
        )
    }

    static func resume(_ webView: WKWebView) {
        webView.evaluateJavaScript(
            "if(typeof resume==='function'){resume();}else if(typeof GM_unpause==='function'){GM_unpause();}",
            completionHandler: nil
        )
    }

    /// EXPERIMENTAL: there is no official speed API in the runner. This feeds
    /// GameMaker a scaled virtual clock via GM_tick, which changes its
    /// delta-time. Audio is disabled in this build by default, so drift is
    /// mostly limited to engine internals.
    static func speedScript(initialSpeed: Double) -> WKUserScript {
        let js = """
        (function(){
          var scale = \(initialSpeed);
          window.__fb3_setSpeed = function(s){ scale = s; return scale; };
          var realNow = performance.now.bind(performance);
          var virtual = realNow();
          var last = virtual;
          var original = null;
          function hooked(){
            var now = realNow();
            virtual += (now - last) * scale;
            last = now;
            return original ? original(virtual) : undefined;
          }
          var tries = 0;
          var timer = setInterval(function(){
            tries++;
            if (!original && typeof window.GM_tick === 'function') {
              original = window.GM_tick;
              window.GM_tick = hooked;
              clearInterval(timer);
            } else if (tries > 800) {
              clearInterval(timer);
            }
          }, 25);
        })();
        """
        return WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    static func setSpeed(_ webView: WKWebView, speed: Double) {
        webView.evaluateJavaScript(
            "if(window.__fb3_setSpeed){window.__fb3_setSpeed(\(speed));}",
            completionHandler: nil
        )
    }

    /// Reports the browser's rendered frame rate back to native every 500 ms.
    static func statsScript() -> WKUserScript {
        let js = """
        (function(){
          if (!window.webkit || !window.webkit.messageHandlers ||
              !window.webkit.messageHandlers.fb3stats) return;
          var frames = 0;
          var last = performance.now();
          function loop(now){
            frames++;
            var elapsed = now - last;
            if (elapsed >= 500) {
              var fps = Math.round(frames * 1000 / elapsed);
              try { window.webkit.messageHandlers.fb3stats.postMessage({fps: fps}); } catch(e){}
              frames = 0;
              last = now;
            }
            requestAnimationFrame(loop);
          }
          requestAnimationFrame(loop);
        })();
        """
        return WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    /// Captures JS console output, page errors, failed network requests and
    /// loading-progress changes into the native diagnostic log.
    static func diagnosticScript() -> WKUserScript {
        let js = """
        (function(){
          function send(level, msg){
            var text = String(msg == null ? '' : msg);
            if (text.length > 4000) text = text.slice(0, 4000) + '…';
            try {
              if (window.webkit && window.webkit.messageHandlers &&
                  window.webkit.messageHandlers.fb3log) {
                window.webkit.messageHandlers.fb3log.postMessage({
                  level: String(level), message: text
                });
              }
            } catch (e) {}
          }
          window.__fb3Log = send;

          function argsToText(args){
            var out = [];
            for (var i = 0; i < args.length; i++) {
              var v = args[i];
              if (v instanceof Error) {
                out.push(v.stack || (v.name + ': ' + v.message));
              } else if (typeof v === 'object') {
                try { out.push(JSON.stringify(v)); } catch (e) { out.push(String(v)); }
              } else {
                out.push(String(v));
              }
            }
            return out.join(' ');
          }

          ['log', 'warn', 'error'].forEach(function(level){
            var original = console[level];
            console[level] = function(){
              send(level.toUpperCase(), argsToText(arguments));
              try { return original.apply(console, arguments); } catch (e) {}
            };
          });

          window.addEventListener('error', function(e){
            send('ERROR', 'window.error: ' + (e.message || '') + ' @ ' +
              (e.filename || '') + ':' + (e.lineno || 0) + ':' + (e.colno || 0) +
              (e.error && e.error.stack ? '\\n' + e.error.stack : ''));
          }, true);
          window.addEventListener('unhandledrejection', function(e){
            var r = e.reason;
            send('ERROR', 'unhandledrejection: ' + ((r && r.stack) || String(r)));
          });

          var originalFetch = window.fetch;
          if (typeof originalFetch === 'function') {
            window.fetch = function(input, init){
              var url = typeof input === 'string' ? input : ((input && input.url) || String(input));
              send('FETCH', 'start ' + url);
              return originalFetch.apply(this, arguments).then(function(resp){
                send('FETCH', 'ok ' + resp.status + ' ' + url);
                return resp;
              }, function(err){
                send('ERROR', 'fetch failed ' + url + ' :: ' + ((err && err.message) || err));
                throw err;
              });
            };
          }

          var originalOpen = XMLHttpRequest.prototype.open;
          var originalSend = XMLHttpRequest.prototype.send;
          XMLHttpRequest.prototype.open = function(method, url){
            this.__fb3url = url;
            return originalOpen.apply(this, arguments);
          };
          XMLHttpRequest.prototype.send = function(){
            var self = this;
            self.addEventListener('load', function(){
              send('XHR', 'load ' + self.status + ' ' + self.__fb3url);
            });
            self.addEventListener('error', function(){
              send('ERROR', 'xhr error ' + self.__fb3url);
            });
            self.addEventListener('timeout', function(){
              send('ERROR', 'xhr timeout ' + self.__fb3url);
            });
            return originalSend.apply(this, arguments);
          };

          var lastSignal = '';
          var bootAt = Date.now();
          var stuckWarned = false;
          setInterval(function(){
            var s = document.getElementById('status');
            var text = s ? String(s.textContent || s.innerText || '').replace(/\\s+/g, ' ').trim() : '(no #status)';
            var seconds = Math.round((Date.now() - bootAt) / 1000);
            if (!stuckWarned && seconds > 120 && /Preparing|Downloading|Loading/i.test(text)) {
              stuckWarned = true;
              send('WARN', 'still loading after ' + seconds + 's: ' + text);
            }
            var p = document.getElementById('progress');
            var pct = p && p.max ? Math.round(100 * Number(p.value) / Number(p.max)) : null;
            var left = window.__fb3_run_left;
            var total = window.__fb3_run_total;
            var signal = text + '|' + pct + '|' + left + '|' + total;
            if (signal !== lastSignal) {
              lastSignal = signal;
              send('STATUS', text + (pct !== null ? ' ' + pct + '%' : '') +
                ' deps=' + (left === undefined ? '-' : left) + '/' +
                (total === undefined ? '-' : total));
            }
          }, 1000);
        })();
        """
        return WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    /// CSS-level zoom. getBoundingClientRect() reflects the transform, so the
    /// engine keeps mapping taps to the correct in-game coordinates.
    static func setZoom(_ webView: WKWebView, scale: CGFloat, tx: CGFloat, ty: CGFloat) {
        let js = """
        (function(){
          var c=document.getElementById('canvas');
          if(!c) return;
          var z=\(scale), x=\(tx), y=\(ty);
          var mw=c.offsetWidth*(z-1)/2, mh=c.offsetHeight*(z-1)/2;
          x=Math.max(-mw,Math.min(mw,x));
          y=Math.max(-mh,Math.min(mh,y));
          c.style.position='relative';
          c.style.zIndex='50';
          c.style.transformOrigin='center center';
          c.style.transform=(z===1)?'none':('translate('+x+'px,'+y+'px) scale('+z+')');
          window.__fb3_zoom=z;
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Diagnostic dump of the live page: URL, visible text and any absolutely
    /// positioned elements. Used by the Settings screen to identify unexpected
    /// overlays without needing a screenshot or Xcode console.
    static func inspect(_ webView: WKWebView, completion: @escaping (String) -> Void) {
        let js = """
        (function(){
          function clip(s,n){ s=String(s||''); return s.length>n?s.slice(0,n)+'…':s; }
          var out=[];
          out.push('URL: ' + location.href);
          out.push('TITLE: ' + document.title);
          out.push('--- VISIBLE TEXT ---');
          out.push(clip(document.body ? document.body.innerText : '', 6000));
          out.push('--- POSITIONED ELEMENTS ---');
          var all=document.querySelectorAll('body *'), n=0;
          for (var i=0;i<all.length;i++){
            var e=all[i], cs=getComputedStyle(e), r=e.getBoundingClientRect();
            if (cs.position!=='fixed' && cs.position!=='absolute') continue;
            if (cs.display==='none' || cs.visibility==='hidden') continue;
            if (r.width<40 || r.height<20) continue;
            out.push(clip(e.tagName+'#'+(e.id||'-')+'.'+(typeof e.className==='string'?e.className:'')+
              ' pos='+cs.position+' z='+cs.zIndex+
              ' rect='+Math.round(r.left)+','+Math.round(r.top)+' '+Math.round(r.width)+'x'+Math.round(r.height)+
              ' text='+String(e.innerText||'').replace(/\\s+/g,' ').trim(),240));
            if (++n>40) break;
          }
          out.push('--- IFRAMES ---');
          var fs=document.querySelectorAll('iframe');
          for (var j=0;j<fs.length;j++) out.push(clip(fs[j].src,200));
          out.push('--- SCRIPT SRC ---');
          var ss=document.querySelectorAll('script[src]');
          for (var k=0;k<ss.length;k++) out.push(clip(ss[k].src,200));
          return out.join('\\n');
        })();
        """
        webView.evaluateJavaScript(js) { result, _ in
            completion(result as? String ?? "No result: \(String(describing: result))")
        }
    }

    private static func q(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "'\(escaped)'"
    }
}

struct TouchEntry: Codable {
    let keyCode: Int
    let key: String
    let code: String
}
