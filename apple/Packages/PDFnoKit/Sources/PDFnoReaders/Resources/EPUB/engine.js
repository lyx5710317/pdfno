// Kookit 95f602e EPUB profile. Corresponding source: engine-build/. See Notices.txt.
(() => {
  var __create = Object.create;
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __getProtoOf = Object.getPrototypeOf;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __require = /* @__PURE__ */ ((x) => typeof require !== "undefined" ? require : typeof Proxy !== "undefined" ? new Proxy(x, {
    get: (a, b) => (typeof require !== "undefined" ? require : a)[b]
  }) : x)(function(x) {
    if (typeof require !== "undefined") return require.apply(this, arguments);
    throw Error('Dynamic require of "' + x + '" is not supported');
  });
  var __commonJS = (cb2, mod) => function __require2() {
    return mod || (0, cb2[__getOwnPropNames(cb2)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
    // If the importer is in node compatibility mode or this is not an ESM
    // file that has been converted to a CommonJS file using a Babel-
    // compatible transform (i.e. "__esModule" has not been set), then set
    // "default" to the CommonJS "module.exports" for node compatibility.
    isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
    mod
  ));

  // node_modules/rangy/lib/rangy-core.js
  var require_rangy_core = __commonJS({
    "node_modules/rangy/lib/rangy-core.js"(exports, module) {
      (function(factory, root2) {
        if (typeof define == "function" && define.amd) {
          define(factory);
        } else if (typeof module != "undefined" && typeof exports == "object") {
          module.exports = factory();
        } else {
          root2.rangy = factory();
        }
      })(function() {
        var OBJECT = "object", FUNCTION = "function", UNDEFINED = "undefined";
        var domRangeProperties = [
          "startContainer",
          "startOffset",
          "endContainer",
          "endOffset",
          "collapsed",
          "commonAncestorContainer"
        ];
        var domRangeMethods = [
          "setStart",
          "setStartBefore",
          "setStartAfter",
          "setEnd",
          "setEndBefore",
          "setEndAfter",
          "collapse",
          "selectNode",
          "selectNodeContents",
          "compareBoundaryPoints",
          "deleteContents",
          "extractContents",
          "cloneContents",
          "insertNode",
          "surroundContents",
          "cloneRange",
          "toString",
          "detach"
        ];
        var textRangeProperties = ["boundingHeight", "boundingLeft", "boundingTop", "boundingWidth", "htmlText", "text"];
        var textRangeMethods = [
          "collapse",
          "compareEndPoints",
          "duplicate",
          "moveToElementText",
          "parentElement",
          "select",
          "setEndPoint",
          "getBoundingClientRect"
        ];
        function isHostMethod(o, p) {
          var t = typeof o[p];
          return t == FUNCTION || !!(t == OBJECT && o[p]) || t == "unknown";
        }
        function isHostObject(o, p) {
          return !!(typeof o[p] == OBJECT && o[p]);
        }
        function isHostProperty(o, p) {
          return typeof o[p] != UNDEFINED;
        }
        function createMultiplePropertyTest(testFunc) {
          return function(o, props) {
            var i = props.length;
            while (i--) {
              if (!testFunc(o, props[i])) {
                return false;
              }
            }
            return true;
          };
        }
        var areHostMethods = createMultiplePropertyTest(isHostMethod);
        var areHostObjects = createMultiplePropertyTest(isHostObject);
        var areHostProperties = createMultiplePropertyTest(isHostProperty);
        function isTextRange(range2) {
          return range2 && areHostMethods(range2, textRangeMethods) && areHostProperties(range2, textRangeProperties);
        }
        function getBody(doc2) {
          return isHostObject(doc2, "body") ? doc2.body : doc2.getElementsByTagName("body")[0];
        }
        var forEach = [].forEach ? function(arr, func) {
          arr.forEach(func);
        } : function(arr, func) {
          for (var i = 0, len = arr.length; i < len; ++i) {
            func(arr[i], i);
          }
        };
        var modules = {};
        var isBrowser = typeof window != UNDEFINED && typeof document != UNDEFINED;
        var util = {
          isHostMethod,
          isHostObject,
          isHostProperty,
          areHostMethods,
          areHostObjects,
          areHostProperties,
          isTextRange,
          getBody,
          forEach
        };
        var api = {
          version: "1.3.2",
          initialized: false,
          isBrowser,
          supported: true,
          util,
          features: {},
          modules,
          config: {
            alertOnFail: false,
            alertOnWarn: false,
            preferTextRange: false,
            autoInitialize: typeof rangyAutoInitialize == UNDEFINED ? true : rangyAutoInitialize
          }
        };
        function consoleLog(msg) {
          if (typeof console != UNDEFINED && isHostMethod(console, "log")) {
            console.log(msg);
          }
        }
        function alertOrLog(msg, shouldAlert) {
          if (isBrowser && shouldAlert) {
            alert(msg);
          } else {
            consoleLog(msg);
          }
        }
        function fail(reason) {
          api.initialized = true;
          api.supported = false;
          alertOrLog("Rangy is not supported in this environment. Reason: " + reason, api.config.alertOnFail);
        }
        api.fail = fail;
        function warn(msg) {
          alertOrLog("Rangy warning: " + msg, api.config.alertOnWarn);
        }
        api.warn = warn;
        var extend;
        if ({}.hasOwnProperty) {
          util.extend = extend = function(obj, props, deep) {
            var o, p;
            for (var i in props) {
              if (i === "__proto__" || i === "constructor" || i === "prototype") {
                continue;
              }
              if (props.hasOwnProperty(i)) {
                o = obj[i];
                p = props[i];
                if (deep && o !== null && typeof o == "object" && p !== null && typeof p == "object") {
                  extend(o, p, true);
                }
                obj[i] = p;
              }
            }
            if (props.hasOwnProperty("toString")) {
              obj.toString = props.toString;
            }
            return obj;
          };
          util.createOptions = function(optionsParam, defaults) {
            var options = {};
            extend(options, defaults);
            if (optionsParam) {
              extend(options, optionsParam);
            }
            return options;
          };
        } else {
          fail("hasOwnProperty not supported");
        }
        if (!isBrowser) {
          fail("Rangy can only run in a browser");
        }
        (function() {
          var toArray2;
          if (isBrowser) {
            var el = document.createElement("div");
            el.appendChild(document.createElement("span"));
            var slice2 = [].slice;
            try {
              if (slice2.call(el.childNodes, 0)[0].nodeType == 1) {
                toArray2 = function(arrayLike) {
                  return slice2.call(arrayLike, 0);
                };
              }
            } catch (e) {
            }
          }
          if (!toArray2) {
            toArray2 = function(arrayLike) {
              var arr = [];
              for (var i = 0, len = arrayLike.length; i < len; ++i) {
                arr[i] = arrayLike[i];
              }
              return arr;
            };
          }
          util.toArray = toArray2;
        })();
        var addListener;
        if (isBrowser) {
          if (isHostMethod(document, "addEventListener")) {
            addListener = function(obj, eventType, listener) {
              obj.addEventListener(eventType, listener, false);
            };
          } else if (isHostMethod(document, "attachEvent")) {
            addListener = function(obj, eventType, listener) {
              obj.attachEvent("on" + eventType, listener);
            };
          } else {
            fail("Document does not have required addEventListener or attachEvent method");
          }
          util.addListener = addListener;
        }
        var initListeners = [];
        function getErrorDesc(ex) {
          return ex.message || ex.description || String(ex);
        }
        function init() {
          if (!isBrowser || api.initialized) {
            return;
          }
          var testRange;
          var implementsDomRange = false, implementsTextRange = false;
          if (isHostMethod(document, "createRange")) {
            testRange = document.createRange();
            if (areHostMethods(testRange, domRangeMethods) && areHostProperties(testRange, domRangeProperties)) {
              implementsDomRange = true;
            }
          }
          var body = getBody(document);
          if (!body || body.nodeName.toLowerCase() != "body") {
            fail("No body element found");
            return;
          }
          if (body && isHostMethod(body, "createTextRange")) {
            testRange = body.createTextRange();
            if (isTextRange(testRange)) {
              implementsTextRange = true;
            }
          }
          if (!implementsDomRange && !implementsTextRange) {
            fail("Neither Range nor TextRange are available");
            return;
          }
          api.initialized = true;
          api.features = {
            implementsDomRange,
            implementsTextRange
          };
          var module2, errorMessage;
          for (var moduleName in modules) {
            if ((module2 = modules[moduleName]) instanceof Module) {
              module2.init(module2, api);
            }
          }
          for (var i = 0, len = initListeners.length; i < len; ++i) {
            try {
              initListeners[i](api);
            } catch (ex) {
              errorMessage = "Rangy init listener threw an exception. Continuing. Detail: " + getErrorDesc(ex);
              consoleLog(errorMessage);
            }
          }
        }
        function deprecationNotice(deprecated, replacement, module2) {
          if (module2) {
            deprecated += " in module " + module2.name;
          }
          api.warn("DEPRECATED: " + deprecated + " is deprecated. Please use " + replacement + " instead.");
        }
        function createAliasForDeprecatedMethod(owner, deprecated, replacement, module2) {
          owner[deprecated] = function() {
            deprecationNotice(deprecated, replacement, module2);
            return owner[replacement].apply(owner, util.toArray(arguments));
          };
        }
        util.deprecationNotice = deprecationNotice;
        util.createAliasForDeprecatedMethod = createAliasForDeprecatedMethod;
        api.init = init;
        api.addInitListener = function(listener) {
          if (api.initialized) {
            listener(api);
          } else {
            initListeners.push(listener);
          }
        };
        var shimListeners = [];
        api.addShimListener = function(listener) {
          shimListeners.push(listener);
        };
        function shim(win) {
          win = win || window;
          init();
          for (var i = 0, len = shimListeners.length; i < len; ++i) {
            shimListeners[i](win);
          }
        }
        if (isBrowser) {
          api.shim = api.createMissingNativeApi = shim;
          createAliasForDeprecatedMethod(api, "createMissingNativeApi", "shim");
        }
        function Module(name, dependencies, initializer) {
          this.name = name;
          this.dependencies = dependencies;
          this.initialized = false;
          this.supported = false;
          this.initializer = initializer;
        }
        Module.prototype = {
          init: function() {
            var requiredModuleNames = this.dependencies || [];
            for (var i = 0, len = requiredModuleNames.length, requiredModule, moduleName; i < len; ++i) {
              moduleName = requiredModuleNames[i];
              requiredModule = modules[moduleName];
              if (!requiredModule || !(requiredModule instanceof Module)) {
                throw new Error("required module '" + moduleName + "' not found");
              }
              requiredModule.init();
              if (!requiredModule.supported) {
                throw new Error("required module '" + moduleName + "' not supported");
              }
            }
            this.initializer(this);
          },
          fail: function(reason) {
            this.initialized = true;
            this.supported = false;
            throw new Error(reason);
          },
          warn: function(msg) {
            api.warn("Module " + this.name + ": " + msg);
          },
          deprecationNotice: function(deprecated, replacement) {
            api.warn("DEPRECATED: " + deprecated + " in module " + this.name + " is deprecated. Please use " + replacement + " instead");
          },
          createError: function(msg) {
            return new Error("Error in Rangy " + this.name + " module: " + msg);
          }
        };
        function createModule(name, dependencies, initFunc) {
          var newModule = new Module(name, dependencies, function(module2) {
            if (!module2.initialized) {
              module2.initialized = true;
              try {
                initFunc(api, module2);
                module2.supported = true;
              } catch (ex) {
                var errorMessage = "Module '" + name + "' failed to load: " + getErrorDesc(ex);
                consoleLog(errorMessage);
                if (ex.stack) {
                  consoleLog(ex.stack);
                }
              }
            }
          });
          modules[name] = newModule;
          return newModule;
        }
        api.createModule = function(name) {
          var initFunc, dependencies;
          if (arguments.length == 2) {
            initFunc = arguments[1];
            dependencies = [];
          } else {
            initFunc = arguments[2];
            dependencies = arguments[1];
          }
          var module2 = createModule(name, dependencies, initFunc);
          if (api.initialized && api.supported) {
            module2.init();
          }
        };
        api.createCoreModule = function(name, dependencies, initFunc) {
          createModule(name, dependencies, initFunc);
        };
        function RangePrototype() {
        }
        api.RangePrototype = RangePrototype;
        api.rangePrototype = new RangePrototype();
        function SelectionPrototype() {
        }
        api.selectionPrototype = new SelectionPrototype();
        api.createCoreModule("DomUtil", [], function(api2, module2) {
          var UNDEF = "undefined";
          var util2 = api2.util;
          var getBody2 = util2.getBody;
          if (!util2.areHostMethods(document, ["createDocumentFragment", "createElement", "createTextNode"])) {
            module2.fail("document missing a Node creation method");
          }
          if (!util2.isHostMethod(document, "getElementsByTagName")) {
            module2.fail("document missing getElementsByTagName method");
          }
          var el = document.createElement("div");
          if (!util2.areHostMethods(el, ["insertBefore", "appendChild", "cloneNode"])) {
            module2.fail("Incomplete Element implementation");
          }
          if (!util2.isHostProperty(el, "innerHTML")) {
            module2.fail("Element is missing innerHTML property");
          }
          var textNode = document.createTextNode("test");
          if (!util2.areHostMethods(textNode, ["splitText", "deleteData", "insertData", "appendData", "cloneNode"])) {
            module2.fail("Incomplete Text Node implementation");
          }
          var arrayContains = (
            /*Array.prototype.indexOf ?
            function(arr, val) {
                return arr.indexOf(val) > -1;
            }:*/
            function(arr, val) {
              var i = arr.length;
              while (i--) {
                if (arr[i] === val) {
                  return true;
                }
              }
              return false;
            }
          );
          function isHtmlNamespace(node2) {
            var ns;
            return typeof node2.namespaceURI == UNDEF || ((ns = node2.namespaceURI) === null || ns == "http://www.w3.org/1999/xhtml");
          }
          function parentElement(node2) {
            var parent = node2.parentNode;
            return parent.nodeType == 1 ? parent : null;
          }
          function getNodeIndex(node2) {
            var i = 0;
            while (node2 = node2.previousSibling) {
              ++i;
            }
            return i;
          }
          function getNodeLength(node2) {
            switch (node2.nodeType) {
              case 7:
              case 10:
                return 0;
              case 3:
              case 8:
                return node2.length;
              default:
                return node2.childNodes.length;
            }
          }
          function getCommonAncestor(node1, node2) {
            var ancestors = [], n;
            for (n = node1; n; n = n.parentNode) {
              ancestors.push(n);
            }
            for (n = node2; n; n = n.parentNode) {
              if (arrayContains(ancestors, n)) {
                return n;
              }
            }
            return null;
          }
          function isAncestorOf(ancestor, descendant, selfIsAncestor) {
            var n = selfIsAncestor ? descendant : descendant.parentNode;
            while (n) {
              if (n === ancestor) {
                return true;
              } else {
                n = n.parentNode;
              }
            }
            return false;
          }
          function isOrIsAncestorOf(ancestor, descendant) {
            return isAncestorOf(ancestor, descendant, true);
          }
          function getClosestAncestorIn(node2, ancestor, selfIsAncestor) {
            var p, n = selfIsAncestor ? node2 : node2.parentNode;
            while (n) {
              p = n.parentNode;
              if (p === ancestor) {
                return n;
              }
              n = p;
            }
            return null;
          }
          function isCharacterDataNode(node2) {
            var t = node2.nodeType;
            return t == 3 || t == 4 || t == 8;
          }
          function isTextOrCommentNode(node2) {
            if (!node2) {
              return false;
            }
            var t = node2.nodeType;
            return t == 3 || t == 8;
          }
          function insertAfter2(node2, precedingNode) {
            var nextNode = precedingNode.nextSibling, parent = precedingNode.parentNode;
            if (nextNode) {
              parent.insertBefore(node2, nextNode);
            } else {
              parent.appendChild(node2);
            }
            return node2;
          }
          function splitDataNode(node2, index, positionsToPreserve) {
            var newNode = node2.cloneNode(false);
            newNode.deleteData(0, index);
            node2.deleteData(index, node2.length - index);
            insertAfter2(newNode, node2);
            if (positionsToPreserve) {
              for (var i = 0, position; position = positionsToPreserve[i++]; ) {
                if (position.node == node2 && position.offset > index) {
                  position.node = newNode;
                  position.offset -= index;
                } else if (position.node == node2.parentNode && position.offset > getNodeIndex(node2)) {
                  ++position.offset;
                }
              }
            }
            return newNode;
          }
          function getDocument(node2) {
            if (node2.nodeType == 9) {
              return node2;
            } else if (typeof node2.ownerDocument != UNDEF) {
              return node2.ownerDocument;
            } else if (typeof node2.document != UNDEF) {
              return node2.document;
            } else if (node2.parentNode) {
              return getDocument(node2.parentNode);
            } else {
              throw module2.createError("getDocument: no document found for node");
            }
          }
          function getWindow(node2) {
            var doc2 = getDocument(node2);
            if (typeof doc2.defaultView != UNDEF) {
              return doc2.defaultView;
            } else if (typeof doc2.parentWindow != UNDEF) {
              return doc2.parentWindow;
            } else {
              throw module2.createError("Cannot get a window object for node");
            }
          }
          function getIframeDocument(iframeEl) {
            if (typeof iframeEl.contentDocument != UNDEF) {
              return iframeEl.contentDocument;
            } else if (typeof iframeEl.contentWindow != UNDEF) {
              return iframeEl.contentWindow.document;
            } else {
              throw module2.createError("getIframeDocument: No Document object found for iframe element");
            }
          }
          function getIframeWindow(iframeEl) {
            if (typeof iframeEl.contentWindow != UNDEF) {
              return iframeEl.contentWindow;
            } else if (typeof iframeEl.contentDocument != UNDEF) {
              return iframeEl.contentDocument.defaultView;
            } else {
              throw module2.createError("getIframeWindow: No Window object found for iframe element");
            }
          }
          function isWindow(obj) {
            return obj && util2.isHostMethod(obj, "setTimeout") && util2.isHostObject(obj, "document");
          }
          function getContentDocument(obj, module3, methodName) {
            var doc2;
            if (!obj) {
              doc2 = document;
            } else if (util2.isHostProperty(obj, "nodeType")) {
              doc2 = obj.nodeType == 1 && obj.tagName.toLowerCase() == "iframe" ? getIframeDocument(obj) : getDocument(obj);
            } else if (isWindow(obj)) {
              doc2 = obj.document;
            }
            if (!doc2) {
              throw module3.createError(methodName + "(): Parameter must be a Window object or DOM node");
            }
            return doc2;
          }
          function getRootContainer(node2) {
            var parent;
            while (parent = node2.parentNode) {
              node2 = parent;
            }
            return node2;
          }
          function comparePoints(nodeA, offsetA, nodeB, offsetB) {
            var nodeC, root2, childA, childB, n;
            if (nodeA == nodeB) {
              return offsetA === offsetB ? 0 : offsetA < offsetB ? -1 : 1;
            } else if (nodeC = getClosestAncestorIn(nodeB, nodeA, true)) {
              return offsetA <= getNodeIndex(nodeC) ? -1 : 1;
            } else if (nodeC = getClosestAncestorIn(nodeA, nodeB, true)) {
              return getNodeIndex(nodeC) < offsetB ? -1 : 1;
            } else {
              root2 = getCommonAncestor(nodeA, nodeB);
              if (!root2) {
                throw new Error("comparePoints error: nodes have no common ancestor");
              }
              childA = nodeA === root2 ? root2 : getClosestAncestorIn(nodeA, root2, true);
              childB = nodeB === root2 ? root2 : getClosestAncestorIn(nodeB, root2, true);
              if (childA === childB) {
                throw module2.createError("comparePoints got to case 4 and childA and childB are the same!");
              } else {
                n = root2.firstChild;
                while (n) {
                  if (n === childA) {
                    return -1;
                  } else if (n === childB) {
                    return 1;
                  }
                  n = n.nextSibling;
                }
              }
            }
          }
          var crashyTextNodes = false;
          function isBrokenNode(node2) {
            var n;
            try {
              n = node2.parentNode;
              return false;
            } catch (e) {
              return true;
            }
          }
          (function() {
            var el2 = document.createElement("b");
            el2.innerHTML = "1";
            var textNode2 = el2.firstChild;
            el2.innerHTML = "<br />";
            crashyTextNodes = isBrokenNode(textNode2);
            api2.features.crashyTextNodes = crashyTextNodes;
          })();
          function inspectNode(node2) {
            if (!node2) {
              return "[No node]";
            }
            if (crashyTextNodes && isBrokenNode(node2)) {
              return "[Broken node]";
            }
            if (isCharacterDataNode(node2)) {
              return '"' + node2.data + '"';
            }
            if (node2.nodeType == 1) {
              var idAttr = node2.id ? ' id="' + node2.id + '"' : "";
              return "<" + node2.nodeName + idAttr + ">[index:" + getNodeIndex(node2) + ",length:" + node2.childNodes.length + "][" + (node2.innerHTML || "[innerHTML not supported]").slice(0, 25) + "]";
            }
            return node2.nodeName;
          }
          function fragmentFromNodeChildren(node2) {
            var fragment = getDocument(node2).createDocumentFragment(), child;
            while (child = node2.firstChild) {
              fragment.appendChild(child);
            }
            return fragment;
          }
          var getComputedStyleProperty;
          if (typeof window.getComputedStyle != UNDEF) {
            getComputedStyleProperty = function(el2, propName) {
              return getWindow(el2).getComputedStyle(el2, null)[propName];
            };
          } else if (typeof document.documentElement.currentStyle != UNDEF) {
            getComputedStyleProperty = function(el2, propName) {
              return el2.currentStyle ? el2.currentStyle[propName] : "";
            };
          } else {
            module2.fail("No means of obtaining computed style properties found");
          }
          function createTestElement(doc2, html, contentEditable) {
            var body = getBody2(doc2);
            var el2 = doc2.createElement("div");
            el2.contentEditable = "" + !!contentEditable;
            if (html) {
              el2.innerHTML = html;
            }
            var bodyFirstChild = body.firstChild;
            if (bodyFirstChild) {
              body.insertBefore(el2, bodyFirstChild);
            } else {
              body.appendChild(el2);
            }
            return el2;
          }
          function removeNode(node2) {
            return node2.parentNode.removeChild(node2);
          }
          function NodeIterator(root2) {
            this.root = root2;
            this._next = root2;
          }
          NodeIterator.prototype = {
            _current: null,
            hasNext: function() {
              return !!this._next;
            },
            next: function() {
              var n = this._current = this._next;
              var child, next;
              if (this._current) {
                child = n.firstChild;
                if (child) {
                  this._next = child;
                } else {
                  next = null;
                  while (n !== this.root && !(next = n.nextSibling)) {
                    n = n.parentNode;
                  }
                  this._next = next;
                }
              }
              return this._current;
            },
            detach: function() {
              this._current = this._next = this.root = null;
            }
          };
          function createIterator(root2) {
            return new NodeIterator(root2);
          }
          function DomPosition(node2, offset) {
            this.node = node2;
            this.offset = offset;
          }
          DomPosition.prototype = {
            equals: function(pos) {
              return !!pos && this.node === pos.node && this.offset == pos.offset;
            },
            inspect: function() {
              return "[DomPosition(" + inspectNode(this.node) + ":" + this.offset + ")]";
            },
            toString: function() {
              return this.inspect();
            }
          };
          function DOMException(codeName) {
            this.code = this[codeName];
            this.codeName = codeName;
            this.message = "DOMException: " + this.codeName;
          }
          DOMException.prototype = {
            INDEX_SIZE_ERR: 1,
            HIERARCHY_REQUEST_ERR: 3,
            WRONG_DOCUMENT_ERR: 4,
            NO_MODIFICATION_ALLOWED_ERR: 7,
            NOT_FOUND_ERR: 8,
            NOT_SUPPORTED_ERR: 9,
            INVALID_STATE_ERR: 11,
            INVALID_NODE_TYPE_ERR: 24
          };
          DOMException.prototype.toString = function() {
            return this.message;
          };
          api2.dom = {
            arrayContains,
            isHtmlNamespace,
            parentElement,
            getNodeIndex,
            getNodeLength,
            getCommonAncestor,
            isAncestorOf,
            isOrIsAncestorOf,
            getClosestAncestorIn,
            isCharacterDataNode,
            isTextOrCommentNode,
            insertAfter: insertAfter2,
            splitDataNode,
            getDocument,
            getWindow,
            getIframeWindow,
            getIframeDocument,
            getBody: getBody2,
            isWindow,
            getContentDocument,
            getRootContainer,
            comparePoints,
            isBrokenNode,
            inspectNode,
            getComputedStyleProperty,
            createTestElement,
            removeNode,
            fragmentFromNodeChildren,
            createIterator,
            DomPosition
          };
          api2.DOMException = DOMException;
        });
        api.createCoreModule("DomRange", ["DomUtil"], function(api2, module2) {
          var dom = api2.dom;
          var util2 = api2.util;
          var DomPosition = dom.DomPosition;
          var DOMException = api2.DOMException;
          var isCharacterDataNode = dom.isCharacterDataNode;
          var getNodeIndex = dom.getNodeIndex;
          var isOrIsAncestorOf = dom.isOrIsAncestorOf;
          var getDocument = dom.getDocument;
          var comparePoints = dom.comparePoints;
          var splitDataNode = dom.splitDataNode;
          var getClosestAncestorIn = dom.getClosestAncestorIn;
          var getNodeLength = dom.getNodeLength;
          var arrayContains = dom.arrayContains;
          var getRootContainer = dom.getRootContainer;
          var crashyTextNodes = api2.features.crashyTextNodes;
          var removeNode = dom.removeNode;
          function isNonTextPartiallySelected(node2, range2) {
            return node2.nodeType != 3 && (isOrIsAncestorOf(node2, range2.startContainer) || isOrIsAncestorOf(node2, range2.endContainer));
          }
          function getRangeDocument(range2) {
            return range2.document || getDocument(range2.startContainer);
          }
          function getRangeRoot(range2) {
            return getRootContainer(range2.startContainer);
          }
          function getBoundaryBeforeNode(node2) {
            return new DomPosition(node2.parentNode, getNodeIndex(node2));
          }
          function getBoundaryAfterNode(node2) {
            return new DomPosition(node2.parentNode, getNodeIndex(node2) + 1);
          }
          function insertNodeAtPosition(node2, n, o) {
            var firstNodeInserted = node2.nodeType == 11 ? node2.firstChild : node2;
            if (isCharacterDataNode(n)) {
              if (o == n.length) {
                dom.insertAfter(node2, n);
              } else {
                n.parentNode.insertBefore(node2, o == 0 ? n : splitDataNode(n, o));
              }
            } else if (o >= n.childNodes.length) {
              n.appendChild(node2);
            } else {
              n.insertBefore(node2, n.childNodes[o]);
            }
            return firstNodeInserted;
          }
          function rangesIntersect(rangeA, rangeB, touchingIsIntersecting) {
            assertRangeValid(rangeA);
            assertRangeValid(rangeB);
            if (getRangeDocument(rangeB) != getRangeDocument(rangeA)) {
              throw new DOMException("WRONG_DOCUMENT_ERR");
            }
            var startComparison = comparePoints(rangeA.startContainer, rangeA.startOffset, rangeB.endContainer, rangeB.endOffset), endComparison = comparePoints(rangeA.endContainer, rangeA.endOffset, rangeB.startContainer, rangeB.startOffset);
            return touchingIsIntersecting ? startComparison <= 0 && endComparison >= 0 : startComparison < 0 && endComparison > 0;
          }
          function cloneSubtree(iterator) {
            var partiallySelected;
            for (var node2, frag = getRangeDocument(iterator.range).createDocumentFragment(), subIterator; node2 = iterator.next(); ) {
              partiallySelected = iterator.isPartiallySelectedSubtree();
              node2 = node2.cloneNode(!partiallySelected);
              if (partiallySelected) {
                subIterator = iterator.getSubtreeIterator();
                node2.appendChild(cloneSubtree(subIterator));
                subIterator.detach();
              }
              if (node2.nodeType == 10) {
                throw new DOMException("HIERARCHY_REQUEST_ERR");
              }
              frag.appendChild(node2);
            }
            return frag;
          }
          function iterateSubtree(rangeIterator, func, iteratorState) {
            var it, n;
            iteratorState = iteratorState || { stop: false };
            for (var node2, subRangeIterator; node2 = rangeIterator.next(); ) {
              if (rangeIterator.isPartiallySelectedSubtree()) {
                if (func(node2) === false) {
                  iteratorState.stop = true;
                  return;
                } else {
                  subRangeIterator = rangeIterator.getSubtreeIterator();
                  iterateSubtree(subRangeIterator, func, iteratorState);
                  subRangeIterator.detach();
                  if (iteratorState.stop) {
                    return;
                  }
                }
              } else {
                it = dom.createIterator(node2);
                while (n = it.next()) {
                  if (func(n) === false) {
                    iteratorState.stop = true;
                    return;
                  }
                }
              }
            }
          }
          function deleteSubtree(iterator) {
            var subIterator;
            while (iterator.next()) {
              if (iterator.isPartiallySelectedSubtree()) {
                subIterator = iterator.getSubtreeIterator();
                deleteSubtree(subIterator);
                subIterator.detach();
              } else {
                iterator.remove();
              }
            }
          }
          function extractSubtree(iterator) {
            for (var node2, frag = getRangeDocument(iterator.range).createDocumentFragment(), subIterator; node2 = iterator.next(); ) {
              if (iterator.isPartiallySelectedSubtree()) {
                node2 = node2.cloneNode(false);
                subIterator = iterator.getSubtreeIterator();
                node2.appendChild(extractSubtree(subIterator));
                subIterator.detach();
              } else {
                iterator.remove();
              }
              if (node2.nodeType == 10) {
                throw new DOMException("HIERARCHY_REQUEST_ERR");
              }
              frag.appendChild(node2);
            }
            return frag;
          }
          function getNodesInRange(range2, nodeTypes, filter2) {
            var filterNodeTypes = !!(nodeTypes && nodeTypes.length), regex;
            var filterExists = !!filter2;
            if (filterNodeTypes) {
              regex = new RegExp("^(" + nodeTypes.join("|") + ")$");
            }
            var nodes = [];
            iterateSubtree(new RangeIterator(range2, false), function(node2) {
              if (filterNodeTypes && !regex.test(node2.nodeType)) {
                return;
              }
              if (filterExists && !filter2(node2)) {
                return;
              }
              var sc = range2.startContainer;
              if (node2 == sc && isCharacterDataNode(sc) && range2.startOffset == sc.length) {
                return;
              }
              var ec = range2.endContainer;
              if (node2 == ec && isCharacterDataNode(ec) && range2.endOffset == 0) {
                return;
              }
              nodes.push(node2);
            });
            return nodes;
          }
          function inspect(range2) {
            var name = typeof range2.getName == "undefined" ? "Range" : range2.getName();
            return "[" + name + "(" + dom.inspectNode(range2.startContainer) + ":" + range2.startOffset + ", " + dom.inspectNode(range2.endContainer) + ":" + range2.endOffset + ")]";
          }
          function RangeIterator(range2, clonePartiallySelectedTextNodes) {
            this.range = range2;
            this.clonePartiallySelectedTextNodes = clonePartiallySelectedTextNodes;
            if (!range2.collapsed) {
              this.sc = range2.startContainer;
              this.so = range2.startOffset;
              this.ec = range2.endContainer;
              this.eo = range2.endOffset;
              var root2 = range2.commonAncestorContainer;
              if (this.sc === this.ec && isCharacterDataNode(this.sc)) {
                this.isSingleCharacterDataNode = true;
                this._first = this._last = this._next = this.sc;
              } else {
                this._first = this._next = this.sc === root2 && !isCharacterDataNode(this.sc) ? this.sc.childNodes[this.so] : getClosestAncestorIn(this.sc, root2, true);
                this._last = this.ec === root2 && !isCharacterDataNode(this.ec) ? this.ec.childNodes[this.eo - 1] : getClosestAncestorIn(this.ec, root2, true);
              }
            }
          }
          RangeIterator.prototype = {
            _current: null,
            _next: null,
            _first: null,
            _last: null,
            isSingleCharacterDataNode: false,
            reset: function() {
              this._current = null;
              this._next = this._first;
            },
            hasNext: function() {
              return !!this._next;
            },
            next: function() {
              var current2 = this._current = this._next;
              if (current2) {
                this._next = current2 !== this._last ? current2.nextSibling : null;
                if (isCharacterDataNode(current2) && this.clonePartiallySelectedTextNodes) {
                  if (current2 === this.ec) {
                    (current2 = current2.cloneNode(true)).deleteData(this.eo, current2.length - this.eo);
                  }
                  if (this._current === this.sc) {
                    (current2 = current2.cloneNode(true)).deleteData(0, this.so);
                  }
                }
              }
              return current2;
            },
            remove: function() {
              var current2 = this._current, start, end;
              if (isCharacterDataNode(current2) && (current2 === this.sc || current2 === this.ec)) {
                start = current2 === this.sc ? this.so : 0;
                end = current2 === this.ec ? this.eo : current2.length;
                if (start != end) {
                  current2.deleteData(start, end - start);
                }
              } else {
                if (current2.parentNode) {
                  removeNode(current2);
                } else {
                }
              }
            },
            // Checks if the current node is partially selected
            isPartiallySelectedSubtree: function() {
              var current2 = this._current;
              return isNonTextPartiallySelected(current2, this.range);
            },
            getSubtreeIterator: function() {
              var subRange;
              if (this.isSingleCharacterDataNode) {
                subRange = this.range.cloneRange();
                subRange.collapse(false);
              } else {
                subRange = new Range2(getRangeDocument(this.range));
                var current2 = this._current;
                var startContainer = current2, startOffset = 0, endContainer = current2, endOffset = getNodeLength(current2);
                if (isOrIsAncestorOf(current2, this.sc)) {
                  startContainer = this.sc;
                  startOffset = this.so;
                }
                if (isOrIsAncestorOf(current2, this.ec)) {
                  endContainer = this.ec;
                  endOffset = this.eo;
                }
                updateBoundaries(subRange, startContainer, startOffset, endContainer, endOffset);
              }
              return new RangeIterator(subRange, this.clonePartiallySelectedTextNodes);
            },
            detach: function() {
              this.range = this._current = this._next = this._first = this._last = this.sc = this.so = this.ec = this.eo = null;
            }
          };
          var beforeAfterNodeTypes = [1, 3, 4, 5, 7, 8, 10];
          var rootContainerNodeTypes = [2, 9, 11];
          var readonlyNodeTypes = [5, 6, 10, 12];
          var insertableNodeTypes = [1, 3, 4, 5, 7, 8, 10, 11];
          var surroundNodeTypes = [1, 3, 4, 5, 7, 8];
          function createAncestorFinder(nodeTypes) {
            return function(node2, selfIsAncestor) {
              var t, n = selfIsAncestor ? node2 : node2.parentNode;
              while (n) {
                t = n.nodeType;
                if (arrayContains(nodeTypes, t)) {
                  return n;
                }
                n = n.parentNode;
              }
              return null;
            };
          }
          var getDocumentOrFragmentContainer = createAncestorFinder([9, 11]);
          var getReadonlyAncestor = createAncestorFinder(readonlyNodeTypes);
          var getDocTypeNotationEntityAncestor = createAncestorFinder([6, 10, 12]);
          var getElementAncestor = createAncestorFinder([1]);
          function assertNoDocTypeNotationEntityAncestor(node2, allowSelf) {
            if (getDocTypeNotationEntityAncestor(node2, allowSelf)) {
              throw new DOMException("INVALID_NODE_TYPE_ERR");
            }
          }
          function assertValidNodeType(node2, invalidTypes) {
            if (!arrayContains(invalidTypes, node2.nodeType)) {
              throw new DOMException("INVALID_NODE_TYPE_ERR");
            }
          }
          function assertValidOffset(node2, offset) {
            if (offset < 0 || offset > (isCharacterDataNode(node2) ? node2.length : node2.childNodes.length)) {
              throw new DOMException("INDEX_SIZE_ERR");
            }
          }
          function assertSameDocumentOrFragment(node1, node2) {
            if (getDocumentOrFragmentContainer(node1, true) !== getDocumentOrFragmentContainer(node2, true)) {
              throw new DOMException("WRONG_DOCUMENT_ERR");
            }
          }
          function assertNodeNotReadOnly(node2) {
            if (getReadonlyAncestor(node2, true)) {
              throw new DOMException("NO_MODIFICATION_ALLOWED_ERR");
            }
          }
          function assertNode(node2, codeName) {
            if (!node2) {
              throw new DOMException(codeName);
            }
          }
          function isValidOffset(node2, offset) {
            return offset <= (isCharacterDataNode(node2) ? node2.length : node2.childNodes.length);
          }
          function isRangeValid(range2) {
            return !!range2.startContainer && !!range2.endContainer && !(crashyTextNodes && (dom.isBrokenNode(range2.startContainer) || dom.isBrokenNode(range2.endContainer))) && getRootContainer(range2.startContainer) == getRootContainer(range2.endContainer) && isValidOffset(range2.startContainer, range2.startOffset) && isValidOffset(range2.endContainer, range2.endOffset);
          }
          function assertRangeValid(range2) {
            if (!isRangeValid(range2)) {
              throw new Error("Range error: Range is not valid. This usually happens after DOM mutation. Range: (" + range2.inspect() + ")");
            }
          }
          var styleEl = document.createElement("style");
          var htmlParsingConforms = false;
          try {
            styleEl.innerHTML = "<b>x</b>";
            htmlParsingConforms = styleEl.firstChild.nodeType == 3;
          } catch (e) {
          }
          api2.features.htmlParsingConforms = htmlParsingConforms;
          var createContextualFragment = htmlParsingConforms ? (
            // Implementation as per HTML parsing spec, trusting in the browser's implementation of innerHTML. See
            // discussion and base code for this implementation at issue 67.
            // Spec: http://html5.org/specs/dom-parsing.html#extensions-to-the-range-interface
            // Thanks to Aleks Williams.
            function(fragmentStr) {
              var node2 = this.startContainer;
              var doc2 = getDocument(node2);
              if (!node2) {
                throw new DOMException("INVALID_STATE_ERR");
              }
              var el = null;
              if (node2.nodeType == 1) {
                el = node2;
              } else if (isCharacterDataNode(node2)) {
                el = dom.parentElement(node2);
              }
              if (el === null || el.nodeName == "HTML" && dom.isHtmlNamespace(getDocument(el).documentElement) && dom.isHtmlNamespace(el)) {
                el = doc2.createElement("body");
              } else {
                el = el.cloneNode(false);
              }
              el.innerHTML = fragmentStr;
              return dom.fragmentFromNodeChildren(el);
            }
          ) : (
            // In this case, innerHTML cannot be trusted, so fall back to a simpler, non-conformant implementation that
            // previous versions of Rangy used (with the exception of using a body element rather than a div)
            function(fragmentStr) {
              var doc2 = getRangeDocument(this);
              var el = doc2.createElement("body");
              el.innerHTML = fragmentStr;
              return dom.fragmentFromNodeChildren(el);
            }
          );
          function splitRangeBoundaries(range2, positionsToPreserve) {
            assertRangeValid(range2);
            var sc = range2.startContainer, so = range2.startOffset, ec = range2.endContainer, eo = range2.endOffset;
            var startEndSame = sc === ec;
            if (isCharacterDataNode(ec) && eo > 0 && eo < ec.length) {
              splitDataNode(ec, eo, positionsToPreserve);
            }
            if (isCharacterDataNode(sc) && so > 0 && so < sc.length) {
              sc = splitDataNode(sc, so, positionsToPreserve);
              if (startEndSame) {
                eo -= so;
                ec = sc;
              } else if (ec == sc.parentNode && eo >= getNodeIndex(sc)) {
                eo++;
              }
              so = 0;
            }
            range2.setStartAndEnd(sc, so, ec, eo);
          }
          function rangeToHtml(range2) {
            assertRangeValid(range2);
            var container = range2.commonAncestorContainer.parentNode.cloneNode(false);
            container.appendChild(range2.cloneContents());
            return container.innerHTML;
          }
          var rangeProperties = [
            "startContainer",
            "startOffset",
            "endContainer",
            "endOffset",
            "collapsed",
            "commonAncestorContainer"
          ];
          var s2s = 0, s2e = 1, e2e = 2, e2s = 3;
          var n_b = 0, n_a = 1, n_b_a = 2, n_i = 3;
          util2.extend(api2.rangePrototype, {
            compareBoundaryPoints: function(how, range2) {
              assertRangeValid(this);
              assertSameDocumentOrFragment(this.startContainer, range2.startContainer);
              var nodeA, offsetA, nodeB, offsetB;
              var prefixA = how == e2s || how == s2s ? "start" : "end";
              var prefixB = how == s2e || how == s2s ? "start" : "end";
              nodeA = this[prefixA + "Container"];
              offsetA = this[prefixA + "Offset"];
              nodeB = range2[prefixB + "Container"];
              offsetB = range2[prefixB + "Offset"];
              return comparePoints(nodeA, offsetA, nodeB, offsetB);
            },
            insertNode: function(node2) {
              assertRangeValid(this);
              assertValidNodeType(node2, insertableNodeTypes);
              assertNodeNotReadOnly(this.startContainer);
              if (isOrIsAncestorOf(node2, this.startContainer)) {
                throw new DOMException("HIERARCHY_REQUEST_ERR");
              }
              var firstNodeInserted = insertNodeAtPosition(node2, this.startContainer, this.startOffset);
              this.setStartBefore(firstNodeInserted);
            },
            cloneContents: function() {
              assertRangeValid(this);
              var clone2, frag;
              if (this.collapsed) {
                return getRangeDocument(this).createDocumentFragment();
              } else {
                if (this.startContainer === this.endContainer && isCharacterDataNode(this.startContainer)) {
                  clone2 = this.startContainer.cloneNode(true);
                  clone2.data = clone2.data.slice(this.startOffset, this.endOffset);
                  frag = getRangeDocument(this).createDocumentFragment();
                  frag.appendChild(clone2);
                  return frag;
                } else {
                  var iterator = new RangeIterator(this, true);
                  clone2 = cloneSubtree(iterator);
                  iterator.detach();
                }
                return clone2;
              }
            },
            canSurroundContents: function() {
              assertRangeValid(this);
              assertNodeNotReadOnly(this.startContainer);
              assertNodeNotReadOnly(this.endContainer);
              var iterator = new RangeIterator(this, true);
              var boundariesInvalid = iterator._first && isNonTextPartiallySelected(iterator._first, this) || iterator._last && isNonTextPartiallySelected(iterator._last, this);
              iterator.detach();
              return !boundariesInvalid;
            },
            surroundContents: function(node2) {
              assertValidNodeType(node2, surroundNodeTypes);
              if (!this.canSurroundContents()) {
                throw new DOMException("INVALID_STATE_ERR");
              }
              var content = this.extractContents();
              if (node2.hasChildNodes()) {
                while (node2.lastChild) {
                  node2.removeChild(node2.lastChild);
                }
              }
              insertNodeAtPosition(node2, this.startContainer, this.startOffset);
              node2.appendChild(content);
              this.selectNode(node2);
            },
            cloneRange: function() {
              assertRangeValid(this);
              var range2 = new Range2(getRangeDocument(this));
              var i = rangeProperties.length, prop;
              while (i--) {
                prop = rangeProperties[i];
                range2[prop] = this[prop];
              }
              return range2;
            },
            toString: function() {
              assertRangeValid(this);
              var sc = this.startContainer;
              if (sc === this.endContainer && isCharacterDataNode(sc)) {
                return sc.nodeType == 3 || sc.nodeType == 4 ? sc.data.slice(this.startOffset, this.endOffset) : "";
              } else {
                var textParts = [], iterator = new RangeIterator(this, true);
                iterateSubtree(iterator, function(node2) {
                  if (node2.nodeType == 3 || node2.nodeType == 4) {
                    textParts.push(node2.data);
                  }
                });
                iterator.detach();
                return textParts.join("");
              }
            },
            // The methods below are all non-standard. The following batch were introduced by Mozilla but have since
            // been removed from Mozilla.
            compareNode: function(node2) {
              assertRangeValid(this);
              var parent = node2.parentNode;
              var nodeIndex = getNodeIndex(node2);
              if (!parent) {
                throw new DOMException("NOT_FOUND_ERR");
              }
              var startComparison = this.comparePoint(parent, nodeIndex), endComparison = this.comparePoint(parent, nodeIndex + 1);
              if (startComparison < 0) {
                return endComparison > 0 ? n_b_a : n_b;
              } else {
                return endComparison > 0 ? n_a : n_i;
              }
            },
            comparePoint: function(node2, offset) {
              assertRangeValid(this);
              assertNode(node2, "HIERARCHY_REQUEST_ERR");
              assertSameDocumentOrFragment(node2, this.startContainer);
              if (comparePoints(node2, offset, this.startContainer, this.startOffset) < 0) {
                return -1;
              } else if (comparePoints(node2, offset, this.endContainer, this.endOffset) > 0) {
                return 1;
              }
              return 0;
            },
            createContextualFragment,
            toHtml: function() {
              return rangeToHtml(this);
            },
            // touchingIsIntersecting determines whether this method considers a node that borders a range intersects
            // with it (as in WebKit) or not (as in Gecko pre-1.9, and the default)
            intersectsNode: function(node2, touchingIsIntersecting) {
              assertRangeValid(this);
              if (getRootContainer(node2) != getRangeRoot(this)) {
                return false;
              }
              var parent = node2.parentNode, offset = getNodeIndex(node2);
              if (!parent) {
                return true;
              }
              var startComparison = comparePoints(parent, offset, this.endContainer, this.endOffset), endComparison = comparePoints(parent, offset + 1, this.startContainer, this.startOffset);
              return touchingIsIntersecting ? startComparison <= 0 && endComparison >= 0 : startComparison < 0 && endComparison > 0;
            },
            isPointInRange: function(node2, offset) {
              assertRangeValid(this);
              assertNode(node2, "HIERARCHY_REQUEST_ERR");
              assertSameDocumentOrFragment(node2, this.startContainer);
              return comparePoints(node2, offset, this.startContainer, this.startOffset) >= 0 && comparePoints(node2, offset, this.endContainer, this.endOffset) <= 0;
            },
            // The methods below are non-standard and invented by me.
            // Sharing a boundary start-to-end or end-to-start does not count as intersection.
            intersectsRange: function(range2) {
              return rangesIntersect(this, range2, false);
            },
            // Sharing a boundary start-to-end or end-to-start does count as intersection.
            intersectsOrTouchesRange: function(range2) {
              return rangesIntersect(this, range2, true);
            },
            intersection: function(range2) {
              if (this.intersectsRange(range2)) {
                var startComparison = comparePoints(this.startContainer, this.startOffset, range2.startContainer, range2.startOffset), endComparison = comparePoints(this.endContainer, this.endOffset, range2.endContainer, range2.endOffset);
                var intersectionRange = this.cloneRange();
                if (startComparison == -1) {
                  intersectionRange.setStart(range2.startContainer, range2.startOffset);
                }
                if (endComparison == 1) {
                  intersectionRange.setEnd(range2.endContainer, range2.endOffset);
                }
                return intersectionRange;
              }
              return null;
            },
            union: function(range2) {
              if (this.intersectsOrTouchesRange(range2)) {
                var unionRange = this.cloneRange();
                if (comparePoints(range2.startContainer, range2.startOffset, this.startContainer, this.startOffset) == -1) {
                  unionRange.setStart(range2.startContainer, range2.startOffset);
                }
                if (comparePoints(range2.endContainer, range2.endOffset, this.endContainer, this.endOffset) == 1) {
                  unionRange.setEnd(range2.endContainer, range2.endOffset);
                }
                return unionRange;
              } else {
                throw new DOMException("Ranges do not intersect");
              }
            },
            containsNode: function(node2, allowPartial) {
              if (allowPartial) {
                return this.intersectsNode(node2, false);
              } else {
                return this.compareNode(node2) == n_i;
              }
            },
            containsNodeContents: function(node2) {
              return this.comparePoint(node2, 0) >= 0 && this.comparePoint(node2, getNodeLength(node2)) <= 0;
            },
            containsRange: function(range2) {
              var intersection2 = this.intersection(range2);
              return intersection2 !== null && range2.equals(intersection2);
            },
            containsNodeText: function(node2) {
              var nodeRange = this.cloneRange();
              nodeRange.selectNode(node2);
              var textNodes = nodeRange.getNodes([3]);
              if (textNodes.length > 0) {
                nodeRange.setStart(textNodes[0], 0);
                var lastTextNode = textNodes.pop();
                nodeRange.setEnd(lastTextNode, lastTextNode.length);
                return this.containsRange(nodeRange);
              } else {
                return this.containsNodeContents(node2);
              }
            },
            getNodes: function(nodeTypes, filter2) {
              assertRangeValid(this);
              return getNodesInRange(this, nodeTypes, filter2);
            },
            getDocument: function() {
              return getRangeDocument(this);
            },
            collapseBefore: function(node2) {
              this.setEndBefore(node2);
              this.collapse(false);
            },
            collapseAfter: function(node2) {
              this.setStartAfter(node2);
              this.collapse(true);
            },
            getBookmark: function(containerNode) {
              var doc2 = getRangeDocument(this);
              var preSelectionRange = api2.createRange(doc2);
              containerNode = containerNode || dom.getBody(doc2);
              preSelectionRange.selectNodeContents(containerNode);
              var range2 = this.intersection(preSelectionRange);
              var start = 0, end = 0;
              if (range2) {
                preSelectionRange.setEnd(range2.startContainer, range2.startOffset);
                start = preSelectionRange.toString().length;
                end = start + range2.toString().length;
              }
              return {
                start,
                end,
                containerNode
              };
            },
            moveToBookmark: function(bookmark) {
              var containerNode = bookmark.containerNode;
              var charIndex = 0;
              this.setStart(containerNode, 0);
              this.collapse(true);
              var nodeStack = [containerNode], node2, foundStart = false, stop = false;
              var nextCharIndex, i, childNodes;
              while (!stop && (node2 = nodeStack.pop())) {
                if (node2.nodeType == 3) {
                  nextCharIndex = charIndex + node2.length;
                  if (!foundStart && bookmark.start >= charIndex && bookmark.start <= nextCharIndex) {
                    this.setStart(node2, bookmark.start - charIndex);
                    foundStart = true;
                  }
                  if (foundStart && bookmark.end >= charIndex && bookmark.end <= nextCharIndex) {
                    this.setEnd(node2, bookmark.end - charIndex);
                    stop = true;
                  }
                  charIndex = nextCharIndex;
                } else {
                  childNodes = node2.childNodes;
                  i = childNodes.length;
                  while (i--) {
                    nodeStack.push(childNodes[i]);
                  }
                }
              }
            },
            getName: function() {
              return "DomRange";
            },
            equals: function(range2) {
              return Range2.rangesEqual(this, range2);
            },
            isValid: function() {
              return isRangeValid(this);
            },
            inspect: function() {
              return inspect(this);
            },
            detach: function() {
            }
          });
          function copyComparisonConstantsToObject(obj) {
            obj.START_TO_START = s2s;
            obj.START_TO_END = s2e;
            obj.END_TO_END = e2e;
            obj.END_TO_START = e2s;
            obj.NODE_BEFORE = n_b;
            obj.NODE_AFTER = n_a;
            obj.NODE_BEFORE_AND_AFTER = n_b_a;
            obj.NODE_INSIDE = n_i;
          }
          function copyComparisonConstants(constructor) {
            copyComparisonConstantsToObject(constructor);
            copyComparisonConstantsToObject(constructor.prototype);
          }
          function createRangeContentRemover(remover, boundaryUpdater) {
            return function() {
              assertRangeValid(this);
              var sc = this.startContainer, so = this.startOffset, root2 = this.commonAncestorContainer;
              var iterator = new RangeIterator(this, true);
              var node2, boundary;
              if (sc !== root2) {
                node2 = getClosestAncestorIn(sc, root2, true);
                boundary = getBoundaryAfterNode(node2);
                sc = boundary.node;
                so = boundary.offset;
              }
              iterateSubtree(iterator, assertNodeNotReadOnly);
              iterator.reset();
              var returnValue = remover(iterator);
              iterator.detach();
              boundaryUpdater(this, sc, so, sc, so);
              return returnValue;
            };
          }
          function createPrototypeRange(constructor, boundaryUpdater) {
            function createBeforeAfterNodeSetter(isBefore, isStart) {
              return function(node2) {
                assertValidNodeType(node2, beforeAfterNodeTypes);
                assertValidNodeType(getRootContainer(node2), rootContainerNodeTypes);
                var boundary = (isBefore ? getBoundaryBeforeNode : getBoundaryAfterNode)(node2);
                (isStart ? setRangeStart : setRangeEnd)(this, boundary.node, boundary.offset);
              };
            }
            function setRangeStart(range2, node2, offset) {
              var ec = range2.endContainer, eo = range2.endOffset;
              if (node2 !== range2.startContainer || offset !== range2.startOffset) {
                if (getRootContainer(node2) != getRootContainer(ec) || comparePoints(node2, offset, ec, eo) == 1) {
                  ec = node2;
                  eo = offset;
                }
                boundaryUpdater(range2, node2, offset, ec, eo);
              }
            }
            function setRangeEnd(range2, node2, offset) {
              var sc = range2.startContainer, so = range2.startOffset;
              if (node2 !== range2.endContainer || offset !== range2.endOffset) {
                if (getRootContainer(node2) != getRootContainer(sc) || comparePoints(node2, offset, sc, so) == -1) {
                  sc = node2;
                  so = offset;
                }
                boundaryUpdater(range2, sc, so, node2, offset);
              }
            }
            var F = function() {
            };
            F.prototype = api2.rangePrototype;
            constructor.prototype = new F();
            util2.extend(constructor.prototype, {
              setStart: function(node2, offset) {
                assertNoDocTypeNotationEntityAncestor(node2, true);
                assertValidOffset(node2, offset);
                setRangeStart(this, node2, offset);
              },
              setEnd: function(node2, offset) {
                assertNoDocTypeNotationEntityAncestor(node2, true);
                assertValidOffset(node2, offset);
                setRangeEnd(this, node2, offset);
              },
              /**
               * Convenience method to set a range's start and end boundaries. Overloaded as follows:
               * - Two parameters (node, offset) creates a collapsed range at that position
               * - Three parameters (node, startOffset, endOffset) creates a range contained with node starting at
               *   startOffset and ending at endOffset
               * - Four parameters (startNode, startOffset, endNode, endOffset) creates a range starting at startOffset in
               *   startNode and ending at endOffset in endNode
               */
              setStartAndEnd: function() {
                var args = arguments;
                var sc = args[0], so = args[1], ec = sc, eo = so;
                switch (args.length) {
                  case 3:
                    eo = args[2];
                    break;
                  case 4:
                    ec = args[2];
                    eo = args[3];
                    break;
                }
                assertNoDocTypeNotationEntityAncestor(sc, true);
                assertValidOffset(sc, so);
                assertNoDocTypeNotationEntityAncestor(ec, true);
                assertValidOffset(ec, eo);
                boundaryUpdater(this, sc, so, ec, eo);
              },
              setBoundary: function(node2, offset, isStart) {
                this["set" + (isStart ? "Start" : "End")](node2, offset);
              },
              setStartBefore: createBeforeAfterNodeSetter(true, true),
              setStartAfter: createBeforeAfterNodeSetter(false, true),
              setEndBefore: createBeforeAfterNodeSetter(true, false),
              setEndAfter: createBeforeAfterNodeSetter(false, false),
              collapse: function(isStart) {
                assertRangeValid(this);
                if (isStart) {
                  boundaryUpdater(this, this.startContainer, this.startOffset, this.startContainer, this.startOffset);
                } else {
                  boundaryUpdater(this, this.endContainer, this.endOffset, this.endContainer, this.endOffset);
                }
              },
              selectNodeContents: function(node2) {
                assertNoDocTypeNotationEntityAncestor(node2, true);
                boundaryUpdater(this, node2, 0, node2, getNodeLength(node2));
              },
              selectNode: function(node2) {
                assertNoDocTypeNotationEntityAncestor(node2, false);
                assertValidNodeType(node2, beforeAfterNodeTypes);
                var start = getBoundaryBeforeNode(node2), end = getBoundaryAfterNode(node2);
                boundaryUpdater(this, start.node, start.offset, end.node, end.offset);
              },
              extractContents: createRangeContentRemover(extractSubtree, boundaryUpdater),
              deleteContents: createRangeContentRemover(deleteSubtree, boundaryUpdater),
              canSurroundContents: function() {
                assertRangeValid(this);
                assertNodeNotReadOnly(this.startContainer);
                assertNodeNotReadOnly(this.endContainer);
                var iterator = new RangeIterator(this, true);
                var boundariesInvalid = iterator._first && isNonTextPartiallySelected(iterator._first, this) || iterator._last && isNonTextPartiallySelected(iterator._last, this);
                iterator.detach();
                return !boundariesInvalid;
              },
              splitBoundaries: function() {
                splitRangeBoundaries(this);
              },
              splitBoundariesPreservingPositions: function(positionsToPreserve) {
                splitRangeBoundaries(this, positionsToPreserve);
              },
              normalizeBoundaries: function() {
                assertRangeValid(this);
                var sc = this.startContainer, so = this.startOffset, ec = this.endContainer, eo = this.endOffset;
                var mergeForward = function(node2) {
                  var sibling2 = node2.nextSibling;
                  if (sibling2 && sibling2.nodeType == node2.nodeType) {
                    ec = node2;
                    eo = node2.length;
                    node2.appendData(sibling2.data);
                    removeNode(sibling2);
                  }
                };
                var mergeBackward = function(node2) {
                  var sibling2 = node2.previousSibling;
                  if (sibling2 && sibling2.nodeType == node2.nodeType) {
                    sc = node2;
                    var nodeLength = node2.length;
                    so = sibling2.length;
                    node2.insertData(0, sibling2.data);
                    removeNode(sibling2);
                    if (sc == ec) {
                      eo += so;
                      ec = sc;
                    } else if (ec == node2.parentNode) {
                      var nodeIndex = getNodeIndex(node2);
                      if (eo == nodeIndex) {
                        ec = node2;
                        eo = nodeLength;
                      } else if (eo > nodeIndex) {
                        eo--;
                      }
                    }
                  }
                };
                var normalizeStart = true;
                var sibling;
                if (isCharacterDataNode(ec)) {
                  if (eo == ec.length) {
                    mergeForward(ec);
                  } else if (eo == 0) {
                    sibling = ec.previousSibling;
                    if (sibling && sibling.nodeType == ec.nodeType) {
                      eo = sibling.length;
                      if (sc == ec) {
                        normalizeStart = false;
                      }
                      sibling.appendData(ec.data);
                      removeNode(ec);
                      ec = sibling;
                    }
                  }
                } else {
                  if (eo > 0) {
                    var endNode = ec.childNodes[eo - 1];
                    if (endNode && isCharacterDataNode(endNode)) {
                      mergeForward(endNode);
                    }
                  }
                  normalizeStart = !this.collapsed;
                }
                if (normalizeStart) {
                  if (isCharacterDataNode(sc)) {
                    if (so == 0) {
                      mergeBackward(sc);
                    } else if (so == sc.length) {
                      sibling = sc.nextSibling;
                      if (sibling && sibling.nodeType == sc.nodeType) {
                        if (ec == sibling) {
                          ec = sc;
                          eo += sc.length;
                        }
                        sc.appendData(sibling.data);
                        removeNode(sibling);
                      }
                    }
                  } else {
                    if (so < sc.childNodes.length) {
                      var startNode = sc.childNodes[so];
                      if (startNode && isCharacterDataNode(startNode)) {
                        mergeBackward(startNode);
                      }
                    }
                  }
                } else {
                  sc = ec;
                  so = eo;
                }
                boundaryUpdater(this, sc, so, ec, eo);
              },
              collapseToPoint: function(node2, offset) {
                assertNoDocTypeNotationEntityAncestor(node2, true);
                assertValidOffset(node2, offset);
                this.setStartAndEnd(node2, offset);
              },
              parentElement: function() {
                assertRangeValid(this);
                var parentNode = this.commonAncestorContainer;
                return parentNode ? getElementAncestor(this.commonAncestorContainer, true) : null;
              }
            });
            copyComparisonConstants(constructor);
          }
          function updateCollapsedAndCommonAncestor(range2) {
            range2.collapsed = range2.startContainer === range2.endContainer && range2.startOffset === range2.endOffset;
            range2.commonAncestorContainer = range2.collapsed ? range2.startContainer : dom.getCommonAncestor(range2.startContainer, range2.endContainer);
          }
          function updateBoundaries(range2, startContainer, startOffset, endContainer, endOffset) {
            range2.startContainer = startContainer;
            range2.startOffset = startOffset;
            range2.endContainer = endContainer;
            range2.endOffset = endOffset;
            range2.document = dom.getDocument(startContainer);
            updateCollapsedAndCommonAncestor(range2);
          }
          function Range2(doc2) {
            updateBoundaries(this, doc2, 0, doc2, 0);
          }
          createPrototypeRange(Range2, updateBoundaries);
          util2.extend(Range2, {
            rangeProperties,
            RangeIterator,
            copyComparisonConstants,
            createPrototypeRange,
            inspect,
            toHtml: rangeToHtml,
            getRangeDocument,
            rangesEqual: function(r1, r2) {
              return r1.startContainer === r2.startContainer && r1.startOffset === r2.startOffset && r1.endContainer === r2.endContainer && r1.endOffset === r2.endOffset;
            }
          });
          api2.DomRange = Range2;
        });
        api.createCoreModule("WrappedRange", ["DomRange"], function(api2, module2) {
          var WrappedRange, WrappedTextRange;
          var dom = api2.dom;
          var util2 = api2.util;
          var DomPosition = dom.DomPosition;
          var DomRange = api2.DomRange;
          var getBody2 = dom.getBody;
          var getContentDocument = dom.getContentDocument;
          var isCharacterDataNode = dom.isCharacterDataNode;
          if (api2.features.implementsDomRange) {
            (function() {
              var rangeProto;
              var rangeProperties = DomRange.rangeProperties;
              function updateRangeProperties(range3) {
                var i = rangeProperties.length, prop;
                while (i--) {
                  prop = rangeProperties[i];
                  range3[prop] = range3.nativeRange[prop];
                }
                range3.collapsed = range3.startContainer === range3.endContainer && range3.startOffset === range3.endOffset;
              }
              function updateNativeRange(range3, startContainer, startOffset, endContainer, endOffset) {
                var startMoved = range3.startContainer !== startContainer || range3.startOffset != startOffset;
                var endMoved = range3.endContainer !== endContainer || range3.endOffset != endOffset;
                var nativeRangeDifferent = !range3.equals(range3.nativeRange);
                if (startMoved || endMoved || nativeRangeDifferent) {
                  range3.setEnd(endContainer, endOffset);
                  range3.setStart(startContainer, startOffset);
                }
              }
              var createBeforeAfterNodeSetter;
              WrappedRange = function(range3) {
                if (!range3) {
                  throw module2.createError("WrappedRange: Range must be specified");
                }
                this.nativeRange = range3;
                updateRangeProperties(this);
              };
              DomRange.createPrototypeRange(WrappedRange, updateNativeRange);
              rangeProto = WrappedRange.prototype;
              rangeProto.selectNode = function(node2) {
                this.nativeRange.selectNode(node2);
                updateRangeProperties(this);
              };
              rangeProto.cloneContents = function() {
                return this.nativeRange.cloneContents();
              };
              rangeProto.surroundContents = function(node2) {
                this.nativeRange.surroundContents(node2);
                updateRangeProperties(this);
              };
              rangeProto.collapse = function(isStart) {
                this.nativeRange.collapse(isStart);
                updateRangeProperties(this);
              };
              rangeProto.cloneRange = function() {
                return new WrappedRange(this.nativeRange.cloneRange());
              };
              rangeProto.refresh = function() {
                updateRangeProperties(this);
              };
              rangeProto.toString = function() {
                return this.nativeRange.toString();
              };
              var testTextNode = document.createTextNode("test");
              getBody2(document).appendChild(testTextNode);
              var range2 = document.createRange();
              range2.setStart(testTextNode, 0);
              range2.setEnd(testTextNode, 0);
              try {
                range2.setStart(testTextNode, 1);
                rangeProto.setStart = function(node2, offset) {
                  this.nativeRange.setStart(node2, offset);
                  updateRangeProperties(this);
                };
                rangeProto.setEnd = function(node2, offset) {
                  this.nativeRange.setEnd(node2, offset);
                  updateRangeProperties(this);
                };
                createBeforeAfterNodeSetter = function(name) {
                  return function(node2) {
                    this.nativeRange[name](node2);
                    updateRangeProperties(this);
                  };
                };
              } catch (ex) {
                rangeProto.setStart = function(node2, offset) {
                  try {
                    this.nativeRange.setStart(node2, offset);
                  } catch (ex2) {
                    this.nativeRange.setEnd(node2, offset);
                    this.nativeRange.setStart(node2, offset);
                  }
                  updateRangeProperties(this);
                };
                rangeProto.setEnd = function(node2, offset) {
                  try {
                    this.nativeRange.setEnd(node2, offset);
                  } catch (ex2) {
                    this.nativeRange.setStart(node2, offset);
                    this.nativeRange.setEnd(node2, offset);
                  }
                  updateRangeProperties(this);
                };
                createBeforeAfterNodeSetter = function(name, oppositeName) {
                  return function(node2) {
                    try {
                      this.nativeRange[name](node2);
                    } catch (ex2) {
                      this.nativeRange[oppositeName](node2);
                      this.nativeRange[name](node2);
                    }
                    updateRangeProperties(this);
                  };
                };
              }
              rangeProto.setStartBefore = createBeforeAfterNodeSetter("setStartBefore", "setEndBefore");
              rangeProto.setStartAfter = createBeforeAfterNodeSetter("setStartAfter", "setEndAfter");
              rangeProto.setEndBefore = createBeforeAfterNodeSetter("setEndBefore", "setStartBefore");
              rangeProto.setEndAfter = createBeforeAfterNodeSetter("setEndAfter", "setStartAfter");
              rangeProto.selectNodeContents = function(node2) {
                this.setStartAndEnd(node2, 0, dom.getNodeLength(node2));
              };
              range2.selectNodeContents(testTextNode);
              range2.setEnd(testTextNode, 3);
              var range22 = document.createRange();
              range22.selectNodeContents(testTextNode);
              range22.setEnd(testTextNode, 4);
              range22.setStart(testTextNode, 2);
              if (range2.compareBoundaryPoints(range2.START_TO_END, range22) == -1 && range2.compareBoundaryPoints(range2.END_TO_START, range22) == 1) {
                rangeProto.compareBoundaryPoints = function(type, range3) {
                  range3 = range3.nativeRange || range3;
                  if (type == range3.START_TO_END) {
                    type = range3.END_TO_START;
                  } else if (type == range3.END_TO_START) {
                    type = range3.START_TO_END;
                  }
                  return this.nativeRange.compareBoundaryPoints(type, range3);
                };
              } else {
                rangeProto.compareBoundaryPoints = function(type, range3) {
                  return this.nativeRange.compareBoundaryPoints(type, range3.nativeRange || range3);
                };
              }
              var el = document.createElement("div");
              el.innerHTML = "123";
              var textNode = el.firstChild;
              var body = getBody2(document);
              body.appendChild(el);
              range2.setStart(textNode, 1);
              range2.setEnd(textNode, 2);
              range2.deleteContents();
              if (textNode.data == "13") {
                rangeProto.deleteContents = function() {
                  this.nativeRange.deleteContents();
                  updateRangeProperties(this);
                };
                rangeProto.extractContents = function() {
                  var frag = this.nativeRange.extractContents();
                  updateRangeProperties(this);
                  return frag;
                };
              } else {
              }
              body.removeChild(el);
              body = null;
              if (util2.isHostMethod(range2, "createContextualFragment")) {
                rangeProto.createContextualFragment = function(fragmentStr) {
                  return this.nativeRange.createContextualFragment(fragmentStr);
                };
              }
              getBody2(document).removeChild(testTextNode);
              rangeProto.getName = function() {
                return "WrappedRange";
              };
              api2.WrappedRange = WrappedRange;
              api2.createNativeRange = function(doc2) {
                doc2 = getContentDocument(doc2, module2, "createNativeRange");
                return doc2.createRange();
              };
            })();
          }
          if (api2.features.implementsTextRange) {
            var getTextRangeContainerElement = function(textRange) {
              var parentEl = textRange.parentElement();
              var range2 = textRange.duplicate();
              range2.collapse(true);
              var startEl = range2.parentElement();
              range2 = textRange.duplicate();
              range2.collapse(false);
              var endEl = range2.parentElement();
              var startEndContainer = startEl == endEl ? startEl : dom.getCommonAncestor(startEl, endEl);
              return startEndContainer == parentEl ? startEndContainer : dom.getCommonAncestor(parentEl, startEndContainer);
            };
            var textRangeIsCollapsed = function(textRange) {
              return textRange.compareEndPoints("StartToEnd", textRange) == 0;
            };
            var getTextRangeBoundaryPosition = function(textRange, wholeRangeContainerElement, isStart, isCollapsed, startInfo) {
              var workingRange = textRange.duplicate();
              workingRange.collapse(isStart);
              var containerElement = workingRange.parentElement();
              if (!dom.isOrIsAncestorOf(wholeRangeContainerElement, containerElement)) {
                containerElement = wholeRangeContainerElement;
              }
              if (!containerElement.canHaveHTML) {
                var pos = new DomPosition(containerElement.parentNode, dom.getNodeIndex(containerElement));
                return {
                  boundaryPosition: pos,
                  nodeInfo: {
                    nodeIndex: pos.offset,
                    containerElement: pos.node
                  }
                };
              }
              var workingNode = dom.getDocument(containerElement).createElement("span");
              if (workingNode.parentNode) {
                dom.removeNode(workingNode);
              }
              var comparison, workingComparisonType = isStart ? "StartToStart" : "StartToEnd";
              var previousNode, nextNode, boundaryPosition, boundaryNode;
              var start = startInfo && startInfo.containerElement == containerElement ? startInfo.nodeIndex : 0;
              var childNodeCount = containerElement.childNodes.length;
              var end = childNodeCount;
              var nodeIndex = end;
              while (true) {
                if (nodeIndex == childNodeCount) {
                  containerElement.appendChild(workingNode);
                } else {
                  containerElement.insertBefore(workingNode, containerElement.childNodes[nodeIndex]);
                }
                workingRange.moveToElementText(workingNode);
                comparison = workingRange.compareEndPoints(workingComparisonType, textRange);
                if (comparison == 0 || start == end) {
                  break;
                } else if (comparison == -1) {
                  if (end == start + 1) {
                    break;
                  } else {
                    start = nodeIndex;
                  }
                } else {
                  end = end == start + 1 ? start : nodeIndex;
                }
                nodeIndex = Math.floor((start + end) / 2);
                containerElement.removeChild(workingNode);
              }
              boundaryNode = workingNode.nextSibling;
              if (comparison == -1 && boundaryNode && isCharacterDataNode(boundaryNode)) {
                workingRange.setEndPoint(isStart ? "EndToStart" : "EndToEnd", textRange);
                var offset;
                if (/[\r\n]/.test(boundaryNode.data)) {
                  var tempRange = workingRange.duplicate();
                  var rangeLength = tempRange.text.replace(/\r\n/g, "\r").length;
                  offset = tempRange.moveStart("character", rangeLength);
                  while ((comparison = tempRange.compareEndPoints("StartToEnd", tempRange)) == -1) {
                    offset++;
                    tempRange.moveStart("character", 1);
                  }
                } else {
                  offset = workingRange.text.length;
                }
                boundaryPosition = new DomPosition(boundaryNode, offset);
              } else {
                previousNode = (isCollapsed || !isStart) && workingNode.previousSibling;
                nextNode = (isCollapsed || isStart) && workingNode.nextSibling;
                if (nextNode && isCharacterDataNode(nextNode)) {
                  boundaryPosition = new DomPosition(nextNode, 0);
                } else if (previousNode && isCharacterDataNode(previousNode)) {
                  boundaryPosition = new DomPosition(previousNode, previousNode.data.length);
                } else {
                  boundaryPosition = new DomPosition(containerElement, dom.getNodeIndex(workingNode));
                }
              }
              dom.removeNode(workingNode);
              return {
                boundaryPosition,
                nodeInfo: {
                  nodeIndex,
                  containerElement
                }
              };
            };
            var createBoundaryTextRange = function(boundaryPosition, isStart) {
              var boundaryNode, boundaryParent, boundaryOffset = boundaryPosition.offset;
              var doc2 = dom.getDocument(boundaryPosition.node);
              var workingNode, childNodes, workingRange = getBody2(doc2).createTextRange();
              var nodeIsDataNode = isCharacterDataNode(boundaryPosition.node);
              if (nodeIsDataNode) {
                boundaryNode = boundaryPosition.node;
                boundaryParent = boundaryNode.parentNode;
              } else {
                childNodes = boundaryPosition.node.childNodes;
                boundaryNode = boundaryOffset < childNodes.length ? childNodes[boundaryOffset] : null;
                boundaryParent = boundaryPosition.node;
              }
              workingNode = doc2.createElement("span");
              workingNode.innerHTML = "&#feff;";
              if (boundaryNode) {
                boundaryParent.insertBefore(workingNode, boundaryNode);
              } else {
                boundaryParent.appendChild(workingNode);
              }
              workingRange.moveToElementText(workingNode);
              workingRange.collapse(!isStart);
              boundaryParent.removeChild(workingNode);
              if (nodeIsDataNode) {
                workingRange[isStart ? "moveStart" : "moveEnd"]("character", boundaryOffset);
              }
              return workingRange;
            };
            WrappedTextRange = function(textRange) {
              this.textRange = textRange;
              this.refresh();
            };
            WrappedTextRange.prototype = new DomRange(document);
            WrappedTextRange.prototype.refresh = function() {
              var start, end, startBoundary;
              var rangeContainerElement = getTextRangeContainerElement(this.textRange);
              if (textRangeIsCollapsed(this.textRange)) {
                end = start = getTextRangeBoundaryPosition(
                  this.textRange,
                  rangeContainerElement,
                  true,
                  true
                ).boundaryPosition;
              } else {
                startBoundary = getTextRangeBoundaryPosition(this.textRange, rangeContainerElement, true, false);
                start = startBoundary.boundaryPosition;
                end = getTextRangeBoundaryPosition(
                  this.textRange,
                  rangeContainerElement,
                  false,
                  false,
                  startBoundary.nodeInfo
                ).boundaryPosition;
              }
              this.setStart(start.node, start.offset);
              this.setEnd(end.node, end.offset);
            };
            WrappedTextRange.prototype.getName = function() {
              return "WrappedTextRange";
            };
            DomRange.copyComparisonConstants(WrappedTextRange);
            var rangeToTextRange = function(range2) {
              if (range2.collapsed) {
                return createBoundaryTextRange(new DomPosition(range2.startContainer, range2.startOffset), true);
              } else {
                var startRange = createBoundaryTextRange(new DomPosition(range2.startContainer, range2.startOffset), true);
                var endRange = createBoundaryTextRange(new DomPosition(range2.endContainer, range2.endOffset), false);
                var textRange = getBody2(DomRange.getRangeDocument(range2)).createTextRange();
                textRange.setEndPoint("StartToStart", startRange);
                textRange.setEndPoint("EndToEnd", endRange);
                return textRange;
              }
            };
            WrappedTextRange.rangeToTextRange = rangeToTextRange;
            WrappedTextRange.prototype.toTextRange = function() {
              return rangeToTextRange(this);
            };
            api2.WrappedTextRange = WrappedTextRange;
            if (!api2.features.implementsDomRange || api2.config.preferTextRange) {
              var globalObj = (function(f) {
                return f("return this;")();
              })(Function);
              if (typeof globalObj.Range == "undefined") {
                globalObj.Range = WrappedTextRange;
              }
              api2.createNativeRange = function(doc2) {
                doc2 = getContentDocument(doc2, module2, "createNativeRange");
                return getBody2(doc2).createTextRange();
              };
              api2.WrappedRange = WrappedTextRange;
            }
          }
          api2.createRange = function(doc2) {
            doc2 = getContentDocument(doc2, module2, "createRange");
            return new api2.WrappedRange(api2.createNativeRange(doc2));
          };
          api2.createRangyRange = function(doc2) {
            doc2 = getContentDocument(doc2, module2, "createRangyRange");
            return new DomRange(doc2);
          };
          util2.createAliasForDeprecatedMethod(api2, "createIframeRange", "createRange");
          util2.createAliasForDeprecatedMethod(api2, "createIframeRangyRange", "createRangyRange");
          api2.addShimListener(function(win) {
            var doc2 = win.document;
            if (typeof doc2.createRange == "undefined") {
              doc2.createRange = function() {
                return api2.createRange(doc2);
              };
            }
            doc2 = win = null;
          });
        });
        api.createCoreModule("WrappedSelection", ["DomRange", "WrappedRange"], function(api2, module2) {
          api2.config.checkSelectionRanges = true;
          var BOOLEAN = "boolean";
          var NUMBER = "number";
          var dom = api2.dom;
          var util2 = api2.util;
          var isHostMethod2 = util2.isHostMethod;
          var DomRange = api2.DomRange;
          var WrappedRange = api2.WrappedRange;
          var DOMException = api2.DOMException;
          var DomPosition = dom.DomPosition;
          var getNativeSelection;
          var selectionIsCollapsed;
          var features = api2.features;
          var CONTROL = "Control";
          var getDocument = dom.getDocument;
          var getBody2 = dom.getBody;
          var rangesEqual = DomRange.rangesEqual;
          function isDirectionBackward(dir) {
            return typeof dir == "string" ? /^backward(s)?$/i.test(dir) : !!dir;
          }
          function getWindow(win, methodName) {
            if (!win) {
              return window;
            } else if (dom.isWindow(win)) {
              return win;
            } else if (win instanceof WrappedSelection) {
              return win.win;
            } else {
              var doc2 = dom.getContentDocument(win, module2, methodName);
              return dom.getWindow(doc2);
            }
          }
          function getWinSelection(winParam) {
            return getWindow(winParam, "getWinSelection").getSelection();
          }
          function getDocSelection(winParam) {
            return getWindow(winParam, "getDocSelection").document.selection;
          }
          function winSelectionIsBackward(sel) {
            var backward = false;
            if (sel.anchorNode) {
              backward = dom.comparePoints(sel.anchorNode, sel.anchorOffset, sel.focusNode, sel.focusOffset) == 1;
            }
            return backward;
          }
          var implementsWinGetSelection = isHostMethod2(window, "getSelection"), implementsDocSelection = util2.isHostObject(document, "selection");
          features.implementsWinGetSelection = implementsWinGetSelection;
          features.implementsDocSelection = implementsDocSelection;
          var useDocumentSelection = implementsDocSelection && (!implementsWinGetSelection || api2.config.preferTextRange);
          if (useDocumentSelection) {
            getNativeSelection = getDocSelection;
            api2.isSelectionValid = function(winParam) {
              var doc2 = getWindow(winParam, "isSelectionValid").document, nativeSel = doc2.selection;
              return nativeSel.type != "None" || getDocument(nativeSel.createRange().parentElement()) == doc2;
            };
          } else if (implementsWinGetSelection) {
            getNativeSelection = getWinSelection;
            api2.isSelectionValid = function() {
              return true;
            };
          } else {
            module2.fail("Neither document.selection or window.getSelection() detected.");
            return false;
          }
          api2.getNativeSelection = getNativeSelection;
          var testSelection = getNativeSelection();
          if (!testSelection) {
            module2.fail("Native selection was null (possibly issue 138?)");
            return false;
          }
          var testRange = api2.createNativeRange(document);
          var body = getBody2(document);
          var selectionHasAnchorAndFocus = util2.areHostProperties(
            testSelection,
            ["anchorNode", "focusNode", "anchorOffset", "focusOffset"]
          );
          features.selectionHasAnchorAndFocus = selectionHasAnchorAndFocus;
          var selectionHasExtend = isHostMethod2(testSelection, "extend");
          features.selectionHasExtend = selectionHasExtend;
          var selectionHasSetBaseAndExtent = isHostMethod2(testSelection, "setBaseAndExtent");
          features.selectionHasSetBaseAndExtent = selectionHasSetBaseAndExtent;
          var selectionHasRangeCount = typeof testSelection.rangeCount == NUMBER;
          features.selectionHasRangeCount = selectionHasRangeCount;
          var selectionSupportsMultipleRanges = false;
          var collapsedNonEditableSelectionsSupported = true;
          var addRangeBackwardToNative = selectionHasExtend ? function(nativeSelection, range2) {
            var doc2 = DomRange.getRangeDocument(range2);
            var endRange = api2.createRange(doc2);
            endRange.collapseToPoint(range2.endContainer, range2.endOffset);
            nativeSelection.addRange(getNativeRange(endRange));
            nativeSelection.extend(range2.startContainer, range2.startOffset);
          } : null;
          if (util2.areHostMethods(testSelection, ["addRange", "getRangeAt", "removeAllRanges"]) && typeof testSelection.rangeCount == NUMBER && features.implementsDomRange) {
            (function() {
              var sel = window.getSelection();
              if (sel) {
                var originalSelectionRangeCount = sel.rangeCount;
                var selectionHasMultipleRanges = originalSelectionRangeCount > 1;
                var originalSelectionRanges = [];
                var originalSelectionBackward = winSelectionIsBackward(sel);
                for (var i = 0; i < originalSelectionRangeCount; ++i) {
                  originalSelectionRanges[i] = sel.getRangeAt(i);
                }
                var testEl = dom.createTestElement(document, "", false);
                var textNode = testEl.appendChild(document.createTextNode("\xA0\xA0\xA0"));
                var r1 = document.createRange();
                r1.setStart(textNode, 1);
                r1.collapse(true);
                sel.removeAllRanges();
                sel.addRange(r1);
                collapsedNonEditableSelectionsSupported = sel.rangeCount == 1;
                sel.removeAllRanges();
                if (!selectionHasMultipleRanges) {
                  var chromeMatch = window.navigator.appVersion.match(/Chrome\/(.*?) /);
                  if (chromeMatch && parseInt(chromeMatch[1]) >= 36) {
                    selectionSupportsMultipleRanges = false;
                  } else {
                    var r2 = r1.cloneRange();
                    r1.setStart(textNode, 0);
                    r2.setEnd(textNode, 3);
                    r2.setStart(textNode, 2);
                    sel.addRange(r1);
                    sel.addRange(r2);
                    selectionSupportsMultipleRanges = sel.rangeCount == 2;
                  }
                }
                dom.removeNode(testEl);
                sel.removeAllRanges();
                for (i = 0; i < originalSelectionRangeCount; ++i) {
                  if (i == 0 && originalSelectionBackward) {
                    if (addRangeBackwardToNative) {
                      addRangeBackwardToNative(sel, originalSelectionRanges[i]);
                    } else {
                      api2.warn("Rangy initialization: original selection was backwards but selection has been restored forwards because the browser does not support Selection.extend");
                      sel.addRange(originalSelectionRanges[i]);
                    }
                  } else {
                    sel.addRange(originalSelectionRanges[i]);
                  }
                }
              }
            })();
          }
          features.selectionSupportsMultipleRanges = selectionSupportsMultipleRanges;
          features.collapsedNonEditableSelectionsSupported = collapsedNonEditableSelectionsSupported;
          var implementsControlRange = false, testControlRange;
          if (body && isHostMethod2(body, "createControlRange")) {
            testControlRange = body.createControlRange();
            if (util2.areHostProperties(testControlRange, ["item", "add"])) {
              implementsControlRange = true;
            }
          }
          features.implementsControlRange = implementsControlRange;
          if (selectionHasAnchorAndFocus) {
            selectionIsCollapsed = function(sel) {
              return sel.anchorNode === sel.focusNode && sel.anchorOffset === sel.focusOffset;
            };
          } else {
            selectionIsCollapsed = function(sel) {
              return sel.rangeCount ? sel.getRangeAt(sel.rangeCount - 1).collapsed : false;
            };
          }
          function updateAnchorAndFocusFromRange(sel, range2, backward) {
            var anchorPrefix = backward ? "end" : "start", focusPrefix = backward ? "start" : "end";
            sel.anchorNode = range2[anchorPrefix + "Container"];
            sel.anchorOffset = range2[anchorPrefix + "Offset"];
            sel.focusNode = range2[focusPrefix + "Container"];
            sel.focusOffset = range2[focusPrefix + "Offset"];
          }
          function updateAnchorAndFocusFromNativeSelection(sel) {
            var nativeSel = sel.nativeSelection;
            sel.anchorNode = nativeSel.anchorNode;
            sel.anchorOffset = nativeSel.anchorOffset;
            sel.focusNode = nativeSel.focusNode;
            sel.focusOffset = nativeSel.focusOffset;
          }
          function updateEmptySelection(sel) {
            sel.anchorNode = sel.focusNode = null;
            sel.anchorOffset = sel.focusOffset = 0;
            sel.rangeCount = 0;
            sel.isCollapsed = true;
            sel._ranges.length = 0;
            updateType(sel);
          }
          function updateType(sel) {
            sel.type = sel.rangeCount == 0 ? "None" : selectionIsCollapsed(sel) ? "Caret" : "Range";
          }
          function getNativeRange(range2) {
            var nativeRange;
            if (range2 instanceof DomRange) {
              nativeRange = api2.createNativeRange(range2.getDocument());
              nativeRange.setEnd(range2.endContainer, range2.endOffset);
              nativeRange.setStart(range2.startContainer, range2.startOffset);
            } else if (range2 instanceof WrappedRange) {
              nativeRange = range2.nativeRange;
            } else if (features.implementsDomRange && range2 instanceof dom.getWindow(range2.startContainer).Range) {
              nativeRange = range2;
            }
            return nativeRange;
          }
          function rangeContainsSingleElement(rangeNodes) {
            if (!rangeNodes.length || rangeNodes[0].nodeType != 1) {
              return false;
            }
            for (var i = 1, len = rangeNodes.length; i < len; ++i) {
              if (!dom.isAncestorOf(rangeNodes[0], rangeNodes[i])) {
                return false;
              }
            }
            return true;
          }
          function getSingleElementFromRange(range2) {
            var nodes = range2.getNodes();
            if (!rangeContainsSingleElement(nodes)) {
              throw module2.createError("getSingleElementFromRange: range " + range2.inspect() + " did not consist of a single element");
            }
            return nodes[0];
          }
          function isTextRange2(range2) {
            return !!range2 && typeof range2.text != "undefined";
          }
          function updateFromTextRange(sel, range2) {
            var wrappedRange = new WrappedRange(range2);
            sel._ranges = [wrappedRange];
            updateAnchorAndFocusFromRange(sel, wrappedRange, false);
            sel.rangeCount = 1;
            sel.isCollapsed = wrappedRange.collapsed;
            updateType(sel);
          }
          function updateControlSelection(sel) {
            sel._ranges.length = 0;
            if (sel.docSelection.type == "None") {
              updateEmptySelection(sel);
            } else {
              var controlRange = sel.docSelection.createRange();
              if (isTextRange2(controlRange)) {
                updateFromTextRange(sel, controlRange);
              } else {
                sel.rangeCount = controlRange.length;
                var range2, doc2 = getDocument(controlRange.item(0));
                for (var i = 0; i < sel.rangeCount; ++i) {
                  range2 = api2.createRange(doc2);
                  range2.selectNode(controlRange.item(i));
                  sel._ranges.push(range2);
                }
                sel.isCollapsed = sel.rangeCount == 1 && sel._ranges[0].collapsed;
                updateAnchorAndFocusFromRange(sel, sel._ranges[sel.rangeCount - 1], false);
                updateType(sel);
              }
            }
          }
          function addRangeToControlSelection(sel, range2) {
            var controlRange = sel.docSelection.createRange();
            var rangeElement = getSingleElementFromRange(range2);
            var doc2 = getDocument(controlRange.item(0));
            var newControlRange = getBody2(doc2).createControlRange();
            for (var i = 0, len = controlRange.length; i < len; ++i) {
              newControlRange.add(controlRange.item(i));
            }
            try {
              newControlRange.add(rangeElement);
            } catch (ex) {
              throw module2.createError("addRange(): Element within the specified Range could not be added to control selection (does it have layout?)");
            }
            newControlRange.select();
            updateControlSelection(sel);
          }
          var getSelectionRangeAt;
          if (isHostMethod2(testSelection, "getRangeAt")) {
            getSelectionRangeAt = function(sel, index) {
              try {
                return sel.getRangeAt(index);
              } catch (ex) {
                return null;
              }
            };
          } else if (selectionHasAnchorAndFocus) {
            getSelectionRangeAt = function(sel) {
              var doc2 = getDocument(sel.anchorNode);
              var range2 = api2.createRange(doc2);
              range2.setStartAndEnd(sel.anchorNode, sel.anchorOffset, sel.focusNode, sel.focusOffset);
              if (range2.collapsed !== this.isCollapsed) {
                range2.setStartAndEnd(sel.focusNode, sel.focusOffset, sel.anchorNode, sel.anchorOffset);
              }
              return range2;
            };
          }
          function WrappedSelection(selection2, docSelection, win) {
            this.nativeSelection = selection2;
            this.docSelection = docSelection;
            this._ranges = [];
            this.win = win;
            this.refresh();
          }
          WrappedSelection.prototype = api2.selectionPrototype;
          function deleteProperties(sel) {
            sel.win = sel.anchorNode = sel.focusNode = sel._ranges = null;
            sel.rangeCount = sel.anchorOffset = sel.focusOffset = 0;
            sel.detached = true;
            updateType(sel);
          }
          var cachedRangySelections = [];
          function actOnCachedSelection(win, action) {
            var i = cachedRangySelections.length, cached, sel;
            while (i--) {
              cached = cachedRangySelections[i];
              sel = cached.selection;
              if (action == "deleteAll") {
                deleteProperties(sel);
              } else if (cached.win == win) {
                if (action == "delete") {
                  cachedRangySelections.splice(i, 1);
                  return true;
                } else {
                  return sel;
                }
              }
            }
            if (action == "deleteAll") {
              cachedRangySelections.length = 0;
            }
            return null;
          }
          var getSelection = function(win) {
            if (win && win instanceof WrappedSelection) {
              win.refresh();
              return win;
            }
            win = getWindow(win, "getNativeSelection");
            var sel = actOnCachedSelection(win);
            var nativeSel = getNativeSelection(win), docSel = implementsDocSelection ? getDocSelection(win) : null;
            if (sel) {
              sel.nativeSelection = nativeSel;
              sel.docSelection = docSel;
              sel.refresh();
            } else {
              sel = new WrappedSelection(nativeSel, docSel, win);
              cachedRangySelections.push({ win, selection: sel });
            }
            return sel;
          };
          api2.getSelection = getSelection;
          util2.createAliasForDeprecatedMethod(api2, "getIframeSelection", "getSelection");
          var selProto = WrappedSelection.prototype;
          function createControlSelection(sel, ranges) {
            var doc2 = getDocument(ranges[0].startContainer);
            var controlRange = getBody2(doc2).createControlRange();
            for (var i = 0, el, len = ranges.length; i < len; ++i) {
              el = getSingleElementFromRange(ranges[i]);
              try {
                controlRange.add(el);
              } catch (ex) {
                throw module2.createError("setRanges(): Element within one of the specified Ranges could not be added to control selection (does it have layout?)");
              }
            }
            controlRange.select();
            updateControlSelection(sel);
          }
          if (!useDocumentSelection && selectionHasAnchorAndFocus && util2.areHostMethods(testSelection, ["removeAllRanges", "addRange"])) {
            selProto.removeAllRanges = function() {
              this.nativeSelection.removeAllRanges();
              updateEmptySelection(this);
            };
            var addRangeBackward = function(sel, range2) {
              addRangeBackwardToNative(sel.nativeSelection, range2);
              sel.refresh();
            };
            if (selectionHasRangeCount) {
              selProto.addRange = function(range2, direction) {
                if (implementsControlRange && implementsDocSelection && this.docSelection.type == CONTROL) {
                  addRangeToControlSelection(this, range2);
                } else {
                  if (isDirectionBackward(direction) && selectionHasExtend) {
                    addRangeBackward(this, range2);
                  } else {
                    var previousRangeCount;
                    if (selectionSupportsMultipleRanges) {
                      previousRangeCount = this.rangeCount;
                    } else {
                      this.removeAllRanges();
                      previousRangeCount = 0;
                    }
                    var clonedNativeRange = getNativeRange(range2).cloneRange();
                    try {
                      this.nativeSelection.addRange(clonedNativeRange);
                    } catch (ex) {
                    }
                    this.rangeCount = this.nativeSelection.rangeCount;
                    if (this.rangeCount == previousRangeCount + 1) {
                      if (api2.config.checkSelectionRanges) {
                        var nativeRange = getSelectionRangeAt(this.nativeSelection, this.rangeCount - 1);
                        if (nativeRange && !rangesEqual(nativeRange, range2)) {
                          range2 = new WrappedRange(nativeRange);
                        }
                      }
                      this._ranges[this.rangeCount - 1] = range2;
                      updateAnchorAndFocusFromRange(this, range2, selectionIsBackward(this.nativeSelection));
                      this.isCollapsed = selectionIsCollapsed(this);
                      updateType(this);
                    } else {
                      this.refresh();
                    }
                  }
                }
              };
            } else {
              selProto.addRange = function(range2, direction) {
                if (isDirectionBackward(direction) && selectionHasExtend) {
                  addRangeBackward(this, range2);
                } else {
                  this.nativeSelection.addRange(getNativeRange(range2));
                  this.refresh();
                }
              };
            }
            selProto.setRanges = function(ranges) {
              if (implementsControlRange && implementsDocSelection && ranges.length > 1) {
                createControlSelection(this, ranges);
              } else {
                this.removeAllRanges();
                for (var i = 0, len = ranges.length; i < len; ++i) {
                  this.addRange(ranges[i]);
                }
              }
            };
          } else if (isHostMethod2(testSelection, "empty") && isHostMethod2(testRange, "select") && implementsControlRange && useDocumentSelection) {
            selProto.removeAllRanges = function() {
              try {
                this.docSelection.empty();
                if (this.docSelection.type != "None") {
                  var doc2;
                  if (this.anchorNode) {
                    doc2 = getDocument(this.anchorNode);
                  } else if (this.docSelection.type == CONTROL) {
                    var controlRange = this.docSelection.createRange();
                    if (controlRange.length) {
                      doc2 = getDocument(controlRange.item(0));
                    }
                  }
                  if (doc2) {
                    var textRange = getBody2(doc2).createTextRange();
                    textRange.select();
                    this.docSelection.empty();
                  }
                }
              } catch (ex) {
              }
              updateEmptySelection(this);
            };
            selProto.addRange = function(range2) {
              if (this.docSelection.type == CONTROL) {
                addRangeToControlSelection(this, range2);
              } else {
                api2.WrappedTextRange.rangeToTextRange(range2).select();
                this._ranges[0] = range2;
                this.rangeCount = 1;
                this.isCollapsed = this._ranges[0].collapsed;
                updateAnchorAndFocusFromRange(this, range2, false);
                updateType(this);
              }
            };
            selProto.setRanges = function(ranges) {
              this.removeAllRanges();
              var rangeCount = ranges.length;
              if (rangeCount > 1) {
                createControlSelection(this, ranges);
              } else if (rangeCount) {
                this.addRange(ranges[0]);
              }
            };
          } else {
            module2.fail("No means of selecting a Range or TextRange was found");
            return false;
          }
          selProto.getRangeAt = function(index) {
            if (index < 0 || index >= this.rangeCount) {
              throw new DOMException("INDEX_SIZE_ERR");
            } else {
              return this._ranges[index].cloneRange();
            }
          };
          var refreshSelection;
          if (useDocumentSelection) {
            refreshSelection = function(sel) {
              var range2;
              if (api2.isSelectionValid(sel.win)) {
                range2 = sel.docSelection.createRange();
              } else {
                range2 = getBody2(sel.win.document).createTextRange();
                range2.collapse(true);
              }
              if (sel.docSelection.type == CONTROL) {
                updateControlSelection(sel);
              } else if (isTextRange2(range2)) {
                updateFromTextRange(sel, range2);
              } else {
                updateEmptySelection(sel);
              }
            };
          } else if (isHostMethod2(testSelection, "getRangeAt") && typeof testSelection.rangeCount == NUMBER) {
            refreshSelection = function(sel) {
              if (implementsControlRange && implementsDocSelection && sel.docSelection.type == CONTROL) {
                updateControlSelection(sel);
              } else {
                sel._ranges.length = sel.rangeCount = sel.nativeSelection.rangeCount;
                if (sel.rangeCount) {
                  for (var i = 0, len = sel.rangeCount; i < len; ++i) {
                    sel._ranges[i] = new api2.WrappedRange(sel.nativeSelection.getRangeAt(i));
                  }
                  updateAnchorAndFocusFromRange(sel, sel._ranges[sel.rangeCount - 1], selectionIsBackward(sel.nativeSelection));
                  sel.isCollapsed = selectionIsCollapsed(sel);
                  updateType(sel);
                } else {
                  updateEmptySelection(sel);
                }
              }
            };
          } else if (selectionHasAnchorAndFocus && typeof testSelection.isCollapsed == BOOLEAN && typeof testRange.collapsed == BOOLEAN && features.implementsDomRange) {
            refreshSelection = function(sel) {
              var range2, nativeSel = sel.nativeSelection;
              if (nativeSel.anchorNode) {
                range2 = getSelectionRangeAt(nativeSel, 0);
                sel._ranges = [range2];
                sel.rangeCount = 1;
                updateAnchorAndFocusFromNativeSelection(sel);
                sel.isCollapsed = selectionIsCollapsed(sel);
                updateType(sel);
              } else {
                updateEmptySelection(sel);
              }
            };
          } else {
            module2.fail("No means of obtaining a Range or TextRange from the user's selection was found");
            return false;
          }
          selProto.refresh = function(checkForChanges) {
            var oldRanges = checkForChanges ? this._ranges.slice(0) : null;
            var oldAnchorNode = this.anchorNode, oldAnchorOffset = this.anchorOffset;
            refreshSelection(this);
            if (checkForChanges) {
              var i = oldRanges.length;
              if (i != this._ranges.length) {
                return true;
              }
              if (this.anchorNode != oldAnchorNode || this.anchorOffset != oldAnchorOffset) {
                return true;
              }
              while (i--) {
                if (!rangesEqual(oldRanges[i], this._ranges[i])) {
                  return true;
                }
              }
              return false;
            }
          };
          var removeRangeManually = function(sel, range2) {
            var ranges = sel.getAllRanges();
            sel.removeAllRanges();
            for (var i = 0, len = ranges.length; i < len; ++i) {
              if (!rangesEqual(range2, ranges[i])) {
                sel.addRange(ranges[i]);
              }
            }
            if (!sel.rangeCount) {
              updateEmptySelection(sel);
            }
          };
          if (implementsControlRange && implementsDocSelection) {
            selProto.removeRange = function(range2) {
              if (this.docSelection.type == CONTROL) {
                var controlRange = this.docSelection.createRange();
                var rangeElement = getSingleElementFromRange(range2);
                var doc2 = getDocument(controlRange.item(0));
                var newControlRange = getBody2(doc2).createControlRange();
                var el, removed = false;
                for (var i = 0, len = controlRange.length; i < len; ++i) {
                  el = controlRange.item(i);
                  if (el !== rangeElement || removed) {
                    newControlRange.add(controlRange.item(i));
                  } else {
                    removed = true;
                  }
                }
                newControlRange.select();
                updateControlSelection(this);
              } else {
                removeRangeManually(this, range2);
              }
            };
          } else {
            selProto.removeRange = function(range2) {
              removeRangeManually(this, range2);
            };
          }
          var selectionIsBackward;
          if (!useDocumentSelection && selectionHasAnchorAndFocus && features.implementsDomRange) {
            selectionIsBackward = winSelectionIsBackward;
            selProto.isBackward = function() {
              return selectionIsBackward(this);
            };
          } else {
            selectionIsBackward = selProto.isBackward = function() {
              return false;
            };
          }
          selProto.isBackwards = selProto.isBackward;
          selProto.toString = function() {
            var rangeTexts = [];
            for (var i = 0, len = this.rangeCount; i < len; ++i) {
              rangeTexts[i] = "" + this._ranges[i];
            }
            return rangeTexts.join("");
          };
          function assertNodeInSameDocument(sel, node2) {
            if (sel.win.document != getDocument(node2)) {
              throw new DOMException("WRONG_DOCUMENT_ERR");
            }
          }
          function assertValidOffset(node2, offset) {
            if (offset < 0 || offset > (dom.isCharacterDataNode(node2) ? node2.length : node2.childNodes.length)) {
              throw new DOMException("INDEX_SIZE_ERR");
            }
          }
          selProto.collapse = function(node2, offset) {
            assertNodeInSameDocument(this, node2);
            var range2 = api2.createRange(node2);
            range2.collapseToPoint(node2, offset);
            this.setSingleRange(range2);
            this.isCollapsed = true;
          };
          selProto.collapseToStart = function() {
            if (this.rangeCount) {
              var range2 = this._ranges[0];
              this.collapse(range2.startContainer, range2.startOffset);
            } else {
              throw new DOMException("INVALID_STATE_ERR");
            }
          };
          selProto.collapseToEnd = function() {
            if (this.rangeCount) {
              var range2 = this._ranges[this.rangeCount - 1];
              this.collapse(range2.endContainer, range2.endOffset);
            } else {
              throw new DOMException("INVALID_STATE_ERR");
            }
          };
          selProto.selectAllChildren = function(node2) {
            assertNodeInSameDocument(this, node2);
            var range2 = api2.createRange(node2);
            range2.selectNodeContents(node2);
            this.setSingleRange(range2);
          };
          if (selectionHasSetBaseAndExtent) {
            selProto.setBaseAndExtent = function(anchorNode, anchorOffset, focusNode, focusOffset) {
              this.nativeSelection.setBaseAndExtent(anchorNode, anchorOffset, focusNode, focusOffset);
              this.refresh();
            };
          } else if (selectionHasExtend) {
            selProto.setBaseAndExtent = function(anchorNode, anchorOffset, focusNode, focusOffset) {
              assertValidOffset(anchorNode, anchorOffset);
              assertValidOffset(focusNode, focusOffset);
              assertNodeInSameDocument(this, anchorNode);
              assertNodeInSameDocument(this, focusNode);
              var range2 = api2.createRange(node);
              var isBackwards = dom.comparePoints(anchorNode, anchorOffset, focusNode, focusOffset) == -1;
              if (isBackwards) {
                range2.setStartAndEnd(focusNode, focusOffset, anchorNode, anchorOffset);
              } else {
                range2.setStartAndEnd(anchorNode, anchorOffset, focusNode, focusOffset);
              }
              this.setSingleRange(range2, isBackwards);
            };
          }
          selProto.deleteFromDocument = function() {
            if (implementsControlRange && implementsDocSelection && this.docSelection.type == CONTROL) {
              var controlRange = this.docSelection.createRange();
              var element;
              while (controlRange.length) {
                element = controlRange.item(0);
                controlRange.remove(element);
                dom.removeNode(element);
              }
              this.refresh();
            } else if (this.rangeCount) {
              var ranges = this.getAllRanges();
              if (ranges.length) {
                this.removeAllRanges();
                for (var i = 0, len = ranges.length; i < len; ++i) {
                  ranges[i].deleteContents();
                }
                this.addRange(ranges[len - 1]);
              }
            }
          };
          selProto.eachRange = function(func, returnValue) {
            for (var i = 0, len = this._ranges.length; i < len; ++i) {
              if (func(this.getRangeAt(i))) {
                return returnValue;
              }
            }
          };
          selProto.getAllRanges = function() {
            var ranges = [];
            this.eachRange(function(range2) {
              ranges.push(range2);
            });
            return ranges;
          };
          selProto.setSingleRange = function(range2, direction) {
            this.removeAllRanges();
            this.addRange(range2, direction);
          };
          selProto.callMethodOnEachRange = function(methodName, params) {
            var results = [];
            this.eachRange(function(range2) {
              results.push(range2[methodName].apply(range2, params || []));
            });
            return results;
          };
          function createStartOrEndSetter(isStart) {
            return function(node2, offset) {
              var range2;
              if (this.rangeCount) {
                range2 = this.getRangeAt(0);
                range2["set" + (isStart ? "Start" : "End")](node2, offset);
              } else {
                range2 = api2.createRange(this.win.document);
                range2.setStartAndEnd(node2, offset);
              }
              this.setSingleRange(range2, this.isBackward());
            };
          }
          selProto.setStart = createStartOrEndSetter(true);
          selProto.setEnd = createStartOrEndSetter(false);
          api2.rangePrototype.select = function(direction) {
            getSelection(this.getDocument()).setSingleRange(this, direction);
          };
          selProto.changeEachRange = function(func) {
            var ranges = [];
            var backward = this.isBackward();
            this.eachRange(function(range2) {
              func(range2);
              ranges.push(range2);
            });
            this.removeAllRanges();
            if (backward && ranges.length == 1) {
              this.addRange(ranges[0], "backward");
            } else {
              this.setRanges(ranges);
            }
          };
          selProto.containsNode = function(node2, allowPartial) {
            return this.eachRange(function(range2) {
              return range2.containsNode(node2, allowPartial);
            }, true) || false;
          };
          selProto.getBookmark = function(containerNode) {
            return {
              backward: this.isBackward(),
              rangeBookmarks: this.callMethodOnEachRange("getBookmark", [containerNode])
            };
          };
          selProto.moveToBookmark = function(bookmark) {
            var selRanges = [];
            for (var i = 0, rangeBookmark, range2; rangeBookmark = bookmark.rangeBookmarks[i++]; ) {
              range2 = api2.createRange(this.win);
              range2.moveToBookmark(rangeBookmark);
              selRanges.push(range2);
            }
            if (bookmark.backward) {
              this.setSingleRange(selRanges[0], "backward");
            } else {
              this.setRanges(selRanges);
            }
          };
          selProto.saveRanges = function() {
            return {
              backward: this.isBackward(),
              ranges: this.callMethodOnEachRange("cloneRange")
            };
          };
          selProto.restoreRanges = function(selRanges) {
            this.removeAllRanges();
            for (var i = 0, range2; range2 = selRanges.ranges[i]; ++i) {
              this.addRange(range2, selRanges.backward && i == 0);
            }
          };
          selProto.toHtml = function() {
            var rangeHtmls = [];
            this.eachRange(function(range2) {
              rangeHtmls.push(DomRange.toHtml(range2));
            });
            return rangeHtmls.join("");
          };
          if (features.implementsTextRange) {
            selProto.getNativeTextRange = function() {
              var sel, textRange;
              if (sel = this.docSelection) {
                var range2 = sel.createRange();
                if (isTextRange2(range2)) {
                  return range2;
                } else {
                  throw module2.createError("getNativeTextRange: selection is a control selection");
                }
              } else if (this.rangeCount > 0) {
                return api2.WrappedTextRange.rangeToTextRange(this.getRangeAt(0));
              } else {
                throw module2.createError("getNativeTextRange: selection contains no range");
              }
            };
          }
          function inspect(sel) {
            var rangeInspects = [];
            var anchor = new DomPosition(sel.anchorNode, sel.anchorOffset);
            var focus = new DomPosition(sel.focusNode, sel.focusOffset);
            var name = typeof sel.getName == "function" ? sel.getName() : "Selection";
            if (typeof sel.rangeCount != "undefined") {
              for (var i = 0, len = sel.rangeCount; i < len; ++i) {
                rangeInspects[i] = DomRange.inspect(sel.getRangeAt(i));
              }
            }
            return "[" + name + "(Ranges: " + rangeInspects.join(", ") + ")(anchor: " + anchor.inspect() + ", focus: " + focus.inspect() + "]";
          }
          selProto.getName = function() {
            return "WrappedSelection";
          };
          selProto.inspect = function() {
            return inspect(this);
          };
          selProto.detach = function() {
            actOnCachedSelection(this.win, "delete");
            deleteProperties(this);
          };
          WrappedSelection.detachAll = function() {
            actOnCachedSelection(null, "deleteAll");
          };
          WrappedSelection.inspect = inspect;
          WrappedSelection.isDirectionBackward = isDirectionBackward;
          api2.Selection = WrappedSelection;
          api2.selectionPrototype = selProto;
          api2.addShimListener(function(win) {
            if (typeof win.getSelection == "undefined") {
              win.getSelection = function() {
                return getSelection(win);
              };
            }
            win = null;
          });
        });
        var docReady = false;
        var loadHandler = function(e) {
          if (!docReady) {
            docReady = true;
            if (!api.initialized && api.config.autoInitialize) {
              init();
            }
          }
        };
        if (isBrowser) {
          if (document.readyState == "complete") {
            loadHandler();
          } else {
            if (isHostMethod(document, "addEventListener")) {
              document.addEventListener("DOMContentLoaded", loadHandler, false);
            }
            addListener(window, "load", loadHandler);
          }
        }
        return api;
      }, exports);
    }
  });

  // node_modules/rangy/lib/rangy-textrange.js
  var require_rangy_textrange = __commonJS({
    "node_modules/rangy/lib/rangy-textrange.js"(exports, module) {
      (function(factory, root2) {
        if (typeof define == "function" && define.amd) {
          define(["./rangy-core"], factory);
        } else if (typeof module != "undefined" && typeof exports == "object") {
          module.exports = factory(require_rangy_core());
        } else {
          factory(root2.rangy);
        }
      })(function(rangy4) {
        rangy4.createModule("TextRange", ["WrappedSelection"], function(api, module2) {
          var UNDEF = "undefined";
          var CHARACTER = "character", WORD = "word";
          var dom = api.dom, util = api.util;
          var extend = util.extend;
          var createOptions = util.createOptions;
          var getBody = dom.getBody;
          var spacesRegex = /^[ \t\f\r\n]+$/;
          var spacesMinusLineBreaksRegex = /^[ \t\f\r]+$/;
          var allWhiteSpaceRegex = /^[\t-\r \u0085\u00A0\u1680\u180E\u2000-\u200B\u2028\u2029\u202F\u205F\u3000]+$/;
          var nonLineBreakWhiteSpaceRegex = /^[\t \u00A0\u1680\u180E\u2000-\u200B\u202F\u205F\u3000]+$/;
          var lineBreakRegex = /^[\n-\r\u0085\u2028\u2029]$/;
          var defaultLanguage = "en";
          var isDirectionBackward = api.Selection.isDirectionBackward;
          var trailingSpaceInBlockCollapses = false;
          var trailingSpaceBeforeBrCollapses = false;
          var trailingSpaceBeforeBlockCollapses = false;
          var trailingSpaceBeforeLineBreakInPreLineCollapses = true;
          (function() {
            var el = dom.createTestElement(document, "<p>1 </p><p></p>", true);
            var p = el.firstChild;
            var sel = api.getSelection();
            sel.collapse(p.lastChild, 2);
            sel.setStart(p.firstChild, 0);
            trailingSpaceInBlockCollapses = ("" + sel).length == 1;
            el.innerHTML = "1 <br />";
            sel.collapse(el, 2);
            sel.setStart(el.firstChild, 0);
            trailingSpaceBeforeBrCollapses = ("" + sel).length == 1;
            el.innerHTML = "1 <p>1</p>";
            sel.collapse(el, 2);
            sel.setStart(el.firstChild, 0);
            trailingSpaceBeforeBlockCollapses = ("" + sel).length == 1;
            dom.removeNode(el);
            sel.removeAllRanges();
          })();
          function defaultTokenizer(chars, wordOptions) {
            var word = chars.join(""), result2, tokenRanges = [];
            function createTokenRange(start, end, isWord) {
              tokenRanges.push({ start, end, isWord });
            }
            var lastWordEnd = 0, wordStart, wordEnd;
            while (result2 = wordOptions.wordRegex.exec(word)) {
              wordStart = result2.index;
              wordEnd = wordStart + result2[0].length;
              if (wordStart > lastWordEnd) {
                createTokenRange(lastWordEnd, wordStart, false);
              }
              if (wordOptions.includeTrailingSpace) {
                while (nonLineBreakWhiteSpaceRegex.test(chars[wordEnd])) {
                  ++wordEnd;
                }
              }
              createTokenRange(wordStart, wordEnd, true);
              lastWordEnd = wordEnd;
            }
            if (lastWordEnd < chars.length) {
              createTokenRange(lastWordEnd, chars.length, false);
            }
            return tokenRanges;
          }
          function convertCharRangeToToken(chars, tokenRange) {
            var tokenChars = chars.slice(tokenRange.start, tokenRange.end);
            var token = {
              isWord: tokenRange.isWord,
              chars: tokenChars,
              toString: function() {
                return tokenChars.join("");
              }
            };
            for (var i = 0, len = tokenChars.length; i < len; ++i) {
              tokenChars[i].token = token;
            }
            return token;
          }
          function tokenize(chars, wordOptions, tokenizer2) {
            var tokenRanges = tokenizer2(chars, wordOptions);
            var tokens = [];
            for (var i = 0, tokenRange; tokenRange = tokenRanges[i++]; ) {
              tokens.push(convertCharRangeToToken(chars, tokenRange));
            }
            return tokens;
          }
          var defaultCharacterOptions = {
            includeBlockContentTrailingSpace: true,
            includeSpaceBeforeBr: true,
            includeSpaceBeforeBlock: true,
            includePreLineTrailingSpace: true,
            ignoreCharacters: ""
          };
          function normalizeIgnoredCharacters(ignoredCharacters) {
            var ignoredChars = ignoredCharacters || "";
            var ignoredCharsArray = typeof ignoredChars == "string" ? ignoredChars.split("") : ignoredChars;
            ignoredCharsArray.sort(function(char1, char2) {
              return char1.charCodeAt(0) - char2.charCodeAt(0);
            });
            return ignoredCharsArray.join("").replace(/(.)\1+/g, "$1");
          }
          var defaultCaretCharacterOptions = {
            includeBlockContentTrailingSpace: !trailingSpaceBeforeLineBreakInPreLineCollapses,
            includeSpaceBeforeBr: !trailingSpaceBeforeBrCollapses,
            includeSpaceBeforeBlock: !trailingSpaceBeforeBlockCollapses,
            includePreLineTrailingSpace: true
          };
          var defaultWordOptions = {
            "en": {
              wordRegex: /[a-z0-9]+('[a-z0-9]+)*/gi,
              includeTrailingSpace: false,
              tokenizer: defaultTokenizer
            }
          };
          var defaultFindOptions = {
            caseSensitive: false,
            withinRange: null,
            wholeWordsOnly: false,
            wrap: false,
            direction: "forward",
            wordOptions: null,
            characterOptions: null
          };
          var defaultMoveOptions = {
            wordOptions: null,
            characterOptions: null
          };
          var defaultExpandOptions = {
            wordOptions: null,
            characterOptions: null,
            trim: false,
            trimStart: true,
            trimEnd: true
          };
          var defaultWordIteratorOptions = {
            wordOptions: null,
            characterOptions: null,
            direction: "forward"
          };
          function createWordOptions(options) {
            var lang, defaults;
            if (!options) {
              return defaultWordOptions[defaultLanguage];
            } else {
              lang = options.language || defaultLanguage;
              defaults = {};
              extend(defaults, defaultWordOptions[lang] || defaultWordOptions[defaultLanguage]);
              extend(defaults, options);
              return defaults;
            }
          }
          function createNestedOptions(optionsParam, defaults) {
            var options = createOptions(optionsParam, defaults);
            if (defaults.hasOwnProperty("wordOptions")) {
              options.wordOptions = createWordOptions(options.wordOptions);
            }
            if (defaults.hasOwnProperty("characterOptions")) {
              options.characterOptions = createOptions(options.characterOptions, defaultCharacterOptions);
            }
            return options;
          }
          var getComputedStyleProperty = dom.getComputedStyleProperty;
          var tableCssDisplayBlock;
          (function() {
            var table = document.createElement("table");
            var body = getBody(document);
            body.appendChild(table);
            tableCssDisplayBlock = getComputedStyleProperty(table, "display") == "block";
            body.removeChild(table);
          })();
          var defaultDisplayValueForTag = {
            table: "table",
            caption: "table-caption",
            colgroup: "table-column-group",
            col: "table-column",
            thead: "table-header-group",
            tbody: "table-row-group",
            tfoot: "table-footer-group",
            tr: "table-row",
            td: "table-cell",
            th: "table-cell"
          };
          function getComputedDisplay(el, win) {
            var display = getComputedStyleProperty(el, "display", win);
            var tagName = el.tagName.toLowerCase();
            return display == "block" && tableCssDisplayBlock && defaultDisplayValueForTag.hasOwnProperty(tagName) ? defaultDisplayValueForTag[tagName] : display;
          }
          function isHidden(node2) {
            var ancestors = getAncestorsAndSelf(node2);
            for (var i = 0, len = ancestors.length; i < len; ++i) {
              if (ancestors[i].nodeType == 1 && getComputedDisplay(ancestors[i]) == "none") {
                return true;
              }
            }
            return false;
          }
          function isVisibilityHiddenTextNode(textNode) {
            var el;
            return textNode.nodeType == 3 && (el = textNode.parentNode) && getComputedStyleProperty(el, "visibility") == "hidden";
          }
          function isBlockNode(node2) {
            return node2 && (node2.nodeType == 1 && !/^(inline(-block|-table)?|none)$/.test(getComputedDisplay(node2)) || node2.nodeType == 9 || node2.nodeType == 11);
          }
          function getLastDescendantOrSelf(node2) {
            var lastChild = node2.lastChild;
            return lastChild ? getLastDescendantOrSelf(lastChild) : node2;
          }
          function containsPositions(node2) {
            return dom.isCharacterDataNode(node2) || !/^(area|base|basefont|br|col|frame|hr|img|input|isindex|link|meta|param)$/i.test(node2.nodeName);
          }
          function getAncestors(node2) {
            var ancestors = [];
            while (node2.parentNode) {
              ancestors.unshift(node2.parentNode);
              node2 = node2.parentNode;
            }
            return ancestors;
          }
          function getAncestorsAndSelf(node2) {
            return getAncestors(node2).concat([node2]);
          }
          function nextNodeDescendants(node2) {
            while (node2 && !node2.nextSibling) {
              node2 = node2.parentNode;
            }
            if (!node2) {
              return null;
            }
            return node2.nextSibling;
          }
          function nextNode(node2, excludeChildren) {
            if (!excludeChildren && node2.hasChildNodes()) {
              return node2.firstChild;
            }
            return nextNodeDescendants(node2);
          }
          function previousNode(node2) {
            var previous = node2.previousSibling;
            if (previous) {
              node2 = previous;
              while (node2.hasChildNodes()) {
                node2 = node2.lastChild;
              }
              return node2;
            }
            var parent = node2.parentNode;
            if (parent && parent.nodeType == 1) {
              return parent;
            }
            return null;
          }
          function isWhitespaceNode(node2) {
            if (!node2 || node2.nodeType != 3) {
              return false;
            }
            var text = node2.data;
            if (text === "") {
              return true;
            }
            var parent = node2.parentNode;
            if (!parent || parent.nodeType != 1) {
              return false;
            }
            var computedWhiteSpace = getComputedStyleProperty(node2.parentNode, "whiteSpace");
            return /^[\t\n\r ]+$/.test(text) && /^(normal|nowrap)$/.test(computedWhiteSpace) || /^[\t\r ]+$/.test(text) && computedWhiteSpace == "pre-line";
          }
          function isCollapsedWhitespaceNode(node2) {
            if (node2.data === "") {
              return true;
            }
            if (!isWhitespaceNode(node2)) {
              return false;
            }
            var ancestor = node2.parentNode;
            if (!ancestor) {
              return true;
            }
            if (isHidden(node2)) {
              return true;
            }
            return false;
          }
          function isCollapsedNode(node2) {
            var type = node2.nodeType;
            return type == 7 || type == 8 || isHidden(node2) || /^(script|style)$/i.test(node2.nodeName) || isVisibilityHiddenTextNode(node2) || isCollapsedWhitespaceNode(node2);
          }
          function isIgnoredNode(node2, win) {
            var type = node2.nodeType;
            return type == 7 || type == 8 || type == 1 && getComputedDisplay(node2, win) == "none";
          }
          function Cache() {
            this.store = {};
          }
          Cache.prototype = {
            get: function(key) {
              return this.store.hasOwnProperty(key) ? this.store[key] : null;
            },
            set: function(key, value) {
              return this.store[key] = value;
            }
          };
          var cachedCount = 0, uncachedCount = 0;
          function createCachingGetter(methodName, func, objProperty) {
            return function(args) {
              var cache = this.cache;
              if (cache.hasOwnProperty(methodName)) {
                cachedCount++;
                return cache[methodName];
              } else {
                uncachedCount++;
                var value = func.call(this, objProperty ? this[objProperty] : this, args);
                cache[methodName] = value;
                return value;
              }
            };
          }
          function NodeWrapper(node2, session) {
            this.node = node2;
            this.session = session;
            this.cache = new Cache();
            this.positions = new Cache();
          }
          var nodeProto = {
            getPosition: function(offset) {
              var positions = this.positions;
              return positions.get(offset) || positions.set(offset, new Position(this, offset));
            },
            toString: function() {
              return "[NodeWrapper(" + dom.inspectNode(this.node) + ")]";
            }
          };
          NodeWrapper.prototype = nodeProto;
          var EMPTY = "EMPTY", NON_SPACE = "NON_SPACE", UNCOLLAPSIBLE_SPACE = "UNCOLLAPSIBLE_SPACE", COLLAPSIBLE_SPACE = "COLLAPSIBLE_SPACE", TRAILING_SPACE_BEFORE_BLOCK = "TRAILING_SPACE_BEFORE_BLOCK", TRAILING_SPACE_IN_BLOCK = "TRAILING_SPACE_IN_BLOCK", TRAILING_SPACE_BEFORE_BR = "TRAILING_SPACE_BEFORE_BR", PRE_LINE_TRAILING_SPACE_BEFORE_LINE_BREAK = "PRE_LINE_TRAILING_SPACE_BEFORE_LINE_BREAK", TRAILING_LINE_BREAK_AFTER_BR = "TRAILING_LINE_BREAK_AFTER_BR", INCLUDED_TRAILING_LINE_BREAK_AFTER_BR = "INCLUDED_TRAILING_LINE_BREAK_AFTER_BR";
          extend(nodeProto, {
            isCharacterDataNode: createCachingGetter("isCharacterDataNode", dom.isCharacterDataNode, "node"),
            getNodeIndex: createCachingGetter("nodeIndex", dom.getNodeIndex, "node"),
            getLength: createCachingGetter("nodeLength", dom.getNodeLength, "node"),
            containsPositions: createCachingGetter("containsPositions", containsPositions, "node"),
            isWhitespace: createCachingGetter("isWhitespace", isWhitespaceNode, "node"),
            isCollapsedWhitespace: createCachingGetter("isCollapsedWhitespace", isCollapsedWhitespaceNode, "node"),
            getComputedDisplay: createCachingGetter("computedDisplay", getComputedDisplay, "node"),
            isCollapsed: createCachingGetter("collapsed", isCollapsedNode, "node"),
            isIgnored: createCachingGetter("ignored", isIgnoredNode, "node"),
            next: createCachingGetter("nextPos", nextNode, "node"),
            previous: createCachingGetter("previous", previousNode, "node"),
            getTextNodeInfo: createCachingGetter("textNodeInfo", function(textNode) {
              var spaceRegex = null, collapseSpaces = false;
              var cssWhitespace = getComputedStyleProperty(textNode.parentNode, "whiteSpace");
              var preLine = cssWhitespace == "pre-line";
              if (preLine) {
                spaceRegex = spacesMinusLineBreaksRegex;
                collapseSpaces = true;
              } else if (cssWhitespace == "normal" || cssWhitespace == "nowrap") {
                spaceRegex = spacesRegex;
                collapseSpaces = true;
              }
              return {
                node: textNode,
                text: textNode.data,
                spaceRegex,
                collapseSpaces,
                preLine
              };
            }, "node"),
            hasInnerText: createCachingGetter("hasInnerText", function(el, backward) {
              var session = this.session;
              var posAfterEl = session.getPosition(el.parentNode, this.getNodeIndex() + 1);
              var firstPosInEl = session.getPosition(el, 0);
              var pos = backward ? posAfterEl : firstPosInEl;
              var endPos = backward ? firstPosInEl : posAfterEl;
              while (pos !== endPos) {
                pos.prepopulateChar();
                if (pos.isDefinitelyNonEmpty()) {
                  return true;
                }
                pos = backward ? pos.previousVisible() : pos.nextVisible();
              }
              return false;
            }, "node"),
            isRenderedBlock: createCachingGetter("isRenderedBlock", function(el) {
              var brs = el.getElementsByTagName("br");
              for (var i = 0, len = brs.length; i < len; ++i) {
                if (!isCollapsedNode(brs[i])) {
                  return true;
                }
              }
              return this.hasInnerText();
            }, "node"),
            getTrailingSpace: createCachingGetter("trailingSpace", function(el) {
              if (el.tagName.toLowerCase() == "br") {
                return "";
              } else {
                switch (this.getComputedDisplay()) {
                  case "inline":
                    var child = el.lastChild;
                    while (child) {
                      if (!isIgnoredNode(child)) {
                        return child.nodeType == 1 ? this.session.getNodeWrapper(child).getTrailingSpace() : "";
                      }
                      child = child.previousSibling;
                    }
                    break;
                  case "inline-block":
                  case "inline-table":
                  case "none":
                  case "table-column":
                  case "table-column-group":
                    break;
                  case "table-cell":
                    return "	";
                  default:
                    return this.isRenderedBlock(true) ? "\n" : "";
                }
              }
              return "";
            }, "node"),
            getLeadingSpace: createCachingGetter("leadingSpace", function(el) {
              switch (this.getComputedDisplay()) {
                case "inline":
                case "inline-block":
                case "inline-table":
                case "none":
                case "table-column":
                case "table-column-group":
                case "table-cell":
                  break;
                default:
                  return this.isRenderedBlock(false) ? "\n" : "";
              }
              return "";
            }, "node")
          });
          function Position(nodeWrapper, offset) {
            this.offset = offset;
            this.nodeWrapper = nodeWrapper;
            this.node = nodeWrapper.node;
            this.session = nodeWrapper.session;
            this.cache = new Cache();
          }
          function inspectPosition() {
            return "[Position(" + dom.inspectNode(this.node) + ":" + this.offset + ")]";
          }
          var positionProto = {
            character: "",
            characterType: EMPTY,
            isBr: false,
            /*
            This method:
            - Fully populates positions that have characters that can be determined independently of any other characters.
            - Populates most types of space positions with a provisional character. The character is finalized later.
             */
            prepopulateChar: function() {
              var pos = this;
              if (!pos.prepopulatedChar) {
                var node2 = pos.node, offset = pos.offset;
                var visibleChar = "", charType = EMPTY;
                var finalizedChar = false;
                if (offset > 0) {
                  if (node2.nodeType == 3) {
                    var text = node2.data;
                    var textChar = text.charAt(offset - 1);
                    var nodeInfo = pos.nodeWrapper.getTextNodeInfo();
                    var spaceRegex = nodeInfo.spaceRegex;
                    if (nodeInfo.collapseSpaces) {
                      if (spaceRegex.test(textChar)) {
                        if (offset > 1 && spaceRegex.test(text.charAt(offset - 2))) {
                        } else if (nodeInfo.preLine && text.charAt(offset) === "\n") {
                          visibleChar = " ";
                          charType = PRE_LINE_TRAILING_SPACE_BEFORE_LINE_BREAK;
                        } else {
                          visibleChar = " ";
                          charType = COLLAPSIBLE_SPACE;
                        }
                      } else {
                        visibleChar = textChar;
                        charType = NON_SPACE;
                        finalizedChar = true;
                      }
                    } else {
                      visibleChar = textChar;
                      charType = UNCOLLAPSIBLE_SPACE;
                      finalizedChar = true;
                    }
                  } else {
                    var nodePassed = node2.childNodes[offset - 1];
                    if (nodePassed && nodePassed.nodeType == 1 && !isCollapsedNode(nodePassed)) {
                      if (nodePassed.tagName.toLowerCase() == "br") {
                        visibleChar = "\n";
                        pos.isBr = true;
                        charType = COLLAPSIBLE_SPACE;
                        finalizedChar = false;
                      } else {
                        pos.checkForTrailingSpace = true;
                      }
                    }
                    if (!visibleChar) {
                      var nextNode2 = node2.childNodes[offset];
                      if (nextNode2 && nextNode2.nodeType == 1 && !isCollapsedNode(nextNode2)) {
                        pos.checkForLeadingSpace = true;
                      }
                    }
                  }
                }
                pos.prepopulatedChar = true;
                pos.character = visibleChar;
                pos.characterType = charType;
                pos.isCharInvariant = finalizedChar;
              }
            },
            isDefinitelyNonEmpty: function() {
              var charType = this.characterType;
              return charType == NON_SPACE || charType == UNCOLLAPSIBLE_SPACE;
            },
            // Resolve leading and trailing spaces, which may involve prepopulating other positions
            resolveLeadingAndTrailingSpaces: function() {
              if (!this.prepopulatedChar) {
                this.prepopulateChar();
              }
              if (this.checkForTrailingSpace) {
                var trailingSpace = this.session.getNodeWrapper(this.node.childNodes[this.offset - 1]).getTrailingSpace();
                if (trailingSpace) {
                  this.isTrailingSpace = true;
                  this.character = trailingSpace;
                  this.characterType = COLLAPSIBLE_SPACE;
                }
                this.checkForTrailingSpace = false;
              }
              if (this.checkForLeadingSpace) {
                var leadingSpace = this.session.getNodeWrapper(this.node.childNodes[this.offset]).getLeadingSpace();
                if (leadingSpace) {
                  this.isLeadingSpace = true;
                  this.character = leadingSpace;
                  this.characterType = COLLAPSIBLE_SPACE;
                }
                this.checkForLeadingSpace = false;
              }
            },
            getPrecedingUncollapsedPosition: function(characterOptions) {
              var pos = this, character;
              while (pos = pos.previousVisible()) {
                character = pos.getCharacter(characterOptions);
                if (character !== "") {
                  return pos;
                }
              }
              return null;
            },
            getCharacter: function(characterOptions) {
              this.resolveLeadingAndTrailingSpaces();
              var thisChar = this.character, returnChar;
              var ignoredChars = normalizeIgnoredCharacters(characterOptions.ignoreCharacters);
              var isIgnoredCharacter = thisChar !== "" && ignoredChars.indexOf(thisChar) > -1;
              if (this.isCharInvariant) {
                returnChar = isIgnoredCharacter ? "" : thisChar;
                return returnChar;
              }
              var cacheKey = ["character", characterOptions.includeSpaceBeforeBr, characterOptions.includeBlockContentTrailingSpace, characterOptions.includePreLineTrailingSpace, ignoredChars].join("_");
              var cachedChar = this.cache.get(cacheKey);
              if (cachedChar !== null) {
                return cachedChar;
              }
              var character = "";
              var collapsible = this.characterType == COLLAPSIBLE_SPACE;
              var nextPos, previousPos;
              var gotPreviousPos = false;
              var pos = this;
              function getPreviousPos() {
                if (!gotPreviousPos) {
                  previousPos = pos.getPrecedingUncollapsedPosition(characterOptions);
                  gotPreviousPos = true;
                }
                return previousPos;
              }
              if (collapsible) {
                if (this.type == INCLUDED_TRAILING_LINE_BREAK_AFTER_BR) {
                  character = "\n";
                } else if (thisChar == " " && (!getPreviousPos() || previousPos.isTrailingSpace || previousPos.character == "\n" || previousPos.character == " " && previousPos.characterType == COLLAPSIBLE_SPACE)) {
                } else if (thisChar == "\n" && this.isLeadingSpace) {
                  if (getPreviousPos() && previousPos.character != "\n") {
                    character = "\n";
                  } else {
                  }
                } else {
                  nextPos = this.nextUncollapsed();
                  if (nextPos) {
                    if (nextPos.isBr) {
                      this.type = TRAILING_SPACE_BEFORE_BR;
                    } else if (nextPos.isTrailingSpace && nextPos.character == "\n") {
                      this.type = TRAILING_SPACE_IN_BLOCK;
                    } else if (nextPos.isLeadingSpace && nextPos.character == "\n") {
                      this.type = TRAILING_SPACE_BEFORE_BLOCK;
                    }
                    if (nextPos.character == "\n") {
                      if (this.type == TRAILING_SPACE_BEFORE_BR && !characterOptions.includeSpaceBeforeBr) {
                      } else if (this.type == TRAILING_SPACE_BEFORE_BLOCK && !characterOptions.includeSpaceBeforeBlock) {
                      } else if (this.type == TRAILING_SPACE_IN_BLOCK && nextPos.isTrailingSpace && !characterOptions.includeBlockContentTrailingSpace) {
                      } else if (this.type == PRE_LINE_TRAILING_SPACE_BEFORE_LINE_BREAK && nextPos.type == NON_SPACE && !characterOptions.includePreLineTrailingSpace) {
                      } else if (thisChar == "\n") {
                        if (nextPos.isTrailingSpace) {
                          if (this.isTrailingSpace) {
                          } else if (this.isBr) {
                            nextPos.type = TRAILING_LINE_BREAK_AFTER_BR;
                            if (getPreviousPos() && previousPos.isLeadingSpace && !previousPos.isTrailingSpace && previousPos.character == "\n") {
                              nextPos.character = "";
                            } else {
                              nextPos.type = INCLUDED_TRAILING_LINE_BREAK_AFTER_BR;
                            }
                          }
                        } else {
                          character = "\n";
                        }
                      } else if (thisChar == " ") {
                        character = " ";
                      } else {
                      }
                    } else {
                      character = thisChar;
                    }
                  } else {
                  }
                }
              }
              if (ignoredChars.indexOf(character) > -1) {
                character = "";
              }
              this.cache.set(cacheKey, character);
              return character;
            },
            equals: function(pos) {
              return !!pos && this.node === pos.node && this.offset === pos.offset;
            },
            inspect: inspectPosition,
            toString: function() {
              return this.character;
            }
          };
          Position.prototype = positionProto;
          extend(positionProto, {
            next: createCachingGetter("nextPos", function(pos) {
              var nodeWrapper = pos.nodeWrapper, node2 = pos.node, offset = pos.offset, session = nodeWrapper.session;
              if (!node2) {
                return null;
              }
              var nextNode2, nextOffset, child;
              if (offset == nodeWrapper.getLength()) {
                nextNode2 = node2.parentNode;
                nextOffset = nextNode2 ? nodeWrapper.getNodeIndex() + 1 : 0;
              } else {
                if (nodeWrapper.isCharacterDataNode()) {
                  nextNode2 = node2;
                  nextOffset = offset + 1;
                } else {
                  child = node2.childNodes[offset];
                  if (session.getNodeWrapper(child).containsPositions()) {
                    nextNode2 = child;
                    nextOffset = 0;
                  } else {
                    nextNode2 = node2;
                    nextOffset = offset + 1;
                  }
                }
              }
              return nextNode2 ? session.getPosition(nextNode2, nextOffset) : null;
            }),
            previous: createCachingGetter("previous", function(pos) {
              var nodeWrapper = pos.nodeWrapper, node2 = pos.node, offset = pos.offset, session = nodeWrapper.session;
              var previousNode2, previousOffset, child;
              if (offset == 0) {
                previousNode2 = node2.parentNode;
                previousOffset = previousNode2 ? nodeWrapper.getNodeIndex() : 0;
              } else {
                if (nodeWrapper.isCharacterDataNode()) {
                  previousNode2 = node2;
                  previousOffset = offset - 1;
                } else {
                  child = node2.childNodes[offset - 1];
                  if (session.getNodeWrapper(child).containsPositions()) {
                    previousNode2 = child;
                    previousOffset = dom.getNodeLength(child);
                  } else {
                    previousNode2 = node2;
                    previousOffset = offset - 1;
                  }
                }
              }
              return previousNode2 ? session.getPosition(previousNode2, previousOffset) : null;
            }),
            /*
                         Next and previous position moving functions that filter out
            
                         - Hidden (CSS visibility/display) elements
                         - Script and style elements
                         */
            nextVisible: createCachingGetter("nextVisible", function(pos) {
              var next = pos.next();
              if (!next) {
                return null;
              }
              var nodeWrapper = next.nodeWrapper, node2 = next.node;
              var newPos = next;
              if (nodeWrapper.isCollapsed()) {
                newPos = nodeWrapper.session.getPosition(node2.parentNode, nodeWrapper.getNodeIndex() + 1);
              }
              return newPos;
            }),
            nextUncollapsed: createCachingGetter("nextUncollapsed", function(pos) {
              var nextPos = pos;
              while (nextPos = nextPos.nextVisible()) {
                nextPos.resolveLeadingAndTrailingSpaces();
                if (nextPos.character !== "") {
                  return nextPos;
                }
              }
              return null;
            }),
            previousVisible: createCachingGetter("previousVisible", function(pos) {
              var previous = pos.previous();
              if (!previous) {
                return null;
              }
              var nodeWrapper = previous.nodeWrapper, node2 = previous.node;
              var newPos = previous;
              if (nodeWrapper.isCollapsed()) {
                newPos = nodeWrapper.session.getPosition(node2.parentNode, nodeWrapper.getNodeIndex());
              }
              return newPos;
            })
          });
          var currentSession = null;
          var Session = (function() {
            function createWrapperCache(nodeProperty) {
              var cache = new Cache();
              return {
                get: function(node2) {
                  var wrappersByProperty = cache.get(node2[nodeProperty]);
                  if (wrappersByProperty) {
                    for (var i = 0, wrapper; wrapper = wrappersByProperty[i++]; ) {
                      if (wrapper.node === node2) {
                        return wrapper;
                      }
                    }
                  }
                  return null;
                },
                set: function(nodeWrapper) {
                  var property2 = nodeWrapper.node[nodeProperty];
                  var wrappersByProperty = cache.get(property2) || cache.set(property2, []);
                  wrappersByProperty.push(nodeWrapper);
                }
              };
            }
            var uniqueIDSupported = util.isHostProperty(document.documentElement, "uniqueID");
            function Session2() {
              this.initCaches();
            }
            Session2.prototype = {
              initCaches: function() {
                this.elementCache = uniqueIDSupported ? (function() {
                  var elementsCache = new Cache();
                  return {
                    get: function(el) {
                      return elementsCache.get(el.uniqueID);
                    },
                    set: function(elWrapper) {
                      elementsCache.set(elWrapper.node.uniqueID, elWrapper);
                    }
                  };
                })() : createWrapperCache("tagName");
                this.textNodeCache = createWrapperCache("data");
                this.otherNodeCache = createWrapperCache("nodeName");
              },
              getNodeWrapper: function(node2) {
                var wrapperCache;
                switch (node2.nodeType) {
                  case 1:
                    wrapperCache = this.elementCache;
                    break;
                  case 3:
                    wrapperCache = this.textNodeCache;
                    break;
                  default:
                    wrapperCache = this.otherNodeCache;
                    break;
                }
                var wrapper = wrapperCache.get(node2);
                if (!wrapper) {
                  wrapper = new NodeWrapper(node2, this);
                  wrapperCache.set(wrapper);
                }
                return wrapper;
              },
              getPosition: function(node2, offset) {
                return this.getNodeWrapper(node2).getPosition(offset);
              },
              getRangeBoundaryPosition: function(range2, isStart) {
                var prefix = isStart ? "start" : "end";
                return this.getPosition(range2[prefix + "Container"], range2[prefix + "Offset"]);
              },
              detach: function() {
                this.elementCache = this.textNodeCache = this.otherNodeCache = null;
              }
            };
            return Session2;
          })();
          function startSession() {
            endSession();
            return currentSession = new Session();
          }
          function getSession() {
            return currentSession || startSession();
          }
          function endSession() {
            if (currentSession) {
              currentSession.detach();
            }
            currentSession = null;
          }
          extend(dom, {
            nextNode,
            previousNode
          });
          function createCharacterIterator(startPos, backward, endPos, characterOptions) {
            if (endPos) {
              if (backward) {
                if (isCollapsedNode(endPos.node)) {
                  endPos = startPos.previousVisible();
                }
              } else {
                if (isCollapsedNode(endPos.node)) {
                  endPos = endPos.nextVisible();
                }
              }
            }
            var pos = startPos, finished = false;
            function next() {
              var charPos = null;
              if (backward) {
                charPos = pos;
                if (!finished) {
                  pos = pos.previousVisible();
                  finished = !pos || endPos && pos.equals(endPos);
                }
              } else {
                if (!finished) {
                  charPos = pos = pos.nextVisible();
                  finished = !pos || endPos && pos.equals(endPos);
                }
              }
              if (finished) {
                pos = null;
              }
              return charPos;
            }
            var previousTextPos, returnPreviousTextPos = false;
            return {
              next: function() {
                if (returnPreviousTextPos) {
                  returnPreviousTextPos = false;
                  return previousTextPos;
                } else {
                  var pos2, character;
                  while (pos2 = next()) {
                    character = pos2.getCharacter(characterOptions);
                    if (character) {
                      previousTextPos = pos2;
                      return pos2;
                    }
                  }
                  return null;
                }
              },
              rewind: function() {
                if (previousTextPos) {
                  returnPreviousTextPos = true;
                } else {
                  throw module2.createError("createCharacterIterator: cannot rewind. Only one position can be rewound.");
                }
              },
              dispose: function() {
                startPos = endPos = null;
              }
            };
          }
          var arrayIndexOf = Array.prototype.indexOf ? function(arr, val) {
            return arr.indexOf(val);
          } : function(arr, val) {
            for (var i = 0, len = arr.length; i < len; ++i) {
              if (arr[i] === val) {
                return i;
              }
            }
            return -1;
          };
          function createTokenizedTextProvider(pos, characterOptions, wordOptions) {
            var forwardIterator = createCharacterIterator(pos, false, null, characterOptions);
            var backwardIterator = createCharacterIterator(pos, true, null, characterOptions);
            var tokenizer2 = wordOptions.tokenizer;
            function consumeWord(forward) {
              var pos2, textChar;
              var newChars = [], it = forward ? forwardIterator : backwardIterator;
              var passedWordBoundary = false, insideWord = false;
              while (pos2 = it.next()) {
                textChar = pos2.character;
                if (allWhiteSpaceRegex.test(textChar)) {
                  if (insideWord) {
                    insideWord = false;
                    passedWordBoundary = true;
                  }
                } else {
                  if (passedWordBoundary) {
                    it.rewind();
                    break;
                  } else {
                    insideWord = true;
                  }
                }
                newChars.push(pos2);
              }
              return newChars;
            }
            var forwardChars = consumeWord(true);
            var backwardChars = consumeWord(false).reverse();
            var tokens = tokenize(backwardChars.concat(forwardChars), wordOptions, tokenizer2);
            var forwardTokensBuffer = forwardChars.length ? tokens.slice(arrayIndexOf(tokens, forwardChars[0].token)) : [];
            var backwardTokensBuffer = backwardChars.length ? tokens.slice(0, arrayIndexOf(tokens, backwardChars.pop().token) + 1) : [];
            function inspectBuffer(buffer) {
              var textPositions = ["[" + buffer.length + "]"];
              for (var i = 0; i < buffer.length; ++i) {
                textPositions.push("(word: " + buffer[i] + ", is word: " + buffer[i].isWord + ")");
              }
              return textPositions;
            }
            return {
              nextEndToken: function() {
                var lastToken, forwardChars2;
                while (forwardTokensBuffer.length == 1 && !(lastToken = forwardTokensBuffer[0]).isWord && (forwardChars2 = consumeWord(true)).length > 0) {
                  forwardTokensBuffer = tokenize(lastToken.chars.concat(forwardChars2), wordOptions, tokenizer2);
                }
                return forwardTokensBuffer.shift();
              },
              previousStartToken: function() {
                var lastToken, backwardChars2;
                while (backwardTokensBuffer.length == 1 && !(lastToken = backwardTokensBuffer[0]).isWord && (backwardChars2 = consumeWord(false)).length > 0) {
                  backwardTokensBuffer = tokenize(backwardChars2.reverse().concat(lastToken.chars), wordOptions, tokenizer2);
                }
                return backwardTokensBuffer.pop();
              },
              dispose: function() {
                forwardIterator.dispose();
                backwardIterator.dispose();
                forwardTokensBuffer = backwardTokensBuffer = null;
              }
            };
          }
          function movePositionBy(pos, unit, count, characterOptions, wordOptions) {
            var unitsMoved = 0, currentPos, newPos = pos, charIterator, nextPos, absCount = Math.abs(count), token;
            if (count !== 0) {
              var backward = count < 0;
              switch (unit) {
                case CHARACTER:
                  charIterator = createCharacterIterator(pos, backward, null, characterOptions);
                  while ((currentPos = charIterator.next()) && unitsMoved < absCount) {
                    ++unitsMoved;
                    newPos = currentPos;
                  }
                  nextPos = currentPos;
                  charIterator.dispose();
                  break;
                case WORD:
                  var tokenizedTextProvider = createTokenizedTextProvider(pos, characterOptions, wordOptions);
                  var next = backward ? tokenizedTextProvider.previousStartToken : tokenizedTextProvider.nextEndToken;
                  while ((token = next()) && unitsMoved < absCount) {
                    if (token.isWord) {
                      ++unitsMoved;
                      newPos = backward ? token.chars[0] : token.chars[token.chars.length - 1];
                    }
                  }
                  break;
                default:
                  throw new Error("movePositionBy: unit '" + unit + "' not implemented");
              }
              if (backward) {
                newPos = newPos.previousVisible();
                unitsMoved = -unitsMoved;
              } else if (newPos && newPos.isLeadingSpace && !newPos.isTrailingSpace) {
                if (unit == WORD) {
                  charIterator = createCharacterIterator(pos, false, null, characterOptions);
                  nextPos = charIterator.next();
                  charIterator.dispose();
                }
                if (nextPos) {
                  newPos = nextPos.previousVisible();
                }
              }
            }
            return {
              position: newPos,
              unitsMoved
            };
          }
          function createRangeCharacterIterator(session, range2, characterOptions, backward) {
            var rangeStart = session.getRangeBoundaryPosition(range2, true);
            var rangeEnd = session.getRangeBoundaryPosition(range2, false);
            var itStart = backward ? rangeEnd : rangeStart;
            var itEnd = backward ? rangeStart : rangeEnd;
            return createCharacterIterator(itStart, !!backward, itEnd, characterOptions);
          }
          function getRangeCharacters(session, range2, characterOptions) {
            var chars = [], it = createRangeCharacterIterator(session, range2, characterOptions), pos;
            while (pos = it.next()) {
              chars.push(pos);
            }
            it.dispose();
            return chars;
          }
          function isWholeWord(startPos, endPos, wordOptions) {
            var range2 = api.createRange(startPos.node);
            range2.setStartAndEnd(startPos.node, startPos.offset, endPos.node, endPos.offset);
            return !range2.expand("word", { wordOptions });
          }
          function findTextFromPosition(initialPos, searchTerm, isRegex, searchScopeRange, findOptions) {
            var backward = isDirectionBackward(findOptions.direction);
            var it = createCharacterIterator(
              initialPos,
              backward,
              initialPos.session.getRangeBoundaryPosition(searchScopeRange, backward),
              findOptions.characterOptions
            );
            var text = "", chars = [], pos, currentChar, matchStartIndex, matchEndIndex;
            var result2, insideRegexMatch;
            var returnValue = null;
            function handleMatch(startIndex, endIndex) {
              var startPos = chars[startIndex].previousVisible();
              var endPos = chars[endIndex - 1];
              var valid = !findOptions.wholeWordsOnly || isWholeWord(startPos, endPos, findOptions.wordOptions);
              return {
                startPos,
                endPos,
                valid
              };
            }
            while (pos = it.next()) {
              currentChar = pos.character;
              if (!isRegex && !findOptions.caseSensitive) {
                currentChar = currentChar.toLowerCase();
              }
              if (backward) {
                chars.unshift(pos);
                text = currentChar + text;
              } else {
                chars.push(pos);
                text += currentChar;
              }
              if (isRegex) {
                result2 = searchTerm.exec(text);
                if (result2) {
                  matchStartIndex = result2.index;
                  matchEndIndex = matchStartIndex + result2[0].length;
                  if (insideRegexMatch) {
                    if (!backward && matchEndIndex < text.length || backward && matchStartIndex > 0) {
                      returnValue = handleMatch(matchStartIndex, matchEndIndex);
                      break;
                    }
                  } else {
                    insideRegexMatch = true;
                  }
                }
              } else if ((matchStartIndex = text.indexOf(searchTerm)) != -1) {
                returnValue = handleMatch(matchStartIndex, matchStartIndex + searchTerm.length);
                break;
              }
            }
            if (insideRegexMatch) {
              returnValue = handleMatch(matchStartIndex, matchEndIndex);
            }
            it.dispose();
            return returnValue;
          }
          function createEntryPointFunction(func) {
            return function() {
              var sessionRunning = !!currentSession;
              var session = getSession();
              var args = [session].concat(util.toArray(arguments));
              var returnValue = func.apply(this, args);
              if (!sessionRunning) {
                endSession();
              }
              return returnValue;
            };
          }
          function createRangeBoundaryMover(isStart, collapse2) {
            return createEntryPointFunction(
              function(session, unit, count, moveOptions) {
                if (typeof count == UNDEF) {
                  count = unit;
                  unit = CHARACTER;
                }
                moveOptions = createNestedOptions(moveOptions, defaultMoveOptions);
                var boundaryIsStart = isStart;
                if (collapse2) {
                  boundaryIsStart = count >= 0;
                  this.collapse(!boundaryIsStart);
                }
                var moveResult = movePositionBy(session.getRangeBoundaryPosition(this, boundaryIsStart), unit, count, moveOptions.characterOptions, moveOptions.wordOptions);
                var newPos = moveResult.position;
                this[boundaryIsStart ? "setStart" : "setEnd"](newPos.node, newPos.offset);
                return moveResult.unitsMoved;
              }
            );
          }
          function createRangeTrimmer(isStart) {
            return createEntryPointFunction(
              function(session, characterOptions) {
                characterOptions = createOptions(characterOptions, defaultCharacterOptions);
                var pos;
                var it = createRangeCharacterIterator(session, this, characterOptions, !isStart);
                var trimCharCount = 0;
                while ((pos = it.next()) && allWhiteSpaceRegex.test(pos.character)) {
                  ++trimCharCount;
                }
                it.dispose();
                var trimmed = trimCharCount > 0;
                if (trimmed) {
                  this[isStart ? "moveStart" : "moveEnd"](
                    "character",
                    isStart ? trimCharCount : -trimCharCount,
                    { characterOptions }
                  );
                }
                return trimmed;
              }
            );
          }
          extend(api.rangePrototype, {
            moveStart: createRangeBoundaryMover(true, false),
            moveEnd: createRangeBoundaryMover(false, false),
            move: createRangeBoundaryMover(true, true),
            trimStart: createRangeTrimmer(true),
            trimEnd: createRangeTrimmer(false),
            trim: createEntryPointFunction(
              function(session, characterOptions) {
                var startTrimmed = this.trimStart(characterOptions), endTrimmed = this.trimEnd(characterOptions);
                return startTrimmed || endTrimmed;
              }
            ),
            expand: createEntryPointFunction(
              function(session, unit, expandOptions) {
                var moved = false;
                expandOptions = createNestedOptions(expandOptions, defaultExpandOptions);
                var characterOptions = expandOptions.characterOptions;
                if (!unit) {
                  unit = CHARACTER;
                }
                if (unit == WORD) {
                  var wordOptions = expandOptions.wordOptions;
                  var startPos = session.getRangeBoundaryPosition(this, true);
                  var endPos = session.getRangeBoundaryPosition(this, false);
                  var startTokenizedTextProvider = createTokenizedTextProvider(startPos, characterOptions, wordOptions);
                  var startToken = startTokenizedTextProvider.nextEndToken();
                  var newStartPos = startToken.chars[0].previousVisible();
                  var endToken, newEndPos;
                  if (this.collapsed) {
                    endToken = startToken;
                  } else {
                    var endTokenizedTextProvider = createTokenizedTextProvider(endPos, characterOptions, wordOptions);
                    endToken = endTokenizedTextProvider.previousStartToken();
                  }
                  newEndPos = endToken.chars[endToken.chars.length - 1];
                  if (!newStartPos.equals(startPos)) {
                    this.setStart(newStartPos.node, newStartPos.offset);
                    moved = true;
                  }
                  if (newEndPos && !newEndPos.equals(endPos)) {
                    this.setEnd(newEndPos.node, newEndPos.offset);
                    moved = true;
                  }
                  if (expandOptions.trim) {
                    if (expandOptions.trimStart) {
                      moved = this.trimStart(characterOptions) || moved;
                    }
                    if (expandOptions.trimEnd) {
                      moved = this.trimEnd(characterOptions) || moved;
                    }
                  }
                  return moved;
                } else {
                  return this.moveEnd(CHARACTER, 1, expandOptions);
                }
              }
            ),
            text: createEntryPointFunction(
              function(session, characterOptions) {
                return this.collapsed ? "" : getRangeCharacters(session, this, createOptions(characterOptions, defaultCharacterOptions)).join("");
              }
            ),
            selectCharacters: createEntryPointFunction(
              function(session, containerNode, startIndex, endIndex, characterOptions) {
                var moveOptions = { characterOptions };
                if (!containerNode) {
                  containerNode = getBody(this.getDocument());
                }
                this.selectNodeContents(containerNode);
                this.collapse(true);
                this.moveStart("character", startIndex, moveOptions);
                this.collapse(true);
                this.moveEnd("character", endIndex - startIndex, moveOptions);
              }
            ),
            // Character indexes are relative to the start of node
            toCharacterRange: createEntryPointFunction(
              function(session, containerNode, characterOptions) {
                if (!containerNode) {
                  containerNode = getBody(this.getDocument());
                }
                var parent = containerNode.parentNode, nodeIndex = dom.getNodeIndex(containerNode);
                var rangeStartsBeforeNode = dom.comparePoints(this.startContainer, this.endContainer, parent, nodeIndex) == -1;
                var rangeBetween = this.cloneRange();
                var startIndex, endIndex;
                if (rangeStartsBeforeNode) {
                  rangeBetween.setStartAndEnd(this.startContainer, this.startOffset, parent, nodeIndex);
                  startIndex = -rangeBetween.text(characterOptions).length;
                } else {
                  rangeBetween.setStartAndEnd(parent, nodeIndex, this.startContainer, this.startOffset);
                  startIndex = rangeBetween.text(characterOptions).length;
                }
                endIndex = startIndex + this.text(characterOptions).length;
                return {
                  start: startIndex,
                  end: endIndex
                };
              }
            ),
            findText: createEntryPointFunction(
              function(session, searchTermParam, findOptions) {
                findOptions = createNestedOptions(findOptions, defaultFindOptions);
                if (findOptions.wholeWordsOnly) {
                  findOptions.wordOptions.includeTrailingSpace = false;
                }
                var backward = isDirectionBackward(findOptions.direction);
                var searchScopeRange = findOptions.withinRange;
                if (!searchScopeRange) {
                  searchScopeRange = api.createRange();
                  searchScopeRange.selectNodeContents(this.getDocument());
                }
                var searchTerm = searchTermParam, isRegex = false;
                if (typeof searchTerm == "string") {
                  if (!findOptions.caseSensitive) {
                    searchTerm = searchTerm.toLowerCase();
                  }
                } else {
                  isRegex = true;
                }
                var initialPos = session.getRangeBoundaryPosition(this, !backward);
                var comparison = searchScopeRange.comparePoint(initialPos.node, initialPos.offset);
                if (comparison === -1) {
                  initialPos = session.getRangeBoundaryPosition(searchScopeRange, true);
                } else if (comparison === 1) {
                  initialPos = session.getRangeBoundaryPosition(searchScopeRange, false);
                }
                var pos = initialPos;
                var wrappedAround = false;
                var findResult;
                while (true) {
                  findResult = findTextFromPosition(pos, searchTerm, isRegex, searchScopeRange, findOptions);
                  if (findResult) {
                    if (findResult.valid) {
                      this.setStartAndEnd(findResult.startPos.node, findResult.startPos.offset, findResult.endPos.node, findResult.endPos.offset);
                      return true;
                    } else {
                      pos = backward ? findResult.startPos : findResult.endPos;
                    }
                  } else if (findOptions.wrap && !wrappedAround) {
                    searchScopeRange = searchScopeRange.cloneRange();
                    pos = session.getRangeBoundaryPosition(searchScopeRange, !backward);
                    searchScopeRange.setBoundary(initialPos.node, initialPos.offset, backward);
                    wrappedAround = true;
                  } else {
                    return false;
                  }
                }
              }
            ),
            pasteHtml: function(html) {
              this.deleteContents();
              if (html) {
                var frag = this.createContextualFragment(html);
                var lastChild = frag.lastChild;
                this.insertNode(frag);
                this.collapseAfter(lastChild);
              }
            }
          });
          function createSelectionTrimmer(methodName) {
            return createEntryPointFunction(
              function(session, characterOptions) {
                var trimmed = false;
                this.changeEachRange(function(range2) {
                  trimmed = range2[methodName](characterOptions) || trimmed;
                });
                return trimmed;
              }
            );
          }
          extend(api.selectionPrototype, {
            expand: createEntryPointFunction(
              function(session, unit, expandOptions) {
                this.changeEachRange(function(range2) {
                  range2.expand(unit, expandOptions);
                });
              }
            ),
            move: createEntryPointFunction(
              function(session, unit, count, options) {
                var unitsMoved = 0;
                if (this.focusNode) {
                  this.collapse(this.focusNode, this.focusOffset);
                  var range2 = this.getRangeAt(0);
                  if (!options) {
                    options = {};
                  }
                  options.characterOptions = createOptions(options.characterOptions, defaultCaretCharacterOptions);
                  unitsMoved = range2.move(unit, count, options);
                  this.setSingleRange(range2);
                }
                return unitsMoved;
              }
            ),
            trimStart: createSelectionTrimmer("trimStart"),
            trimEnd: createSelectionTrimmer("trimEnd"),
            trim: createSelectionTrimmer("trim"),
            selectCharacters: createEntryPointFunction(
              function(session, containerNode, startIndex, endIndex, direction, characterOptions) {
                var range2 = api.createRange(containerNode);
                range2.selectCharacters(containerNode, startIndex, endIndex, characterOptions);
                this.setSingleRange(range2, direction);
              }
            ),
            saveCharacterRanges: createEntryPointFunction(
              function(session, containerNode, characterOptions) {
                var ranges = this.getAllRanges(), rangeCount = ranges.length;
                var rangeInfos = [];
                var backward = rangeCount == 1 && this.isBackward();
                for (var i = 0, len = ranges.length; i < len; ++i) {
                  rangeInfos[i] = {
                    characterRange: ranges[i].toCharacterRange(containerNode, characterOptions),
                    backward,
                    characterOptions
                  };
                }
                return rangeInfos;
              }
            ),
            restoreCharacterRanges: createEntryPointFunction(
              function(session, containerNode, saved) {
                this.removeAllRanges();
                for (var i = 0, len = saved.length, range2, rangeInfo, characterRange; i < len; ++i) {
                  rangeInfo = saved[i];
                  characterRange = rangeInfo.characterRange;
                  range2 = api.createRange(containerNode);
                  range2.selectCharacters(containerNode, characterRange.start, characterRange.end, rangeInfo.characterOptions);
                  this.addRange(range2, rangeInfo.backward);
                }
              }
            ),
            text: createEntryPointFunction(
              function(session, characterOptions) {
                var rangeTexts = [];
                for (var i = 0, len = this.rangeCount; i < len; ++i) {
                  rangeTexts[i] = this.getRangeAt(i).text(characterOptions);
                }
                return rangeTexts.join("");
              }
            )
          });
          api.innerText = function(el, characterOptions) {
            var range2 = api.createRange(el);
            range2.selectNodeContents(el);
            var text = range2.text(characterOptions);
            return text;
          };
          api.createWordIterator = function(startNode, startOffset, iteratorOptions) {
            var session = getSession();
            iteratorOptions = createNestedOptions(iteratorOptions, defaultWordIteratorOptions);
            var startPos = session.getPosition(startNode, startOffset);
            var tokenizedTextProvider = createTokenizedTextProvider(startPos, iteratorOptions.characterOptions, iteratorOptions.wordOptions);
            var backward = isDirectionBackward(iteratorOptions.direction);
            return {
              next: function() {
                return backward ? tokenizedTextProvider.previousStartToken() : tokenizedTextProvider.nextEndToken();
              },
              dispose: function() {
                tokenizedTextProvider.dispose();
                this.next = function() {
                };
              }
            };
          };
          api.noMutation = function(func) {
            var session = getSession();
            func(session);
            endSession();
          };
          api.noMutation.createEntryPointFunction = createEntryPointFunction;
          api.textRange = {
            isBlockNode,
            isCollapsedWhitespaceNode,
            createPosition: createEntryPointFunction(
              function(session, node2, offset) {
                return session.getPosition(node2, offset);
              }
            )
          };
        });
        return rangy4;
      }, exports);
    }
  });

  // node_modules/jszip/dist/jszip.min.js
  var require_jszip_min = __commonJS({
    "node_modules/jszip/dist/jszip.min.js"(exports, module) {
      /*!
      
      JSZip v3.10.1 - A JavaScript class for generating and reading zip files
      <http://stuartk.com/jszip>
      
      (c) 2009-2016 Stuart Knightley <stuart [at] stuartk.com>
      Dual licenced under the MIT license or GPLv3. See https://raw.github.com/Stuk/jszip/main/LICENSE.markdown.
      
      JSZip uses the library pako released under the MIT license :
      https://github.com/nodeca/pako/blob/main/LICENSE
      */
      !(function(e) {
        if ("object" == typeof exports && "undefined" != typeof module) module.exports = e();
        else if ("function" == typeof define && define.amd) define([], e);
        else {
          ("undefined" != typeof window ? window : "undefined" != typeof global ? global : "undefined" != typeof self ? self : this).JSZip = e();
        }
      })(function() {
        return (function s(a, o, h) {
          function u(r, e2) {
            if (!o[r]) {
              if (!a[r]) {
                var t = "function" == typeof __require && __require;
                if (!e2 && t) return t(r, true);
                if (l) return l(r, true);
                var n = new Error("Cannot find module '" + r + "'");
                throw n.code = "MODULE_NOT_FOUND", n;
              }
              var i = o[r] = { exports: {} };
              a[r][0].call(i.exports, function(e3) {
                var t2 = a[r][1][e3];
                return u(t2 || e3);
              }, i, i.exports, s, a, o, h);
            }
            return o[r].exports;
          }
          for (var l = "function" == typeof __require && __require, e = 0; e < h.length; e++) u(h[e]);
          return u;
        })({ 1: [function(e, t, r) {
          "use strict";
          var d = e("./utils"), c = e("./support"), p = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
          r.encode = function(e2) {
            for (var t2, r2, n, i, s, a, o, h = [], u = 0, l = e2.length, f = l, c2 = "string" !== d.getTypeOf(e2); u < e2.length; ) f = l - u, n = c2 ? (t2 = e2[u++], r2 = u < l ? e2[u++] : 0, u < l ? e2[u++] : 0) : (t2 = e2.charCodeAt(u++), r2 = u < l ? e2.charCodeAt(u++) : 0, u < l ? e2.charCodeAt(u++) : 0), i = t2 >> 2, s = (3 & t2) << 4 | r2 >> 4, a = 1 < f ? (15 & r2) << 2 | n >> 6 : 64, o = 2 < f ? 63 & n : 64, h.push(p.charAt(i) + p.charAt(s) + p.charAt(a) + p.charAt(o));
            return h.join("");
          }, r.decode = function(e2) {
            var t2, r2, n, i, s, a, o = 0, h = 0, u = "data:";
            if (e2.substr(0, u.length) === u) throw new Error("Invalid base64 input, it looks like a data url.");
            var l, f = 3 * (e2 = e2.replace(/[^A-Za-z0-9+/=]/g, "")).length / 4;
            if (e2.charAt(e2.length - 1) === p.charAt(64) && f--, e2.charAt(e2.length - 2) === p.charAt(64) && f--, f % 1 != 0) throw new Error("Invalid base64 input, bad content length.");
            for (l = c.uint8array ? new Uint8Array(0 | f) : new Array(0 | f); o < e2.length; ) t2 = p.indexOf(e2.charAt(o++)) << 2 | (i = p.indexOf(e2.charAt(o++))) >> 4, r2 = (15 & i) << 4 | (s = p.indexOf(e2.charAt(o++))) >> 2, n = (3 & s) << 6 | (a = p.indexOf(e2.charAt(o++))), l[h++] = t2, 64 !== s && (l[h++] = r2), 64 !== a && (l[h++] = n);
            return l;
          };
        }, { "./support": 30, "./utils": 32 }], 2: [function(e, t, r) {
          "use strict";
          var n = e("./external"), i = e("./stream/DataWorker"), s = e("./stream/Crc32Probe"), a = e("./stream/DataLengthProbe");
          function o(e2, t2, r2, n2, i2) {
            this.compressedSize = e2, this.uncompressedSize = t2, this.crc32 = r2, this.compression = n2, this.compressedContent = i2;
          }
          o.prototype = { getContentWorker: function() {
            var e2 = new i(n.Promise.resolve(this.compressedContent)).pipe(this.compression.uncompressWorker()).pipe(new a("data_length")), t2 = this;
            return e2.on("end", function() {
              if (this.streamInfo.data_length !== t2.uncompressedSize) throw new Error("Bug : uncompressed data size mismatch");
            }), e2;
          }, getCompressedWorker: function() {
            return new i(n.Promise.resolve(this.compressedContent)).withStreamInfo("compressedSize", this.compressedSize).withStreamInfo("uncompressedSize", this.uncompressedSize).withStreamInfo("crc32", this.crc32).withStreamInfo("compression", this.compression);
          } }, o.createWorkerFrom = function(e2, t2, r2) {
            return e2.pipe(new s()).pipe(new a("uncompressedSize")).pipe(t2.compressWorker(r2)).pipe(new a("compressedSize")).withStreamInfo("compression", t2);
          }, t.exports = o;
        }, { "./external": 6, "./stream/Crc32Probe": 25, "./stream/DataLengthProbe": 26, "./stream/DataWorker": 27 }], 3: [function(e, t, r) {
          "use strict";
          var n = e("./stream/GenericWorker");
          r.STORE = { magic: "\0\0", compressWorker: function() {
            return new n("STORE compression");
          }, uncompressWorker: function() {
            return new n("STORE decompression");
          } }, r.DEFLATE = e("./flate");
        }, { "./flate": 7, "./stream/GenericWorker": 28 }], 4: [function(e, t, r) {
          "use strict";
          var n = e("./utils");
          var o = (function() {
            for (var e2, t2 = [], r2 = 0; r2 < 256; r2++) {
              e2 = r2;
              for (var n2 = 0; n2 < 8; n2++) e2 = 1 & e2 ? 3988292384 ^ e2 >>> 1 : e2 >>> 1;
              t2[r2] = e2;
            }
            return t2;
          })();
          t.exports = function(e2, t2) {
            return void 0 !== e2 && e2.length ? "string" !== n.getTypeOf(e2) ? (function(e3, t3, r2, n2) {
              var i = o, s = n2 + r2;
              e3 ^= -1;
              for (var a = n2; a < s; a++) e3 = e3 >>> 8 ^ i[255 & (e3 ^ t3[a])];
              return -1 ^ e3;
            })(0 | t2, e2, e2.length, 0) : (function(e3, t3, r2, n2) {
              var i = o, s = n2 + r2;
              e3 ^= -1;
              for (var a = n2; a < s; a++) e3 = e3 >>> 8 ^ i[255 & (e3 ^ t3.charCodeAt(a))];
              return -1 ^ e3;
            })(0 | t2, e2, e2.length, 0) : 0;
          };
        }, { "./utils": 32 }], 5: [function(e, t, r) {
          "use strict";
          r.base64 = false, r.binary = false, r.dir = false, r.createFolders = true, r.date = null, r.compression = null, r.compressionOptions = null, r.comment = null, r.unixPermissions = null, r.dosPermissions = null;
        }, {}], 6: [function(e, t, r) {
          "use strict";
          var n = null;
          n = "undefined" != typeof Promise ? Promise : e("lie"), t.exports = { Promise: n };
        }, { lie: 37 }], 7: [function(e, t, r) {
          "use strict";
          var n = "undefined" != typeof Uint8Array && "undefined" != typeof Uint16Array && "undefined" != typeof Uint32Array, i = e("pako"), s = e("./utils"), a = e("./stream/GenericWorker"), o = n ? "uint8array" : "array";
          function h(e2, t2) {
            a.call(this, "FlateWorker/" + e2), this._pako = null, this._pakoAction = e2, this._pakoOptions = t2, this.meta = {};
          }
          r.magic = "\b\0", s.inherits(h, a), h.prototype.processChunk = function(e2) {
            this.meta = e2.meta, null === this._pako && this._createPako(), this._pako.push(s.transformTo(o, e2.data), false);
          }, h.prototype.flush = function() {
            a.prototype.flush.call(this), null === this._pako && this._createPako(), this._pako.push([], true);
          }, h.prototype.cleanUp = function() {
            a.prototype.cleanUp.call(this), this._pako = null;
          }, h.prototype._createPako = function() {
            this._pako = new i[this._pakoAction]({ raw: true, level: this._pakoOptions.level || -1 });
            var t2 = this;
            this._pako.onData = function(e2) {
              t2.push({ data: e2, meta: t2.meta });
            };
          }, r.compressWorker = function(e2) {
            return new h("Deflate", e2);
          }, r.uncompressWorker = function() {
            return new h("Inflate", {});
          };
        }, { "./stream/GenericWorker": 28, "./utils": 32, pako: 38 }], 8: [function(e, t, r) {
          "use strict";
          function A(e2, t2) {
            var r2, n2 = "";
            for (r2 = 0; r2 < t2; r2++) n2 += String.fromCharCode(255 & e2), e2 >>>= 8;
            return n2;
          }
          function n(e2, t2, r2, n2, i2, s2) {
            var a, o, h = e2.file, u = e2.compression, l = s2 !== O.utf8encode, f = I.transformTo("string", s2(h.name)), c = I.transformTo("string", O.utf8encode(h.name)), d = h.comment, p = I.transformTo("string", s2(d)), m = I.transformTo("string", O.utf8encode(d)), _3 = c.length !== h.name.length, g = m.length !== d.length, b = "", v = "", y = "", w = h.dir, k = h.date, x = { crc32: 0, compressedSize: 0, uncompressedSize: 0 };
            t2 && !r2 || (x.crc32 = e2.crc32, x.compressedSize = e2.compressedSize, x.uncompressedSize = e2.uncompressedSize);
            var S = 0;
            t2 && (S |= 8), l || !_3 && !g || (S |= 2048);
            var z = 0, C = 0;
            w && (z |= 16), "UNIX" === i2 ? (C = 798, z |= (function(e3, t3) {
              var r3 = e3;
              return e3 || (r3 = t3 ? 16893 : 33204), (65535 & r3) << 16;
            })(h.unixPermissions, w)) : (C = 20, z |= (function(e3) {
              return 63 & (e3 || 0);
            })(h.dosPermissions)), a = k.getUTCHours(), a <<= 6, a |= k.getUTCMinutes(), a <<= 5, a |= k.getUTCSeconds() / 2, o = k.getUTCFullYear() - 1980, o <<= 4, o |= k.getUTCMonth() + 1, o <<= 5, o |= k.getUTCDate(), _3 && (v = A(1, 1) + A(B(f), 4) + c, b += "up" + A(v.length, 2) + v), g && (y = A(1, 1) + A(B(p), 4) + m, b += "uc" + A(y.length, 2) + y);
            var E = "";
            return E += "\n\0", E += A(S, 2), E += u.magic, E += A(a, 2), E += A(o, 2), E += A(x.crc32, 4), E += A(x.compressedSize, 4), E += A(x.uncompressedSize, 4), E += A(f.length, 2), E += A(b.length, 2), { fileRecord: R.LOCAL_FILE_HEADER + E + f + b, dirRecord: R.CENTRAL_FILE_HEADER + A(C, 2) + E + A(p.length, 2) + "\0\0\0\0" + A(z, 4) + A(n2, 4) + f + b + p };
          }
          var I = e("../utils"), i = e("../stream/GenericWorker"), O = e("../utf8"), B = e("../crc32"), R = e("../signature");
          function s(e2, t2, r2, n2) {
            i.call(this, "ZipFileWorker"), this.bytesWritten = 0, this.zipComment = t2, this.zipPlatform = r2, this.encodeFileName = n2, this.streamFiles = e2, this.accumulate = false, this.contentBuffer = [], this.dirRecords = [], this.currentSourceOffset = 0, this.entriesCount = 0, this.currentFile = null, this._sources = [];
          }
          I.inherits(s, i), s.prototype.push = function(e2) {
            var t2 = e2.meta.percent || 0, r2 = this.entriesCount, n2 = this._sources.length;
            this.accumulate ? this.contentBuffer.push(e2) : (this.bytesWritten += e2.data.length, i.prototype.push.call(this, { data: e2.data, meta: { currentFile: this.currentFile, percent: r2 ? (t2 + 100 * (r2 - n2 - 1)) / r2 : 100 } }));
          }, s.prototype.openedSource = function(e2) {
            this.currentSourceOffset = this.bytesWritten, this.currentFile = e2.file.name;
            var t2 = this.streamFiles && !e2.file.dir;
            if (t2) {
              var r2 = n(e2, t2, false, this.currentSourceOffset, this.zipPlatform, this.encodeFileName);
              this.push({ data: r2.fileRecord, meta: { percent: 0 } });
            } else this.accumulate = true;
          }, s.prototype.closedSource = function(e2) {
            this.accumulate = false;
            var t2 = this.streamFiles && !e2.file.dir, r2 = n(e2, t2, true, this.currentSourceOffset, this.zipPlatform, this.encodeFileName);
            if (this.dirRecords.push(r2.dirRecord), t2) this.push({ data: (function(e3) {
              return R.DATA_DESCRIPTOR + A(e3.crc32, 4) + A(e3.compressedSize, 4) + A(e3.uncompressedSize, 4);
            })(e2), meta: { percent: 100 } });
            else for (this.push({ data: r2.fileRecord, meta: { percent: 0 } }); this.contentBuffer.length; ) this.push(this.contentBuffer.shift());
            this.currentFile = null;
          }, s.prototype.flush = function() {
            for (var e2 = this.bytesWritten, t2 = 0; t2 < this.dirRecords.length; t2++) this.push({ data: this.dirRecords[t2], meta: { percent: 100 } });
            var r2 = this.bytesWritten - e2, n2 = (function(e3, t3, r3, n3, i2) {
              var s2 = I.transformTo("string", i2(n3));
              return R.CENTRAL_DIRECTORY_END + "\0\0\0\0" + A(e3, 2) + A(e3, 2) + A(t3, 4) + A(r3, 4) + A(s2.length, 2) + s2;
            })(this.dirRecords.length, r2, e2, this.zipComment, this.encodeFileName);
            this.push({ data: n2, meta: { percent: 100 } });
          }, s.prototype.prepareNextSource = function() {
            this.previous = this._sources.shift(), this.openedSource(this.previous.streamInfo), this.isPaused ? this.previous.pause() : this.previous.resume();
          }, s.prototype.registerPrevious = function(e2) {
            this._sources.push(e2);
            var t2 = this;
            return e2.on("data", function(e3) {
              t2.processChunk(e3);
            }), e2.on("end", function() {
              t2.closedSource(t2.previous.streamInfo), t2._sources.length ? t2.prepareNextSource() : t2.end();
            }), e2.on("error", function(e3) {
              t2.error(e3);
            }), this;
          }, s.prototype.resume = function() {
            return !!i.prototype.resume.call(this) && (!this.previous && this._sources.length ? (this.prepareNextSource(), true) : this.previous || this._sources.length || this.generatedError ? void 0 : (this.end(), true));
          }, s.prototype.error = function(e2) {
            var t2 = this._sources;
            if (!i.prototype.error.call(this, e2)) return false;
            for (var r2 = 0; r2 < t2.length; r2++) try {
              t2[r2].error(e2);
            } catch (e3) {
            }
            return true;
          }, s.prototype.lock = function() {
            i.prototype.lock.call(this);
            for (var e2 = this._sources, t2 = 0; t2 < e2.length; t2++) e2[t2].lock();
          }, t.exports = s;
        }, { "../crc32": 4, "../signature": 23, "../stream/GenericWorker": 28, "../utf8": 31, "../utils": 32 }], 9: [function(e, t, r) {
          "use strict";
          var u = e("../compressions"), n = e("./ZipFileWorker");
          r.generateWorker = function(e2, a, t2) {
            var o = new n(a.streamFiles, t2, a.platform, a.encodeFileName), h = 0;
            try {
              e2.forEach(function(e3, t3) {
                h++;
                var r2 = (function(e4, t4) {
                  var r3 = e4 || t4, n3 = u[r3];
                  if (!n3) throw new Error(r3 + " is not a valid compression method !");
                  return n3;
                })(t3.options.compression, a.compression), n2 = t3.options.compressionOptions || a.compressionOptions || {}, i = t3.dir, s = t3.date;
                t3._compressWorker(r2, n2).withStreamInfo("file", { name: e3, dir: i, date: s, comment: t3.comment || "", unixPermissions: t3.unixPermissions, dosPermissions: t3.dosPermissions }).pipe(o);
              }), o.entriesCount = h;
            } catch (e3) {
              o.error(e3);
            }
            return o;
          };
        }, { "../compressions": 3, "./ZipFileWorker": 8 }], 10: [function(e, t, r) {
          "use strict";
          function n() {
            if (!(this instanceof n)) return new n();
            if (arguments.length) throw new Error("The constructor with parameters has been removed in JSZip 3.0, please check the upgrade guide.");
            this.files = /* @__PURE__ */ Object.create(null), this.comment = null, this.root = "", this.clone = function() {
              var e2 = new n();
              for (var t2 in this) "function" != typeof this[t2] && (e2[t2] = this[t2]);
              return e2;
            };
          }
          (n.prototype = e("./object")).loadAsync = e("./load"), n.support = e("./support"), n.defaults = e("./defaults"), n.version = "3.10.1", n.loadAsync = function(e2, t2) {
            return new n().loadAsync(e2, t2);
          }, n.external = e("./external"), t.exports = n;
        }, { "./defaults": 5, "./external": 6, "./load": 11, "./object": 15, "./support": 30 }], 11: [function(e, t, r) {
          "use strict";
          var u = e("./utils"), i = e("./external"), n = e("./utf8"), s = e("./zipEntries"), a = e("./stream/Crc32Probe"), l = e("./nodejsUtils");
          function f(n2) {
            return new i.Promise(function(e2, t2) {
              var r2 = n2.decompressed.getContentWorker().pipe(new a());
              r2.on("error", function(e3) {
                t2(e3);
              }).on("end", function() {
                r2.streamInfo.crc32 !== n2.decompressed.crc32 ? t2(new Error("Corrupted zip : CRC32 mismatch")) : e2();
              }).resume();
            });
          }
          t.exports = function(e2, o) {
            var h = this;
            return o = u.extend(o || {}, { base64: false, checkCRC32: false, optimizedBinaryString: false, createFolders: false, decodeFileName: n.utf8decode }), l.isNode && l.isStream(e2) ? i.Promise.reject(new Error("JSZip can't accept a stream when loading a zip file.")) : u.prepareContent("the loaded zip file", e2, true, o.optimizedBinaryString, o.base64).then(function(e3) {
              var t2 = new s(o);
              return t2.load(e3), t2;
            }).then(function(e3) {
              var t2 = [i.Promise.resolve(e3)], r2 = e3.files;
              if (o.checkCRC32) for (var n2 = 0; n2 < r2.length; n2++) t2.push(f(r2[n2]));
              return i.Promise.all(t2);
            }).then(function(e3) {
              for (var t2 = e3.shift(), r2 = t2.files, n2 = 0; n2 < r2.length; n2++) {
                var i2 = r2[n2], s2 = i2.fileNameStr, a2 = u.resolve(i2.fileNameStr);
                h.file(a2, i2.decompressed, { binary: true, optimizedBinaryString: true, date: i2.date, dir: i2.dir, comment: i2.fileCommentStr.length ? i2.fileCommentStr : null, unixPermissions: i2.unixPermissions, dosPermissions: i2.dosPermissions, createFolders: o.createFolders }), i2.dir || (h.file(a2).unsafeOriginalName = s2);
              }
              return t2.zipComment.length && (h.comment = t2.zipComment), h;
            });
          };
        }, { "./external": 6, "./nodejsUtils": 14, "./stream/Crc32Probe": 25, "./utf8": 31, "./utils": 32, "./zipEntries": 33 }], 12: [function(e, t, r) {
          "use strict";
          var n = e("../utils"), i = e("../stream/GenericWorker");
          function s(e2, t2) {
            i.call(this, "Nodejs stream input adapter for " + e2), this._upstreamEnded = false, this._bindStream(t2);
          }
          n.inherits(s, i), s.prototype._bindStream = function(e2) {
            var t2 = this;
            (this._stream = e2).pause(), e2.on("data", function(e3) {
              t2.push({ data: e3, meta: { percent: 0 } });
            }).on("error", function(e3) {
              t2.isPaused ? this.generatedError = e3 : t2.error(e3);
            }).on("end", function() {
              t2.isPaused ? t2._upstreamEnded = true : t2.end();
            });
          }, s.prototype.pause = function() {
            return !!i.prototype.pause.call(this) && (this._stream.pause(), true);
          }, s.prototype.resume = function() {
            return !!i.prototype.resume.call(this) && (this._upstreamEnded ? this.end() : this._stream.resume(), true);
          }, t.exports = s;
        }, { "../stream/GenericWorker": 28, "../utils": 32 }], 13: [function(e, t, r) {
          "use strict";
          var i = e("readable-stream").Readable;
          function n(e2, t2, r2) {
            i.call(this, t2), this._helper = e2;
            var n2 = this;
            e2.on("data", function(e3, t3) {
              n2.push(e3) || n2._helper.pause(), r2 && r2(t3);
            }).on("error", function(e3) {
              n2.emit("error", e3);
            }).on("end", function() {
              n2.push(null);
            });
          }
          e("../utils").inherits(n, i), n.prototype._read = function() {
            this._helper.resume();
          }, t.exports = n;
        }, { "../utils": 32, "readable-stream": 16 }], 14: [function(e, t, r) {
          "use strict";
          t.exports = { isNode: "undefined" != typeof Buffer, newBufferFrom: function(e2, t2) {
            if (Buffer.from && Buffer.from !== Uint8Array.from) return Buffer.from(e2, t2);
            if ("number" == typeof e2) throw new Error('The "data" argument must not be a number');
            return new Buffer(e2, t2);
          }, allocBuffer: function(e2) {
            if (Buffer.alloc) return Buffer.alloc(e2);
            var t2 = new Buffer(e2);
            return t2.fill(0), t2;
          }, isBuffer: function(e2) {
            return Buffer.isBuffer(e2);
          }, isStream: function(e2) {
            return e2 && "function" == typeof e2.on && "function" == typeof e2.pause && "function" == typeof e2.resume;
          } };
        }, {}], 15: [function(e, t, r) {
          "use strict";
          function s(e2, t2, r2) {
            var n2, i2 = u.getTypeOf(t2), s2 = u.extend(r2 || {}, f);
            s2.date = s2.date || /* @__PURE__ */ new Date(), null !== s2.compression && (s2.compression = s2.compression.toUpperCase()), "string" == typeof s2.unixPermissions && (s2.unixPermissions = parseInt(s2.unixPermissions, 8)), s2.unixPermissions && 16384 & s2.unixPermissions && (s2.dir = true), s2.dosPermissions && 16 & s2.dosPermissions && (s2.dir = true), s2.dir && (e2 = g(e2)), s2.createFolders && (n2 = _3(e2)) && b.call(this, n2, true);
            var a2 = "string" === i2 && false === s2.binary && false === s2.base64;
            r2 && void 0 !== r2.binary || (s2.binary = !a2), (t2 instanceof c && 0 === t2.uncompressedSize || s2.dir || !t2 || 0 === t2.length) && (s2.base64 = false, s2.binary = true, t2 = "", s2.compression = "STORE", i2 = "string");
            var o2 = null;
            o2 = t2 instanceof c || t2 instanceof l ? t2 : p.isNode && p.isStream(t2) ? new m(e2, t2) : u.prepareContent(e2, t2, s2.binary, s2.optimizedBinaryString, s2.base64);
            var h2 = new d(e2, o2, s2);
            this.files[e2] = h2;
          }
          var i = e("./utf8"), u = e("./utils"), l = e("./stream/GenericWorker"), a = e("./stream/StreamHelper"), f = e("./defaults"), c = e("./compressedObject"), d = e("./zipObject"), o = e("./generate"), p = e("./nodejsUtils"), m = e("./nodejs/NodejsStreamInputAdapter"), _3 = function(e2) {
            "/" === e2.slice(-1) && (e2 = e2.substring(0, e2.length - 1));
            var t2 = e2.lastIndexOf("/");
            return 0 < t2 ? e2.substring(0, t2) : "";
          }, g = function(e2) {
            return "/" !== e2.slice(-1) && (e2 += "/"), e2;
          }, b = function(e2, t2) {
            return t2 = void 0 !== t2 ? t2 : f.createFolders, e2 = g(e2), this.files[e2] || s.call(this, e2, null, { dir: true, createFolders: t2 }), this.files[e2];
          };
          function h(e2) {
            return "[object RegExp]" === Object.prototype.toString.call(e2);
          }
          var n = { load: function() {
            throw new Error("This method has been removed in JSZip 3.0, please check the upgrade guide.");
          }, forEach: function(e2) {
            var t2, r2, n2;
            for (t2 in this.files) n2 = this.files[t2], (r2 = t2.slice(this.root.length, t2.length)) && t2.slice(0, this.root.length) === this.root && e2(r2, n2);
          }, filter: function(r2) {
            var n2 = [];
            return this.forEach(function(e2, t2) {
              r2(e2, t2) && n2.push(t2);
            }), n2;
          }, file: function(e2, t2, r2) {
            if (1 !== arguments.length) return e2 = this.root + e2, s.call(this, e2, t2, r2), this;
            if (h(e2)) {
              var n2 = e2;
              return this.filter(function(e3, t3) {
                return !t3.dir && n2.test(e3);
              });
            }
            var i2 = this.files[this.root + e2];
            return i2 && !i2.dir ? i2 : null;
          }, folder: function(r2) {
            if (!r2) return this;
            if (h(r2)) return this.filter(function(e3, t3) {
              return t3.dir && r2.test(e3);
            });
            var e2 = this.root + r2, t2 = b.call(this, e2), n2 = this.clone();
            return n2.root = t2.name, n2;
          }, remove: function(r2) {
            r2 = this.root + r2;
            var e2 = this.files[r2];
            if (e2 || ("/" !== r2.slice(-1) && (r2 += "/"), e2 = this.files[r2]), e2 && !e2.dir) delete this.files[r2];
            else for (var t2 = this.filter(function(e3, t3) {
              return t3.name.slice(0, r2.length) === r2;
            }), n2 = 0; n2 < t2.length; n2++) delete this.files[t2[n2].name];
            return this;
          }, generate: function() {
            throw new Error("This method has been removed in JSZip 3.0, please check the upgrade guide.");
          }, generateInternalStream: function(e2) {
            var t2, r2 = {};
            try {
              if ((r2 = u.extend(e2 || {}, { streamFiles: false, compression: "STORE", compressionOptions: null, type: "", platform: "DOS", comment: null, mimeType: "application/zip", encodeFileName: i.utf8encode })).type = r2.type.toLowerCase(), r2.compression = r2.compression.toUpperCase(), "binarystring" === r2.type && (r2.type = "string"), !r2.type) throw new Error("No output type specified.");
              u.checkSupport(r2.type), "darwin" !== r2.platform && "freebsd" !== r2.platform && "linux" !== r2.platform && "sunos" !== r2.platform || (r2.platform = "UNIX"), "win32" === r2.platform && (r2.platform = "DOS");
              var n2 = r2.comment || this.comment || "";
              t2 = o.generateWorker(this, r2, n2);
            } catch (e3) {
              (t2 = new l("error")).error(e3);
            }
            return new a(t2, r2.type || "string", r2.mimeType);
          }, generateAsync: function(e2, t2) {
            return this.generateInternalStream(e2).accumulate(t2);
          }, generateNodeStream: function(e2, t2) {
            return (e2 = e2 || {}).type || (e2.type = "nodebuffer"), this.generateInternalStream(e2).toNodejsStream(t2);
          } };
          t.exports = n;
        }, { "./compressedObject": 2, "./defaults": 5, "./generate": 9, "./nodejs/NodejsStreamInputAdapter": 12, "./nodejsUtils": 14, "./stream/GenericWorker": 28, "./stream/StreamHelper": 29, "./utf8": 31, "./utils": 32, "./zipObject": 35 }], 16: [function(e, t, r) {
          "use strict";
          t.exports = e("stream");
        }, { stream: void 0 }], 17: [function(e, t, r) {
          "use strict";
          var n = e("./DataReader");
          function i(e2) {
            n.call(this, e2);
            for (var t2 = 0; t2 < this.data.length; t2++) e2[t2] = 255 & e2[t2];
          }
          e("../utils").inherits(i, n), i.prototype.byteAt = function(e2) {
            return this.data[this.zero + e2];
          }, i.prototype.lastIndexOfSignature = function(e2) {
            for (var t2 = e2.charCodeAt(0), r2 = e2.charCodeAt(1), n2 = e2.charCodeAt(2), i2 = e2.charCodeAt(3), s = this.length - 4; 0 <= s; --s) if (this.data[s] === t2 && this.data[s + 1] === r2 && this.data[s + 2] === n2 && this.data[s + 3] === i2) return s - this.zero;
            return -1;
          }, i.prototype.readAndCheckSignature = function(e2) {
            var t2 = e2.charCodeAt(0), r2 = e2.charCodeAt(1), n2 = e2.charCodeAt(2), i2 = e2.charCodeAt(3), s = this.readData(4);
            return t2 === s[0] && r2 === s[1] && n2 === s[2] && i2 === s[3];
          }, i.prototype.readData = function(e2) {
            if (this.checkOffset(e2), 0 === e2) return [];
            var t2 = this.data.slice(this.zero + this.index, this.zero + this.index + e2);
            return this.index += e2, t2;
          }, t.exports = i;
        }, { "../utils": 32, "./DataReader": 18 }], 18: [function(e, t, r) {
          "use strict";
          var n = e("../utils");
          function i(e2) {
            this.data = e2, this.length = e2.length, this.index = 0, this.zero = 0;
          }
          i.prototype = { checkOffset: function(e2) {
            this.checkIndex(this.index + e2);
          }, checkIndex: function(e2) {
            if (this.length < this.zero + e2 || e2 < 0) throw new Error("End of data reached (data length = " + this.length + ", asked index = " + e2 + "). Corrupted zip ?");
          }, setIndex: function(e2) {
            this.checkIndex(e2), this.index = e2;
          }, skip: function(e2) {
            this.setIndex(this.index + e2);
          }, byteAt: function() {
          }, readInt: function(e2) {
            var t2, r2 = 0;
            for (this.checkOffset(e2), t2 = this.index + e2 - 1; t2 >= this.index; t2--) r2 = (r2 << 8) + this.byteAt(t2);
            return this.index += e2, r2;
          }, readString: function(e2) {
            return n.transformTo("string", this.readData(e2));
          }, readData: function() {
          }, lastIndexOfSignature: function() {
          }, readAndCheckSignature: function() {
          }, readDate: function() {
            var e2 = this.readInt(4);
            return new Date(Date.UTC(1980 + (e2 >> 25 & 127), (e2 >> 21 & 15) - 1, e2 >> 16 & 31, e2 >> 11 & 31, e2 >> 5 & 63, (31 & e2) << 1));
          } }, t.exports = i;
        }, { "../utils": 32 }], 19: [function(e, t, r) {
          "use strict";
          var n = e("./Uint8ArrayReader");
          function i(e2) {
            n.call(this, e2);
          }
          e("../utils").inherits(i, n), i.prototype.readData = function(e2) {
            this.checkOffset(e2);
            var t2 = this.data.slice(this.zero + this.index, this.zero + this.index + e2);
            return this.index += e2, t2;
          }, t.exports = i;
        }, { "../utils": 32, "./Uint8ArrayReader": 21 }], 20: [function(e, t, r) {
          "use strict";
          var n = e("./DataReader");
          function i(e2) {
            n.call(this, e2);
          }
          e("../utils").inherits(i, n), i.prototype.byteAt = function(e2) {
            return this.data.charCodeAt(this.zero + e2);
          }, i.prototype.lastIndexOfSignature = function(e2) {
            return this.data.lastIndexOf(e2) - this.zero;
          }, i.prototype.readAndCheckSignature = function(e2) {
            return e2 === this.readData(4);
          }, i.prototype.readData = function(e2) {
            this.checkOffset(e2);
            var t2 = this.data.slice(this.zero + this.index, this.zero + this.index + e2);
            return this.index += e2, t2;
          }, t.exports = i;
        }, { "../utils": 32, "./DataReader": 18 }], 21: [function(e, t, r) {
          "use strict";
          var n = e("./ArrayReader");
          function i(e2) {
            n.call(this, e2);
          }
          e("../utils").inherits(i, n), i.prototype.readData = function(e2) {
            if (this.checkOffset(e2), 0 === e2) return new Uint8Array(0);
            var t2 = this.data.subarray(this.zero + this.index, this.zero + this.index + e2);
            return this.index += e2, t2;
          }, t.exports = i;
        }, { "../utils": 32, "./ArrayReader": 17 }], 22: [function(e, t, r) {
          "use strict";
          var n = e("../utils"), i = e("../support"), s = e("./ArrayReader"), a = e("./StringReader"), o = e("./NodeBufferReader"), h = e("./Uint8ArrayReader");
          t.exports = function(e2) {
            var t2 = n.getTypeOf(e2);
            return n.checkSupport(t2), "string" !== t2 || i.uint8array ? "nodebuffer" === t2 ? new o(e2) : i.uint8array ? new h(n.transformTo("uint8array", e2)) : new s(n.transformTo("array", e2)) : new a(e2);
          };
        }, { "../support": 30, "../utils": 32, "./ArrayReader": 17, "./NodeBufferReader": 19, "./StringReader": 20, "./Uint8ArrayReader": 21 }], 23: [function(e, t, r) {
          "use strict";
          r.LOCAL_FILE_HEADER = "PK", r.CENTRAL_FILE_HEADER = "PK", r.CENTRAL_DIRECTORY_END = "PK", r.ZIP64_CENTRAL_DIRECTORY_LOCATOR = "PK\x07", r.ZIP64_CENTRAL_DIRECTORY_END = "PK", r.DATA_DESCRIPTOR = "PK\x07\b";
        }, {}], 24: [function(e, t, r) {
          "use strict";
          var n = e("./GenericWorker"), i = e("../utils");
          function s(e2) {
            n.call(this, "ConvertWorker to " + e2), this.destType = e2;
          }
          i.inherits(s, n), s.prototype.processChunk = function(e2) {
            this.push({ data: i.transformTo(this.destType, e2.data), meta: e2.meta });
          }, t.exports = s;
        }, { "../utils": 32, "./GenericWorker": 28 }], 25: [function(e, t, r) {
          "use strict";
          var n = e("./GenericWorker"), i = e("../crc32");
          function s() {
            n.call(this, "Crc32Probe"), this.withStreamInfo("crc32", 0);
          }
          e("../utils").inherits(s, n), s.prototype.processChunk = function(e2) {
            this.streamInfo.crc32 = i(e2.data, this.streamInfo.crc32 || 0), this.push(e2);
          }, t.exports = s;
        }, { "../crc32": 4, "../utils": 32, "./GenericWorker": 28 }], 26: [function(e, t, r) {
          "use strict";
          var n = e("../utils"), i = e("./GenericWorker");
          function s(e2) {
            i.call(this, "DataLengthProbe for " + e2), this.propName = e2, this.withStreamInfo(e2, 0);
          }
          n.inherits(s, i), s.prototype.processChunk = function(e2) {
            if (e2) {
              var t2 = this.streamInfo[this.propName] || 0;
              this.streamInfo[this.propName] = t2 + e2.data.length;
            }
            i.prototype.processChunk.call(this, e2);
          }, t.exports = s;
        }, { "../utils": 32, "./GenericWorker": 28 }], 27: [function(e, t, r) {
          "use strict";
          var n = e("../utils"), i = e("./GenericWorker");
          function s(e2) {
            i.call(this, "DataWorker");
            var t2 = this;
            this.dataIsReady = false, this.index = 0, this.max = 0, this.data = null, this.type = "", this._tickScheduled = false, e2.then(function(e3) {
              t2.dataIsReady = true, t2.data = e3, t2.max = e3 && e3.length || 0, t2.type = n.getTypeOf(e3), t2.isPaused || t2._tickAndRepeat();
            }, function(e3) {
              t2.error(e3);
            });
          }
          n.inherits(s, i), s.prototype.cleanUp = function() {
            i.prototype.cleanUp.call(this), this.data = null;
          }, s.prototype.resume = function() {
            return !!i.prototype.resume.call(this) && (!this._tickScheduled && this.dataIsReady && (this._tickScheduled = true, n.delay(this._tickAndRepeat, [], this)), true);
          }, s.prototype._tickAndRepeat = function() {
            this._tickScheduled = false, this.isPaused || this.isFinished || (this._tick(), this.isFinished || (n.delay(this._tickAndRepeat, [], this), this._tickScheduled = true));
          }, s.prototype._tick = function() {
            if (this.isPaused || this.isFinished) return false;
            var e2 = null, t2 = Math.min(this.max, this.index + 16384);
            if (this.index >= this.max) return this.end();
            switch (this.type) {
              case "string":
                e2 = this.data.substring(this.index, t2);
                break;
              case "uint8array":
                e2 = this.data.subarray(this.index, t2);
                break;
              case "array":
              case "nodebuffer":
                e2 = this.data.slice(this.index, t2);
            }
            return this.index = t2, this.push({ data: e2, meta: { percent: this.max ? this.index / this.max * 100 : 0 } });
          }, t.exports = s;
        }, { "../utils": 32, "./GenericWorker": 28 }], 28: [function(e, t, r) {
          "use strict";
          function n(e2) {
            this.name = e2 || "default", this.streamInfo = {}, this.generatedError = null, this.extraStreamInfo = {}, this.isPaused = true, this.isFinished = false, this.isLocked = false, this._listeners = { data: [], end: [], error: [] }, this.previous = null;
          }
          n.prototype = { push: function(e2) {
            this.emit("data", e2);
          }, end: function() {
            if (this.isFinished) return false;
            this.flush();
            try {
              this.emit("end"), this.cleanUp(), this.isFinished = true;
            } catch (e2) {
              this.emit("error", e2);
            }
            return true;
          }, error: function(e2) {
            return !this.isFinished && (this.isPaused ? this.generatedError = e2 : (this.isFinished = true, this.emit("error", e2), this.previous && this.previous.error(e2), this.cleanUp()), true);
          }, on: function(e2, t2) {
            return this._listeners[e2].push(t2), this;
          }, cleanUp: function() {
            this.streamInfo = this.generatedError = this.extraStreamInfo = null, this._listeners = [];
          }, emit: function(e2, t2) {
            if (this._listeners[e2]) for (var r2 = 0; r2 < this._listeners[e2].length; r2++) this._listeners[e2][r2].call(this, t2);
          }, pipe: function(e2) {
            return e2.registerPrevious(this);
          }, registerPrevious: function(e2) {
            if (this.isLocked) throw new Error("The stream '" + this + "' has already been used.");
            this.streamInfo = e2.streamInfo, this.mergeStreamInfo(), this.previous = e2;
            var t2 = this;
            return e2.on("data", function(e3) {
              t2.processChunk(e3);
            }), e2.on("end", function() {
              t2.end();
            }), e2.on("error", function(e3) {
              t2.error(e3);
            }), this;
          }, pause: function() {
            return !this.isPaused && !this.isFinished && (this.isPaused = true, this.previous && this.previous.pause(), true);
          }, resume: function() {
            if (!this.isPaused || this.isFinished) return false;
            var e2 = this.isPaused = false;
            return this.generatedError && (this.error(this.generatedError), e2 = true), this.previous && this.previous.resume(), !e2;
          }, flush: function() {
          }, processChunk: function(e2) {
            this.push(e2);
          }, withStreamInfo: function(e2, t2) {
            return this.extraStreamInfo[e2] = t2, this.mergeStreamInfo(), this;
          }, mergeStreamInfo: function() {
            for (var e2 in this.extraStreamInfo) Object.prototype.hasOwnProperty.call(this.extraStreamInfo, e2) && (this.streamInfo[e2] = this.extraStreamInfo[e2]);
          }, lock: function() {
            if (this.isLocked) throw new Error("The stream '" + this + "' has already been used.");
            this.isLocked = true, this.previous && this.previous.lock();
          }, toString: function() {
            var e2 = "Worker " + this.name;
            return this.previous ? this.previous + " -> " + e2 : e2;
          } }, t.exports = n;
        }, {}], 29: [function(e, t, r) {
          "use strict";
          var h = e("../utils"), i = e("./ConvertWorker"), s = e("./GenericWorker"), u = e("../base64"), n = e("../support"), a = e("../external"), o = null;
          if (n.nodestream) try {
            o = e("../nodejs/NodejsStreamOutputAdapter");
          } catch (e2) {
          }
          function l(e2, o2) {
            return new a.Promise(function(t2, r2) {
              var n2 = [], i2 = e2._internalType, s2 = e2._outputType, a2 = e2._mimeType;
              e2.on("data", function(e3, t3) {
                n2.push(e3), o2 && o2(t3);
              }).on("error", function(e3) {
                n2 = [], r2(e3);
              }).on("end", function() {
                try {
                  var e3 = (function(e4, t3, r3) {
                    switch (e4) {
                      case "blob":
                        return h.newBlob(h.transformTo("arraybuffer", t3), r3);
                      case "base64":
                        return u.encode(t3);
                      default:
                        return h.transformTo(e4, t3);
                    }
                  })(s2, (function(e4, t3) {
                    var r3, n3 = 0, i3 = null, s3 = 0;
                    for (r3 = 0; r3 < t3.length; r3++) s3 += t3[r3].length;
                    switch (e4) {
                      case "string":
                        return t3.join("");
                      case "array":
                        return Array.prototype.concat.apply([], t3);
                      case "uint8array":
                        for (i3 = new Uint8Array(s3), r3 = 0; r3 < t3.length; r3++) i3.set(t3[r3], n3), n3 += t3[r3].length;
                        return i3;
                      case "nodebuffer":
                        return Buffer.concat(t3);
                      default:
                        throw new Error("concat : unsupported type '" + e4 + "'");
                    }
                  })(i2, n2), a2);
                  t2(e3);
                } catch (e4) {
                  r2(e4);
                }
                n2 = [];
              }).resume();
            });
          }
          function f(e2, t2, r2) {
            var n2 = t2;
            switch (t2) {
              case "blob":
              case "arraybuffer":
                n2 = "uint8array";
                break;
              case "base64":
                n2 = "string";
            }
            try {
              this._internalType = n2, this._outputType = t2, this._mimeType = r2, h.checkSupport(n2), this._worker = e2.pipe(new i(n2)), e2.lock();
            } catch (e3) {
              this._worker = new s("error"), this._worker.error(e3);
            }
          }
          f.prototype = { accumulate: function(e2) {
            return l(this, e2);
          }, on: function(e2, t2) {
            var r2 = this;
            return "data" === e2 ? this._worker.on(e2, function(e3) {
              t2.call(r2, e3.data, e3.meta);
            }) : this._worker.on(e2, function() {
              h.delay(t2, arguments, r2);
            }), this;
          }, resume: function() {
            return h.delay(this._worker.resume, [], this._worker), this;
          }, pause: function() {
            return this._worker.pause(), this;
          }, toNodejsStream: function(e2) {
            if (h.checkSupport("nodestream"), "nodebuffer" !== this._outputType) throw new Error(this._outputType + " is not supported by this method");
            return new o(this, { objectMode: "nodebuffer" !== this._outputType }, e2);
          } }, t.exports = f;
        }, { "../base64": 1, "../external": 6, "../nodejs/NodejsStreamOutputAdapter": 13, "../support": 30, "../utils": 32, "./ConvertWorker": 24, "./GenericWorker": 28 }], 30: [function(e, t, r) {
          "use strict";
          if (r.base64 = true, r.array = true, r.string = true, r.arraybuffer = "undefined" != typeof ArrayBuffer && "undefined" != typeof Uint8Array, r.nodebuffer = "undefined" != typeof Buffer, r.uint8array = "undefined" != typeof Uint8Array, "undefined" == typeof ArrayBuffer) r.blob = false;
          else {
            var n = new ArrayBuffer(0);
            try {
              r.blob = 0 === new Blob([n], { type: "application/zip" }).size;
            } catch (e2) {
              try {
                var i = new (self.BlobBuilder || self.WebKitBlobBuilder || self.MozBlobBuilder || self.MSBlobBuilder)();
                i.append(n), r.blob = 0 === i.getBlob("application/zip").size;
              } catch (e3) {
                r.blob = false;
              }
            }
          }
          try {
            r.nodestream = !!e("readable-stream").Readable;
          } catch (e2) {
            r.nodestream = false;
          }
        }, { "readable-stream": 16 }], 31: [function(e, t, s) {
          "use strict";
          for (var o = e("./utils"), h = e("./support"), r = e("./nodejsUtils"), n = e("./stream/GenericWorker"), u = new Array(256), i = 0; i < 256; i++) u[i] = 252 <= i ? 6 : 248 <= i ? 5 : 240 <= i ? 4 : 224 <= i ? 3 : 192 <= i ? 2 : 1;
          u[254] = u[254] = 1;
          function a() {
            n.call(this, "utf-8 decode"), this.leftOver = null;
          }
          function l() {
            n.call(this, "utf-8 encode");
          }
          s.utf8encode = function(e2) {
            return h.nodebuffer ? r.newBufferFrom(e2, "utf-8") : (function(e3) {
              var t2, r2, n2, i2, s2, a2 = e3.length, o2 = 0;
              for (i2 = 0; i2 < a2; i2++) 55296 == (64512 & (r2 = e3.charCodeAt(i2))) && i2 + 1 < a2 && 56320 == (64512 & (n2 = e3.charCodeAt(i2 + 1))) && (r2 = 65536 + (r2 - 55296 << 10) + (n2 - 56320), i2++), o2 += r2 < 128 ? 1 : r2 < 2048 ? 2 : r2 < 65536 ? 3 : 4;
              for (t2 = h.uint8array ? new Uint8Array(o2) : new Array(o2), i2 = s2 = 0; s2 < o2; i2++) 55296 == (64512 & (r2 = e3.charCodeAt(i2))) && i2 + 1 < a2 && 56320 == (64512 & (n2 = e3.charCodeAt(i2 + 1))) && (r2 = 65536 + (r2 - 55296 << 10) + (n2 - 56320), i2++), r2 < 128 ? t2[s2++] = r2 : (r2 < 2048 ? t2[s2++] = 192 | r2 >>> 6 : (r2 < 65536 ? t2[s2++] = 224 | r2 >>> 12 : (t2[s2++] = 240 | r2 >>> 18, t2[s2++] = 128 | r2 >>> 12 & 63), t2[s2++] = 128 | r2 >>> 6 & 63), t2[s2++] = 128 | 63 & r2);
              return t2;
            })(e2);
          }, s.utf8decode = function(e2) {
            return h.nodebuffer ? o.transformTo("nodebuffer", e2).toString("utf-8") : (function(e3) {
              var t2, r2, n2, i2, s2 = e3.length, a2 = new Array(2 * s2);
              for (t2 = r2 = 0; t2 < s2; ) if ((n2 = e3[t2++]) < 128) a2[r2++] = n2;
              else if (4 < (i2 = u[n2])) a2[r2++] = 65533, t2 += i2 - 1;
              else {
                for (n2 &= 2 === i2 ? 31 : 3 === i2 ? 15 : 7; 1 < i2 && t2 < s2; ) n2 = n2 << 6 | 63 & e3[t2++], i2--;
                1 < i2 ? a2[r2++] = 65533 : n2 < 65536 ? a2[r2++] = n2 : (n2 -= 65536, a2[r2++] = 55296 | n2 >> 10 & 1023, a2[r2++] = 56320 | 1023 & n2);
              }
              return a2.length !== r2 && (a2.subarray ? a2 = a2.subarray(0, r2) : a2.length = r2), o.applyFromCharCode(a2);
            })(e2 = o.transformTo(h.uint8array ? "uint8array" : "array", e2));
          }, o.inherits(a, n), a.prototype.processChunk = function(e2) {
            var t2 = o.transformTo(h.uint8array ? "uint8array" : "array", e2.data);
            if (this.leftOver && this.leftOver.length) {
              if (h.uint8array) {
                var r2 = t2;
                (t2 = new Uint8Array(r2.length + this.leftOver.length)).set(this.leftOver, 0), t2.set(r2, this.leftOver.length);
              } else t2 = this.leftOver.concat(t2);
              this.leftOver = null;
            }
            var n2 = (function(e3, t3) {
              var r3;
              for ((t3 = t3 || e3.length) > e3.length && (t3 = e3.length), r3 = t3 - 1; 0 <= r3 && 128 == (192 & e3[r3]); ) r3--;
              return r3 < 0 ? t3 : 0 === r3 ? t3 : r3 + u[e3[r3]] > t3 ? r3 : t3;
            })(t2), i2 = t2;
            n2 !== t2.length && (h.uint8array ? (i2 = t2.subarray(0, n2), this.leftOver = t2.subarray(n2, t2.length)) : (i2 = t2.slice(0, n2), this.leftOver = t2.slice(n2, t2.length))), this.push({ data: s.utf8decode(i2), meta: e2.meta });
          }, a.prototype.flush = function() {
            this.leftOver && this.leftOver.length && (this.push({ data: s.utf8decode(this.leftOver), meta: {} }), this.leftOver = null);
          }, s.Utf8DecodeWorker = a, o.inherits(l, n), l.prototype.processChunk = function(e2) {
            this.push({ data: s.utf8encode(e2.data), meta: e2.meta });
          }, s.Utf8EncodeWorker = l;
        }, { "./nodejsUtils": 14, "./stream/GenericWorker": 28, "./support": 30, "./utils": 32 }], 32: [function(e, t, a) {
          "use strict";
          var o = e("./support"), h = e("./base64"), r = e("./nodejsUtils"), u = e("./external");
          function n(e2) {
            return e2;
          }
          function l(e2, t2) {
            for (var r2 = 0; r2 < e2.length; ++r2) t2[r2] = 255 & e2.charCodeAt(r2);
            return t2;
          }
          e("setimmediate"), a.newBlob = function(t2, r2) {
            a.checkSupport("blob");
            try {
              return new Blob([t2], { type: r2 });
            } catch (e2) {
              try {
                var n2 = new (self.BlobBuilder || self.WebKitBlobBuilder || self.MozBlobBuilder || self.MSBlobBuilder)();
                return n2.append(t2), n2.getBlob(r2);
              } catch (e3) {
                throw new Error("Bug : can't construct the Blob.");
              }
            }
          };
          var i = { stringifyByChunk: function(e2, t2, r2) {
            var n2 = [], i2 = 0, s2 = e2.length;
            if (s2 <= r2) return String.fromCharCode.apply(null, e2);
            for (; i2 < s2; ) "array" === t2 || "nodebuffer" === t2 ? n2.push(String.fromCharCode.apply(null, e2.slice(i2, Math.min(i2 + r2, s2)))) : n2.push(String.fromCharCode.apply(null, e2.subarray(i2, Math.min(i2 + r2, s2)))), i2 += r2;
            return n2.join("");
          }, stringifyByChar: function(e2) {
            for (var t2 = "", r2 = 0; r2 < e2.length; r2++) t2 += String.fromCharCode(e2[r2]);
            return t2;
          }, applyCanBeUsed: { uint8array: (function() {
            try {
              return o.uint8array && 1 === String.fromCharCode.apply(null, new Uint8Array(1)).length;
            } catch (e2) {
              return false;
            }
          })(), nodebuffer: (function() {
            try {
              return o.nodebuffer && 1 === String.fromCharCode.apply(null, r.allocBuffer(1)).length;
            } catch (e2) {
              return false;
            }
          })() } };
          function s(e2) {
            var t2 = 65536, r2 = a.getTypeOf(e2), n2 = true;
            if ("uint8array" === r2 ? n2 = i.applyCanBeUsed.uint8array : "nodebuffer" === r2 && (n2 = i.applyCanBeUsed.nodebuffer), n2) for (; 1 < t2; ) try {
              return i.stringifyByChunk(e2, r2, t2);
            } catch (e3) {
              t2 = Math.floor(t2 / 2);
            }
            return i.stringifyByChar(e2);
          }
          function f(e2, t2) {
            for (var r2 = 0; r2 < e2.length; r2++) t2[r2] = e2[r2];
            return t2;
          }
          a.applyFromCharCode = s;
          var c = {};
          c.string = { string: n, array: function(e2) {
            return l(e2, new Array(e2.length));
          }, arraybuffer: function(e2) {
            return c.string.uint8array(e2).buffer;
          }, uint8array: function(e2) {
            return l(e2, new Uint8Array(e2.length));
          }, nodebuffer: function(e2) {
            return l(e2, r.allocBuffer(e2.length));
          } }, c.array = { string: s, array: n, arraybuffer: function(e2) {
            return new Uint8Array(e2).buffer;
          }, uint8array: function(e2) {
            return new Uint8Array(e2);
          }, nodebuffer: function(e2) {
            return r.newBufferFrom(e2);
          } }, c.arraybuffer = { string: function(e2) {
            return s(new Uint8Array(e2));
          }, array: function(e2) {
            return f(new Uint8Array(e2), new Array(e2.byteLength));
          }, arraybuffer: n, uint8array: function(e2) {
            return new Uint8Array(e2);
          }, nodebuffer: function(e2) {
            return r.newBufferFrom(new Uint8Array(e2));
          } }, c.uint8array = { string: s, array: function(e2) {
            return f(e2, new Array(e2.length));
          }, arraybuffer: function(e2) {
            return e2.buffer;
          }, uint8array: n, nodebuffer: function(e2) {
            return r.newBufferFrom(e2);
          } }, c.nodebuffer = { string: s, array: function(e2) {
            return f(e2, new Array(e2.length));
          }, arraybuffer: function(e2) {
            return c.nodebuffer.uint8array(e2).buffer;
          }, uint8array: function(e2) {
            return f(e2, new Uint8Array(e2.length));
          }, nodebuffer: n }, a.transformTo = function(e2, t2) {
            if (t2 = t2 || "", !e2) return t2;
            a.checkSupport(e2);
            var r2 = a.getTypeOf(t2);
            return c[r2][e2](t2);
          }, a.resolve = function(e2) {
            for (var t2 = e2.split("/"), r2 = [], n2 = 0; n2 < t2.length; n2++) {
              var i2 = t2[n2];
              "." === i2 || "" === i2 && 0 !== n2 && n2 !== t2.length - 1 || (".." === i2 ? r2.pop() : r2.push(i2));
            }
            return r2.join("/");
          }, a.getTypeOf = function(e2) {
            return "string" == typeof e2 ? "string" : "[object Array]" === Object.prototype.toString.call(e2) ? "array" : o.nodebuffer && r.isBuffer(e2) ? "nodebuffer" : o.uint8array && e2 instanceof Uint8Array ? "uint8array" : o.arraybuffer && e2 instanceof ArrayBuffer ? "arraybuffer" : void 0;
          }, a.checkSupport = function(e2) {
            if (!o[e2.toLowerCase()]) throw new Error(e2 + " is not supported by this platform");
          }, a.MAX_VALUE_16BITS = 65535, a.MAX_VALUE_32BITS = -1, a.pretty = function(e2) {
            var t2, r2, n2 = "";
            for (r2 = 0; r2 < (e2 || "").length; r2++) n2 += "\\x" + ((t2 = e2.charCodeAt(r2)) < 16 ? "0" : "") + t2.toString(16).toUpperCase();
            return n2;
          }, a.delay = function(e2, t2, r2) {
            setImmediate(function() {
              e2.apply(r2 || null, t2 || []);
            });
          }, a.inherits = function(e2, t2) {
            function r2() {
            }
            r2.prototype = t2.prototype, e2.prototype = new r2();
          }, a.extend = function() {
            var e2, t2, r2 = {};
            for (e2 = 0; e2 < arguments.length; e2++) for (t2 in arguments[e2]) Object.prototype.hasOwnProperty.call(arguments[e2], t2) && void 0 === r2[t2] && (r2[t2] = arguments[e2][t2]);
            return r2;
          }, a.prepareContent = function(r2, e2, n2, i2, s2) {
            return u.Promise.resolve(e2).then(function(n3) {
              return o.blob && (n3 instanceof Blob || -1 !== ["[object File]", "[object Blob]"].indexOf(Object.prototype.toString.call(n3))) && "undefined" != typeof FileReader ? new u.Promise(function(t2, r3) {
                var e3 = new FileReader();
                e3.onload = function(e4) {
                  t2(e4.target.result);
                }, e3.onerror = function(e4) {
                  r3(e4.target.error);
                }, e3.readAsArrayBuffer(n3);
              }) : n3;
            }).then(function(e3) {
              var t2 = a.getTypeOf(e3);
              return t2 ? ("arraybuffer" === t2 ? e3 = a.transformTo("uint8array", e3) : "string" === t2 && (s2 ? e3 = h.decode(e3) : n2 && true !== i2 && (e3 = (function(e4) {
                return l(e4, o.uint8array ? new Uint8Array(e4.length) : new Array(e4.length));
              })(e3))), e3) : u.Promise.reject(new Error("Can't read the data of '" + r2 + "'. Is it in a supported JavaScript type (String, Blob, ArrayBuffer, etc) ?"));
            });
          };
        }, { "./base64": 1, "./external": 6, "./nodejsUtils": 14, "./support": 30, setimmediate: 54 }], 33: [function(e, t, r) {
          "use strict";
          var n = e("./reader/readerFor"), i = e("./utils"), s = e("./signature"), a = e("./zipEntry"), o = e("./support");
          function h(e2) {
            this.files = [], this.loadOptions = e2;
          }
          h.prototype = { checkSignature: function(e2) {
            if (!this.reader.readAndCheckSignature(e2)) {
              this.reader.index -= 4;
              var t2 = this.reader.readString(4);
              throw new Error("Corrupted zip or bug: unexpected signature (" + i.pretty(t2) + ", expected " + i.pretty(e2) + ")");
            }
          }, isSignature: function(e2, t2) {
            var r2 = this.reader.index;
            this.reader.setIndex(e2);
            var n2 = this.reader.readString(4) === t2;
            return this.reader.setIndex(r2), n2;
          }, readBlockEndOfCentral: function() {
            this.diskNumber = this.reader.readInt(2), this.diskWithCentralDirStart = this.reader.readInt(2), this.centralDirRecordsOnThisDisk = this.reader.readInt(2), this.centralDirRecords = this.reader.readInt(2), this.centralDirSize = this.reader.readInt(4), this.centralDirOffset = this.reader.readInt(4), this.zipCommentLength = this.reader.readInt(2);
            var e2 = this.reader.readData(this.zipCommentLength), t2 = o.uint8array ? "uint8array" : "array", r2 = i.transformTo(t2, e2);
            this.zipComment = this.loadOptions.decodeFileName(r2);
          }, readBlockZip64EndOfCentral: function() {
            this.zip64EndOfCentralSize = this.reader.readInt(8), this.reader.skip(4), this.diskNumber = this.reader.readInt(4), this.diskWithCentralDirStart = this.reader.readInt(4), this.centralDirRecordsOnThisDisk = this.reader.readInt(8), this.centralDirRecords = this.reader.readInt(8), this.centralDirSize = this.reader.readInt(8), this.centralDirOffset = this.reader.readInt(8), this.zip64ExtensibleData = {};
            for (var e2, t2, r2, n2 = this.zip64EndOfCentralSize - 44; 0 < n2; ) e2 = this.reader.readInt(2), t2 = this.reader.readInt(4), r2 = this.reader.readData(t2), this.zip64ExtensibleData[e2] = { id: e2, length: t2, value: r2 };
          }, readBlockZip64EndOfCentralLocator: function() {
            if (this.diskWithZip64CentralDirStart = this.reader.readInt(4), this.relativeOffsetEndOfZip64CentralDir = this.reader.readInt(8), this.disksCount = this.reader.readInt(4), 1 < this.disksCount) throw new Error("Multi-volumes zip are not supported");
          }, readLocalFiles: function() {
            var e2, t2;
            for (e2 = 0; e2 < this.files.length; e2++) t2 = this.files[e2], this.reader.setIndex(t2.localHeaderOffset), this.checkSignature(s.LOCAL_FILE_HEADER), t2.readLocalPart(this.reader), t2.handleUTF8(), t2.processAttributes();
          }, readCentralDir: function() {
            var e2;
            for (this.reader.setIndex(this.centralDirOffset); this.reader.readAndCheckSignature(s.CENTRAL_FILE_HEADER); ) (e2 = new a({ zip64: this.zip64 }, this.loadOptions)).readCentralPart(this.reader), this.files.push(e2);
            if (this.centralDirRecords !== this.files.length && 0 !== this.centralDirRecords && 0 === this.files.length) throw new Error("Corrupted zip or bug: expected " + this.centralDirRecords + " records in central dir, got " + this.files.length);
          }, readEndOfCentral: function() {
            var e2 = this.reader.lastIndexOfSignature(s.CENTRAL_DIRECTORY_END);
            if (e2 < 0) throw !this.isSignature(0, s.LOCAL_FILE_HEADER) ? new Error("Can't find end of central directory : is this a zip file ? If it is, see https://stuk.github.io/jszip/documentation/howto/read_zip.html") : new Error("Corrupted zip: can't find end of central directory");
            this.reader.setIndex(e2);
            var t2 = e2;
            if (this.checkSignature(s.CENTRAL_DIRECTORY_END), this.readBlockEndOfCentral(), this.diskNumber === i.MAX_VALUE_16BITS || this.diskWithCentralDirStart === i.MAX_VALUE_16BITS || this.centralDirRecordsOnThisDisk === i.MAX_VALUE_16BITS || this.centralDirRecords === i.MAX_VALUE_16BITS || this.centralDirSize === i.MAX_VALUE_32BITS || this.centralDirOffset === i.MAX_VALUE_32BITS) {
              if (this.zip64 = true, (e2 = this.reader.lastIndexOfSignature(s.ZIP64_CENTRAL_DIRECTORY_LOCATOR)) < 0) throw new Error("Corrupted zip: can't find the ZIP64 end of central directory locator");
              if (this.reader.setIndex(e2), this.checkSignature(s.ZIP64_CENTRAL_DIRECTORY_LOCATOR), this.readBlockZip64EndOfCentralLocator(), !this.isSignature(this.relativeOffsetEndOfZip64CentralDir, s.ZIP64_CENTRAL_DIRECTORY_END) && (this.relativeOffsetEndOfZip64CentralDir = this.reader.lastIndexOfSignature(s.ZIP64_CENTRAL_DIRECTORY_END), this.relativeOffsetEndOfZip64CentralDir < 0)) throw new Error("Corrupted zip: can't find the ZIP64 end of central directory");
              this.reader.setIndex(this.relativeOffsetEndOfZip64CentralDir), this.checkSignature(s.ZIP64_CENTRAL_DIRECTORY_END), this.readBlockZip64EndOfCentral();
            }
            var r2 = this.centralDirOffset + this.centralDirSize;
            this.zip64 && (r2 += 20, r2 += 12 + this.zip64EndOfCentralSize);
            var n2 = t2 - r2;
            if (0 < n2) this.isSignature(t2, s.CENTRAL_FILE_HEADER) || (this.reader.zero = n2);
            else if (n2 < 0) throw new Error("Corrupted zip: missing " + Math.abs(n2) + " bytes.");
          }, prepareReader: function(e2) {
            this.reader = n(e2);
          }, load: function(e2) {
            this.prepareReader(e2), this.readEndOfCentral(), this.readCentralDir(), this.readLocalFiles();
          } }, t.exports = h;
        }, { "./reader/readerFor": 22, "./signature": 23, "./support": 30, "./utils": 32, "./zipEntry": 34 }], 34: [function(e, t, r) {
          "use strict";
          var n = e("./reader/readerFor"), s = e("./utils"), i = e("./compressedObject"), a = e("./crc32"), o = e("./utf8"), h = e("./compressions"), u = e("./support");
          function l(e2, t2) {
            this.options = e2, this.loadOptions = t2;
          }
          l.prototype = { isEncrypted: function() {
            return 1 == (1 & this.bitFlag);
          }, useUTF8: function() {
            return 2048 == (2048 & this.bitFlag);
          }, readLocalPart: function(e2) {
            var t2, r2;
            if (e2.skip(22), this.fileNameLength = e2.readInt(2), r2 = e2.readInt(2), this.fileName = e2.readData(this.fileNameLength), e2.skip(r2), -1 === this.compressedSize || -1 === this.uncompressedSize) throw new Error("Bug or corrupted zip : didn't get enough information from the central directory (compressedSize === -1 || uncompressedSize === -1)");
            if (null === (t2 = (function(e3) {
              for (var t3 in h) if (Object.prototype.hasOwnProperty.call(h, t3) && h[t3].magic === e3) return h[t3];
              return null;
            })(this.compressionMethod))) throw new Error("Corrupted zip : compression " + s.pretty(this.compressionMethod) + " unknown (inner file : " + s.transformTo("string", this.fileName) + ")");
            this.decompressed = new i(this.compressedSize, this.uncompressedSize, this.crc32, t2, e2.readData(this.compressedSize));
          }, readCentralPart: function(e2) {
            this.versionMadeBy = e2.readInt(2), e2.skip(2), this.bitFlag = e2.readInt(2), this.compressionMethod = e2.readString(2), this.date = e2.readDate(), this.crc32 = e2.readInt(4), this.compressedSize = e2.readInt(4), this.uncompressedSize = e2.readInt(4);
            var t2 = e2.readInt(2);
            if (this.extraFieldsLength = e2.readInt(2), this.fileCommentLength = e2.readInt(2), this.diskNumberStart = e2.readInt(2), this.internalFileAttributes = e2.readInt(2), this.externalFileAttributes = e2.readInt(4), this.localHeaderOffset = e2.readInt(4), this.isEncrypted()) throw new Error("Encrypted zip are not supported");
            e2.skip(t2), this.readExtraFields(e2), this.parseZIP64ExtraField(e2), this.fileComment = e2.readData(this.fileCommentLength);
          }, processAttributes: function() {
            this.unixPermissions = null, this.dosPermissions = null;
            var e2 = this.versionMadeBy >> 8;
            this.dir = !!(16 & this.externalFileAttributes), 0 == e2 && (this.dosPermissions = 63 & this.externalFileAttributes), 3 == e2 && (this.unixPermissions = this.externalFileAttributes >> 16 & 65535), this.dir || "/" !== this.fileNameStr.slice(-1) || (this.dir = true);
          }, parseZIP64ExtraField: function() {
            if (this.extraFields[1]) {
              var e2 = n(this.extraFields[1].value);
              this.uncompressedSize === s.MAX_VALUE_32BITS && (this.uncompressedSize = e2.readInt(8)), this.compressedSize === s.MAX_VALUE_32BITS && (this.compressedSize = e2.readInt(8)), this.localHeaderOffset === s.MAX_VALUE_32BITS && (this.localHeaderOffset = e2.readInt(8)), this.diskNumberStart === s.MAX_VALUE_32BITS && (this.diskNumberStart = e2.readInt(4));
            }
          }, readExtraFields: function(e2) {
            var t2, r2, n2, i2 = e2.index + this.extraFieldsLength;
            for (this.extraFields || (this.extraFields = {}); e2.index + 4 < i2; ) t2 = e2.readInt(2), r2 = e2.readInt(2), n2 = e2.readData(r2), this.extraFields[t2] = { id: t2, length: r2, value: n2 };
            e2.setIndex(i2);
          }, handleUTF8: function() {
            var e2 = u.uint8array ? "uint8array" : "array";
            if (this.useUTF8()) this.fileNameStr = o.utf8decode(this.fileName), this.fileCommentStr = o.utf8decode(this.fileComment);
            else {
              var t2 = this.findExtraFieldUnicodePath();
              if (null !== t2) this.fileNameStr = t2;
              else {
                var r2 = s.transformTo(e2, this.fileName);
                this.fileNameStr = this.loadOptions.decodeFileName(r2);
              }
              var n2 = this.findExtraFieldUnicodeComment();
              if (null !== n2) this.fileCommentStr = n2;
              else {
                var i2 = s.transformTo(e2, this.fileComment);
                this.fileCommentStr = this.loadOptions.decodeFileName(i2);
              }
            }
          }, findExtraFieldUnicodePath: function() {
            var e2 = this.extraFields[28789];
            if (e2) {
              var t2 = n(e2.value);
              return 1 !== t2.readInt(1) ? null : a(this.fileName) !== t2.readInt(4) ? null : o.utf8decode(t2.readData(e2.length - 5));
            }
            return null;
          }, findExtraFieldUnicodeComment: function() {
            var e2 = this.extraFields[25461];
            if (e2) {
              var t2 = n(e2.value);
              return 1 !== t2.readInt(1) ? null : a(this.fileComment) !== t2.readInt(4) ? null : o.utf8decode(t2.readData(e2.length - 5));
            }
            return null;
          } }, t.exports = l;
        }, { "./compressedObject": 2, "./compressions": 3, "./crc32": 4, "./reader/readerFor": 22, "./support": 30, "./utf8": 31, "./utils": 32 }], 35: [function(e, t, r) {
          "use strict";
          function n(e2, t2, r2) {
            this.name = e2, this.dir = r2.dir, this.date = r2.date, this.comment = r2.comment, this.unixPermissions = r2.unixPermissions, this.dosPermissions = r2.dosPermissions, this._data = t2, this._dataBinary = r2.binary, this.options = { compression: r2.compression, compressionOptions: r2.compressionOptions };
          }
          var s = e("./stream/StreamHelper"), i = e("./stream/DataWorker"), a = e("./utf8"), o = e("./compressedObject"), h = e("./stream/GenericWorker");
          n.prototype = { internalStream: function(e2) {
            var t2 = null, r2 = "string";
            try {
              if (!e2) throw new Error("No output type specified.");
              var n2 = "string" === (r2 = e2.toLowerCase()) || "text" === r2;
              "binarystring" !== r2 && "text" !== r2 || (r2 = "string"), t2 = this._decompressWorker();
              var i2 = !this._dataBinary;
              i2 && !n2 && (t2 = t2.pipe(new a.Utf8EncodeWorker())), !i2 && n2 && (t2 = t2.pipe(new a.Utf8DecodeWorker()));
            } catch (e3) {
              (t2 = new h("error")).error(e3);
            }
            return new s(t2, r2, "");
          }, async: function(e2, t2) {
            return this.internalStream(e2).accumulate(t2);
          }, nodeStream: function(e2, t2) {
            return this.internalStream(e2 || "nodebuffer").toNodejsStream(t2);
          }, _compressWorker: function(e2, t2) {
            if (this._data instanceof o && this._data.compression.magic === e2.magic) return this._data.getCompressedWorker();
            var r2 = this._decompressWorker();
            return this._dataBinary || (r2 = r2.pipe(new a.Utf8EncodeWorker())), o.createWorkerFrom(r2, e2, t2);
          }, _decompressWorker: function() {
            return this._data instanceof o ? this._data.getContentWorker() : this._data instanceof h ? this._data : new i(this._data);
          } };
          for (var u = ["asText", "asBinary", "asNodeBuffer", "asUint8Array", "asArrayBuffer"], l = function() {
            throw new Error("This method has been removed in JSZip 3.0, please check the upgrade guide.");
          }, f = 0; f < u.length; f++) n.prototype[u[f]] = l;
          t.exports = n;
        }, { "./compressedObject": 2, "./stream/DataWorker": 27, "./stream/GenericWorker": 28, "./stream/StreamHelper": 29, "./utf8": 31 }], 36: [function(e, l, t) {
          (function(t2) {
            "use strict";
            var r, n, e2 = t2.MutationObserver || t2.WebKitMutationObserver;
            if (e2) {
              var i = 0, s = new e2(u), a = t2.document.createTextNode("");
              s.observe(a, { characterData: true }), r = function() {
                a.data = i = ++i % 2;
              };
            } else if (t2.setImmediate || void 0 === t2.MessageChannel) r = "document" in t2 && "onreadystatechange" in t2.document.createElement("script") ? function() {
              var e3 = t2.document.createElement("script");
              e3.onreadystatechange = function() {
                u(), e3.onreadystatechange = null, e3.parentNode.removeChild(e3), e3 = null;
              }, t2.document.documentElement.appendChild(e3);
            } : function() {
              setTimeout(u, 0);
            };
            else {
              var o = new t2.MessageChannel();
              o.port1.onmessage = u, r = function() {
                o.port2.postMessage(0);
              };
            }
            var h = [];
            function u() {
              var e3, t3;
              n = true;
              for (var r2 = h.length; r2; ) {
                for (t3 = h, h = [], e3 = -1; ++e3 < r2; ) t3[e3]();
                r2 = h.length;
              }
              n = false;
            }
            l.exports = function(e3) {
              1 !== h.push(e3) || n || r();
            };
          }).call(this, "undefined" != typeof global ? global : "undefined" != typeof self ? self : "undefined" != typeof window ? window : {});
        }, {}], 37: [function(e, t, r) {
          "use strict";
          var i = e("immediate");
          function u() {
          }
          var l = {}, s = ["REJECTED"], a = ["FULFILLED"], n = ["PENDING"];
          function o(e2) {
            if ("function" != typeof e2) throw new TypeError("resolver must be a function");
            this.state = n, this.queue = [], this.outcome = void 0, e2 !== u && d(this, e2);
          }
          function h(e2, t2, r2) {
            this.promise = e2, "function" == typeof t2 && (this.onFulfilled = t2, this.callFulfilled = this.otherCallFulfilled), "function" == typeof r2 && (this.onRejected = r2, this.callRejected = this.otherCallRejected);
          }
          function f(t2, r2, n2) {
            i(function() {
              var e2;
              try {
                e2 = r2(n2);
              } catch (e3) {
                return l.reject(t2, e3);
              }
              e2 === t2 ? l.reject(t2, new TypeError("Cannot resolve promise with itself")) : l.resolve(t2, e2);
            });
          }
          function c(e2) {
            var t2 = e2 && e2.then;
            if (e2 && ("object" == typeof e2 || "function" == typeof e2) && "function" == typeof t2) return function() {
              t2.apply(e2, arguments);
            };
          }
          function d(t2, e2) {
            var r2 = false;
            function n2(e3) {
              r2 || (r2 = true, l.reject(t2, e3));
            }
            function i2(e3) {
              r2 || (r2 = true, l.resolve(t2, e3));
            }
            var s2 = p(function() {
              e2(i2, n2);
            });
            "error" === s2.status && n2(s2.value);
          }
          function p(e2, t2) {
            var r2 = {};
            try {
              r2.value = e2(t2), r2.status = "success";
            } catch (e3) {
              r2.status = "error", r2.value = e3;
            }
            return r2;
          }
          (t.exports = o).prototype.finally = function(t2) {
            if ("function" != typeof t2) return this;
            var r2 = this.constructor;
            return this.then(function(e2) {
              return r2.resolve(t2()).then(function() {
                return e2;
              });
            }, function(e2) {
              return r2.resolve(t2()).then(function() {
                throw e2;
              });
            });
          }, o.prototype.catch = function(e2) {
            return this.then(null, e2);
          }, o.prototype.then = function(e2, t2) {
            if ("function" != typeof e2 && this.state === a || "function" != typeof t2 && this.state === s) return this;
            var r2 = new this.constructor(u);
            this.state !== n ? f(r2, this.state === a ? e2 : t2, this.outcome) : this.queue.push(new h(r2, e2, t2));
            return r2;
          }, h.prototype.callFulfilled = function(e2) {
            l.resolve(this.promise, e2);
          }, h.prototype.otherCallFulfilled = function(e2) {
            f(this.promise, this.onFulfilled, e2);
          }, h.prototype.callRejected = function(e2) {
            l.reject(this.promise, e2);
          }, h.prototype.otherCallRejected = function(e2) {
            f(this.promise, this.onRejected, e2);
          }, l.resolve = function(e2, t2) {
            var r2 = p(c, t2);
            if ("error" === r2.status) return l.reject(e2, r2.value);
            var n2 = r2.value;
            if (n2) d(e2, n2);
            else {
              e2.state = a, e2.outcome = t2;
              for (var i2 = -1, s2 = e2.queue.length; ++i2 < s2; ) e2.queue[i2].callFulfilled(t2);
            }
            return e2;
          }, l.reject = function(e2, t2) {
            e2.state = s, e2.outcome = t2;
            for (var r2 = -1, n2 = e2.queue.length; ++r2 < n2; ) e2.queue[r2].callRejected(t2);
            return e2;
          }, o.resolve = function(e2) {
            if (e2 instanceof this) return e2;
            return l.resolve(new this(u), e2);
          }, o.reject = function(e2) {
            var t2 = new this(u);
            return l.reject(t2, e2);
          }, o.all = function(e2) {
            var r2 = this;
            if ("[object Array]" !== Object.prototype.toString.call(e2)) return this.reject(new TypeError("must be an array"));
            var n2 = e2.length, i2 = false;
            if (!n2) return this.resolve([]);
            var s2 = new Array(n2), a2 = 0, t2 = -1, o2 = new this(u);
            for (; ++t2 < n2; ) h2(e2[t2], t2);
            return o2;
            function h2(e3, t3) {
              r2.resolve(e3).then(function(e4) {
                s2[t3] = e4, ++a2 !== n2 || i2 || (i2 = true, l.resolve(o2, s2));
              }, function(e4) {
                i2 || (i2 = true, l.reject(o2, e4));
              });
            }
          }, o.race = function(e2) {
            var t2 = this;
            if ("[object Array]" !== Object.prototype.toString.call(e2)) return this.reject(new TypeError("must be an array"));
            var r2 = e2.length, n2 = false;
            if (!r2) return this.resolve([]);
            var i2 = -1, s2 = new this(u);
            for (; ++i2 < r2; ) a2 = e2[i2], t2.resolve(a2).then(function(e3) {
              n2 || (n2 = true, l.resolve(s2, e3));
            }, function(e3) {
              n2 || (n2 = true, l.reject(s2, e3));
            });
            var a2;
            return s2;
          };
        }, { immediate: 36 }], 38: [function(e, t, r) {
          "use strict";
          var n = {};
          (0, e("./lib/utils/common").assign)(n, e("./lib/deflate"), e("./lib/inflate"), e("./lib/zlib/constants")), t.exports = n;
        }, { "./lib/deflate": 39, "./lib/inflate": 40, "./lib/utils/common": 41, "./lib/zlib/constants": 44 }], 39: [function(e, t, r) {
          "use strict";
          var a = e("./zlib/deflate"), o = e("./utils/common"), h = e("./utils/strings"), i = e("./zlib/messages"), s = e("./zlib/zstream"), u = Object.prototype.toString, l = 0, f = -1, c = 0, d = 8;
          function p(e2) {
            if (!(this instanceof p)) return new p(e2);
            this.options = o.assign({ level: f, method: d, chunkSize: 16384, windowBits: 15, memLevel: 8, strategy: c, to: "" }, e2 || {});
            var t2 = this.options;
            t2.raw && 0 < t2.windowBits ? t2.windowBits = -t2.windowBits : t2.gzip && 0 < t2.windowBits && t2.windowBits < 16 && (t2.windowBits += 16), this.err = 0, this.msg = "", this.ended = false, this.chunks = [], this.strm = new s(), this.strm.avail_out = 0;
            var r2 = a.deflateInit2(this.strm, t2.level, t2.method, t2.windowBits, t2.memLevel, t2.strategy);
            if (r2 !== l) throw new Error(i[r2]);
            if (t2.header && a.deflateSetHeader(this.strm, t2.header), t2.dictionary) {
              var n2;
              if (n2 = "string" == typeof t2.dictionary ? h.string2buf(t2.dictionary) : "[object ArrayBuffer]" === u.call(t2.dictionary) ? new Uint8Array(t2.dictionary) : t2.dictionary, (r2 = a.deflateSetDictionary(this.strm, n2)) !== l) throw new Error(i[r2]);
              this._dict_set = true;
            }
          }
          function n(e2, t2) {
            var r2 = new p(t2);
            if (r2.push(e2, true), r2.err) throw r2.msg || i[r2.err];
            return r2.result;
          }
          p.prototype.push = function(e2, t2) {
            var r2, n2, i2 = this.strm, s2 = this.options.chunkSize;
            if (this.ended) return false;
            n2 = t2 === ~~t2 ? t2 : true === t2 ? 4 : 0, "string" == typeof e2 ? i2.input = h.string2buf(e2) : "[object ArrayBuffer]" === u.call(e2) ? i2.input = new Uint8Array(e2) : i2.input = e2, i2.next_in = 0, i2.avail_in = i2.input.length;
            do {
              if (0 === i2.avail_out && (i2.output = new o.Buf8(s2), i2.next_out = 0, i2.avail_out = s2), 1 !== (r2 = a.deflate(i2, n2)) && r2 !== l) return this.onEnd(r2), !(this.ended = true);
              0 !== i2.avail_out && (0 !== i2.avail_in || 4 !== n2 && 2 !== n2) || ("string" === this.options.to ? this.onData(h.buf2binstring(o.shrinkBuf(i2.output, i2.next_out))) : this.onData(o.shrinkBuf(i2.output, i2.next_out)));
            } while ((0 < i2.avail_in || 0 === i2.avail_out) && 1 !== r2);
            return 4 === n2 ? (r2 = a.deflateEnd(this.strm), this.onEnd(r2), this.ended = true, r2 === l) : 2 !== n2 || (this.onEnd(l), !(i2.avail_out = 0));
          }, p.prototype.onData = function(e2) {
            this.chunks.push(e2);
          }, p.prototype.onEnd = function(e2) {
            e2 === l && ("string" === this.options.to ? this.result = this.chunks.join("") : this.result = o.flattenChunks(this.chunks)), this.chunks = [], this.err = e2, this.msg = this.strm.msg;
          }, r.Deflate = p, r.deflate = n, r.deflateRaw = function(e2, t2) {
            return (t2 = t2 || {}).raw = true, n(e2, t2);
          }, r.gzip = function(e2, t2) {
            return (t2 = t2 || {}).gzip = true, n(e2, t2);
          };
        }, { "./utils/common": 41, "./utils/strings": 42, "./zlib/deflate": 46, "./zlib/messages": 51, "./zlib/zstream": 53 }], 40: [function(e, t, r) {
          "use strict";
          var c = e("./zlib/inflate"), d = e("./utils/common"), p = e("./utils/strings"), m = e("./zlib/constants"), n = e("./zlib/messages"), i = e("./zlib/zstream"), s = e("./zlib/gzheader"), _3 = Object.prototype.toString;
          function a(e2) {
            if (!(this instanceof a)) return new a(e2);
            this.options = d.assign({ chunkSize: 16384, windowBits: 0, to: "" }, e2 || {});
            var t2 = this.options;
            t2.raw && 0 <= t2.windowBits && t2.windowBits < 16 && (t2.windowBits = -t2.windowBits, 0 === t2.windowBits && (t2.windowBits = -15)), !(0 <= t2.windowBits && t2.windowBits < 16) || e2 && e2.windowBits || (t2.windowBits += 32), 15 < t2.windowBits && t2.windowBits < 48 && 0 == (15 & t2.windowBits) && (t2.windowBits |= 15), this.err = 0, this.msg = "", this.ended = false, this.chunks = [], this.strm = new i(), this.strm.avail_out = 0;
            var r2 = c.inflateInit2(this.strm, t2.windowBits);
            if (r2 !== m.Z_OK) throw new Error(n[r2]);
            this.header = new s(), c.inflateGetHeader(this.strm, this.header);
          }
          function o(e2, t2) {
            var r2 = new a(t2);
            if (r2.push(e2, true), r2.err) throw r2.msg || n[r2.err];
            return r2.result;
          }
          a.prototype.push = function(e2, t2) {
            var r2, n2, i2, s2, a2, o2, h = this.strm, u = this.options.chunkSize, l = this.options.dictionary, f = false;
            if (this.ended) return false;
            n2 = t2 === ~~t2 ? t2 : true === t2 ? m.Z_FINISH : m.Z_NO_FLUSH, "string" == typeof e2 ? h.input = p.binstring2buf(e2) : "[object ArrayBuffer]" === _3.call(e2) ? h.input = new Uint8Array(e2) : h.input = e2, h.next_in = 0, h.avail_in = h.input.length;
            do {
              if (0 === h.avail_out && (h.output = new d.Buf8(u), h.next_out = 0, h.avail_out = u), (r2 = c.inflate(h, m.Z_NO_FLUSH)) === m.Z_NEED_DICT && l && (o2 = "string" == typeof l ? p.string2buf(l) : "[object ArrayBuffer]" === _3.call(l) ? new Uint8Array(l) : l, r2 = c.inflateSetDictionary(this.strm, o2)), r2 === m.Z_BUF_ERROR && true === f && (r2 = m.Z_OK, f = false), r2 !== m.Z_STREAM_END && r2 !== m.Z_OK) return this.onEnd(r2), !(this.ended = true);
              h.next_out && (0 !== h.avail_out && r2 !== m.Z_STREAM_END && (0 !== h.avail_in || n2 !== m.Z_FINISH && n2 !== m.Z_SYNC_FLUSH) || ("string" === this.options.to ? (i2 = p.utf8border(h.output, h.next_out), s2 = h.next_out - i2, a2 = p.buf2string(h.output, i2), h.next_out = s2, h.avail_out = u - s2, s2 && d.arraySet(h.output, h.output, i2, s2, 0), this.onData(a2)) : this.onData(d.shrinkBuf(h.output, h.next_out)))), 0 === h.avail_in && 0 === h.avail_out && (f = true);
            } while ((0 < h.avail_in || 0 === h.avail_out) && r2 !== m.Z_STREAM_END);
            return r2 === m.Z_STREAM_END && (n2 = m.Z_FINISH), n2 === m.Z_FINISH ? (r2 = c.inflateEnd(this.strm), this.onEnd(r2), this.ended = true, r2 === m.Z_OK) : n2 !== m.Z_SYNC_FLUSH || (this.onEnd(m.Z_OK), !(h.avail_out = 0));
          }, a.prototype.onData = function(e2) {
            this.chunks.push(e2);
          }, a.prototype.onEnd = function(e2) {
            e2 === m.Z_OK && ("string" === this.options.to ? this.result = this.chunks.join("") : this.result = d.flattenChunks(this.chunks)), this.chunks = [], this.err = e2, this.msg = this.strm.msg;
          }, r.Inflate = a, r.inflate = o, r.inflateRaw = function(e2, t2) {
            return (t2 = t2 || {}).raw = true, o(e2, t2);
          }, r.ungzip = o;
        }, { "./utils/common": 41, "./utils/strings": 42, "./zlib/constants": 44, "./zlib/gzheader": 47, "./zlib/inflate": 49, "./zlib/messages": 51, "./zlib/zstream": 53 }], 41: [function(e, t, r) {
          "use strict";
          var n = "undefined" != typeof Uint8Array && "undefined" != typeof Uint16Array && "undefined" != typeof Int32Array;
          r.assign = function(e2) {
            for (var t2 = Array.prototype.slice.call(arguments, 1); t2.length; ) {
              var r2 = t2.shift();
              if (r2) {
                if ("object" != typeof r2) throw new TypeError(r2 + "must be non-object");
                for (var n2 in r2) r2.hasOwnProperty(n2) && (e2[n2] = r2[n2]);
              }
            }
            return e2;
          }, r.shrinkBuf = function(e2, t2) {
            return e2.length === t2 ? e2 : e2.subarray ? e2.subarray(0, t2) : (e2.length = t2, e2);
          };
          var i = { arraySet: function(e2, t2, r2, n2, i2) {
            if (t2.subarray && e2.subarray) e2.set(t2.subarray(r2, r2 + n2), i2);
            else for (var s2 = 0; s2 < n2; s2++) e2[i2 + s2] = t2[r2 + s2];
          }, flattenChunks: function(e2) {
            var t2, r2, n2, i2, s2, a;
            for (t2 = n2 = 0, r2 = e2.length; t2 < r2; t2++) n2 += e2[t2].length;
            for (a = new Uint8Array(n2), t2 = i2 = 0, r2 = e2.length; t2 < r2; t2++) s2 = e2[t2], a.set(s2, i2), i2 += s2.length;
            return a;
          } }, s = { arraySet: function(e2, t2, r2, n2, i2) {
            for (var s2 = 0; s2 < n2; s2++) e2[i2 + s2] = t2[r2 + s2];
          }, flattenChunks: function(e2) {
            return [].concat.apply([], e2);
          } };
          r.setTyped = function(e2) {
            e2 ? (r.Buf8 = Uint8Array, r.Buf16 = Uint16Array, r.Buf32 = Int32Array, r.assign(r, i)) : (r.Buf8 = Array, r.Buf16 = Array, r.Buf32 = Array, r.assign(r, s));
          }, r.setTyped(n);
        }, {}], 42: [function(e, t, r) {
          "use strict";
          var h = e("./common"), i = true, s = true;
          try {
            String.fromCharCode.apply(null, [0]);
          } catch (e2) {
            i = false;
          }
          try {
            String.fromCharCode.apply(null, new Uint8Array(1));
          } catch (e2) {
            s = false;
          }
          for (var u = new h.Buf8(256), n = 0; n < 256; n++) u[n] = 252 <= n ? 6 : 248 <= n ? 5 : 240 <= n ? 4 : 224 <= n ? 3 : 192 <= n ? 2 : 1;
          function l(e2, t2) {
            if (t2 < 65537 && (e2.subarray && s || !e2.subarray && i)) return String.fromCharCode.apply(null, h.shrinkBuf(e2, t2));
            for (var r2 = "", n2 = 0; n2 < t2; n2++) r2 += String.fromCharCode(e2[n2]);
            return r2;
          }
          u[254] = u[254] = 1, r.string2buf = function(e2) {
            var t2, r2, n2, i2, s2, a = e2.length, o = 0;
            for (i2 = 0; i2 < a; i2++) 55296 == (64512 & (r2 = e2.charCodeAt(i2))) && i2 + 1 < a && 56320 == (64512 & (n2 = e2.charCodeAt(i2 + 1))) && (r2 = 65536 + (r2 - 55296 << 10) + (n2 - 56320), i2++), o += r2 < 128 ? 1 : r2 < 2048 ? 2 : r2 < 65536 ? 3 : 4;
            for (t2 = new h.Buf8(o), i2 = s2 = 0; s2 < o; i2++) 55296 == (64512 & (r2 = e2.charCodeAt(i2))) && i2 + 1 < a && 56320 == (64512 & (n2 = e2.charCodeAt(i2 + 1))) && (r2 = 65536 + (r2 - 55296 << 10) + (n2 - 56320), i2++), r2 < 128 ? t2[s2++] = r2 : (r2 < 2048 ? t2[s2++] = 192 | r2 >>> 6 : (r2 < 65536 ? t2[s2++] = 224 | r2 >>> 12 : (t2[s2++] = 240 | r2 >>> 18, t2[s2++] = 128 | r2 >>> 12 & 63), t2[s2++] = 128 | r2 >>> 6 & 63), t2[s2++] = 128 | 63 & r2);
            return t2;
          }, r.buf2binstring = function(e2) {
            return l(e2, e2.length);
          }, r.binstring2buf = function(e2) {
            for (var t2 = new h.Buf8(e2.length), r2 = 0, n2 = t2.length; r2 < n2; r2++) t2[r2] = e2.charCodeAt(r2);
            return t2;
          }, r.buf2string = function(e2, t2) {
            var r2, n2, i2, s2, a = t2 || e2.length, o = new Array(2 * a);
            for (r2 = n2 = 0; r2 < a; ) if ((i2 = e2[r2++]) < 128) o[n2++] = i2;
            else if (4 < (s2 = u[i2])) o[n2++] = 65533, r2 += s2 - 1;
            else {
              for (i2 &= 2 === s2 ? 31 : 3 === s2 ? 15 : 7; 1 < s2 && r2 < a; ) i2 = i2 << 6 | 63 & e2[r2++], s2--;
              1 < s2 ? o[n2++] = 65533 : i2 < 65536 ? o[n2++] = i2 : (i2 -= 65536, o[n2++] = 55296 | i2 >> 10 & 1023, o[n2++] = 56320 | 1023 & i2);
            }
            return l(o, n2);
          }, r.utf8border = function(e2, t2) {
            var r2;
            for ((t2 = t2 || e2.length) > e2.length && (t2 = e2.length), r2 = t2 - 1; 0 <= r2 && 128 == (192 & e2[r2]); ) r2--;
            return r2 < 0 ? t2 : 0 === r2 ? t2 : r2 + u[e2[r2]] > t2 ? r2 : t2;
          };
        }, { "./common": 41 }], 43: [function(e, t, r) {
          "use strict";
          t.exports = function(e2, t2, r2, n) {
            for (var i = 65535 & e2 | 0, s = e2 >>> 16 & 65535 | 0, a = 0; 0 !== r2; ) {
              for (r2 -= a = 2e3 < r2 ? 2e3 : r2; s = s + (i = i + t2[n++] | 0) | 0, --a; ) ;
              i %= 65521, s %= 65521;
            }
            return i | s << 16 | 0;
          };
        }, {}], 44: [function(e, t, r) {
          "use strict";
          t.exports = { Z_NO_FLUSH: 0, Z_PARTIAL_FLUSH: 1, Z_SYNC_FLUSH: 2, Z_FULL_FLUSH: 3, Z_FINISH: 4, Z_BLOCK: 5, Z_TREES: 6, Z_OK: 0, Z_STREAM_END: 1, Z_NEED_DICT: 2, Z_ERRNO: -1, Z_STREAM_ERROR: -2, Z_DATA_ERROR: -3, Z_BUF_ERROR: -5, Z_NO_COMPRESSION: 0, Z_BEST_SPEED: 1, Z_BEST_COMPRESSION: 9, Z_DEFAULT_COMPRESSION: -1, Z_FILTERED: 1, Z_HUFFMAN_ONLY: 2, Z_RLE: 3, Z_FIXED: 4, Z_DEFAULT_STRATEGY: 0, Z_BINARY: 0, Z_TEXT: 1, Z_UNKNOWN: 2, Z_DEFLATED: 8 };
        }, {}], 45: [function(e, t, r) {
          "use strict";
          var o = (function() {
            for (var e2, t2 = [], r2 = 0; r2 < 256; r2++) {
              e2 = r2;
              for (var n = 0; n < 8; n++) e2 = 1 & e2 ? 3988292384 ^ e2 >>> 1 : e2 >>> 1;
              t2[r2] = e2;
            }
            return t2;
          })();
          t.exports = function(e2, t2, r2, n) {
            var i = o, s = n + r2;
            e2 ^= -1;
            for (var a = n; a < s; a++) e2 = e2 >>> 8 ^ i[255 & (e2 ^ t2[a])];
            return -1 ^ e2;
          };
        }, {}], 46: [function(e, t, r) {
          "use strict";
          var h, c = e("../utils/common"), u = e("./trees"), d = e("./adler32"), p = e("./crc32"), n = e("./messages"), l = 0, f = 4, m = 0, _3 = -2, g = -1, b = 4, i = 2, v = 8, y = 9, s = 286, a = 30, o = 19, w = 2 * s + 1, k = 15, x = 3, S = 258, z = S + x + 1, C = 42, E = 113, A = 1, I = 2, O = 3, B = 4;
          function R(e2, t2) {
            return e2.msg = n[t2], t2;
          }
          function T(e2) {
            return (e2 << 1) - (4 < e2 ? 9 : 0);
          }
          function D(e2) {
            for (var t2 = e2.length; 0 <= --t2; ) e2[t2] = 0;
          }
          function F(e2) {
            var t2 = e2.state, r2 = t2.pending;
            r2 > e2.avail_out && (r2 = e2.avail_out), 0 !== r2 && (c.arraySet(e2.output, t2.pending_buf, t2.pending_out, r2, e2.next_out), e2.next_out += r2, t2.pending_out += r2, e2.total_out += r2, e2.avail_out -= r2, t2.pending -= r2, 0 === t2.pending && (t2.pending_out = 0));
          }
          function N(e2, t2) {
            u._tr_flush_block(e2, 0 <= e2.block_start ? e2.block_start : -1, e2.strstart - e2.block_start, t2), e2.block_start = e2.strstart, F(e2.strm);
          }
          function U(e2, t2) {
            e2.pending_buf[e2.pending++] = t2;
          }
          function P(e2, t2) {
            e2.pending_buf[e2.pending++] = t2 >>> 8 & 255, e2.pending_buf[e2.pending++] = 255 & t2;
          }
          function L(e2, t2) {
            var r2, n2, i2 = e2.max_chain_length, s2 = e2.strstart, a2 = e2.prev_length, o2 = e2.nice_match, h2 = e2.strstart > e2.w_size - z ? e2.strstart - (e2.w_size - z) : 0, u2 = e2.window, l2 = e2.w_mask, f2 = e2.prev, c2 = e2.strstart + S, d2 = u2[s2 + a2 - 1], p2 = u2[s2 + a2];
            e2.prev_length >= e2.good_match && (i2 >>= 2), o2 > e2.lookahead && (o2 = e2.lookahead);
            do {
              if (u2[(r2 = t2) + a2] === p2 && u2[r2 + a2 - 1] === d2 && u2[r2] === u2[s2] && u2[++r2] === u2[s2 + 1]) {
                s2 += 2, r2++;
                do {
                } while (u2[++s2] === u2[++r2] && u2[++s2] === u2[++r2] && u2[++s2] === u2[++r2] && u2[++s2] === u2[++r2] && u2[++s2] === u2[++r2] && u2[++s2] === u2[++r2] && u2[++s2] === u2[++r2] && u2[++s2] === u2[++r2] && s2 < c2);
                if (n2 = S - (c2 - s2), s2 = c2 - S, a2 < n2) {
                  if (e2.match_start = t2, o2 <= (a2 = n2)) break;
                  d2 = u2[s2 + a2 - 1], p2 = u2[s2 + a2];
                }
              }
            } while ((t2 = f2[t2 & l2]) > h2 && 0 != --i2);
            return a2 <= e2.lookahead ? a2 : e2.lookahead;
          }
          function j(e2) {
            var t2, r2, n2, i2, s2, a2, o2, h2, u2, l2, f2 = e2.w_size;
            do {
              if (i2 = e2.window_size - e2.lookahead - e2.strstart, e2.strstart >= f2 + (f2 - z)) {
                for (c.arraySet(e2.window, e2.window, f2, f2, 0), e2.match_start -= f2, e2.strstart -= f2, e2.block_start -= f2, t2 = r2 = e2.hash_size; n2 = e2.head[--t2], e2.head[t2] = f2 <= n2 ? n2 - f2 : 0, --r2; ) ;
                for (t2 = r2 = f2; n2 = e2.prev[--t2], e2.prev[t2] = f2 <= n2 ? n2 - f2 : 0, --r2; ) ;
                i2 += f2;
              }
              if (0 === e2.strm.avail_in) break;
              if (a2 = e2.strm, o2 = e2.window, h2 = e2.strstart + e2.lookahead, u2 = i2, l2 = void 0, l2 = a2.avail_in, u2 < l2 && (l2 = u2), r2 = 0 === l2 ? 0 : (a2.avail_in -= l2, c.arraySet(o2, a2.input, a2.next_in, l2, h2), 1 === a2.state.wrap ? a2.adler = d(a2.adler, o2, l2, h2) : 2 === a2.state.wrap && (a2.adler = p(a2.adler, o2, l2, h2)), a2.next_in += l2, a2.total_in += l2, l2), e2.lookahead += r2, e2.lookahead + e2.insert >= x) for (s2 = e2.strstart - e2.insert, e2.ins_h = e2.window[s2], e2.ins_h = (e2.ins_h << e2.hash_shift ^ e2.window[s2 + 1]) & e2.hash_mask; e2.insert && (e2.ins_h = (e2.ins_h << e2.hash_shift ^ e2.window[s2 + x - 1]) & e2.hash_mask, e2.prev[s2 & e2.w_mask] = e2.head[e2.ins_h], e2.head[e2.ins_h] = s2, s2++, e2.insert--, !(e2.lookahead + e2.insert < x)); ) ;
            } while (e2.lookahead < z && 0 !== e2.strm.avail_in);
          }
          function Z(e2, t2) {
            for (var r2, n2; ; ) {
              if (e2.lookahead < z) {
                if (j(e2), e2.lookahead < z && t2 === l) return A;
                if (0 === e2.lookahead) break;
              }
              if (r2 = 0, e2.lookahead >= x && (e2.ins_h = (e2.ins_h << e2.hash_shift ^ e2.window[e2.strstart + x - 1]) & e2.hash_mask, r2 = e2.prev[e2.strstart & e2.w_mask] = e2.head[e2.ins_h], e2.head[e2.ins_h] = e2.strstart), 0 !== r2 && e2.strstart - r2 <= e2.w_size - z && (e2.match_length = L(e2, r2)), e2.match_length >= x) if (n2 = u._tr_tally(e2, e2.strstart - e2.match_start, e2.match_length - x), e2.lookahead -= e2.match_length, e2.match_length <= e2.max_lazy_match && e2.lookahead >= x) {
                for (e2.match_length--; e2.strstart++, e2.ins_h = (e2.ins_h << e2.hash_shift ^ e2.window[e2.strstart + x - 1]) & e2.hash_mask, r2 = e2.prev[e2.strstart & e2.w_mask] = e2.head[e2.ins_h], e2.head[e2.ins_h] = e2.strstart, 0 != --e2.match_length; ) ;
                e2.strstart++;
              } else e2.strstart += e2.match_length, e2.match_length = 0, e2.ins_h = e2.window[e2.strstart], e2.ins_h = (e2.ins_h << e2.hash_shift ^ e2.window[e2.strstart + 1]) & e2.hash_mask;
              else n2 = u._tr_tally(e2, 0, e2.window[e2.strstart]), e2.lookahead--, e2.strstart++;
              if (n2 && (N(e2, false), 0 === e2.strm.avail_out)) return A;
            }
            return e2.insert = e2.strstart < x - 1 ? e2.strstart : x - 1, t2 === f ? (N(e2, true), 0 === e2.strm.avail_out ? O : B) : e2.last_lit && (N(e2, false), 0 === e2.strm.avail_out) ? A : I;
          }
          function W(e2, t2) {
            for (var r2, n2, i2; ; ) {
              if (e2.lookahead < z) {
                if (j(e2), e2.lookahead < z && t2 === l) return A;
                if (0 === e2.lookahead) break;
              }
              if (r2 = 0, e2.lookahead >= x && (e2.ins_h = (e2.ins_h << e2.hash_shift ^ e2.window[e2.strstart + x - 1]) & e2.hash_mask, r2 = e2.prev[e2.strstart & e2.w_mask] = e2.head[e2.ins_h], e2.head[e2.ins_h] = e2.strstart), e2.prev_length = e2.match_length, e2.prev_match = e2.match_start, e2.match_length = x - 1, 0 !== r2 && e2.prev_length < e2.max_lazy_match && e2.strstart - r2 <= e2.w_size - z && (e2.match_length = L(e2, r2), e2.match_length <= 5 && (1 === e2.strategy || e2.match_length === x && 4096 < e2.strstart - e2.match_start) && (e2.match_length = x - 1)), e2.prev_length >= x && e2.match_length <= e2.prev_length) {
                for (i2 = e2.strstart + e2.lookahead - x, n2 = u._tr_tally(e2, e2.strstart - 1 - e2.prev_match, e2.prev_length - x), e2.lookahead -= e2.prev_length - 1, e2.prev_length -= 2; ++e2.strstart <= i2 && (e2.ins_h = (e2.ins_h << e2.hash_shift ^ e2.window[e2.strstart + x - 1]) & e2.hash_mask, r2 = e2.prev[e2.strstart & e2.w_mask] = e2.head[e2.ins_h], e2.head[e2.ins_h] = e2.strstart), 0 != --e2.prev_length; ) ;
                if (e2.match_available = 0, e2.match_length = x - 1, e2.strstart++, n2 && (N(e2, false), 0 === e2.strm.avail_out)) return A;
              } else if (e2.match_available) {
                if ((n2 = u._tr_tally(e2, 0, e2.window[e2.strstart - 1])) && N(e2, false), e2.strstart++, e2.lookahead--, 0 === e2.strm.avail_out) return A;
              } else e2.match_available = 1, e2.strstart++, e2.lookahead--;
            }
            return e2.match_available && (n2 = u._tr_tally(e2, 0, e2.window[e2.strstart - 1]), e2.match_available = 0), e2.insert = e2.strstart < x - 1 ? e2.strstart : x - 1, t2 === f ? (N(e2, true), 0 === e2.strm.avail_out ? O : B) : e2.last_lit && (N(e2, false), 0 === e2.strm.avail_out) ? A : I;
          }
          function M(e2, t2, r2, n2, i2) {
            this.good_length = e2, this.max_lazy = t2, this.nice_length = r2, this.max_chain = n2, this.func = i2;
          }
          function H() {
            this.strm = null, this.status = 0, this.pending_buf = null, this.pending_buf_size = 0, this.pending_out = 0, this.pending = 0, this.wrap = 0, this.gzhead = null, this.gzindex = 0, this.method = v, this.last_flush = -1, this.w_size = 0, this.w_bits = 0, this.w_mask = 0, this.window = null, this.window_size = 0, this.prev = null, this.head = null, this.ins_h = 0, this.hash_size = 0, this.hash_bits = 0, this.hash_mask = 0, this.hash_shift = 0, this.block_start = 0, this.match_length = 0, this.prev_match = 0, this.match_available = 0, this.strstart = 0, this.match_start = 0, this.lookahead = 0, this.prev_length = 0, this.max_chain_length = 0, this.max_lazy_match = 0, this.level = 0, this.strategy = 0, this.good_match = 0, this.nice_match = 0, this.dyn_ltree = new c.Buf16(2 * w), this.dyn_dtree = new c.Buf16(2 * (2 * a + 1)), this.bl_tree = new c.Buf16(2 * (2 * o + 1)), D(this.dyn_ltree), D(this.dyn_dtree), D(this.bl_tree), this.l_desc = null, this.d_desc = null, this.bl_desc = null, this.bl_count = new c.Buf16(k + 1), this.heap = new c.Buf16(2 * s + 1), D(this.heap), this.heap_len = 0, this.heap_max = 0, this.depth = new c.Buf16(2 * s + 1), D(this.depth), this.l_buf = 0, this.lit_bufsize = 0, this.last_lit = 0, this.d_buf = 0, this.opt_len = 0, this.static_len = 0, this.matches = 0, this.insert = 0, this.bi_buf = 0, this.bi_valid = 0;
          }
          function G(e2) {
            var t2;
            return e2 && e2.state ? (e2.total_in = e2.total_out = 0, e2.data_type = i, (t2 = e2.state).pending = 0, t2.pending_out = 0, t2.wrap < 0 && (t2.wrap = -t2.wrap), t2.status = t2.wrap ? C : E, e2.adler = 2 === t2.wrap ? 0 : 1, t2.last_flush = l, u._tr_init(t2), m) : R(e2, _3);
          }
          function K(e2) {
            var t2 = G(e2);
            return t2 === m && (function(e3) {
              e3.window_size = 2 * e3.w_size, D(e3.head), e3.max_lazy_match = h[e3.level].max_lazy, e3.good_match = h[e3.level].good_length, e3.nice_match = h[e3.level].nice_length, e3.max_chain_length = h[e3.level].max_chain, e3.strstart = 0, e3.block_start = 0, e3.lookahead = 0, e3.insert = 0, e3.match_length = e3.prev_length = x - 1, e3.match_available = 0, e3.ins_h = 0;
            })(e2.state), t2;
          }
          function Y(e2, t2, r2, n2, i2, s2) {
            if (!e2) return _3;
            var a2 = 1;
            if (t2 === g && (t2 = 6), n2 < 0 ? (a2 = 0, n2 = -n2) : 15 < n2 && (a2 = 2, n2 -= 16), i2 < 1 || y < i2 || r2 !== v || n2 < 8 || 15 < n2 || t2 < 0 || 9 < t2 || s2 < 0 || b < s2) return R(e2, _3);
            8 === n2 && (n2 = 9);
            var o2 = new H();
            return (e2.state = o2).strm = e2, o2.wrap = a2, o2.gzhead = null, o2.w_bits = n2, o2.w_size = 1 << o2.w_bits, o2.w_mask = o2.w_size - 1, o2.hash_bits = i2 + 7, o2.hash_size = 1 << o2.hash_bits, o2.hash_mask = o2.hash_size - 1, o2.hash_shift = ~~((o2.hash_bits + x - 1) / x), o2.window = new c.Buf8(2 * o2.w_size), o2.head = new c.Buf16(o2.hash_size), o2.prev = new c.Buf16(o2.w_size), o2.lit_bufsize = 1 << i2 + 6, o2.pending_buf_size = 4 * o2.lit_bufsize, o2.pending_buf = new c.Buf8(o2.pending_buf_size), o2.d_buf = 1 * o2.lit_bufsize, o2.l_buf = 3 * o2.lit_bufsize, o2.level = t2, o2.strategy = s2, o2.method = r2, K(e2);
          }
          h = [new M(0, 0, 0, 0, function(e2, t2) {
            var r2 = 65535;
            for (r2 > e2.pending_buf_size - 5 && (r2 = e2.pending_buf_size - 5); ; ) {
              if (e2.lookahead <= 1) {
                if (j(e2), 0 === e2.lookahead && t2 === l) return A;
                if (0 === e2.lookahead) break;
              }
              e2.strstart += e2.lookahead, e2.lookahead = 0;
              var n2 = e2.block_start + r2;
              if ((0 === e2.strstart || e2.strstart >= n2) && (e2.lookahead = e2.strstart - n2, e2.strstart = n2, N(e2, false), 0 === e2.strm.avail_out)) return A;
              if (e2.strstart - e2.block_start >= e2.w_size - z && (N(e2, false), 0 === e2.strm.avail_out)) return A;
            }
            return e2.insert = 0, t2 === f ? (N(e2, true), 0 === e2.strm.avail_out ? O : B) : (e2.strstart > e2.block_start && (N(e2, false), e2.strm.avail_out), A);
          }), new M(4, 4, 8, 4, Z), new M(4, 5, 16, 8, Z), new M(4, 6, 32, 32, Z), new M(4, 4, 16, 16, W), new M(8, 16, 32, 32, W), new M(8, 16, 128, 128, W), new M(8, 32, 128, 256, W), new M(32, 128, 258, 1024, W), new M(32, 258, 258, 4096, W)], r.deflateInit = function(e2, t2) {
            return Y(e2, t2, v, 15, 8, 0);
          }, r.deflateInit2 = Y, r.deflateReset = K, r.deflateResetKeep = G, r.deflateSetHeader = function(e2, t2) {
            return e2 && e2.state ? 2 !== e2.state.wrap ? _3 : (e2.state.gzhead = t2, m) : _3;
          }, r.deflate = function(e2, t2) {
            var r2, n2, i2, s2;
            if (!e2 || !e2.state || 5 < t2 || t2 < 0) return e2 ? R(e2, _3) : _3;
            if (n2 = e2.state, !e2.output || !e2.input && 0 !== e2.avail_in || 666 === n2.status && t2 !== f) return R(e2, 0 === e2.avail_out ? -5 : _3);
            if (n2.strm = e2, r2 = n2.last_flush, n2.last_flush = t2, n2.status === C) if (2 === n2.wrap) e2.adler = 0, U(n2, 31), U(n2, 139), U(n2, 8), n2.gzhead ? (U(n2, (n2.gzhead.text ? 1 : 0) + (n2.gzhead.hcrc ? 2 : 0) + (n2.gzhead.extra ? 4 : 0) + (n2.gzhead.name ? 8 : 0) + (n2.gzhead.comment ? 16 : 0)), U(n2, 255 & n2.gzhead.time), U(n2, n2.gzhead.time >> 8 & 255), U(n2, n2.gzhead.time >> 16 & 255), U(n2, n2.gzhead.time >> 24 & 255), U(n2, 9 === n2.level ? 2 : 2 <= n2.strategy || n2.level < 2 ? 4 : 0), U(n2, 255 & n2.gzhead.os), n2.gzhead.extra && n2.gzhead.extra.length && (U(n2, 255 & n2.gzhead.extra.length), U(n2, n2.gzhead.extra.length >> 8 & 255)), n2.gzhead.hcrc && (e2.adler = p(e2.adler, n2.pending_buf, n2.pending, 0)), n2.gzindex = 0, n2.status = 69) : (U(n2, 0), U(n2, 0), U(n2, 0), U(n2, 0), U(n2, 0), U(n2, 9 === n2.level ? 2 : 2 <= n2.strategy || n2.level < 2 ? 4 : 0), U(n2, 3), n2.status = E);
            else {
              var a2 = v + (n2.w_bits - 8 << 4) << 8;
              a2 |= (2 <= n2.strategy || n2.level < 2 ? 0 : n2.level < 6 ? 1 : 6 === n2.level ? 2 : 3) << 6, 0 !== n2.strstart && (a2 |= 32), a2 += 31 - a2 % 31, n2.status = E, P(n2, a2), 0 !== n2.strstart && (P(n2, e2.adler >>> 16), P(n2, 65535 & e2.adler)), e2.adler = 1;
            }
            if (69 === n2.status) if (n2.gzhead.extra) {
              for (i2 = n2.pending; n2.gzindex < (65535 & n2.gzhead.extra.length) && (n2.pending !== n2.pending_buf_size || (n2.gzhead.hcrc && n2.pending > i2 && (e2.adler = p(e2.adler, n2.pending_buf, n2.pending - i2, i2)), F(e2), i2 = n2.pending, n2.pending !== n2.pending_buf_size)); ) U(n2, 255 & n2.gzhead.extra[n2.gzindex]), n2.gzindex++;
              n2.gzhead.hcrc && n2.pending > i2 && (e2.adler = p(e2.adler, n2.pending_buf, n2.pending - i2, i2)), n2.gzindex === n2.gzhead.extra.length && (n2.gzindex = 0, n2.status = 73);
            } else n2.status = 73;
            if (73 === n2.status) if (n2.gzhead.name) {
              i2 = n2.pending;
              do {
                if (n2.pending === n2.pending_buf_size && (n2.gzhead.hcrc && n2.pending > i2 && (e2.adler = p(e2.adler, n2.pending_buf, n2.pending - i2, i2)), F(e2), i2 = n2.pending, n2.pending === n2.pending_buf_size)) {
                  s2 = 1;
                  break;
                }
                s2 = n2.gzindex < n2.gzhead.name.length ? 255 & n2.gzhead.name.charCodeAt(n2.gzindex++) : 0, U(n2, s2);
              } while (0 !== s2);
              n2.gzhead.hcrc && n2.pending > i2 && (e2.adler = p(e2.adler, n2.pending_buf, n2.pending - i2, i2)), 0 === s2 && (n2.gzindex = 0, n2.status = 91);
            } else n2.status = 91;
            if (91 === n2.status) if (n2.gzhead.comment) {
              i2 = n2.pending;
              do {
                if (n2.pending === n2.pending_buf_size && (n2.gzhead.hcrc && n2.pending > i2 && (e2.adler = p(e2.adler, n2.pending_buf, n2.pending - i2, i2)), F(e2), i2 = n2.pending, n2.pending === n2.pending_buf_size)) {
                  s2 = 1;
                  break;
                }
                s2 = n2.gzindex < n2.gzhead.comment.length ? 255 & n2.gzhead.comment.charCodeAt(n2.gzindex++) : 0, U(n2, s2);
              } while (0 !== s2);
              n2.gzhead.hcrc && n2.pending > i2 && (e2.adler = p(e2.adler, n2.pending_buf, n2.pending - i2, i2)), 0 === s2 && (n2.status = 103);
            } else n2.status = 103;
            if (103 === n2.status && (n2.gzhead.hcrc ? (n2.pending + 2 > n2.pending_buf_size && F(e2), n2.pending + 2 <= n2.pending_buf_size && (U(n2, 255 & e2.adler), U(n2, e2.adler >> 8 & 255), e2.adler = 0, n2.status = E)) : n2.status = E), 0 !== n2.pending) {
              if (F(e2), 0 === e2.avail_out) return n2.last_flush = -1, m;
            } else if (0 === e2.avail_in && T(t2) <= T(r2) && t2 !== f) return R(e2, -5);
            if (666 === n2.status && 0 !== e2.avail_in) return R(e2, -5);
            if (0 !== e2.avail_in || 0 !== n2.lookahead || t2 !== l && 666 !== n2.status) {
              var o2 = 2 === n2.strategy ? (function(e3, t3) {
                for (var r3; ; ) {
                  if (0 === e3.lookahead && (j(e3), 0 === e3.lookahead)) {
                    if (t3 === l) return A;
                    break;
                  }
                  if (e3.match_length = 0, r3 = u._tr_tally(e3, 0, e3.window[e3.strstart]), e3.lookahead--, e3.strstart++, r3 && (N(e3, false), 0 === e3.strm.avail_out)) return A;
                }
                return e3.insert = 0, t3 === f ? (N(e3, true), 0 === e3.strm.avail_out ? O : B) : e3.last_lit && (N(e3, false), 0 === e3.strm.avail_out) ? A : I;
              })(n2, t2) : 3 === n2.strategy ? (function(e3, t3) {
                for (var r3, n3, i3, s3, a3 = e3.window; ; ) {
                  if (e3.lookahead <= S) {
                    if (j(e3), e3.lookahead <= S && t3 === l) return A;
                    if (0 === e3.lookahead) break;
                  }
                  if (e3.match_length = 0, e3.lookahead >= x && 0 < e3.strstart && (n3 = a3[i3 = e3.strstart - 1]) === a3[++i3] && n3 === a3[++i3] && n3 === a3[++i3]) {
                    s3 = e3.strstart + S;
                    do {
                    } while (n3 === a3[++i3] && n3 === a3[++i3] && n3 === a3[++i3] && n3 === a3[++i3] && n3 === a3[++i3] && n3 === a3[++i3] && n3 === a3[++i3] && n3 === a3[++i3] && i3 < s3);
                    e3.match_length = S - (s3 - i3), e3.match_length > e3.lookahead && (e3.match_length = e3.lookahead);
                  }
                  if (e3.match_length >= x ? (r3 = u._tr_tally(e3, 1, e3.match_length - x), e3.lookahead -= e3.match_length, e3.strstart += e3.match_length, e3.match_length = 0) : (r3 = u._tr_tally(e3, 0, e3.window[e3.strstart]), e3.lookahead--, e3.strstart++), r3 && (N(e3, false), 0 === e3.strm.avail_out)) return A;
                }
                return e3.insert = 0, t3 === f ? (N(e3, true), 0 === e3.strm.avail_out ? O : B) : e3.last_lit && (N(e3, false), 0 === e3.strm.avail_out) ? A : I;
              })(n2, t2) : h[n2.level].func(n2, t2);
              if (o2 !== O && o2 !== B || (n2.status = 666), o2 === A || o2 === O) return 0 === e2.avail_out && (n2.last_flush = -1), m;
              if (o2 === I && (1 === t2 ? u._tr_align(n2) : 5 !== t2 && (u._tr_stored_block(n2, 0, 0, false), 3 === t2 && (D(n2.head), 0 === n2.lookahead && (n2.strstart = 0, n2.block_start = 0, n2.insert = 0))), F(e2), 0 === e2.avail_out)) return n2.last_flush = -1, m;
            }
            return t2 !== f ? m : n2.wrap <= 0 ? 1 : (2 === n2.wrap ? (U(n2, 255 & e2.adler), U(n2, e2.adler >> 8 & 255), U(n2, e2.adler >> 16 & 255), U(n2, e2.adler >> 24 & 255), U(n2, 255 & e2.total_in), U(n2, e2.total_in >> 8 & 255), U(n2, e2.total_in >> 16 & 255), U(n2, e2.total_in >> 24 & 255)) : (P(n2, e2.adler >>> 16), P(n2, 65535 & e2.adler)), F(e2), 0 < n2.wrap && (n2.wrap = -n2.wrap), 0 !== n2.pending ? m : 1);
          }, r.deflateEnd = function(e2) {
            var t2;
            return e2 && e2.state ? (t2 = e2.state.status) !== C && 69 !== t2 && 73 !== t2 && 91 !== t2 && 103 !== t2 && t2 !== E && 666 !== t2 ? R(e2, _3) : (e2.state = null, t2 === E ? R(e2, -3) : m) : _3;
          }, r.deflateSetDictionary = function(e2, t2) {
            var r2, n2, i2, s2, a2, o2, h2, u2, l2 = t2.length;
            if (!e2 || !e2.state) return _3;
            if (2 === (s2 = (r2 = e2.state).wrap) || 1 === s2 && r2.status !== C || r2.lookahead) return _3;
            for (1 === s2 && (e2.adler = d(e2.adler, t2, l2, 0)), r2.wrap = 0, l2 >= r2.w_size && (0 === s2 && (D(r2.head), r2.strstart = 0, r2.block_start = 0, r2.insert = 0), u2 = new c.Buf8(r2.w_size), c.arraySet(u2, t2, l2 - r2.w_size, r2.w_size, 0), t2 = u2, l2 = r2.w_size), a2 = e2.avail_in, o2 = e2.next_in, h2 = e2.input, e2.avail_in = l2, e2.next_in = 0, e2.input = t2, j(r2); r2.lookahead >= x; ) {
              for (n2 = r2.strstart, i2 = r2.lookahead - (x - 1); r2.ins_h = (r2.ins_h << r2.hash_shift ^ r2.window[n2 + x - 1]) & r2.hash_mask, r2.prev[n2 & r2.w_mask] = r2.head[r2.ins_h], r2.head[r2.ins_h] = n2, n2++, --i2; ) ;
              r2.strstart = n2, r2.lookahead = x - 1, j(r2);
            }
            return r2.strstart += r2.lookahead, r2.block_start = r2.strstart, r2.insert = r2.lookahead, r2.lookahead = 0, r2.match_length = r2.prev_length = x - 1, r2.match_available = 0, e2.next_in = o2, e2.input = h2, e2.avail_in = a2, r2.wrap = s2, m;
          }, r.deflateInfo = "pako deflate (from Nodeca project)";
        }, { "../utils/common": 41, "./adler32": 43, "./crc32": 45, "./messages": 51, "./trees": 52 }], 47: [function(e, t, r) {
          "use strict";
          t.exports = function() {
            this.text = 0, this.time = 0, this.xflags = 0, this.os = 0, this.extra = null, this.extra_len = 0, this.name = "", this.comment = "", this.hcrc = 0, this.done = false;
          };
        }, {}], 48: [function(e, t, r) {
          "use strict";
          t.exports = function(e2, t2) {
            var r2, n, i, s, a, o, h, u, l, f, c, d, p, m, _3, g, b, v, y, w, k, x, S, z, C;
            r2 = e2.state, n = e2.next_in, z = e2.input, i = n + (e2.avail_in - 5), s = e2.next_out, C = e2.output, a = s - (t2 - e2.avail_out), o = s + (e2.avail_out - 257), h = r2.dmax, u = r2.wsize, l = r2.whave, f = r2.wnext, c = r2.window, d = r2.hold, p = r2.bits, m = r2.lencode, _3 = r2.distcode, g = (1 << r2.lenbits) - 1, b = (1 << r2.distbits) - 1;
            e: do {
              p < 15 && (d += z[n++] << p, p += 8, d += z[n++] << p, p += 8), v = m[d & g];
              t: for (; ; ) {
                if (d >>>= y = v >>> 24, p -= y, 0 === (y = v >>> 16 & 255)) C[s++] = 65535 & v;
                else {
                  if (!(16 & y)) {
                    if (0 == (64 & y)) {
                      v = m[(65535 & v) + (d & (1 << y) - 1)];
                      continue t;
                    }
                    if (32 & y) {
                      r2.mode = 12;
                      break e;
                    }
                    e2.msg = "invalid literal/length code", r2.mode = 30;
                    break e;
                  }
                  w = 65535 & v, (y &= 15) && (p < y && (d += z[n++] << p, p += 8), w += d & (1 << y) - 1, d >>>= y, p -= y), p < 15 && (d += z[n++] << p, p += 8, d += z[n++] << p, p += 8), v = _3[d & b];
                  r: for (; ; ) {
                    if (d >>>= y = v >>> 24, p -= y, !(16 & (y = v >>> 16 & 255))) {
                      if (0 == (64 & y)) {
                        v = _3[(65535 & v) + (d & (1 << y) - 1)];
                        continue r;
                      }
                      e2.msg = "invalid distance code", r2.mode = 30;
                      break e;
                    }
                    if (k = 65535 & v, p < (y &= 15) && (d += z[n++] << p, (p += 8) < y && (d += z[n++] << p, p += 8)), h < (k += d & (1 << y) - 1)) {
                      e2.msg = "invalid distance too far back", r2.mode = 30;
                      break e;
                    }
                    if (d >>>= y, p -= y, (y = s - a) < k) {
                      if (l < (y = k - y) && r2.sane) {
                        e2.msg = "invalid distance too far back", r2.mode = 30;
                        break e;
                      }
                      if (S = c, (x = 0) === f) {
                        if (x += u - y, y < w) {
                          for (w -= y; C[s++] = c[x++], --y; ) ;
                          x = s - k, S = C;
                        }
                      } else if (f < y) {
                        if (x += u + f - y, (y -= f) < w) {
                          for (w -= y; C[s++] = c[x++], --y; ) ;
                          if (x = 0, f < w) {
                            for (w -= y = f; C[s++] = c[x++], --y; ) ;
                            x = s - k, S = C;
                          }
                        }
                      } else if (x += f - y, y < w) {
                        for (w -= y; C[s++] = c[x++], --y; ) ;
                        x = s - k, S = C;
                      }
                      for (; 2 < w; ) C[s++] = S[x++], C[s++] = S[x++], C[s++] = S[x++], w -= 3;
                      w && (C[s++] = S[x++], 1 < w && (C[s++] = S[x++]));
                    } else {
                      for (x = s - k; C[s++] = C[x++], C[s++] = C[x++], C[s++] = C[x++], 2 < (w -= 3); ) ;
                      w && (C[s++] = C[x++], 1 < w && (C[s++] = C[x++]));
                    }
                    break;
                  }
                }
                break;
              }
            } while (n < i && s < o);
            n -= w = p >> 3, d &= (1 << (p -= w << 3)) - 1, e2.next_in = n, e2.next_out = s, e2.avail_in = n < i ? i - n + 5 : 5 - (n - i), e2.avail_out = s < o ? o - s + 257 : 257 - (s - o), r2.hold = d, r2.bits = p;
          };
        }, {}], 49: [function(e, t, r) {
          "use strict";
          var I = e("../utils/common"), O = e("./adler32"), B = e("./crc32"), R = e("./inffast"), T = e("./inftrees"), D = 1, F = 2, N = 0, U = -2, P = 1, n = 852, i = 592;
          function L(e2) {
            return (e2 >>> 24 & 255) + (e2 >>> 8 & 65280) + ((65280 & e2) << 8) + ((255 & e2) << 24);
          }
          function s() {
            this.mode = 0, this.last = false, this.wrap = 0, this.havedict = false, this.flags = 0, this.dmax = 0, this.check = 0, this.total = 0, this.head = null, this.wbits = 0, this.wsize = 0, this.whave = 0, this.wnext = 0, this.window = null, this.hold = 0, this.bits = 0, this.length = 0, this.offset = 0, this.extra = 0, this.lencode = null, this.distcode = null, this.lenbits = 0, this.distbits = 0, this.ncode = 0, this.nlen = 0, this.ndist = 0, this.have = 0, this.next = null, this.lens = new I.Buf16(320), this.work = new I.Buf16(288), this.lendyn = null, this.distdyn = null, this.sane = 0, this.back = 0, this.was = 0;
          }
          function a(e2) {
            var t2;
            return e2 && e2.state ? (t2 = e2.state, e2.total_in = e2.total_out = t2.total = 0, e2.msg = "", t2.wrap && (e2.adler = 1 & t2.wrap), t2.mode = P, t2.last = 0, t2.havedict = 0, t2.dmax = 32768, t2.head = null, t2.hold = 0, t2.bits = 0, t2.lencode = t2.lendyn = new I.Buf32(n), t2.distcode = t2.distdyn = new I.Buf32(i), t2.sane = 1, t2.back = -1, N) : U;
          }
          function o(e2) {
            var t2;
            return e2 && e2.state ? ((t2 = e2.state).wsize = 0, t2.whave = 0, t2.wnext = 0, a(e2)) : U;
          }
          function h(e2, t2) {
            var r2, n2;
            return e2 && e2.state ? (n2 = e2.state, t2 < 0 ? (r2 = 0, t2 = -t2) : (r2 = 1 + (t2 >> 4), t2 < 48 && (t2 &= 15)), t2 && (t2 < 8 || 15 < t2) ? U : (null !== n2.window && n2.wbits !== t2 && (n2.window = null), n2.wrap = r2, n2.wbits = t2, o(e2))) : U;
          }
          function u(e2, t2) {
            var r2, n2;
            return e2 ? (n2 = new s(), (e2.state = n2).window = null, (r2 = h(e2, t2)) !== N && (e2.state = null), r2) : U;
          }
          var l, f, c = true;
          function j(e2) {
            if (c) {
              var t2;
              for (l = new I.Buf32(512), f = new I.Buf32(32), t2 = 0; t2 < 144; ) e2.lens[t2++] = 8;
              for (; t2 < 256; ) e2.lens[t2++] = 9;
              for (; t2 < 280; ) e2.lens[t2++] = 7;
              for (; t2 < 288; ) e2.lens[t2++] = 8;
              for (T(D, e2.lens, 0, 288, l, 0, e2.work, { bits: 9 }), t2 = 0; t2 < 32; ) e2.lens[t2++] = 5;
              T(F, e2.lens, 0, 32, f, 0, e2.work, { bits: 5 }), c = false;
            }
            e2.lencode = l, e2.lenbits = 9, e2.distcode = f, e2.distbits = 5;
          }
          function Z(e2, t2, r2, n2) {
            var i2, s2 = e2.state;
            return null === s2.window && (s2.wsize = 1 << s2.wbits, s2.wnext = 0, s2.whave = 0, s2.window = new I.Buf8(s2.wsize)), n2 >= s2.wsize ? (I.arraySet(s2.window, t2, r2 - s2.wsize, s2.wsize, 0), s2.wnext = 0, s2.whave = s2.wsize) : (n2 < (i2 = s2.wsize - s2.wnext) && (i2 = n2), I.arraySet(s2.window, t2, r2 - n2, i2, s2.wnext), (n2 -= i2) ? (I.arraySet(s2.window, t2, r2 - n2, n2, 0), s2.wnext = n2, s2.whave = s2.wsize) : (s2.wnext += i2, s2.wnext === s2.wsize && (s2.wnext = 0), s2.whave < s2.wsize && (s2.whave += i2))), 0;
          }
          r.inflateReset = o, r.inflateReset2 = h, r.inflateResetKeep = a, r.inflateInit = function(e2) {
            return u(e2, 15);
          }, r.inflateInit2 = u, r.inflate = function(e2, t2) {
            var r2, n2, i2, s2, a2, o2, h2, u2, l2, f2, c2, d, p, m, _3, g, b, v, y, w, k, x, S, z, C = 0, E = new I.Buf8(4), A = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];
            if (!e2 || !e2.state || !e2.output || !e2.input && 0 !== e2.avail_in) return U;
            12 === (r2 = e2.state).mode && (r2.mode = 13), a2 = e2.next_out, i2 = e2.output, h2 = e2.avail_out, s2 = e2.next_in, n2 = e2.input, o2 = e2.avail_in, u2 = r2.hold, l2 = r2.bits, f2 = o2, c2 = h2, x = N;
            e: for (; ; ) switch (r2.mode) {
              case P:
                if (0 === r2.wrap) {
                  r2.mode = 13;
                  break;
                }
                for (; l2 < 16; ) {
                  if (0 === o2) break e;
                  o2--, u2 += n2[s2++] << l2, l2 += 8;
                }
                if (2 & r2.wrap && 35615 === u2) {
                  E[r2.check = 0] = 255 & u2, E[1] = u2 >>> 8 & 255, r2.check = B(r2.check, E, 2, 0), l2 = u2 = 0, r2.mode = 2;
                  break;
                }
                if (r2.flags = 0, r2.head && (r2.head.done = false), !(1 & r2.wrap) || (((255 & u2) << 8) + (u2 >> 8)) % 31) {
                  e2.msg = "incorrect header check", r2.mode = 30;
                  break;
                }
                if (8 != (15 & u2)) {
                  e2.msg = "unknown compression method", r2.mode = 30;
                  break;
                }
                if (l2 -= 4, k = 8 + (15 & (u2 >>>= 4)), 0 === r2.wbits) r2.wbits = k;
                else if (k > r2.wbits) {
                  e2.msg = "invalid window size", r2.mode = 30;
                  break;
                }
                r2.dmax = 1 << k, e2.adler = r2.check = 1, r2.mode = 512 & u2 ? 10 : 12, l2 = u2 = 0;
                break;
              case 2:
                for (; l2 < 16; ) {
                  if (0 === o2) break e;
                  o2--, u2 += n2[s2++] << l2, l2 += 8;
                }
                if (r2.flags = u2, 8 != (255 & r2.flags)) {
                  e2.msg = "unknown compression method", r2.mode = 30;
                  break;
                }
                if (57344 & r2.flags) {
                  e2.msg = "unknown header flags set", r2.mode = 30;
                  break;
                }
                r2.head && (r2.head.text = u2 >> 8 & 1), 512 & r2.flags && (E[0] = 255 & u2, E[1] = u2 >>> 8 & 255, r2.check = B(r2.check, E, 2, 0)), l2 = u2 = 0, r2.mode = 3;
              case 3:
                for (; l2 < 32; ) {
                  if (0 === o2) break e;
                  o2--, u2 += n2[s2++] << l2, l2 += 8;
                }
                r2.head && (r2.head.time = u2), 512 & r2.flags && (E[0] = 255 & u2, E[1] = u2 >>> 8 & 255, E[2] = u2 >>> 16 & 255, E[3] = u2 >>> 24 & 255, r2.check = B(r2.check, E, 4, 0)), l2 = u2 = 0, r2.mode = 4;
              case 4:
                for (; l2 < 16; ) {
                  if (0 === o2) break e;
                  o2--, u2 += n2[s2++] << l2, l2 += 8;
                }
                r2.head && (r2.head.xflags = 255 & u2, r2.head.os = u2 >> 8), 512 & r2.flags && (E[0] = 255 & u2, E[1] = u2 >>> 8 & 255, r2.check = B(r2.check, E, 2, 0)), l2 = u2 = 0, r2.mode = 5;
              case 5:
                if (1024 & r2.flags) {
                  for (; l2 < 16; ) {
                    if (0 === o2) break e;
                    o2--, u2 += n2[s2++] << l2, l2 += 8;
                  }
                  r2.length = u2, r2.head && (r2.head.extra_len = u2), 512 & r2.flags && (E[0] = 255 & u2, E[1] = u2 >>> 8 & 255, r2.check = B(r2.check, E, 2, 0)), l2 = u2 = 0;
                } else r2.head && (r2.head.extra = null);
                r2.mode = 6;
              case 6:
                if (1024 & r2.flags && (o2 < (d = r2.length) && (d = o2), d && (r2.head && (k = r2.head.extra_len - r2.length, r2.head.extra || (r2.head.extra = new Array(r2.head.extra_len)), I.arraySet(r2.head.extra, n2, s2, d, k)), 512 & r2.flags && (r2.check = B(r2.check, n2, d, s2)), o2 -= d, s2 += d, r2.length -= d), r2.length)) break e;
                r2.length = 0, r2.mode = 7;
              case 7:
                if (2048 & r2.flags) {
                  if (0 === o2) break e;
                  for (d = 0; k = n2[s2 + d++], r2.head && k && r2.length < 65536 && (r2.head.name += String.fromCharCode(k)), k && d < o2; ) ;
                  if (512 & r2.flags && (r2.check = B(r2.check, n2, d, s2)), o2 -= d, s2 += d, k) break e;
                } else r2.head && (r2.head.name = null);
                r2.length = 0, r2.mode = 8;
              case 8:
                if (4096 & r2.flags) {
                  if (0 === o2) break e;
                  for (d = 0; k = n2[s2 + d++], r2.head && k && r2.length < 65536 && (r2.head.comment += String.fromCharCode(k)), k && d < o2; ) ;
                  if (512 & r2.flags && (r2.check = B(r2.check, n2, d, s2)), o2 -= d, s2 += d, k) break e;
                } else r2.head && (r2.head.comment = null);
                r2.mode = 9;
              case 9:
                if (512 & r2.flags) {
                  for (; l2 < 16; ) {
                    if (0 === o2) break e;
                    o2--, u2 += n2[s2++] << l2, l2 += 8;
                  }
                  if (u2 !== (65535 & r2.check)) {
                    e2.msg = "header crc mismatch", r2.mode = 30;
                    break;
                  }
                  l2 = u2 = 0;
                }
                r2.head && (r2.head.hcrc = r2.flags >> 9 & 1, r2.head.done = true), e2.adler = r2.check = 0, r2.mode = 12;
                break;
              case 10:
                for (; l2 < 32; ) {
                  if (0 === o2) break e;
                  o2--, u2 += n2[s2++] << l2, l2 += 8;
                }
                e2.adler = r2.check = L(u2), l2 = u2 = 0, r2.mode = 11;
              case 11:
                if (0 === r2.havedict) return e2.next_out = a2, e2.avail_out = h2, e2.next_in = s2, e2.avail_in = o2, r2.hold = u2, r2.bits = l2, 2;
                e2.adler = r2.check = 1, r2.mode = 12;
              case 12:
                if (5 === t2 || 6 === t2) break e;
              case 13:
                if (r2.last) {
                  u2 >>>= 7 & l2, l2 -= 7 & l2, r2.mode = 27;
                  break;
                }
                for (; l2 < 3; ) {
                  if (0 === o2) break e;
                  o2--, u2 += n2[s2++] << l2, l2 += 8;
                }
                switch (r2.last = 1 & u2, l2 -= 1, 3 & (u2 >>>= 1)) {
                  case 0:
                    r2.mode = 14;
                    break;
                  case 1:
                    if (j(r2), r2.mode = 20, 6 !== t2) break;
                    u2 >>>= 2, l2 -= 2;
                    break e;
                  case 2:
                    r2.mode = 17;
                    break;
                  case 3:
                    e2.msg = "invalid block type", r2.mode = 30;
                }
                u2 >>>= 2, l2 -= 2;
                break;
              case 14:
                for (u2 >>>= 7 & l2, l2 -= 7 & l2; l2 < 32; ) {
                  if (0 === o2) break e;
                  o2--, u2 += n2[s2++] << l2, l2 += 8;
                }
                if ((65535 & u2) != (u2 >>> 16 ^ 65535)) {
                  e2.msg = "invalid stored block lengths", r2.mode = 30;
                  break;
                }
                if (r2.length = 65535 & u2, l2 = u2 = 0, r2.mode = 15, 6 === t2) break e;
              case 15:
                r2.mode = 16;
              case 16:
                if (d = r2.length) {
                  if (o2 < d && (d = o2), h2 < d && (d = h2), 0 === d) break e;
                  I.arraySet(i2, n2, s2, d, a2), o2 -= d, s2 += d, h2 -= d, a2 += d, r2.length -= d;
                  break;
                }
                r2.mode = 12;
                break;
              case 17:
                for (; l2 < 14; ) {
                  if (0 === o2) break e;
                  o2--, u2 += n2[s2++] << l2, l2 += 8;
                }
                if (r2.nlen = 257 + (31 & u2), u2 >>>= 5, l2 -= 5, r2.ndist = 1 + (31 & u2), u2 >>>= 5, l2 -= 5, r2.ncode = 4 + (15 & u2), u2 >>>= 4, l2 -= 4, 286 < r2.nlen || 30 < r2.ndist) {
                  e2.msg = "too many length or distance symbols", r2.mode = 30;
                  break;
                }
                r2.have = 0, r2.mode = 18;
              case 18:
                for (; r2.have < r2.ncode; ) {
                  for (; l2 < 3; ) {
                    if (0 === o2) break e;
                    o2--, u2 += n2[s2++] << l2, l2 += 8;
                  }
                  r2.lens[A[r2.have++]] = 7 & u2, u2 >>>= 3, l2 -= 3;
                }
                for (; r2.have < 19; ) r2.lens[A[r2.have++]] = 0;
                if (r2.lencode = r2.lendyn, r2.lenbits = 7, S = { bits: r2.lenbits }, x = T(0, r2.lens, 0, 19, r2.lencode, 0, r2.work, S), r2.lenbits = S.bits, x) {
                  e2.msg = "invalid code lengths set", r2.mode = 30;
                  break;
                }
                r2.have = 0, r2.mode = 19;
              case 19:
                for (; r2.have < r2.nlen + r2.ndist; ) {
                  for (; g = (C = r2.lencode[u2 & (1 << r2.lenbits) - 1]) >>> 16 & 255, b = 65535 & C, !((_3 = C >>> 24) <= l2); ) {
                    if (0 === o2) break e;
                    o2--, u2 += n2[s2++] << l2, l2 += 8;
                  }
                  if (b < 16) u2 >>>= _3, l2 -= _3, r2.lens[r2.have++] = b;
                  else {
                    if (16 === b) {
                      for (z = _3 + 2; l2 < z; ) {
                        if (0 === o2) break e;
                        o2--, u2 += n2[s2++] << l2, l2 += 8;
                      }
                      if (u2 >>>= _3, l2 -= _3, 0 === r2.have) {
                        e2.msg = "invalid bit length repeat", r2.mode = 30;
                        break;
                      }
                      k = r2.lens[r2.have - 1], d = 3 + (3 & u2), u2 >>>= 2, l2 -= 2;
                    } else if (17 === b) {
                      for (z = _3 + 3; l2 < z; ) {
                        if (0 === o2) break e;
                        o2--, u2 += n2[s2++] << l2, l2 += 8;
                      }
                      l2 -= _3, k = 0, d = 3 + (7 & (u2 >>>= _3)), u2 >>>= 3, l2 -= 3;
                    } else {
                      for (z = _3 + 7; l2 < z; ) {
                        if (0 === o2) break e;
                        o2--, u2 += n2[s2++] << l2, l2 += 8;
                      }
                      l2 -= _3, k = 0, d = 11 + (127 & (u2 >>>= _3)), u2 >>>= 7, l2 -= 7;
                    }
                    if (r2.have + d > r2.nlen + r2.ndist) {
                      e2.msg = "invalid bit length repeat", r2.mode = 30;
                      break;
                    }
                    for (; d--; ) r2.lens[r2.have++] = k;
                  }
                }
                if (30 === r2.mode) break;
                if (0 === r2.lens[256]) {
                  e2.msg = "invalid code -- missing end-of-block", r2.mode = 30;
                  break;
                }
                if (r2.lenbits = 9, S = { bits: r2.lenbits }, x = T(D, r2.lens, 0, r2.nlen, r2.lencode, 0, r2.work, S), r2.lenbits = S.bits, x) {
                  e2.msg = "invalid literal/lengths set", r2.mode = 30;
                  break;
                }
                if (r2.distbits = 6, r2.distcode = r2.distdyn, S = { bits: r2.distbits }, x = T(F, r2.lens, r2.nlen, r2.ndist, r2.distcode, 0, r2.work, S), r2.distbits = S.bits, x) {
                  e2.msg = "invalid distances set", r2.mode = 30;
                  break;
                }
                if (r2.mode = 20, 6 === t2) break e;
              case 20:
                r2.mode = 21;
              case 21:
                if (6 <= o2 && 258 <= h2) {
                  e2.next_out = a2, e2.avail_out = h2, e2.next_in = s2, e2.avail_in = o2, r2.hold = u2, r2.bits = l2, R(e2, c2), a2 = e2.next_out, i2 = e2.output, h2 = e2.avail_out, s2 = e2.next_in, n2 = e2.input, o2 = e2.avail_in, u2 = r2.hold, l2 = r2.bits, 12 === r2.mode && (r2.back = -1);
                  break;
                }
                for (r2.back = 0; g = (C = r2.lencode[u2 & (1 << r2.lenbits) - 1]) >>> 16 & 255, b = 65535 & C, !((_3 = C >>> 24) <= l2); ) {
                  if (0 === o2) break e;
                  o2--, u2 += n2[s2++] << l2, l2 += 8;
                }
                if (g && 0 == (240 & g)) {
                  for (v = _3, y = g, w = b; g = (C = r2.lencode[w + ((u2 & (1 << v + y) - 1) >> v)]) >>> 16 & 255, b = 65535 & C, !(v + (_3 = C >>> 24) <= l2); ) {
                    if (0 === o2) break e;
                    o2--, u2 += n2[s2++] << l2, l2 += 8;
                  }
                  u2 >>>= v, l2 -= v, r2.back += v;
                }
                if (u2 >>>= _3, l2 -= _3, r2.back += _3, r2.length = b, 0 === g) {
                  r2.mode = 26;
                  break;
                }
                if (32 & g) {
                  r2.back = -1, r2.mode = 12;
                  break;
                }
                if (64 & g) {
                  e2.msg = "invalid literal/length code", r2.mode = 30;
                  break;
                }
                r2.extra = 15 & g, r2.mode = 22;
              case 22:
                if (r2.extra) {
                  for (z = r2.extra; l2 < z; ) {
                    if (0 === o2) break e;
                    o2--, u2 += n2[s2++] << l2, l2 += 8;
                  }
                  r2.length += u2 & (1 << r2.extra) - 1, u2 >>>= r2.extra, l2 -= r2.extra, r2.back += r2.extra;
                }
                r2.was = r2.length, r2.mode = 23;
              case 23:
                for (; g = (C = r2.distcode[u2 & (1 << r2.distbits) - 1]) >>> 16 & 255, b = 65535 & C, !((_3 = C >>> 24) <= l2); ) {
                  if (0 === o2) break e;
                  o2--, u2 += n2[s2++] << l2, l2 += 8;
                }
                if (0 == (240 & g)) {
                  for (v = _3, y = g, w = b; g = (C = r2.distcode[w + ((u2 & (1 << v + y) - 1) >> v)]) >>> 16 & 255, b = 65535 & C, !(v + (_3 = C >>> 24) <= l2); ) {
                    if (0 === o2) break e;
                    o2--, u2 += n2[s2++] << l2, l2 += 8;
                  }
                  u2 >>>= v, l2 -= v, r2.back += v;
                }
                if (u2 >>>= _3, l2 -= _3, r2.back += _3, 64 & g) {
                  e2.msg = "invalid distance code", r2.mode = 30;
                  break;
                }
                r2.offset = b, r2.extra = 15 & g, r2.mode = 24;
              case 24:
                if (r2.extra) {
                  for (z = r2.extra; l2 < z; ) {
                    if (0 === o2) break e;
                    o2--, u2 += n2[s2++] << l2, l2 += 8;
                  }
                  r2.offset += u2 & (1 << r2.extra) - 1, u2 >>>= r2.extra, l2 -= r2.extra, r2.back += r2.extra;
                }
                if (r2.offset > r2.dmax) {
                  e2.msg = "invalid distance too far back", r2.mode = 30;
                  break;
                }
                r2.mode = 25;
              case 25:
                if (0 === h2) break e;
                if (d = c2 - h2, r2.offset > d) {
                  if ((d = r2.offset - d) > r2.whave && r2.sane) {
                    e2.msg = "invalid distance too far back", r2.mode = 30;
                    break;
                  }
                  p = d > r2.wnext ? (d -= r2.wnext, r2.wsize - d) : r2.wnext - d, d > r2.length && (d = r2.length), m = r2.window;
                } else m = i2, p = a2 - r2.offset, d = r2.length;
                for (h2 < d && (d = h2), h2 -= d, r2.length -= d; i2[a2++] = m[p++], --d; ) ;
                0 === r2.length && (r2.mode = 21);
                break;
              case 26:
                if (0 === h2) break e;
                i2[a2++] = r2.length, h2--, r2.mode = 21;
                break;
              case 27:
                if (r2.wrap) {
                  for (; l2 < 32; ) {
                    if (0 === o2) break e;
                    o2--, u2 |= n2[s2++] << l2, l2 += 8;
                  }
                  if (c2 -= h2, e2.total_out += c2, r2.total += c2, c2 && (e2.adler = r2.check = r2.flags ? B(r2.check, i2, c2, a2 - c2) : O(r2.check, i2, c2, a2 - c2)), c2 = h2, (r2.flags ? u2 : L(u2)) !== r2.check) {
                    e2.msg = "incorrect data check", r2.mode = 30;
                    break;
                  }
                  l2 = u2 = 0;
                }
                r2.mode = 28;
              case 28:
                if (r2.wrap && r2.flags) {
                  for (; l2 < 32; ) {
                    if (0 === o2) break e;
                    o2--, u2 += n2[s2++] << l2, l2 += 8;
                  }
                  if (u2 !== (4294967295 & r2.total)) {
                    e2.msg = "incorrect length check", r2.mode = 30;
                    break;
                  }
                  l2 = u2 = 0;
                }
                r2.mode = 29;
              case 29:
                x = 1;
                break e;
              case 30:
                x = -3;
                break e;
              case 31:
                return -4;
              case 32:
              default:
                return U;
            }
            return e2.next_out = a2, e2.avail_out = h2, e2.next_in = s2, e2.avail_in = o2, r2.hold = u2, r2.bits = l2, (r2.wsize || c2 !== e2.avail_out && r2.mode < 30 && (r2.mode < 27 || 4 !== t2)) && Z(e2, e2.output, e2.next_out, c2 - e2.avail_out) ? (r2.mode = 31, -4) : (f2 -= e2.avail_in, c2 -= e2.avail_out, e2.total_in += f2, e2.total_out += c2, r2.total += c2, r2.wrap && c2 && (e2.adler = r2.check = r2.flags ? B(r2.check, i2, c2, e2.next_out - c2) : O(r2.check, i2, c2, e2.next_out - c2)), e2.data_type = r2.bits + (r2.last ? 64 : 0) + (12 === r2.mode ? 128 : 0) + (20 === r2.mode || 15 === r2.mode ? 256 : 0), (0 == f2 && 0 === c2 || 4 === t2) && x === N && (x = -5), x);
          }, r.inflateEnd = function(e2) {
            if (!e2 || !e2.state) return U;
            var t2 = e2.state;
            return t2.window && (t2.window = null), e2.state = null, N;
          }, r.inflateGetHeader = function(e2, t2) {
            var r2;
            return e2 && e2.state ? 0 == (2 & (r2 = e2.state).wrap) ? U : ((r2.head = t2).done = false, N) : U;
          }, r.inflateSetDictionary = function(e2, t2) {
            var r2, n2 = t2.length;
            return e2 && e2.state ? 0 !== (r2 = e2.state).wrap && 11 !== r2.mode ? U : 11 === r2.mode && O(1, t2, n2, 0) !== r2.check ? -3 : Z(e2, t2, n2, n2) ? (r2.mode = 31, -4) : (r2.havedict = 1, N) : U;
          }, r.inflateInfo = "pako inflate (from Nodeca project)";
        }, { "../utils/common": 41, "./adler32": 43, "./crc32": 45, "./inffast": 48, "./inftrees": 50 }], 50: [function(e, t, r) {
          "use strict";
          var D = e("../utils/common"), F = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 0, 0], N = [16, 16, 16, 16, 16, 16, 16, 16, 17, 17, 17, 17, 18, 18, 18, 18, 19, 19, 19, 19, 20, 20, 20, 20, 21, 21, 21, 21, 16, 72, 78], U = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577, 0, 0], P = [16, 16, 16, 16, 17, 17, 18, 18, 19, 19, 20, 20, 21, 21, 22, 22, 23, 23, 24, 24, 25, 25, 26, 26, 27, 27, 28, 28, 29, 29, 64, 64];
          t.exports = function(e2, t2, r2, n, i, s, a, o) {
            var h, u, l, f, c, d, p, m, _3, g = o.bits, b = 0, v = 0, y = 0, w = 0, k = 0, x = 0, S = 0, z = 0, C = 0, E = 0, A = null, I = 0, O = new D.Buf16(16), B = new D.Buf16(16), R = null, T = 0;
            for (b = 0; b <= 15; b++) O[b] = 0;
            for (v = 0; v < n; v++) O[t2[r2 + v]]++;
            for (k = g, w = 15; 1 <= w && 0 === O[w]; w--) ;
            if (w < k && (k = w), 0 === w) return i[s++] = 20971520, i[s++] = 20971520, o.bits = 1, 0;
            for (y = 1; y < w && 0 === O[y]; y++) ;
            for (k < y && (k = y), b = z = 1; b <= 15; b++) if (z <<= 1, (z -= O[b]) < 0) return -1;
            if (0 < z && (0 === e2 || 1 !== w)) return -1;
            for (B[1] = 0, b = 1; b < 15; b++) B[b + 1] = B[b] + O[b];
            for (v = 0; v < n; v++) 0 !== t2[r2 + v] && (a[B[t2[r2 + v]]++] = v);
            if (d = 0 === e2 ? (A = R = a, 19) : 1 === e2 ? (A = F, I -= 257, R = N, T -= 257, 256) : (A = U, R = P, -1), b = y, c = s, S = v = E = 0, l = -1, f = (C = 1 << (x = k)) - 1, 1 === e2 && 852 < C || 2 === e2 && 592 < C) return 1;
            for (; ; ) {
              for (p = b - S, _3 = a[v] < d ? (m = 0, a[v]) : a[v] > d ? (m = R[T + a[v]], A[I + a[v]]) : (m = 96, 0), h = 1 << b - S, y = u = 1 << x; i[c + (E >> S) + (u -= h)] = p << 24 | m << 16 | _3 | 0, 0 !== u; ) ;
              for (h = 1 << b - 1; E & h; ) h >>= 1;
              if (0 !== h ? (E &= h - 1, E += h) : E = 0, v++, 0 == --O[b]) {
                if (b === w) break;
                b = t2[r2 + a[v]];
              }
              if (k < b && (E & f) !== l) {
                for (0 === S && (S = k), c += y, z = 1 << (x = b - S); x + S < w && !((z -= O[x + S]) <= 0); ) x++, z <<= 1;
                if (C += 1 << x, 1 === e2 && 852 < C || 2 === e2 && 592 < C) return 1;
                i[l = E & f] = k << 24 | x << 16 | c - s | 0;
              }
            }
            return 0 !== E && (i[c + E] = b - S << 24 | 64 << 16 | 0), o.bits = k, 0;
          };
        }, { "../utils/common": 41 }], 51: [function(e, t, r) {
          "use strict";
          t.exports = { 2: "need dictionary", 1: "stream end", 0: "", "-1": "file error", "-2": "stream error", "-3": "data error", "-4": "insufficient memory", "-5": "buffer error", "-6": "incompatible version" };
        }, {}], 52: [function(e, t, r) {
          "use strict";
          var i = e("../utils/common"), o = 0, h = 1;
          function n(e2) {
            for (var t2 = e2.length; 0 <= --t2; ) e2[t2] = 0;
          }
          var s = 0, a = 29, u = 256, l = u + 1 + a, f = 30, c = 19, _3 = 2 * l + 1, g = 15, d = 16, p = 7, m = 256, b = 16, v = 17, y = 18, w = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0], k = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13], x = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 3, 7], S = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15], z = new Array(2 * (l + 2));
          n(z);
          var C = new Array(2 * f);
          n(C);
          var E = new Array(512);
          n(E);
          var A = new Array(256);
          n(A);
          var I = new Array(a);
          n(I);
          var O, B, R, T = new Array(f);
          function D(e2, t2, r2, n2, i2) {
            this.static_tree = e2, this.extra_bits = t2, this.extra_base = r2, this.elems = n2, this.max_length = i2, this.has_stree = e2 && e2.length;
          }
          function F(e2, t2) {
            this.dyn_tree = e2, this.max_code = 0, this.stat_desc = t2;
          }
          function N(e2) {
            return e2 < 256 ? E[e2] : E[256 + (e2 >>> 7)];
          }
          function U(e2, t2) {
            e2.pending_buf[e2.pending++] = 255 & t2, e2.pending_buf[e2.pending++] = t2 >>> 8 & 255;
          }
          function P(e2, t2, r2) {
            e2.bi_valid > d - r2 ? (e2.bi_buf |= t2 << e2.bi_valid & 65535, U(e2, e2.bi_buf), e2.bi_buf = t2 >> d - e2.bi_valid, e2.bi_valid += r2 - d) : (e2.bi_buf |= t2 << e2.bi_valid & 65535, e2.bi_valid += r2);
          }
          function L(e2, t2, r2) {
            P(e2, r2[2 * t2], r2[2 * t2 + 1]);
          }
          function j(e2, t2) {
            for (var r2 = 0; r2 |= 1 & e2, e2 >>>= 1, r2 <<= 1, 0 < --t2; ) ;
            return r2 >>> 1;
          }
          function Z(e2, t2, r2) {
            var n2, i2, s2 = new Array(g + 1), a2 = 0;
            for (n2 = 1; n2 <= g; n2++) s2[n2] = a2 = a2 + r2[n2 - 1] << 1;
            for (i2 = 0; i2 <= t2; i2++) {
              var o2 = e2[2 * i2 + 1];
              0 !== o2 && (e2[2 * i2] = j(s2[o2]++, o2));
            }
          }
          function W(e2) {
            var t2;
            for (t2 = 0; t2 < l; t2++) e2.dyn_ltree[2 * t2] = 0;
            for (t2 = 0; t2 < f; t2++) e2.dyn_dtree[2 * t2] = 0;
            for (t2 = 0; t2 < c; t2++) e2.bl_tree[2 * t2] = 0;
            e2.dyn_ltree[2 * m] = 1, e2.opt_len = e2.static_len = 0, e2.last_lit = e2.matches = 0;
          }
          function M(e2) {
            8 < e2.bi_valid ? U(e2, e2.bi_buf) : 0 < e2.bi_valid && (e2.pending_buf[e2.pending++] = e2.bi_buf), e2.bi_buf = 0, e2.bi_valid = 0;
          }
          function H(e2, t2, r2, n2) {
            var i2 = 2 * t2, s2 = 2 * r2;
            return e2[i2] < e2[s2] || e2[i2] === e2[s2] && n2[t2] <= n2[r2];
          }
          function G(e2, t2, r2) {
            for (var n2 = e2.heap[r2], i2 = r2 << 1; i2 <= e2.heap_len && (i2 < e2.heap_len && H(t2, e2.heap[i2 + 1], e2.heap[i2], e2.depth) && i2++, !H(t2, n2, e2.heap[i2], e2.depth)); ) e2.heap[r2] = e2.heap[i2], r2 = i2, i2 <<= 1;
            e2.heap[r2] = n2;
          }
          function K(e2, t2, r2) {
            var n2, i2, s2, a2, o2 = 0;
            if (0 !== e2.last_lit) for (; n2 = e2.pending_buf[e2.d_buf + 2 * o2] << 8 | e2.pending_buf[e2.d_buf + 2 * o2 + 1], i2 = e2.pending_buf[e2.l_buf + o2], o2++, 0 === n2 ? L(e2, i2, t2) : (L(e2, (s2 = A[i2]) + u + 1, t2), 0 !== (a2 = w[s2]) && P(e2, i2 -= I[s2], a2), L(e2, s2 = N(--n2), r2), 0 !== (a2 = k[s2]) && P(e2, n2 -= T[s2], a2)), o2 < e2.last_lit; ) ;
            L(e2, m, t2);
          }
          function Y(e2, t2) {
            var r2, n2, i2, s2 = t2.dyn_tree, a2 = t2.stat_desc.static_tree, o2 = t2.stat_desc.has_stree, h2 = t2.stat_desc.elems, u2 = -1;
            for (e2.heap_len = 0, e2.heap_max = _3, r2 = 0; r2 < h2; r2++) 0 !== s2[2 * r2] ? (e2.heap[++e2.heap_len] = u2 = r2, e2.depth[r2] = 0) : s2[2 * r2 + 1] = 0;
            for (; e2.heap_len < 2; ) s2[2 * (i2 = e2.heap[++e2.heap_len] = u2 < 2 ? ++u2 : 0)] = 1, e2.depth[i2] = 0, e2.opt_len--, o2 && (e2.static_len -= a2[2 * i2 + 1]);
            for (t2.max_code = u2, r2 = e2.heap_len >> 1; 1 <= r2; r2--) G(e2, s2, r2);
            for (i2 = h2; r2 = e2.heap[1], e2.heap[1] = e2.heap[e2.heap_len--], G(e2, s2, 1), n2 = e2.heap[1], e2.heap[--e2.heap_max] = r2, e2.heap[--e2.heap_max] = n2, s2[2 * i2] = s2[2 * r2] + s2[2 * n2], e2.depth[i2] = (e2.depth[r2] >= e2.depth[n2] ? e2.depth[r2] : e2.depth[n2]) + 1, s2[2 * r2 + 1] = s2[2 * n2 + 1] = i2, e2.heap[1] = i2++, G(e2, s2, 1), 2 <= e2.heap_len; ) ;
            e2.heap[--e2.heap_max] = e2.heap[1], (function(e3, t3) {
              var r3, n3, i3, s3, a3, o3, h3 = t3.dyn_tree, u3 = t3.max_code, l2 = t3.stat_desc.static_tree, f2 = t3.stat_desc.has_stree, c2 = t3.stat_desc.extra_bits, d2 = t3.stat_desc.extra_base, p2 = t3.stat_desc.max_length, m2 = 0;
              for (s3 = 0; s3 <= g; s3++) e3.bl_count[s3] = 0;
              for (h3[2 * e3.heap[e3.heap_max] + 1] = 0, r3 = e3.heap_max + 1; r3 < _3; r3++) p2 < (s3 = h3[2 * h3[2 * (n3 = e3.heap[r3]) + 1] + 1] + 1) && (s3 = p2, m2++), h3[2 * n3 + 1] = s3, u3 < n3 || (e3.bl_count[s3]++, a3 = 0, d2 <= n3 && (a3 = c2[n3 - d2]), o3 = h3[2 * n3], e3.opt_len += o3 * (s3 + a3), f2 && (e3.static_len += o3 * (l2[2 * n3 + 1] + a3)));
              if (0 !== m2) {
                do {
                  for (s3 = p2 - 1; 0 === e3.bl_count[s3]; ) s3--;
                  e3.bl_count[s3]--, e3.bl_count[s3 + 1] += 2, e3.bl_count[p2]--, m2 -= 2;
                } while (0 < m2);
                for (s3 = p2; 0 !== s3; s3--) for (n3 = e3.bl_count[s3]; 0 !== n3; ) u3 < (i3 = e3.heap[--r3]) || (h3[2 * i3 + 1] !== s3 && (e3.opt_len += (s3 - h3[2 * i3 + 1]) * h3[2 * i3], h3[2 * i3 + 1] = s3), n3--);
              }
            })(e2, t2), Z(s2, u2, e2.bl_count);
          }
          function X(e2, t2, r2) {
            var n2, i2, s2 = -1, a2 = t2[1], o2 = 0, h2 = 7, u2 = 4;
            for (0 === a2 && (h2 = 138, u2 = 3), t2[2 * (r2 + 1) + 1] = 65535, n2 = 0; n2 <= r2; n2++) i2 = a2, a2 = t2[2 * (n2 + 1) + 1], ++o2 < h2 && i2 === a2 || (o2 < u2 ? e2.bl_tree[2 * i2] += o2 : 0 !== i2 ? (i2 !== s2 && e2.bl_tree[2 * i2]++, e2.bl_tree[2 * b]++) : o2 <= 10 ? e2.bl_tree[2 * v]++ : e2.bl_tree[2 * y]++, s2 = i2, u2 = (o2 = 0) === a2 ? (h2 = 138, 3) : i2 === a2 ? (h2 = 6, 3) : (h2 = 7, 4));
          }
          function V(e2, t2, r2) {
            var n2, i2, s2 = -1, a2 = t2[1], o2 = 0, h2 = 7, u2 = 4;
            for (0 === a2 && (h2 = 138, u2 = 3), n2 = 0; n2 <= r2; n2++) if (i2 = a2, a2 = t2[2 * (n2 + 1) + 1], !(++o2 < h2 && i2 === a2)) {
              if (o2 < u2) for (; L(e2, i2, e2.bl_tree), 0 != --o2; ) ;
              else 0 !== i2 ? (i2 !== s2 && (L(e2, i2, e2.bl_tree), o2--), L(e2, b, e2.bl_tree), P(e2, o2 - 3, 2)) : o2 <= 10 ? (L(e2, v, e2.bl_tree), P(e2, o2 - 3, 3)) : (L(e2, y, e2.bl_tree), P(e2, o2 - 11, 7));
              s2 = i2, u2 = (o2 = 0) === a2 ? (h2 = 138, 3) : i2 === a2 ? (h2 = 6, 3) : (h2 = 7, 4);
            }
          }
          n(T);
          var q = false;
          function J(e2, t2, r2, n2) {
            P(e2, (s << 1) + (n2 ? 1 : 0), 3), (function(e3, t3, r3, n3) {
              M(e3), n3 && (U(e3, r3), U(e3, ~r3)), i.arraySet(e3.pending_buf, e3.window, t3, r3, e3.pending), e3.pending += r3;
            })(e2, t2, r2, true);
          }
          r._tr_init = function(e2) {
            q || ((function() {
              var e3, t2, r2, n2, i2, s2 = new Array(g + 1);
              for (n2 = r2 = 0; n2 < a - 1; n2++) for (I[n2] = r2, e3 = 0; e3 < 1 << w[n2]; e3++) A[r2++] = n2;
              for (A[r2 - 1] = n2, n2 = i2 = 0; n2 < 16; n2++) for (T[n2] = i2, e3 = 0; e3 < 1 << k[n2]; e3++) E[i2++] = n2;
              for (i2 >>= 7; n2 < f; n2++) for (T[n2] = i2 << 7, e3 = 0; e3 < 1 << k[n2] - 7; e3++) E[256 + i2++] = n2;
              for (t2 = 0; t2 <= g; t2++) s2[t2] = 0;
              for (e3 = 0; e3 <= 143; ) z[2 * e3 + 1] = 8, e3++, s2[8]++;
              for (; e3 <= 255; ) z[2 * e3 + 1] = 9, e3++, s2[9]++;
              for (; e3 <= 279; ) z[2 * e3 + 1] = 7, e3++, s2[7]++;
              for (; e3 <= 287; ) z[2 * e3 + 1] = 8, e3++, s2[8]++;
              for (Z(z, l + 1, s2), e3 = 0; e3 < f; e3++) C[2 * e3 + 1] = 5, C[2 * e3] = j(e3, 5);
              O = new D(z, w, u + 1, l, g), B = new D(C, k, 0, f, g), R = new D(new Array(0), x, 0, c, p);
            })(), q = true), e2.l_desc = new F(e2.dyn_ltree, O), e2.d_desc = new F(e2.dyn_dtree, B), e2.bl_desc = new F(e2.bl_tree, R), e2.bi_buf = 0, e2.bi_valid = 0, W(e2);
          }, r._tr_stored_block = J, r._tr_flush_block = function(e2, t2, r2, n2) {
            var i2, s2, a2 = 0;
            0 < e2.level ? (2 === e2.strm.data_type && (e2.strm.data_type = (function(e3) {
              var t3, r3 = 4093624447;
              for (t3 = 0; t3 <= 31; t3++, r3 >>>= 1) if (1 & r3 && 0 !== e3.dyn_ltree[2 * t3]) return o;
              if (0 !== e3.dyn_ltree[18] || 0 !== e3.dyn_ltree[20] || 0 !== e3.dyn_ltree[26]) return h;
              for (t3 = 32; t3 < u; t3++) if (0 !== e3.dyn_ltree[2 * t3]) return h;
              return o;
            })(e2)), Y(e2, e2.l_desc), Y(e2, e2.d_desc), a2 = (function(e3) {
              var t3;
              for (X(e3, e3.dyn_ltree, e3.l_desc.max_code), X(e3, e3.dyn_dtree, e3.d_desc.max_code), Y(e3, e3.bl_desc), t3 = c - 1; 3 <= t3 && 0 === e3.bl_tree[2 * S[t3] + 1]; t3--) ;
              return e3.opt_len += 3 * (t3 + 1) + 5 + 5 + 4, t3;
            })(e2), i2 = e2.opt_len + 3 + 7 >>> 3, (s2 = e2.static_len + 3 + 7 >>> 3) <= i2 && (i2 = s2)) : i2 = s2 = r2 + 5, r2 + 4 <= i2 && -1 !== t2 ? J(e2, t2, r2, n2) : 4 === e2.strategy || s2 === i2 ? (P(e2, 2 + (n2 ? 1 : 0), 3), K(e2, z, C)) : (P(e2, 4 + (n2 ? 1 : 0), 3), (function(e3, t3, r3, n3) {
              var i3;
              for (P(e3, t3 - 257, 5), P(e3, r3 - 1, 5), P(e3, n3 - 4, 4), i3 = 0; i3 < n3; i3++) P(e3, e3.bl_tree[2 * S[i3] + 1], 3);
              V(e3, e3.dyn_ltree, t3 - 1), V(e3, e3.dyn_dtree, r3 - 1);
            })(e2, e2.l_desc.max_code + 1, e2.d_desc.max_code + 1, a2 + 1), K(e2, e2.dyn_ltree, e2.dyn_dtree)), W(e2), n2 && M(e2);
          }, r._tr_tally = function(e2, t2, r2) {
            return e2.pending_buf[e2.d_buf + 2 * e2.last_lit] = t2 >>> 8 & 255, e2.pending_buf[e2.d_buf + 2 * e2.last_lit + 1] = 255 & t2, e2.pending_buf[e2.l_buf + e2.last_lit] = 255 & r2, e2.last_lit++, 0 === t2 ? e2.dyn_ltree[2 * r2]++ : (e2.matches++, t2--, e2.dyn_ltree[2 * (A[r2] + u + 1)]++, e2.dyn_dtree[2 * N(t2)]++), e2.last_lit === e2.lit_bufsize - 1;
          }, r._tr_align = function(e2) {
            P(e2, 2, 3), L(e2, m, z), (function(e3) {
              16 === e3.bi_valid ? (U(e3, e3.bi_buf), e3.bi_buf = 0, e3.bi_valid = 0) : 8 <= e3.bi_valid && (e3.pending_buf[e3.pending++] = 255 & e3.bi_buf, e3.bi_buf >>= 8, e3.bi_valid -= 8);
            })(e2);
          };
        }, { "../utils/common": 41 }], 53: [function(e, t, r) {
          "use strict";
          t.exports = function() {
            this.input = null, this.next_in = 0, this.avail_in = 0, this.total_in = 0, this.output = null, this.next_out = 0, this.avail_out = 0, this.total_out = 0, this.msg = "", this.state = null, this.data_type = 2, this.adler = 0;
          };
        }, {}], 54: [function(e, t, r) {
          (function(e2) {
            !(function(r2, n) {
              "use strict";
              if (!r2.setImmediate) {
                var i, s, t2, a, o = 1, h = {}, u = false, l = r2.document, e3 = Object.getPrototypeOf && Object.getPrototypeOf(r2);
                e3 = e3 && e3.setTimeout ? e3 : r2, i = "[object process]" === {}.toString.call(r2.process) ? function(e4) {
                  process.nextTick(function() {
                    c(e4);
                  });
                } : (function() {
                  if (r2.postMessage && !r2.importScripts) {
                    var e4 = true, t3 = r2.onmessage;
                    return r2.onmessage = function() {
                      e4 = false;
                    }, r2.postMessage("", "*"), r2.onmessage = t3, e4;
                  }
                })() ? (a = "setImmediate$" + Math.random() + "$", r2.addEventListener ? r2.addEventListener("message", d, false) : r2.attachEvent("onmessage", d), function(e4) {
                  r2.postMessage(a + e4, "*");
                }) : r2.MessageChannel ? ((t2 = new MessageChannel()).port1.onmessage = function(e4) {
                  c(e4.data);
                }, function(e4) {
                  t2.port2.postMessage(e4);
                }) : l && "onreadystatechange" in l.createElement("script") ? (s = l.documentElement, function(e4) {
                  var t3 = l.createElement("script");
                  t3.onreadystatechange = function() {
                    c(e4), t3.onreadystatechange = null, s.removeChild(t3), t3 = null;
                  }, s.appendChild(t3);
                }) : function(e4) {
                  setTimeout(c, 0, e4);
                }, e3.setImmediate = function(e4) {
                  "function" != typeof e4 && (e4 = new Function("" + e4));
                  for (var t3 = new Array(arguments.length - 1), r3 = 0; r3 < t3.length; r3++) t3[r3] = arguments[r3 + 1];
                  var n2 = { callback: e4, args: t3 };
                  return h[o] = n2, i(o), o++;
                }, e3.clearImmediate = f;
              }
              function f(e4) {
                delete h[e4];
              }
              function c(e4) {
                if (u) setTimeout(c, 0, e4);
                else {
                  var t3 = h[e4];
                  if (t3) {
                    u = true;
                    try {
                      !(function(e5) {
                        var t4 = e5.callback, r3 = e5.args;
                        switch (r3.length) {
                          case 0:
                            t4();
                            break;
                          case 1:
                            t4(r3[0]);
                            break;
                          case 2:
                            t4(r3[0], r3[1]);
                            break;
                          case 3:
                            t4(r3[0], r3[1], r3[2]);
                            break;
                          default:
                            t4.apply(n, r3);
                        }
                      })(t3);
                    } finally {
                      f(e4), u = false;
                    }
                  }
                }
              }
              function d(e4) {
                e4.source === r2 && "string" == typeof e4.data && 0 === e4.data.indexOf(a) && c(+e4.data.slice(a.length));
              }
            })("undefined" == typeof self ? void 0 === e2 ? this : e2 : self);
          }).call(this, "undefined" != typeof global ? global : "undefined" != typeof self ? self : "undefined" != typeof window ? window : {});
        }, {}] }, {}, [10])(10);
      });
    }
  });

  // disabled-feature:zh-convert
  var zh_convert_default = { s2t: (x) => x, t2s: (x) => x };

  // vendor/kookit/src/utils/bionicUtil.ts
  var insertAfter = (newNode, existingNode) => {
    if (existingNode.nextSibling !== void 0)
      existingNode.parentNode.insertBefore(newNode, existingNode.nextSibling);
    else existingNode.parentNode.appendChild(newNode);
  };
  var HalfBold = (parentElement) => {
    for (var i = 0; parentElement.childNodes[i] !== void 0; i++) {
      if (parentElement.childNodes[i].nodeName === "#text" && parentElement.childNodes[i].textContent.trim().length !== 0) {
        var recentNode = parentElement.childNodes[i];
        var newNodeCount = 0;
        parentElement.childNodes[i].textContent.split(/(\s+|\S+)/).forEach((word) => {
          if (word.length === 0) return;
          var trimmedWordLength = word.trim().length;
          if (trimmedWordLength === 0) {
            let textNode2 = document.createTextNode(word);
            insertAfter(textNode2, recentNode);
            newNodeCount++;
            recentNode = textNode2;
            return;
          }
          var length = Math.floor(trimmedWordLength / 2);
          if (length === 0) length = 1;
          const bold = document.createElement("b");
          bold.textContent = word.slice(0, length);
          insertAfter(bold, recentNode);
          newNodeCount++;
          recentNode = bold;
          if (word.length === 1) return;
          let textNode = document.createTextNode(word.slice(length));
          insertAfter(textNode, recentNode);
          newNodeCount++;
          recentNode = textNode;
        });
        parentElement.removeChild(parentElement.childNodes[i]);
        i += newNodeCount - 1;
      }
    }
  };
  var ignoreTags = {
    B: true,
    META: true,
    LINK: true,
    SCRIPT: true,
    STYLE: true
  };
  var processDocumentBody = (element) => {
    if (element === null) return;
    if (element.body === void 0) return;
    var collection = element.body.getElementsByTagName("*");
    for (var i = 0; collection[i] !== void 0; i++) {
      if (ignoreTags[collection[i].nodeName]) continue;
      if (collection[i].nodeType !== 1) continue;
      if (collection[i].nodeName === "IFRAME") {
        processDocumentBody(collection[i].contentDocument);
      } else {
        if (collection[i].childNodes.length === 0) continue;
        HalfBold(collection[i]);
      }
    }
  };

  // vendor/kookit/src/utils/common.ts
  var classes = [
    "color-0",
    "color-1",
    "color-2",
    "color-3",
    "line-0",
    "line-1",
    "line-2",
    "line-3"
  ];
  var colors = ["#FEF3CD", "#FBFACC", "#CEFACD", "#CDE9FA"];
  var lines = ["#FF0000", "#000080", "#0000FF", "#2EFF2E"];
  var buildHighlightStyleForType = (colorCode, forPDFOverlay, isVertical) => {
    let styleType = "background";
    let rawColor = "#FEF3CD";
    if (typeof colorCode === "number") {
      if (colorCode >= 0 && colorCode < classes.length) {
        const isBackground = classes[colorCode].indexOf("color") > -1;
        const colorIdx = parseInt(classes[colorCode].split("-")[1]);
        styleType = isBackground ? "background" : "underline";
        rawColor = isBackground ? colors[colorIdx] : lines[colorIdx];
      }
    } else {
      styleType = colorCode.split("-")[0];
      rawColor = colorCode.split("-")[1];
    }
    const color = styleType === "background" ? hexToRgba(rawColor, 0.8) : rawColor;
    switch (styleType) {
      case "background":
        if (forPDFOverlay) {
          return `background: ${color}; mix-blend-mode: multiply;`;
        }
        return `background: ${color};`;
      case "underline":
        if (forPDFOverlay) {
          if (isVertical) {
            return `border-right: 2px solid ${color};`;
          }
          return `border-bottom: 2px solid ${color};`;
        }
        return `text-decoration: underline; text-decoration-color: ${color}; text-decoration-thickness: 2px; text-decoration-skip-ink: none;`;
      case "strikethrough":
        if (forPDFOverlay) {
          return `background: linear-gradient(transparent calc(50% - 1px), ${color} calc(50% - 1px), ${color} calc(50% + 1px), transparent calc(50% + 1px));`;
        }
        if (isVertical) {
          return `background: linear-gradient(to right, transparent calc(50% - 1px), ${color} calc(50% - 1px), ${color} calc(50% + 1px), transparent calc(50% + 1px));`;
        }
        return `text-decoration: line-through; text-decoration-color: ${color}; text-decoration-thickness: 2px; text-decoration-skip-ink: none;`;
      case "wavy":
        const encodedColor = rawColor.replace("#", "%23");
        if (forPDFOverlay) {
          const svgWavy = `url("data:image/svg+xml,%3Csvg xmlns='http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg' width='6' height='3'%3E%3Cpath d='M0 2 Q1.5 0 3 2 Q4.5 4 6 2' fill='none' stroke='${encodedColor}' stroke-width='1.5'%2F%3E%3C%2Fsvg%3E")`;
          return `background-image: ${svgWavy}; background-repeat: repeat-x; background-position: bottom; background-size: 6px 3px;`;
        }
        if (isVertical) {
          const svgWavyVertical = `url("data:image/svg+xml,%3Csvg xmlns='http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg' width='3' height='6'%3E%3Cpath d='M2 0 Q0 1.5 2 3 Q4 4.5 2 6' fill='none' stroke='${encodedColor}' stroke-width='1.5'%2F%3E%3C%2Fsvg%3E")`;
          return `background-image: ${svgWavyVertical}; background-repeat: repeat-y; background-position: right; background-size: 3px 6px;`;
        }
        return `text-decoration-line: underline; text-decoration-style: wavy; text-decoration-color: ${color}; text-decoration-thickness: 2px; text-decoration-skip-ink: none;`;
      default:
        return `background: ${color};`;
    }
  };
  var hexToRgba = (hexColor, alpha) => {
    const hex = hexColor.replace("#", "");
    const isShort = hex.length === 3;
    const normalized = isShort ? hex.split("").map((ch) => ch + ch).join("") : hex;
    if (normalized.length !== 6) return hexColor;
    const r = parseInt(normalized.slice(0, 2), 16);
    const g = parseInt(normalized.slice(2, 4), 16);
    const b = parseInt(normalized.slice(4, 6), 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  };
  var isElectron = () => {
    if (typeof window !== "undefined" && typeof window.process === "object" && window.process.type === "renderer") {
      return true;
    }
    if (typeof process !== "undefined" && typeof process.versions === "object" && !!process.versions.electron) {
      return true;
    }
    if (typeof navigator === "object" && typeof navigator.userAgent === "string" && navigator.userAgent.indexOf("Electron") >= 0) {
      return true;
    }
    return false;
  };
  var getBlockElement = (Element) => {
    return Array.from(
      Element.querySelectorAll(
        "h1,h2,h3,h4,h5,h6,p,div,ul,dl,ol,li,dt,dd,pre,blockquote,address,kookitmarker"
      )
    );
  };
  var isParentBlock = (myDiv) => {
    var children = myDiv.children;
    let flag = false;
    var blockRegex = /^(address|kookitmarker|section|blockquote|body|center|dir|div|dl|fieldset|form|h[1-6]|hr|isindex|menu|noframes|noscript|ol|p|pre|table|ul|dd|dt|frameset|li|tbody|td|tfoot|th|thead|tr|html)$/i;
    for (var i = 0; i < children.length; i++) {
      if (blockRegex.test(children[i].nodeName)) {
        flag = true;
        break;
      }
    }
    return flag;
  };
  function parseStyleToMap(styleText) {
    const map2 = {};
    if (!styleText) return map2;
    const parts = styleText.split(";");
    for (const rawPart of parts) {
      const part = rawPart.trim();
      if (!part) continue;
      const idx = part.indexOf(":");
      if (idx <= 0) continue;
      const prop = part.slice(0, idx).trim().toLowerCase();
      const value = part.slice(idx + 1).trim();
      if (!prop) continue;
      map2[prop] = value;
    }
    return map2;
  }
  function styleMapToString(map2) {
    const entries = Object.entries(map2).filter(([, v]) => (v || "").trim());
    if (entries.length === 0) return "";
    return entries.map(([k, v]) => `${k}: ${v}`).join("; ");
  }
  function mergeStyleStrings(baseStyle, extraStyle) {
    const base = parseStyleToMap(baseStyle);
    const extra = parseStyleToMap(extraStyle);
    const merged = { ...base, ...extra };
    return styleMapToString(merged);
  }
  function getViewportSize(htmlStr) {
    if (!htmlStr) return null;
    const metaMatch = htmlStr.match(
      /<meta\b[^>]*name\s*=\s*["']viewport["'][^>]*content\s*=\s*["']([^"']+)["'][^>]*>/i
    );
    if (!metaMatch) return null;
    const content = metaMatch[1] || "";
    const widthMatch = content.match(/\bwidth\s*=\s*(\d+(?:\.\d+)?)\b/i);
    const heightMatch = content.match(/\bheight\s*=\s*(\d+(?:\.\d+)?)\b/i);
    const width = widthMatch ? parseFloat(widthMatch[1]) : void 0;
    const height = heightMatch ? parseFloat(heightMatch[1]) : void 0;
    if (!width && !height) return null;
    return { width, height };
  }
  function getStylePxNumber(styleText, prop) {
    if (!styleText || !prop) return null;
    const map2 = parseStyleToMap(styleText);
    const val = map2[prop.toLowerCase()];
    if (!val) return null;
    const normalized = val.replace(/\s*!important\s*$/i, "").trim();
    const m = normalized.match(/^(-?\d+(?:\.\d+)?)(?:px)?$/i);
    if (!m) return null;
    const num = parseFloat(m[1]);
    return Number.isFinite(num) && num > 0 ? num : null;
  }
  function getPageWidth(element, readerMode) {
    if (!element) return 0;
    const section = Math.floor(element.clientWidth / 12);
    const gap = section % 2 === 0 ? section : section - 1;
    const scale = readerMode === "double" ? 2 : 1;
    return (element.clientWidth - gap) / scale;
  }
  var cumulativeSumWithPrevious = (arr) => {
    return arr.map((num, index) => {
      const sumBefore = arr.slice(0, index).reduce((acc, cur) => acc + cur, 0);
      return sumBefore;
    });
  };

  // vendor/kookit/src/utils/textRuleUtil.ts
  var BLOCK_SELECTOR = "h1,h2,h3,h4,h5,h6,p,div,ul,dl,ol,pre,li,dt,dd,blockquote,address,kookitmarker";
  var REJECTED_CLASSES = [
    "kookit-note",
    "kookit-note-icon",
    "kookit-word-def",
    "kookit-note-tooltip",
    "kookit-word-tooltip",
    "kookit-text-rule-replace",
    "kookit-text-rule-delete",
    "kookit-text-rule-highlight",
    "kookit-translation-host"
  ];
  var isRejectedTextNode = (node2) => {
    let parent = node2.parentElement;
    while (parent) {
      const tag = parent.tagName;
      if (tag === "SCRIPT" || tag === "STYLE" || tag === "RUBY") {
        return true;
      }
      for (let i = 0; i < REJECTED_CLASSES.length; i++) {
        if (parent.classList.contains(REJECTED_CLASSES[i])) {
          return true;
        }
      }
      parent = parent.parentElement;
    }
    return false;
  };
  var expandReplacement = (replacement, match) => {
    return replacement.replace(/\$(\$|\d+)/g, (_m, group2) => {
      if (group2 === "$") return "$";
      const index = parseInt(group2, 10);
      return match[index] ?? "";
    });
  };
  var clearTextRules = (doc2) => {
    const spans = doc2.querySelectorAll(
      ".kookit-text-rule-replace, .kookit-text-rule-delete, .kookit-text-rule-highlight"
    );
    for (let i = 0; i < spans.length; i++) {
      const span = spans[i];
      const parent = span.parentNode;
      if (!parent) continue;
      while (span.firstChild) {
        parent.insertBefore(span.firstChild, span);
      }
      parent.removeChild(span);
      parent.normalize();
    }
  };
  var collectTextNodes = (doc2, root2) => {
    const walker = doc2.createTreeWalker(root2, NodeFilter.SHOW_TEXT, {
      acceptNode: (node2) => {
        return isRejectedTextNode(node2) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
      }
    });
    const textNodes = [];
    while (walker.nextNode()) {
      textNodes.push(walker.currentNode);
    }
    return textNodes;
  };
  var wrapMatchesInTextNode = (doc2, textNode, regex, rule) => {
    const text = textNode.textContent || "";
    regex.lastIndex = 0;
    if (!regex.test(text)) return;
    regex.lastIndex = 0;
    const fragment = doc2.createDocumentFragment();
    let lastIndex = 0;
    let match;
    while ((match = regex.exec(text)) !== null) {
      const before2 = text.slice(lastIndex, match.index);
      if (before2) fragment.appendChild(doc2.createTextNode(before2));
      const matchedText = match[0];
      const span = doc2.createElement("span");
      if (rule.type === "replace") {
        span.className = "kookit-text-rule-replace";
        const replacement = rule.matchType === "regex" ? expandReplacement(rule.replacement || "", match) : rule.replacement || "";
        span.setAttribute("data-kookit-replacement", replacement);
      } else if (rule.type === "delete") {
        span.className = "kookit-text-rule-delete";
      } else if (rule.type === "highlight") {
        span.className = "kookit-text-rule-highlight";
        if (rule.highlightStyle && rule.highlightColor) {
          const colorCode = `${rule.highlightStyle}-${rule.highlightColor}`;
          const inlineStyle = buildHighlightStyleForType(colorCode, false, false);
          span.setAttribute("style", inlineStyle);
        }
      }
      span.appendChild(doc2.createTextNode(matchedText));
      fragment.appendChild(span);
      lastIndex = match.index + matchedText.length;
      if (matchedText.length === 0) {
        regex.lastIndex++;
      }
    }
    if (lastIndex === 0) return;
    const after2 = text.slice(lastIndex);
    if (after2) fragment.appendChild(doc2.createTextNode(after2));
    textNode.parentNode?.replaceChild(fragment, textNode);
  };
  var applyRule = (doc2, rule) => {
    const elements = doc2.querySelectorAll(BLOCK_SELECTOR);
    const regex = rule.matchType === "regex" ? new RegExp(rule.pattern, "g") : new RegExp(rule.pattern.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g");
    for (let i = 0; i < elements.length; i++) {
      const textNodes = collectTextNodes(doc2, elements[i]);
      for (let j = 0; j < textNodes.length; j++) {
        wrapMatchesInTextNode(doc2, textNodes[j], regex, rule);
      }
    }
  };
  var applyTextRules = (doc2, rules) => {
    clearTextRules(doc2);
    for (let i = 0; i < rules.length; i++) {
      const rule = rules[i];
      if (rule.scope === "all" || rule.scope === "book") {
        applyRule(doc2, rule);
      }
    }
  };

  // vendor/kookit/src/utils/layoutUtil.ts
  var isVerticalLayout = () => {
    return window.textOrientation === "vertical";
  };
  var convertStyleNum = (value) => {
    if (!value) return 0;
    return parseFloat(value + "");
  };
  var convertComputedNum = (value) => {
    return parseFloat(value.substring(0, value.length - 2));
  };
  var getActualOffsetLeft = (child) => {
    if (child) {
      const childRect = child.getBoundingClientRect();
      return childRect.left - (child.offsetParent?.getBoundingClientRect().left || 0);
    }
    return 0;
  };
  var getActualOffsetTop = (child) => {
    if (child) {
      const childRect = child.getBoundingClientRect();
      return childRect.top - (child.offsetParent?.getBoundingClientRect().top || 0);
    }
    return 0;
  };
  var handleIframeHeight = async (element, readerMode, format, iframe, doc2) => {
    await Promise.race([
      Promise.all(
        Array.from([...doc2.images, ...doc2.querySelectorAll("image")]).map(
          (img) => {
            if (img.complete) return Promise.resolve(img.naturalHeight !== 0);
            return new Promise((resolve) => {
              img.addEventListener("load", () => resolve(true));
              img.addEventListener("error", () => resolve(false));
            });
          }
        )
      ),
      new Promise((resolve, reject2) => {
        setTimeout(() => {
          resolve("image load timeout");
        }, 10);
      })
    ]);
    if (!doc2.body.getAttribute("data-kookit-fixed-scale")) {
      await handleImageSize(element, readerMode, format, doc2);
    }
    await handleTextStyle(doc2);
    if (readerMode !== "scroll") {
      iframe.height = element.clientHeight + "px";
      if (readerMode === "double") {
        if (isVerticalLayout()) {
        } else {
          let section = Math.floor(element.clientWidth / 12);
          let gap = section % 2 === 0 ? section : section - 1;
          let pageWidth = (element.clientWidth + gap) / 2;
          if ((doc2.body.scrollWidth - doc2.body.clientWidth) / pageWidth % 2 === 1) {
            let tailElem = document.createElement("div");
            tailElem.setAttribute(
              "style",
              "height: " + doc2.body.clientHeight + "px; display: inline-block; width: " + (pageWidth - gap) + "px"
            );
            doc2.body.appendChild(tailElem);
          }
        }
      }
    } else {
      iframe.height = doc2.body.scrollHeight + "px";
      iframe.height = doc2.body.scrollHeight + 300 + "px";
    }
  };
  var handleOneChapterDoc = async (item, isSearch) => {
    let chapterText = "";
    if (item && item.load) {
      let chapteruUrl = await item.load();
      let res = await fetch(chapteruUrl);
      let blob = await res.blob();
      chapterText = await blob.text();
    }
    if (isSearch) {
      return chapterText;
    }
    chapterText = await handlePrecacheAssets(chapterText, item);
    return chapterText;
  };
  var getImageElement = (Element) => {
    return Array.from(Element.querySelectorAll("img, image"));
  };
  var getImageUrl = (el) => {
    return el.getAttribute("src") || el.getAttribute("href") || el.getAttribute("xlink:href") || null;
  };
  var collectChapterImageUrls = (root2) => {
    const urls = [];
    const nodes = root2.querySelectorAll("img, svg, image");
    for (const el of nodes) {
      const tag = el.tagName.toLowerCase();
      if (tag === "img") {
        const url = getImageUrl(el);
        if (url) urls.push(url);
      } else if (tag === "svg") {
        el.querySelectorAll("image").forEach((img) => {
          if (img.closest("svg") !== el) return;
          const url = getImageUrl(img);
          if (url) urls.push(url);
        });
      } else if (tag === "image" && !el.closest("svg")) {
        const url = getImageUrl(el);
        if (url) urls.push(url);
      }
    }
    return urls;
  };
  var handlePrecacheAssets = async (bookStr, item) => {
    let chapterDoc = new DOMParser().parseFromString(bookStr, "text/html");
    if (item && item.loadAsset) {
      let loadAsset = item.loadAsset;
      let imgDomList2 = getImageElement(chapterDoc);
      for (let subindex = 0; subindex < imgDomList2.length; subindex++) {
        if (imgDomList2[subindex].getAttribute("src")) {
          imgDomList2[subindex].src = await loadAsset(
            imgDomList2[subindex].getAttribute("src")
          );
        } else if (imgDomList2[subindex].getAttribute("xlink:href")) {
          imgDomList2[subindex].setAttribute(
            "xlink:href",
            await loadAsset(imgDomList2[subindex].getAttribute("xlink:href"))
          );
        }
      }
      let linkList = Array.from(chapterDoc.getElementsByTagName("link"));
      for (let index = 0; index < linkList.length; index++) {
        const link = linkList[index];
        if (link.getAttribute("href")) {
          link.href = await loadAsset(link.getAttribute("href"));
        }
      }
    }
    if (chapterDoc && chapterDoc.documentElement) {
      chapterDoc.documentElement.lang = "en";
    }
    if (window.isHyphenation === "yes" && isElectron()) {
      applyHyphenation(chapterDoc);
    }
    if (window.fullTranslationMode === "both" || window.fullTranslationMode === "target") {
      let nodeList = getBlockElement(chapterDoc.body).filter(
        (item2) => !isParentBlock(item2)
      );
      for (let node2 of nodeList) {
        if (node2.textContent && node2.textContent?.trim()) {
          let id = node2.getAttribute("id") || "kookit-trans-" + Math.random().toString(36).substr(2, 9);
          if (window.transMap[node2.textContent]) {
            id = window.transMap[node2.textContent].id;
          }
          node2.setAttribute("id", id);
          node2.classList.add("kookit-translation-host");
          node2.classList.add("kookit-translation-loading");
          node2.setAttribute("data-kookit-translation", "");
          let originalText = node2.textContent || "";
          window.transMap[originalText] = {
            id
          };
        }
      }
    }
    let imgDomList = getImageElement(chapterDoc);
    if (imgDomList.length > 0) {
      for (let i = 0; i < imgDomList.length; i++) {
        if (imgDomList[i].tagName === "image") {
          continue;
        }
        var newItem = document.createElement("kookitmarker");
        var textnode = document.createTextNode("img");
        newItem.appendChild(textnode);
        newItem.setAttribute(
          "style",
          "visibility: hidden; position: absolute;display: inline-block; width: 0; height: 0;"
        );
        let imgElement = imgDomList[i];
        let topLevelParent = imgElement;
        while (topLevelParent.parentElement && topLevelParent.parentElement !== chapterDoc.body) {
          topLevelParent = topLevelParent.parentElement;
        }
        if (topLevelParent.parentElement === chapterDoc.body) {
          topLevelParent.insertAdjacentElement("afterend", newItem);
        } else {
          chapterDoc.body.appendChild(newItem);
        }
      }
      return chapterDoc.documentElement.innerHTML;
    }
    return chapterDoc.documentElement.innerHTML;
  };
  var createIframe = (element, isAllowScript, scale) => {
    var iframe = document.createElement("iframe");
    iframe.style.width = scale ? (scale - 0.4) * 100 + "%" : "100%";
    iframe.style.margin = "0";
    iframe.style.border = "0";
    iframe.style.padding = "0";
    iframe.style.minHeight = "calc(100% - 2px)";
    iframe.style.fontSize = "100%";
    iframe.style.font = "inherit";
    iframe.scrolling = "no";
    iframe.tabIndex = 0;
    iframe.id = "kookit-iframe";
    iframe.style.verticalAlign = "baseline";
    if (isAllowScript !== "yes") {
      iframe.setAttribute("sandbox", "allow-same-origin");
    }
    element.innerHTML = "";
    element.appendChild(iframe);
    const doc2 = iframe.contentDocument || iframe.contentWindow?.document;
    if (doc2 && doc2.documentElement) {
      doc2.documentElement.lang = "en";
    }
    if (scale) {
      element.scrollLeft = element.scrollWidth / 2 - element.clientWidth / 2;
    }
  };
  var progressInfo = (readerMode, doc2, element) => {
    const vertical = isVerticalLayout() && readerMode !== "scroll";
    if (vertical) {
      let section2 = Math.floor(element.clientHeight / 12);
      let gap2 = section2 % 2 === 0 ? section2 : section2 - 1;
      return {
        totalPage: readerMode === "single" ? Math.round(
          parseFloat(
            doc2.body.scrollHeight / (doc2.body.clientHeight + gap2) + ""
          )
        ) : Math.round(
          parseFloat(
            doc2.body.scrollHeight / (doc2.body.clientHeight + gap2) + ""
          )
        ) * 2,
        currentPage: Math.round(
          parseFloat(
            convertStyleNum(doc2.body.scrollTop) / (doc2.body.clientHeight + gap2) + ""
          )
        ) + 1
      };
    }
    let section = Math.floor(element.clientWidth / 12);
    let gap = section % 2 === 0 ? section : section - 1;
    return {
      totalPage: readerMode === "scroll" ? Math.floor(element.scrollHeight / (element.clientHeight - 50)) : readerMode === "single" ? Math.round(
        parseFloat(
          doc2.body.scrollWidth / (doc2.body.clientWidth + gap) + ""
        )
      ) : Math.round(
        parseFloat(
          doc2.body.scrollWidth / (doc2.body.clientWidth + gap) + ""
        )
      ) * 2,
      currentPage: readerMode === "scroll" ? Math.floor(element.scrollTop / (element.clientHeight - 50)) + 1 : Math.round(
        parseFloat(
          convertStyleNum(doc2.body.scrollLeft) / (doc2.body.clientWidth + gap) + ""
        )
      ) + 1
    };
  };
  var fetchHighlightAsset = async (path) => {
    const url = `${isElectron() ? "." : ""}/lib/highlight-js/${path}`;
    return await (await fetch(url)).text();
  };
  var runHighlightScript = (source) => {
    const script = document.createElement("script");
    script.textContent = source;
    document.head.appendChild(script);
  };
  var ensureHighlightJs = async (language) => {
    if (!window.hljs) {
      runHighlightScript(await fetchHighlightAsset("highlight.min.js"));
    }
    if (window.kookitHljsLanguage !== language) {
      runHighlightScript(
        await fetchHighlightAsset(`languages/${language}.min.js`)
      );
      window.kookitHljsLanguage = language;
    }
  };
  var getCodeHighlightTargets = (doc2) => {
    return Array.from(doc2.querySelectorAll("code"));
  };
  var applyCodeHighlighting = async (doc2, language) => {
    await ensureHighlightJs(language);
    if (!doc2.head.querySelector("#kookit-code-highlighter-style")) {
      const style = document.createElement("style");
      style.id = "kookit-code-highlighter-style";
      style.textContent = await fetchHighlightAsset("default.min.css");
      doc2.head.appendChild(style);
    }
    const langClass = "language-" + language;
    getCodeHighlightTargets(doc2).forEach((element) => {
      element.classList.add(langClass);
      delete element.dataset.highlighted;
      window.hljs.highlightElement(element);
    });
  };
  var transformText = async (doc2) => {
    if (window.bookLayout) {
      const cssPath = () => `${isElectron() ? "." : ""}/lib/${window.bookLayout}-css/${window.bookLayout}.min.css`;
      const fetchText = async (url) => await (await fetch(url)).text();
      const textCSS = async () => await fetchText(cssPath());
      const style = document.createElement("style");
      style.id = "kookit-book-layout-style";
      style.textContent = await textCSS();
      doc2.head.appendChild(style);
      if (!doc2.body.classList.contains(window.bookLayout)) {
        doc2.body.classList.add(window.bookLayout);
      }
    }
    if (window.convertChinese === "Simplified To Traditional") {
      doc2.querySelectorAll(
        "h1,h2,h3,h4,h5,h6,p,div,ul,dl,ol,pre,li,dt,dd,blockquote,address,kookitmarker"
      ).forEach((item) => {
        item.innerHTML = item.innerHTML.split("").map((item2) => zh_convert_default.s2t(item2)).join("");
      });
    } else if (window.convertChinese === "Traditional To Simplified") {
      doc2.querySelectorAll(
        "h1,h2,h3,h4,h5,h6,p,div,ul,dl,ol,pre,li,dt,dd,blockquote,address,kookitmarker"
      ).forEach((item) => {
        item.innerHTML = item.innerHTML.split("").map((item2) => zh_convert_default.t2s(item2)).join("");
      });
    }
    if (window.isIndent === "yes") {
      doc2.querySelectorAll(
        "h1,h2,h3,h4,h5,h6,p,div,ul,dl,ol,pre,li,dt,dd,blockquote,address"
      ).forEach((item) => {
        for (let node2 of item.childNodes) {
          if (node2.nodeType === Node.TEXT_NODE) {
            const text = node2.nodeValue || "";
            const firstChar = text.charAt(0);
            if (firstChar && firstChar.trim() === "" && firstChar !== " " && firstChar !== "\n" && firstChar !== "	") {
              item.setAttribute(
                "style",
                (item.getAttribute("style") || "") + "text-indent: 0em !important;"
              );
            }
            break;
          }
          if (node2.nodeType === Node.ELEMENT_NODE && node2.tagName.toLowerCase() === "img") {
            item.setAttribute(
              "style",
              (item.getAttribute("style") || "") + "text-indent: 0em !important;"
            );
            break;
          }
        }
      });
    }
    if (window.isBionic === "yes") {
      processDocumentBody(doc2);
    }
    if (window.codeHighlight) {
      await applyCodeHighlighting(doc2, window.codeHighlight);
    }
    if (window.textRules && window.textRules.length > 0) {
      applyTextRules(doc2, window.textRules);
    }
  };
  var handleTextStyle = async (doc2) => {
    await transformText(doc2);
  };
  var getImageMeta = async (url) => {
    const img = new Image();
    img.src = url;
    try {
      await img.decode();
    } catch (error) {
      console.error(error);
    }
    return img;
  };
  var handleImageSize = async (element, readerMode, format, doc2) => {
    let section = Math.floor(element.clientWidth / 12);
    let gap = section % 2 === 0 ? section : section - 1;
    let scale = readerMode === "double" ? 2 : 1;
    let pageWidth = (element.clientWidth - gap) / scale;
    let imgs = Array.from(doc2.querySelectorAll("img, image"));
    await Promise.all(
      imgs.map(async (item) => {
        if (item.tagName === "image" && !item._naturalWidth) {
          let img = await getImageMeta(item.getAttribute("xlink:href"));
          item._naturalWidth = img.naturalWidth;
          item._naturalHeight = img.naturalHeight;
        }
      })
    );
    const BATCH = 20;
    const elementClientWidth = element.clientWidth;
    const elementClientHeight = element.clientHeight;
    const bodyClientHeight = doc2.body.clientHeight;
    const getContentWidth = (el) => {
      if (!el) return 0;
      const style = getComputedStyle(el);
      return Math.min(el.clientWidth, pageWidth) - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight);
    };
    const getContentHeight = (el) => {
      if (!el) return 0;
      const style = getComputedStyle(el);
      return Math.min(el.clientHeight, elementClientHeight) - parseFloat(style.paddingTop) - parseFloat(style.paddingBottom);
    };
    const measures = imgs.map((item) => {
      const parentItem = item.parentElement;
      const grandItem = parentItem?.parentElement;
      let width = item.getAttribute("width");
      let height = item.getAttribute("height");
      if (!width && item.getAttribute("style")) {
        width = getStylePxNumber(item.getAttribute("style"), "width");
      }
      if (!height && item.getAttribute("style")) {
        height = getStylePxNumber(item.getAttribute("style"), "height");
      }
      if (!width) {
        width = item.tagName === "image" ? item._naturalWidth : item.naturalWidth;
      }
      if (!height) {
        height = item.tagName === "image" ? item._naturalHeight : item.naturalHeight;
      }
      return {
        item,
        width: width || 0,
        height: height || 0,
        parentOffsetWidth: parentItem?.offsetWidth || 0,
        parentClientWidth: getContentWidth(parentItem),
        parentClientHeight: getContentHeight(parentItem),
        grandClientWidth: getContentWidth(grandItem),
        grandClientHeight: getContentHeight(grandItem),
        grandTagName: grandItem?.tagName || "",
        existingStyle: item.getAttribute("style") || ""
      };
    });
    const writes = measures.map((m) => {
      const {
        item,
        width,
        height,
        parentOffsetWidth,
        parentClientWidth,
        parentClientHeight,
        grandClientWidth,
        grandClientHeight,
        grandTagName
      } = m;
      let maxHeight = 0;
      let maxWidth = 0;
      let setParentIndent = false;
      let setGrandIndent = false;
      if (format.startsWith("CB") && readerMode === "scroll") {
        maxWidth = parentOffsetWidth;
      } else if (format.startsWith("CB") && readerMode === "single") {
        maxHeight = elementClientHeight;
        maxWidth = elementClientWidth;
      } else if (parentClientWidth && parentClientHeight && width && height) {
        let isImageScaleLargerThanElement = height / width > parentClientHeight / parentClientWidth;
        if (isImageScaleLargerThanElement) {
          maxHeight = parentClientHeight;
          maxWidth = parseInt(maxHeight * width / height + "");
        } else {
          maxWidth = parentClientWidth;
          maxHeight = parseInt(maxWidth * height / width + "");
        }
        if (maxHeight > bodyClientHeight && readerMode !== "scroll") {
          maxWidth = parseInt(maxWidth * (bodyClientHeight / maxHeight) + "");
          maxHeight = bodyClientHeight;
        }
        setParentIndent = true;
      } else if (parentClientWidth > 0) {
        maxWidth = parentClientWidth;
        maxHeight = parentClientHeight;
        setParentIndent = true;
      } else if (grandTagName !== "BODY" && grandClientWidth > 0) {
        maxWidth = grandClientWidth;
        maxHeight = grandClientHeight;
        setGrandIndent = true;
      } else {
        maxWidth = elementClientWidth;
        maxHeight = elementClientHeight;
      }
      if (maxWidth) {
        maxWidth = Math.min(
          readerMode === "scroll" || readerMode === "single" ? elementClientWidth : pageWidth,
          maxWidth
        );
      } else {
        maxWidth = readerMode === "scroll" || readerMode === "single" ? elementClientWidth : pageWidth;
      }
      if (width && height) {
        if (width > height) {
          maxHeight = maxWidth * (height / width);
        } else {
          if (maxHeight / maxWidth > height / width) {
            maxHeight = maxWidth * (height / width);
          } else {
            maxWidth = maxHeight * (width / height);
          }
        }
      }
      if (readerMode !== "scroll" && maxWidth && maxHeight && maxHeight > elementClientHeight) {
        maxWidth = maxWidth * (elementClientHeight / maxHeight);
        maxHeight = elementClientHeight;
      }
      const styles = [];
      if (maxWidth || maxHeight) {
        styles.push(
          `max-width: ${maxWidth > 0 ? maxWidth + "px" : ""};max-height:${maxHeight > 0 ? maxHeight + "px" : ""}; margin: 0 auto; min-width: 0px; min-height: 0px;`
        );
      }
      if (format.startsWith("CB") && readerMode === "scroll") {
        styles.push("margin-left: 0px; width: 100%;");
      }
      return {
        item,
        styles,
        isSvgImage: item.tagName === "image",
        maxWidth,
        maxHeight,
        parentItem: item.parentElement,
        grandItem: item.parentElement?.parentElement,
        setParentIndent,
        setGrandIndent
      };
    });
    for (let i = 0; i < writes.length; i++) {
      if (i > 0 && i % BATCH === 0) {
        await new Promise((r) => setTimeout(r, 0));
      }
      const w = writes[i];
      const { item, styles, isSvgImage, maxWidth, maxHeight } = w;
      if (w.setParentIndent && w.parentItem) {
        w.parentItem.style.textIndent = "0px";
      }
      if (w.setGrandIndent && w.grandItem) {
        w.grandItem.style.textIndent = "0px";
      }
      if (styles.length > 0) {
        const existing = item.getAttribute("style") || "";
        item.setAttribute("style", existing + ";" + styles.join(";"));
      }
      if (isSvgImage) {
        item.parentElement?.setAttribute("width", maxWidth);
        item.parentElement?.setAttribute("height", maxHeight);
      }
      if (format.startsWith("CB") && readerMode !== "scroll") {
        const liveWidth = item.getBoundingClientRect().width;
        const existing = item.getAttribute("style") || "";
        item.setAttribute(
          "style",
          existing + `;margin-left: calc(50% - ${liveWidth / 2}px);`
        );
      }
    }
  };
  var handleLayout = (element, readerMode, doc2) => {
    let style = doc2.createElement("style");
    style.id = "default-style";
    style.textContent = "body{margin: 0px}";
    doc2.head.appendChild(style);
    const vertical = isVerticalLayout();
    if (readerMode === "scroll") {
      return;
    }
    let scale = readerMode === "double" ? 2 : 1;
    if (vertical) {
      let section = Math.floor(element.clientHeight / 12);
      let gap = section % 2 === 0 ? section : section - 1;
      doc2.documentElement.setAttribute(
        "style",
        `writing-mode: vertical-rl; text-orientation: mixed; height: ${element.clientHeight + "px"};width: 100%;overflow-y: hidden;overflow-x: hidden;padding-left: 0px;padding-right: 0px;margin: 0px;box-sizing: border-box;touch-action:none; overscroll-behavior: none;max-width: inherit;column-fill: auto;column-gap: ${gap}px; column-width: ${(element.clientHeight - gap) / scale}px;`
      );
      doc2.body.setAttribute(
        "style",
        `margin: 0px !important; padding: 0px !important;`
      );
    } else {
      let section = Math.floor(element.clientWidth / 12);
      let gap = section % 2 === 0 ? section : section - 1;
      doc2.documentElement.setAttribute(
        "style",
        `width: ${element.clientWidth + "px"};height: 100%;overflow-y: hidden;overflow-X: hidden;padding-left: 0px;padding-right: 0px;margin: 0px;box-sizing: border-box;touch-action:none; overscroll-behavior: none;max-width: inherit;column-fill: auto;column-gap: ${gap}px; column-width: ${(element.clientWidth - gap) / scale}px;`
      );
      doc2.body.setAttribute(
        "style",
        `margin: 0px !important; padding: 0px !important;`
      );
    }
  };
  function getSelectedElement(doc2) {
    const selection2 = doc2.getSelection();
    if (!selection2) return null;
    if (selection2.rangeCount > 0) {
      const range2 = selection2.getRangeAt(0);
      const selectedElement = range2.startContainer.parentElement;
      return selectedElement;
    }
    return null;
  }
  var applyHyphenation = (doc2) => {
    if (!doc2 || !doc2.body) return;
    const SKIP_TAGS = /* @__PURE__ */ new Set([
      "CODE",
      "PRE",
      "SCRIPT",
      "STYLE",
      "KBD",
      "SAMP",
      "A"
    ]);
    function getBreakpoints(word) {
      const len = word.length;
      const points = [];
      for (let i = 2; i < len; i++) {
        if (len - i - 1 >= 3 && (i + 1) % 6 === 0) {
          points.push(i + 1);
        }
      }
      return points;
    }
    const WORD_RE = /[A-Za-zÀ-ɏ]{9,}/g;
    const walker = doc2.createTreeWalker(doc2.body, NodeFilter.SHOW_TEXT, {
      acceptNode(node3) {
        const parent = node3.parentElement;
        if (!parent) return NodeFilter.FILTER_REJECT;
        if (SKIP_TAGS.has(parent.tagName?.toUpperCase())) {
          return NodeFilter.FILTER_REJECT;
        }
        if (parent.classList?.contains("kookit-hyphen")) {
          return NodeFilter.FILTER_REJECT;
        }
        return NodeFilter.FILTER_ACCEPT;
      }
    });
    const nodes = [];
    let node2;
    while (node2 = walker.nextNode()) {
      nodes.push(node2);
    }
    for (const textNode of nodes) {
      const text = textNode.textContent || "";
      WORD_RE.lastIndex = 0;
      if (!WORD_RE.test(text)) continue;
      WORD_RE.lastIndex = 0;
      const matches = [];
      let m;
      while ((m = WORD_RE.exec(text)) !== null) {
        const breaks = getBreakpoints(m[0]);
        if (breaks.length) {
          matches.push({
            start: m.index,
            end: m.index + m[0].length,
            breaks
          });
        }
      }
      if (!matches.length) continue;
      const parent = textNode.parentNode;
      if (!parent) continue;
      const allBreaks = [];
      for (const mt of matches) {
        for (const b of mt.breaks) allBreaks.push(mt.start + b);
      }
      allBreaks.sort((a, b) => a - b);
      let current2 = textNode;
      for (const absOffset of allBreaks) {
        const curLen = current2.textContent?.length || 0;
        if (absOffset <= 0 || absOffset >= curLen) continue;
        const after2 = current2.splitText(absOffset);
        const marker = doc2.createElement("span");
        marker.className = "kookit-hyphen";
        parent.insertBefore(marker, after2);
        current2 = after2;
      }
    }
  };

  // node_modules/underscore/modules/index.js
  var modules_exports = {};
  __export(modules_exports, {
    VERSION: () => VERSION,
    after: () => after,
    all: () => every,
    allKeys: () => allKeys,
    any: () => some,
    assign: () => extendOwn_default,
    before: () => before,
    bind: () => bind_default,
    bindAll: () => bindAll_default,
    chain: () => chain,
    chunk: () => chunk,
    clone: () => clone,
    collect: () => map,
    compact: () => compact,
    compose: () => compose,
    constant: () => constant,
    contains: () => contains,
    countBy: () => countBy_default,
    create: () => create,
    debounce: () => debounce,
    default: () => underscore_array_methods_default,
    defaults: () => defaults_default,
    defer: () => defer_default,
    delay: () => delay_default,
    detect: () => find,
    difference: () => difference_default,
    drop: () => rest,
    each: () => each,
    escape: () => escape_default,
    every: () => every,
    extend: () => extend_default,
    extendOwn: () => extendOwn_default,
    filter: () => filter,
    find: () => find,
    findIndex: () => findIndex_default,
    findKey: () => findKey,
    findLastIndex: () => findLastIndex_default,
    findWhere: () => findWhere,
    first: () => first,
    flatten: () => flatten2,
    foldl: () => reduce_default,
    foldr: () => reduceRight_default,
    forEach: () => each,
    functions: () => functions,
    get: () => get,
    groupBy: () => groupBy_default,
    has: () => has2,
    head: () => first,
    identity: () => identity,
    include: () => contains,
    includes: () => contains,
    indexBy: () => indexBy_default,
    indexOf: () => indexOf_default,
    initial: () => initial,
    inject: () => reduce_default,
    intersection: () => intersection,
    invert: () => invert,
    invoke: () => invoke_default,
    isArguments: () => isArguments_default,
    isArray: () => isArray_default,
    isArrayBuffer: () => isArrayBuffer_default,
    isBoolean: () => isBoolean,
    isDataView: () => isDataView_default,
    isDate: () => isDate_default,
    isElement: () => isElement,
    isEmpty: () => isEmpty,
    isEqual: () => isEqual,
    isError: () => isError_default,
    isFinite: () => isFinite2,
    isFunction: () => isFunction_default,
    isMap: () => isMap_default,
    isMatch: () => isMatch,
    isNaN: () => isNaN2,
    isNull: () => isNull,
    isNumber: () => isNumber_default,
    isObject: () => isObject,
    isRegExp: () => isRegExp_default,
    isSet: () => isSet_default,
    isString: () => isString_default,
    isSymbol: () => isSymbol_default,
    isTypedArray: () => isTypedArray_default,
    isUndefined: () => isUndefined,
    isWeakMap: () => isWeakMap_default,
    isWeakSet: () => isWeakSet_default,
    iteratee: () => iteratee,
    keys: () => keys,
    last: () => last,
    lastIndexOf: () => lastIndexOf_default,
    map: () => map,
    mapObject: () => mapObject,
    matcher: () => matcher,
    matches: () => matcher,
    max: () => max,
    memoize: () => memoize,
    methods: () => functions,
    min: () => min,
    mixin: () => mixin,
    negate: () => negate,
    noop: () => noop,
    now: () => now_default,
    object: () => object,
    omit: () => omit_default,
    once: () => once_default,
    pairs: () => pairs,
    partial: () => partial_default,
    partition: () => partition_default,
    pick: () => pick_default,
    pluck: () => pluck,
    property: () => property,
    propertyOf: () => propertyOf,
    random: () => random,
    range: () => range,
    reduce: () => reduce_default,
    reduceRight: () => reduceRight_default,
    reject: () => reject,
    rest: () => rest,
    restArguments: () => restArguments,
    result: () => result,
    sample: () => sample,
    select: () => filter,
    shuffle: () => shuffle,
    size: () => size,
    some: () => some,
    sortBy: () => sortBy,
    sortedIndex: () => sortedIndex,
    tail: () => rest,
    take: () => first,
    tap: () => tap,
    template: () => template,
    templateSettings: () => templateSettings_default,
    throttle: () => throttle,
    times: () => times,
    toArray: () => toArray,
    toPath: () => toPath,
    transpose: () => unzip,
    unescape: () => unescape_default,
    union: () => union_default,
    uniq: () => uniq,
    unique: () => uniq,
    uniqueId: () => uniqueId,
    unzip: () => unzip,
    values: () => values,
    where: () => where,
    without: () => without_default,
    wrap: () => wrap,
    zip: () => zip_default
  });

  // node_modules/underscore/modules/_setup.js
  var VERSION = "1.13.8";
  var root = typeof self == "object" && self.self === self && self || typeof global == "object" && global.global === global && global || Function("return this")() || {};
  var ArrayProto = Array.prototype;
  var ObjProto = Object.prototype;
  var SymbolProto = typeof Symbol !== "undefined" ? Symbol.prototype : null;
  var push = ArrayProto.push;
  var slice = ArrayProto.slice;
  var toString = ObjProto.toString;
  var hasOwnProperty = ObjProto.hasOwnProperty;
  var supportsArrayBuffer = typeof ArrayBuffer !== "undefined";
  var supportsDataView = typeof DataView !== "undefined";
  var nativeIsArray = Array.isArray;
  var nativeKeys = Object.keys;
  var nativeCreate = Object.create;
  var nativeIsView = supportsArrayBuffer && ArrayBuffer.isView;
  var _isNaN = isNaN;
  var _isFinite = isFinite;
  var hasEnumBug = !{ toString: null }.propertyIsEnumerable("toString");
  var nonEnumerableProps = [
    "valueOf",
    "isPrototypeOf",
    "toString",
    "propertyIsEnumerable",
    "hasOwnProperty",
    "toLocaleString"
  ];
  var MAX_ARRAY_INDEX = Math.pow(2, 53) - 1;

  // node_modules/underscore/modules/restArguments.js
  function restArguments(func, startIndex) {
    startIndex = startIndex == null ? func.length - 1 : +startIndex;
    return function() {
      var length = Math.max(arguments.length - startIndex, 0), rest2 = Array(length), index = 0;
      for (; index < length; index++) {
        rest2[index] = arguments[index + startIndex];
      }
      switch (startIndex) {
        case 0:
          return func.call(this, rest2);
        case 1:
          return func.call(this, arguments[0], rest2);
        case 2:
          return func.call(this, arguments[0], arguments[1], rest2);
      }
      var args = Array(startIndex + 1);
      for (index = 0; index < startIndex; index++) {
        args[index] = arguments[index];
      }
      args[startIndex] = rest2;
      return func.apply(this, args);
    };
  }

  // node_modules/underscore/modules/isObject.js
  function isObject(obj) {
    var type = typeof obj;
    return type === "function" || type === "object" && !!obj;
  }

  // node_modules/underscore/modules/isNull.js
  function isNull(obj) {
    return obj === null;
  }

  // node_modules/underscore/modules/isUndefined.js
  function isUndefined(obj) {
    return obj === void 0;
  }

  // node_modules/underscore/modules/isBoolean.js
  function isBoolean(obj) {
    return obj === true || obj === false || toString.call(obj) === "[object Boolean]";
  }

  // node_modules/underscore/modules/isElement.js
  function isElement(obj) {
    return !!(obj && obj.nodeType === 1);
  }

  // node_modules/underscore/modules/_tagTester.js
  function tagTester(name) {
    var tag = "[object " + name + "]";
    return function(obj) {
      return toString.call(obj) === tag;
    };
  }

  // node_modules/underscore/modules/isString.js
  var isString_default = tagTester("String");

  // node_modules/underscore/modules/isNumber.js
  var isNumber_default = tagTester("Number");

  // node_modules/underscore/modules/isDate.js
  var isDate_default = tagTester("Date");

  // node_modules/underscore/modules/isRegExp.js
  var isRegExp_default = tagTester("RegExp");

  // node_modules/underscore/modules/isError.js
  var isError_default = tagTester("Error");

  // node_modules/underscore/modules/isSymbol.js
  var isSymbol_default = tagTester("Symbol");

  // node_modules/underscore/modules/isArrayBuffer.js
  var isArrayBuffer_default = tagTester("ArrayBuffer");

  // node_modules/underscore/modules/isFunction.js
  var isFunction = tagTester("Function");
  var nodelist = root.document && root.document.childNodes;
  if (typeof /./ != "function" && typeof Int8Array != "object" && typeof nodelist != "function") {
    isFunction = function(obj) {
      return typeof obj == "function" || false;
    };
  }
  var isFunction_default = isFunction;

  // node_modules/underscore/modules/_hasObjectTag.js
  var hasObjectTag_default = tagTester("Object");

  // node_modules/underscore/modules/_stringTagBug.js
  var hasDataViewBug = supportsDataView && (!/\[native code\]/.test(String(DataView)) || hasObjectTag_default(new DataView(new ArrayBuffer(8))));
  var isIE11 = typeof Map !== "undefined" && hasObjectTag_default(/* @__PURE__ */ new Map());

  // node_modules/underscore/modules/isDataView.js
  var isDataView = tagTester("DataView");
  function alternateIsDataView(obj) {
    return obj != null && isFunction_default(obj.getInt8) && isArrayBuffer_default(obj.buffer);
  }
  var isDataView_default = hasDataViewBug ? alternateIsDataView : isDataView;

  // node_modules/underscore/modules/isArray.js
  var isArray_default = nativeIsArray || tagTester("Array");

  // node_modules/underscore/modules/_has.js
  function has(obj, key) {
    return obj != null && hasOwnProperty.call(obj, key);
  }

  // node_modules/underscore/modules/isArguments.js
  var isArguments = tagTester("Arguments");
  (function() {
    if (!isArguments(arguments)) {
      isArguments = function(obj) {
        return has(obj, "callee");
      };
    }
  })();
  var isArguments_default = isArguments;

  // node_modules/underscore/modules/isFinite.js
  function isFinite2(obj) {
    return !isSymbol_default(obj) && _isFinite(obj) && !isNaN(parseFloat(obj));
  }

  // node_modules/underscore/modules/isNaN.js
  function isNaN2(obj) {
    return isNumber_default(obj) && _isNaN(obj);
  }

  // node_modules/underscore/modules/constant.js
  function constant(value) {
    return function() {
      return value;
    };
  }

  // node_modules/underscore/modules/_createSizePropertyCheck.js
  function createSizePropertyCheck(getSizeProperty) {
    return function(collection) {
      var sizeProperty = getSizeProperty(collection);
      return typeof sizeProperty == "number" && sizeProperty >= 0 && sizeProperty <= MAX_ARRAY_INDEX;
    };
  }

  // node_modules/underscore/modules/_shallowProperty.js
  function shallowProperty(key) {
    return function(obj) {
      return obj == null ? void 0 : obj[key];
    };
  }

  // node_modules/underscore/modules/_getByteLength.js
  var getByteLength_default = shallowProperty("byteLength");

  // node_modules/underscore/modules/_isBufferLike.js
  var isBufferLike_default = createSizePropertyCheck(getByteLength_default);

  // node_modules/underscore/modules/isTypedArray.js
  var typedArrayPattern = /\[object ((I|Ui)nt(8|16|32)|Float(32|64)|Uint8Clamped|Big(I|Ui)nt64)Array\]/;
  function isTypedArray(obj) {
    return nativeIsView ? nativeIsView(obj) && !isDataView_default(obj) : isBufferLike_default(obj) && typedArrayPattern.test(toString.call(obj));
  }
  var isTypedArray_default = supportsArrayBuffer ? isTypedArray : constant(false);

  // node_modules/underscore/modules/_getLength.js
  var getLength_default = shallowProperty("length");

  // node_modules/underscore/modules/_collectNonEnumProps.js
  function emulatedSet(keys2) {
    var hash = {};
    for (var l = keys2.length, i = 0; i < l; ++i) hash[keys2[i]] = true;
    return {
      contains: function(key) {
        return hash[key] === true;
      },
      push: function(key) {
        hash[key] = true;
        return keys2.push(key);
      }
    };
  }
  function collectNonEnumProps(obj, keys2) {
    keys2 = emulatedSet(keys2);
    var nonEnumIdx = nonEnumerableProps.length;
    var constructor = obj.constructor;
    var proto = isFunction_default(constructor) && constructor.prototype || ObjProto;
    var prop = "constructor";
    if (has(obj, prop) && !keys2.contains(prop)) keys2.push(prop);
    while (nonEnumIdx--) {
      prop = nonEnumerableProps[nonEnumIdx];
      if (prop in obj && obj[prop] !== proto[prop] && !keys2.contains(prop)) {
        keys2.push(prop);
      }
    }
  }

  // node_modules/underscore/modules/keys.js
  function keys(obj) {
    if (!isObject(obj)) return [];
    if (nativeKeys) return nativeKeys(obj);
    var keys2 = [];
    for (var key in obj) if (has(obj, key)) keys2.push(key);
    if (hasEnumBug) collectNonEnumProps(obj, keys2);
    return keys2;
  }

  // node_modules/underscore/modules/isEmpty.js
  function isEmpty(obj) {
    if (obj == null) return true;
    var length = getLength_default(obj);
    if (typeof length == "number" && (isArray_default(obj) || isString_default(obj) || isArguments_default(obj))) return length === 0;
    return getLength_default(keys(obj)) === 0;
  }

  // node_modules/underscore/modules/isMatch.js
  function isMatch(object2, attrs) {
    var _keys = keys(attrs), length = _keys.length;
    if (object2 == null) return !length;
    var obj = Object(object2);
    for (var i = 0; i < length; i++) {
      var key = _keys[i];
      if (attrs[key] !== obj[key] || !(key in obj)) return false;
    }
    return true;
  }

  // node_modules/underscore/modules/underscore.js
  function _(obj) {
    if (obj instanceof _) return obj;
    if (!(this instanceof _)) return new _(obj);
    this._wrapped = obj;
  }
  _.VERSION = VERSION;
  _.prototype.value = function() {
    return this._wrapped;
  };
  _.prototype.valueOf = _.prototype.toJSON = _.prototype.value;
  _.prototype.toString = function() {
    return String(this._wrapped);
  };

  // node_modules/underscore/modules/_toBufferView.js
  function toBufferView(bufferSource) {
    return new Uint8Array(
      bufferSource.buffer || bufferSource,
      bufferSource.byteOffset || 0,
      getByteLength_default(bufferSource)
    );
  }

  // node_modules/underscore/modules/isEqual.js
  var tagDataView = "[object DataView]";
  function isEqual(a, b) {
    var todo = [{ a, b }];
    var aStack = [], bStack = [];
    while (todo.length) {
      var frame = todo.pop();
      if (frame === true) {
        aStack.pop();
        bStack.pop();
        continue;
      }
      a = frame.a;
      b = frame.b;
      if (a === b) {
        if (a !== 0 || 1 / a === 1 / b) continue;
        return false;
      }
      if (a == null || b == null) return false;
      if (a !== a) {
        if (b !== b) continue;
        return false;
      }
      var type = typeof a;
      if (type !== "function" && type !== "object" && typeof b != "object") return false;
      if (a instanceof _) a = a._wrapped;
      if (b instanceof _) b = b._wrapped;
      var className = toString.call(a);
      if (className !== toString.call(b)) return false;
      if (hasDataViewBug && className == "[object Object]" && isDataView_default(a)) {
        if (!isDataView_default(b)) return false;
        className = tagDataView;
      }
      switch (className) {
        // These types are compared by value.
        case "[object RegExp]":
        // RegExps are coerced to strings for comparison (Note: '' + /a/i === '/a/i')
        case "[object String]":
          if ("" + a === "" + b) continue;
          return false;
        case "[object Number]":
          todo.push({ a: +a, b: +b });
          continue;
        case "[object Date]":
        case "[object Boolean]":
          if (+a === +b) continue;
          return false;
        case "[object Symbol]":
          if (SymbolProto.valueOf.call(a) === SymbolProto.valueOf.call(b)) continue;
          return false;
        case "[object ArrayBuffer]":
        case tagDataView:
          todo.push({ a: toBufferView(a), b: toBufferView(b) });
          continue;
      }
      var areArrays = className === "[object Array]";
      if (!areArrays && isTypedArray_default(a)) {
        var byteLength = getByteLength_default(a);
        if (byteLength !== getByteLength_default(b)) return false;
        if (a.buffer === b.buffer && a.byteOffset === b.byteOffset) continue;
        areArrays = true;
      }
      if (!areArrays) {
        if (typeof a != "object" || typeof b != "object") return false;
        var aCtor = a.constructor, bCtor = b.constructor;
        if (aCtor !== bCtor && !(isFunction_default(aCtor) && aCtor instanceof aCtor && isFunction_default(bCtor) && bCtor instanceof bCtor) && ("constructor" in a && "constructor" in b)) {
          return false;
        }
      }
      var length = aStack.length;
      while (length--) {
        if (aStack[length] === a) {
          if (bStack[length] === b) break;
          return false;
        }
      }
      if (length >= 0) continue;
      aStack.push(a);
      bStack.push(b);
      todo.push(true);
      if (areArrays) {
        length = a.length;
        if (length !== b.length) return false;
        while (length--) {
          todo.push({ a: a[length], b: b[length] });
        }
      } else {
        var _keys = keys(a), key;
        length = _keys.length;
        if (keys(b).length !== length) return false;
        while (length--) {
          key = _keys[length];
          if (!has(b, key)) return false;
          todo.push({ a: a[key], b: b[key] });
        }
      }
    }
    return true;
  }

  // node_modules/underscore/modules/allKeys.js
  function allKeys(obj) {
    if (!isObject(obj)) return [];
    var keys2 = [];
    for (var key in obj) keys2.push(key);
    if (hasEnumBug) collectNonEnumProps(obj, keys2);
    return keys2;
  }

  // node_modules/underscore/modules/_methodFingerprint.js
  function ie11fingerprint(methods) {
    var length = getLength_default(methods);
    return function(obj) {
      if (obj == null) return false;
      var keys2 = allKeys(obj);
      if (getLength_default(keys2)) return false;
      for (var i = 0; i < length; i++) {
        if (!isFunction_default(obj[methods[i]])) return false;
      }
      return methods !== weakMapMethods || !isFunction_default(obj[forEachName]);
    };
  }
  var forEachName = "forEach";
  var hasName = "has";
  var commonInit = ["clear", "delete"];
  var mapTail = ["get", hasName, "set"];
  var mapMethods = commonInit.concat(forEachName, mapTail);
  var weakMapMethods = commonInit.concat(mapTail);
  var setMethods = ["add"].concat(commonInit, forEachName, hasName);

  // node_modules/underscore/modules/isMap.js
  var isMap_default = isIE11 ? ie11fingerprint(mapMethods) : tagTester("Map");

  // node_modules/underscore/modules/isWeakMap.js
  var isWeakMap_default = isIE11 ? ie11fingerprint(weakMapMethods) : tagTester("WeakMap");

  // node_modules/underscore/modules/isSet.js
  var isSet_default = isIE11 ? ie11fingerprint(setMethods) : tagTester("Set");

  // node_modules/underscore/modules/isWeakSet.js
  var isWeakSet_default = tagTester("WeakSet");

  // node_modules/underscore/modules/values.js
  function values(obj) {
    var _keys = keys(obj);
    var length = _keys.length;
    var values2 = Array(length);
    for (var i = 0; i < length; i++) {
      values2[i] = obj[_keys[i]];
    }
    return values2;
  }

  // node_modules/underscore/modules/pairs.js
  function pairs(obj) {
    var _keys = keys(obj);
    var length = _keys.length;
    var pairs2 = Array(length);
    for (var i = 0; i < length; i++) {
      pairs2[i] = [_keys[i], obj[_keys[i]]];
    }
    return pairs2;
  }

  // node_modules/underscore/modules/invert.js
  function invert(obj) {
    var result2 = {};
    var _keys = keys(obj);
    for (var i = 0, length = _keys.length; i < length; i++) {
      result2[obj[_keys[i]]] = _keys[i];
    }
    return result2;
  }

  // node_modules/underscore/modules/functions.js
  function functions(obj) {
    var names = [];
    for (var key in obj) {
      if (isFunction_default(obj[key])) names.push(key);
    }
    return names.sort();
  }

  // node_modules/underscore/modules/_createAssigner.js
  function createAssigner(keysFunc, defaults) {
    return function(obj) {
      var length = arguments.length;
      if (defaults) obj = Object(obj);
      if (length < 2 || obj == null) return obj;
      for (var index = 1; index < length; index++) {
        var source = arguments[index], keys2 = keysFunc(source), l = keys2.length;
        for (var i = 0; i < l; i++) {
          var key = keys2[i];
          if (!defaults || obj[key] === void 0) obj[key] = source[key];
        }
      }
      return obj;
    };
  }

  // node_modules/underscore/modules/extend.js
  var extend_default = createAssigner(allKeys);

  // node_modules/underscore/modules/extendOwn.js
  var extendOwn_default = createAssigner(keys);

  // node_modules/underscore/modules/defaults.js
  var defaults_default = createAssigner(allKeys, true);

  // node_modules/underscore/modules/_baseCreate.js
  function ctor() {
    return function() {
    };
  }
  function baseCreate(prototype) {
    if (!isObject(prototype)) return {};
    if (nativeCreate) return nativeCreate(prototype);
    var Ctor = ctor();
    Ctor.prototype = prototype;
    var result2 = new Ctor();
    Ctor.prototype = null;
    return result2;
  }

  // node_modules/underscore/modules/create.js
  function create(prototype, props) {
    var result2 = baseCreate(prototype);
    if (props) extendOwn_default(result2, props);
    return result2;
  }

  // node_modules/underscore/modules/clone.js
  function clone(obj) {
    if (!isObject(obj)) return obj;
    return isArray_default(obj) ? obj.slice() : extend_default({}, obj);
  }

  // node_modules/underscore/modules/tap.js
  function tap(obj, interceptor) {
    interceptor(obj);
    return obj;
  }

  // node_modules/underscore/modules/toPath.js
  function toPath(path) {
    return isArray_default(path) ? path : [path];
  }
  _.toPath = toPath;

  // node_modules/underscore/modules/_toPath.js
  function toPath2(path) {
    return _.toPath(path);
  }

  // node_modules/underscore/modules/_deepGet.js
  function deepGet(obj, path) {
    var length = path.length;
    for (var i = 0; i < length; i++) {
      if (obj == null) return void 0;
      obj = obj[path[i]];
    }
    return length ? obj : void 0;
  }

  // node_modules/underscore/modules/get.js
  function get(object2, path, defaultValue) {
    var value = deepGet(object2, toPath2(path));
    return isUndefined(value) ? defaultValue : value;
  }

  // node_modules/underscore/modules/has.js
  function has2(obj, path) {
    path = toPath2(path);
    var length = path.length;
    for (var i = 0; i < length; i++) {
      var key = path[i];
      if (!has(obj, key)) return false;
      obj = obj[key];
    }
    return !!length;
  }

  // node_modules/underscore/modules/identity.js
  function identity(value) {
    return value;
  }

  // node_modules/underscore/modules/matcher.js
  function matcher(attrs) {
    attrs = extendOwn_default({}, attrs);
    return function(obj) {
      return isMatch(obj, attrs);
    };
  }

  // node_modules/underscore/modules/property.js
  function property(path) {
    path = toPath2(path);
    return function(obj) {
      return deepGet(obj, path);
    };
  }

  // node_modules/underscore/modules/_optimizeCb.js
  function optimizeCb(func, context, argCount) {
    if (context === void 0) return func;
    switch (argCount == null ? 3 : argCount) {
      case 1:
        return function(value) {
          return func.call(context, value);
        };
      // The 2-argument case is omitted because we’re not using it.
      case 3:
        return function(value, index, collection) {
          return func.call(context, value, index, collection);
        };
      case 4:
        return function(accumulator, value, index, collection) {
          return func.call(context, accumulator, value, index, collection);
        };
    }
    return function() {
      return func.apply(context, arguments);
    };
  }

  // node_modules/underscore/modules/_baseIteratee.js
  function baseIteratee(value, context, argCount) {
    if (value == null) return identity;
    if (isFunction_default(value)) return optimizeCb(value, context, argCount);
    if (isObject(value) && !isArray_default(value)) return matcher(value);
    return property(value);
  }

  // node_modules/underscore/modules/iteratee.js
  function iteratee(value, context) {
    return baseIteratee(value, context, Infinity);
  }
  _.iteratee = iteratee;

  // node_modules/underscore/modules/_cb.js
  function cb(value, context, argCount) {
    if (_.iteratee !== iteratee) return _.iteratee(value, context);
    return baseIteratee(value, context, argCount);
  }

  // node_modules/underscore/modules/mapObject.js
  function mapObject(obj, iteratee2, context) {
    iteratee2 = cb(iteratee2, context);
    var _keys = keys(obj), length = _keys.length, results = {};
    for (var index = 0; index < length; index++) {
      var currentKey = _keys[index];
      results[currentKey] = iteratee2(obj[currentKey], currentKey, obj);
    }
    return results;
  }

  // node_modules/underscore/modules/noop.js
  function noop() {
  }

  // node_modules/underscore/modules/propertyOf.js
  function propertyOf(obj) {
    if (obj == null) return noop;
    return function(path) {
      return get(obj, path);
    };
  }

  // node_modules/underscore/modules/times.js
  function times(n, iteratee2, context) {
    var accum = Array(Math.max(0, n));
    iteratee2 = optimizeCb(iteratee2, context, 1);
    for (var i = 0; i < n; i++) accum[i] = iteratee2(i);
    return accum;
  }

  // node_modules/underscore/modules/random.js
  function random(min2, max2) {
    if (max2 == null) {
      max2 = min2;
      min2 = 0;
    }
    return min2 + Math.floor(Math.random() * (max2 - min2 + 1));
  }

  // node_modules/underscore/modules/now.js
  var now_default = Date.now || function() {
    return (/* @__PURE__ */ new Date()).getTime();
  };

  // node_modules/underscore/modules/_createEscaper.js
  function createEscaper(map2) {
    var escaper = function(match) {
      return map2[match];
    };
    var source = "(?:" + keys(map2).join("|") + ")";
    var testRegexp = RegExp(source);
    var replaceRegexp = RegExp(source, "g");
    return function(string) {
      string = string == null ? "" : "" + string;
      return testRegexp.test(string) ? string.replace(replaceRegexp, escaper) : string;
    };
  }

  // node_modules/underscore/modules/_escapeMap.js
  var escapeMap_default = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#x27;",
    "`": "&#x60;"
  };

  // node_modules/underscore/modules/escape.js
  var escape_default = createEscaper(escapeMap_default);

  // node_modules/underscore/modules/_unescapeMap.js
  var unescapeMap_default = invert(escapeMap_default);

  // node_modules/underscore/modules/unescape.js
  var unescape_default = createEscaper(unescapeMap_default);

  // node_modules/underscore/modules/templateSettings.js
  var templateSettings_default = _.templateSettings = {
    evaluate: /<%([\s\S]+?)%>/g,
    interpolate: /<%=([\s\S]+?)%>/g,
    escape: /<%-([\s\S]+?)%>/g
  };

  // node_modules/underscore/modules/template.js
  var noMatch = /(.)^/;
  var escapes = {
    "'": "'",
    "\\": "\\",
    "\r": "r",
    "\n": "n",
    "\u2028": "u2028",
    "\u2029": "u2029"
  };
  var escapeRegExp = /\\|'|\r|\n|\u2028|\u2029/g;
  function escapeChar(match) {
    return "\\" + escapes[match];
  }
  var bareIdentifier = /^\s*(\w|\$)+\s*$/;
  function template(text, settings, oldSettings) {
    if (!settings && oldSettings) settings = oldSettings;
    settings = defaults_default({}, settings, _.templateSettings);
    var matcher2 = RegExp([
      (settings.escape || noMatch).source,
      (settings.interpolate || noMatch).source,
      (settings.evaluate || noMatch).source
    ].join("|") + "|$", "g");
    var index = 0;
    var source = "__p+='";
    text.replace(matcher2, function(match, escape, interpolate, evaluate, offset) {
      source += text.slice(index, offset).replace(escapeRegExp, escapeChar);
      index = offset + match.length;
      if (escape) {
        source += "'+\n((__t=(" + escape + "))==null?'':_.escape(__t))+\n'";
      } else if (interpolate) {
        source += "'+\n((__t=(" + interpolate + "))==null?'':__t)+\n'";
      } else if (evaluate) {
        source += "';\n" + evaluate + "\n__p+='";
      }
      return match;
    });
    source += "';\n";
    var argument = settings.variable;
    if (argument) {
      if (!bareIdentifier.test(argument)) throw new Error(
        "variable is not a bare identifier: " + argument
      );
    } else {
      source = "with(obj||{}){\n" + source + "}\n";
      argument = "obj";
    }
    source = "var __t,__p='',__j=Array.prototype.join,print=function(){__p+=__j.call(arguments,'');};\n" + source + "return __p;\n";
    var render;
    try {
      render = new Function(argument, "_", source);
    } catch (e) {
      e.source = source;
      throw e;
    }
    var template2 = function(data) {
      return render.call(this, data, _);
    };
    template2.source = "function(" + argument + "){\n" + source + "}";
    return template2;
  }

  // node_modules/underscore/modules/result.js
  function result(obj, path, fallback) {
    path = toPath2(path);
    var length = path.length;
    if (!length) {
      return isFunction_default(fallback) ? fallback.call(obj) : fallback;
    }
    for (var i = 0; i < length; i++) {
      var prop = obj == null ? void 0 : obj[path[i]];
      if (prop === void 0) {
        prop = fallback;
        i = length;
      }
      obj = isFunction_default(prop) ? prop.call(obj) : prop;
    }
    return obj;
  }

  // node_modules/underscore/modules/uniqueId.js
  var idCounter = 0;
  function uniqueId(prefix) {
    var id = ++idCounter + "";
    return prefix ? prefix + id : id;
  }

  // node_modules/underscore/modules/chain.js
  function chain(obj) {
    var instance = _(obj);
    instance._chain = true;
    return instance;
  }

  // node_modules/underscore/modules/_executeBound.js
  function executeBound(sourceFunc, boundFunc, context, callingContext, args) {
    if (!(callingContext instanceof boundFunc)) return sourceFunc.apply(context, args);
    var self2 = baseCreate(sourceFunc.prototype);
    var result2 = sourceFunc.apply(self2, args);
    if (isObject(result2)) return result2;
    return self2;
  }

  // node_modules/underscore/modules/partial.js
  var partial = restArguments(function(func, boundArgs) {
    var placeholder = partial.placeholder;
    var bound = function() {
      var position = 0, length = boundArgs.length;
      var args = Array(length);
      for (var i = 0; i < length; i++) {
        args[i] = boundArgs[i] === placeholder ? arguments[position++] : boundArgs[i];
      }
      while (position < arguments.length) args.push(arguments[position++]);
      return executeBound(func, bound, this, this, args);
    };
    return bound;
  });
  partial.placeholder = _;
  var partial_default = partial;

  // node_modules/underscore/modules/bind.js
  var bind_default = restArguments(function(func, context, args) {
    if (!isFunction_default(func)) throw new TypeError("Bind must be called on a function");
    var bound = restArguments(function(callArgs) {
      return executeBound(func, bound, context, this, args.concat(callArgs));
    });
    return bound;
  });

  // node_modules/underscore/modules/_isArrayLike.js
  var isArrayLike_default = createSizePropertyCheck(getLength_default);

  // node_modules/underscore/modules/_flatten.js
  function flatten(input, depth, strict) {
    if (!depth && depth !== 0) depth = Infinity;
    var output = [], idx = 0, i = 0, length = getLength_default(input) || 0, stack = [];
    while (true) {
      if (i >= length) {
        if (!stack.length) break;
        var frame = stack.pop();
        i = frame.i;
        input = frame.v;
        length = getLength_default(input);
        continue;
      }
      var value = input[i++];
      if (stack.length >= depth) {
        output[idx++] = value;
      } else if (isArrayLike_default(value) && (isArray_default(value) || isArguments_default(value))) {
        stack.push({ i, v: input });
        i = 0;
        input = value;
        length = getLength_default(input);
      } else if (!strict) {
        output[idx++] = value;
      }
    }
    return output;
  }

  // node_modules/underscore/modules/bindAll.js
  var bindAll_default = restArguments(function(obj, keys2) {
    keys2 = flatten(keys2, false, false);
    var index = keys2.length;
    if (index < 1) throw new Error("bindAll must be passed function names");
    while (index--) {
      var key = keys2[index];
      obj[key] = bind_default(obj[key], obj);
    }
    return obj;
  });

  // node_modules/underscore/modules/memoize.js
  function memoize(func, hasher) {
    var memoize2 = function(key) {
      var cache = memoize2.cache;
      var address = "" + (hasher ? hasher.apply(this, arguments) : key);
      if (!has(cache, address)) cache[address] = func.apply(this, arguments);
      return cache[address];
    };
    memoize2.cache = {};
    return memoize2;
  }

  // node_modules/underscore/modules/delay.js
  var delay_default = restArguments(function(func, wait, args) {
    return setTimeout(function() {
      return func.apply(null, args);
    }, wait);
  });

  // node_modules/underscore/modules/defer.js
  var defer_default = partial_default(delay_default, _, 1);

  // node_modules/underscore/modules/throttle.js
  function throttle(func, wait, options) {
    var timeout, context, args, result2;
    var previous = 0;
    if (!options) options = {};
    var later = function() {
      previous = options.leading === false ? 0 : now_default();
      timeout = null;
      result2 = func.apply(context, args);
      if (!timeout) context = args = null;
    };
    var throttled = function() {
      var _now = now_default();
      if (!previous && options.leading === false) previous = _now;
      var remaining = wait - (_now - previous);
      context = this;
      args = arguments;
      if (remaining <= 0 || remaining > wait) {
        if (timeout) {
          clearTimeout(timeout);
          timeout = null;
        }
        previous = _now;
        result2 = func.apply(context, args);
        if (!timeout) context = args = null;
      } else if (!timeout && options.trailing !== false) {
        timeout = setTimeout(later, remaining);
      }
      return result2;
    };
    throttled.cancel = function() {
      clearTimeout(timeout);
      previous = 0;
      timeout = context = args = null;
    };
    return throttled;
  }

  // node_modules/underscore/modules/debounce.js
  function debounce(func, wait, immediate) {
    var timeout, previous, args, result2, context;
    var later = function() {
      var passed = now_default() - previous;
      if (wait > passed) {
        timeout = setTimeout(later, wait - passed);
      } else {
        timeout = null;
        if (!immediate) result2 = func.apply(context, args);
        if (!timeout) args = context = null;
      }
    };
    var debounced = restArguments(function(_args) {
      context = this;
      args = _args;
      previous = now_default();
      if (!timeout) {
        timeout = setTimeout(later, wait);
        if (immediate) result2 = func.apply(context, args);
      }
      return result2;
    });
    debounced.cancel = function() {
      clearTimeout(timeout);
      timeout = args = context = null;
    };
    return debounced;
  }

  // node_modules/underscore/modules/wrap.js
  function wrap(func, wrapper) {
    return partial_default(wrapper, func);
  }

  // node_modules/underscore/modules/negate.js
  function negate(predicate) {
    return function() {
      return !predicate.apply(this, arguments);
    };
  }

  // node_modules/underscore/modules/compose.js
  function compose() {
    var args = arguments;
    var start = args.length - 1;
    return function() {
      var i = start;
      var result2 = args[start].apply(this, arguments);
      while (i--) result2 = args[i].call(this, result2);
      return result2;
    };
  }

  // node_modules/underscore/modules/after.js
  function after(times2, func) {
    return function() {
      if (--times2 < 1) {
        return func.apply(this, arguments);
      }
    };
  }

  // node_modules/underscore/modules/before.js
  function before(times2, func) {
    var memo;
    return function() {
      if (--times2 > 0) {
        memo = func.apply(this, arguments);
      }
      if (times2 <= 1) func = null;
      return memo;
    };
  }

  // node_modules/underscore/modules/once.js
  var once_default = partial_default(before, 2);

  // node_modules/underscore/modules/findKey.js
  function findKey(obj, predicate, context) {
    predicate = cb(predicate, context);
    var _keys = keys(obj), key;
    for (var i = 0, length = _keys.length; i < length; i++) {
      key = _keys[i];
      if (predicate(obj[key], key, obj)) return key;
    }
  }

  // node_modules/underscore/modules/_createPredicateIndexFinder.js
  function createPredicateIndexFinder(dir) {
    return function(array, predicate, context) {
      predicate = cb(predicate, context);
      var length = getLength_default(array);
      var index = dir > 0 ? 0 : length - 1;
      for (; index >= 0 && index < length; index += dir) {
        if (predicate(array[index], index, array)) return index;
      }
      return -1;
    };
  }

  // node_modules/underscore/modules/findIndex.js
  var findIndex_default = createPredicateIndexFinder(1);

  // node_modules/underscore/modules/findLastIndex.js
  var findLastIndex_default = createPredicateIndexFinder(-1);

  // node_modules/underscore/modules/sortedIndex.js
  function sortedIndex(array, obj, iteratee2, context) {
    iteratee2 = cb(iteratee2, context, 1);
    var value = iteratee2(obj);
    var low = 0, high = getLength_default(array);
    while (low < high) {
      var mid = Math.floor((low + high) / 2);
      if (iteratee2(array[mid]) < value) low = mid + 1;
      else high = mid;
    }
    return low;
  }

  // node_modules/underscore/modules/_createIndexFinder.js
  function createIndexFinder(dir, predicateFind, sortedIndex2) {
    return function(array, item, idx) {
      var i = 0, length = getLength_default(array);
      if (typeof idx == "number") {
        if (dir > 0) {
          i = idx >= 0 ? idx : Math.max(idx + length, i);
        } else {
          length = idx >= 0 ? Math.min(idx + 1, length) : idx + length + 1;
        }
      } else if (sortedIndex2 && idx && length) {
        idx = sortedIndex2(array, item);
        return array[idx] === item ? idx : -1;
      }
      if (item !== item) {
        idx = predicateFind(slice.call(array, i, length), isNaN2);
        return idx >= 0 ? idx + i : -1;
      }
      for (idx = dir > 0 ? i : length - 1; idx >= 0 && idx < length; idx += dir) {
        if (array[idx] === item) return idx;
      }
      return -1;
    };
  }

  // node_modules/underscore/modules/indexOf.js
  var indexOf_default = createIndexFinder(1, findIndex_default, sortedIndex);

  // node_modules/underscore/modules/lastIndexOf.js
  var lastIndexOf_default = createIndexFinder(-1, findLastIndex_default);

  // node_modules/underscore/modules/find.js
  function find(obj, predicate, context) {
    var keyFinder = isArrayLike_default(obj) ? findIndex_default : findKey;
    var key = keyFinder(obj, predicate, context);
    if (key !== void 0 && key !== -1) return obj[key];
  }

  // node_modules/underscore/modules/findWhere.js
  function findWhere(obj, attrs) {
    return find(obj, matcher(attrs));
  }

  // node_modules/underscore/modules/each.js
  function each(obj, iteratee2, context) {
    iteratee2 = optimizeCb(iteratee2, context);
    var i, length;
    if (isArrayLike_default(obj)) {
      for (i = 0, length = obj.length; i < length; i++) {
        iteratee2(obj[i], i, obj);
      }
    } else {
      var _keys = keys(obj);
      for (i = 0, length = _keys.length; i < length; i++) {
        iteratee2(obj[_keys[i]], _keys[i], obj);
      }
    }
    return obj;
  }

  // node_modules/underscore/modules/map.js
  function map(obj, iteratee2, context) {
    iteratee2 = cb(iteratee2, context);
    var _keys = !isArrayLike_default(obj) && keys(obj), length = (_keys || obj).length, results = Array(length);
    for (var index = 0; index < length; index++) {
      var currentKey = _keys ? _keys[index] : index;
      results[index] = iteratee2(obj[currentKey], currentKey, obj);
    }
    return results;
  }

  // node_modules/underscore/modules/_createReduce.js
  function createReduce(dir) {
    var reducer = function(obj, iteratee2, memo, initial2) {
      var _keys = !isArrayLike_default(obj) && keys(obj), length = (_keys || obj).length, index = dir > 0 ? 0 : length - 1;
      if (!initial2) {
        memo = obj[_keys ? _keys[index] : index];
        index += dir;
      }
      for (; index >= 0 && index < length; index += dir) {
        var currentKey = _keys ? _keys[index] : index;
        memo = iteratee2(memo, obj[currentKey], currentKey, obj);
      }
      return memo;
    };
    return function(obj, iteratee2, memo, context) {
      var initial2 = arguments.length >= 3;
      return reducer(obj, optimizeCb(iteratee2, context, 4), memo, initial2);
    };
  }

  // node_modules/underscore/modules/reduce.js
  var reduce_default = createReduce(1);

  // node_modules/underscore/modules/reduceRight.js
  var reduceRight_default = createReduce(-1);

  // node_modules/underscore/modules/filter.js
  function filter(obj, predicate, context) {
    var results = [];
    predicate = cb(predicate, context);
    each(obj, function(value, index, list) {
      if (predicate(value, index, list)) results.push(value);
    });
    return results;
  }

  // node_modules/underscore/modules/reject.js
  function reject(obj, predicate, context) {
    return filter(obj, negate(cb(predicate)), context);
  }

  // node_modules/underscore/modules/every.js
  function every(obj, predicate, context) {
    predicate = cb(predicate, context);
    var _keys = !isArrayLike_default(obj) && keys(obj), length = (_keys || obj).length;
    for (var index = 0; index < length; index++) {
      var currentKey = _keys ? _keys[index] : index;
      if (!predicate(obj[currentKey], currentKey, obj)) return false;
    }
    return true;
  }

  // node_modules/underscore/modules/some.js
  function some(obj, predicate, context) {
    predicate = cb(predicate, context);
    var _keys = !isArrayLike_default(obj) && keys(obj), length = (_keys || obj).length;
    for (var index = 0; index < length; index++) {
      var currentKey = _keys ? _keys[index] : index;
      if (predicate(obj[currentKey], currentKey, obj)) return true;
    }
    return false;
  }

  // node_modules/underscore/modules/contains.js
  function contains(obj, item, fromIndex, guard) {
    if (!isArrayLike_default(obj)) obj = values(obj);
    if (typeof fromIndex != "number" || guard) fromIndex = 0;
    return indexOf_default(obj, item, fromIndex) >= 0;
  }

  // node_modules/underscore/modules/invoke.js
  var invoke_default = restArguments(function(obj, path, args) {
    var contextPath, func;
    if (isFunction_default(path)) {
      func = path;
    } else {
      path = toPath2(path);
      contextPath = path.slice(0, -1);
      path = path[path.length - 1];
    }
    return map(obj, function(context) {
      var method = func;
      if (!method) {
        if (contextPath && contextPath.length) {
          context = deepGet(context, contextPath);
        }
        if (context == null) return void 0;
        method = context[path];
      }
      return method == null ? method : method.apply(context, args);
    });
  });

  // node_modules/underscore/modules/pluck.js
  function pluck(obj, key) {
    return map(obj, property(key));
  }

  // node_modules/underscore/modules/where.js
  function where(obj, attrs) {
    return filter(obj, matcher(attrs));
  }

  // node_modules/underscore/modules/max.js
  function max(obj, iteratee2, context) {
    var result2 = -Infinity, lastComputed = -Infinity, value, computed;
    if (iteratee2 == null || typeof iteratee2 == "number" && typeof obj[0] != "object" && obj != null) {
      obj = isArrayLike_default(obj) ? obj : values(obj);
      for (var i = 0, length = obj.length; i < length; i++) {
        value = obj[i];
        if (value != null && value > result2) {
          result2 = value;
        }
      }
    } else {
      iteratee2 = cb(iteratee2, context);
      each(obj, function(v, index, list) {
        computed = iteratee2(v, index, list);
        if (computed > lastComputed || computed === -Infinity && result2 === -Infinity) {
          result2 = v;
          lastComputed = computed;
        }
      });
    }
    return result2;
  }

  // node_modules/underscore/modules/min.js
  function min(obj, iteratee2, context) {
    var result2 = Infinity, lastComputed = Infinity, value, computed;
    if (iteratee2 == null || typeof iteratee2 == "number" && typeof obj[0] != "object" && obj != null) {
      obj = isArrayLike_default(obj) ? obj : values(obj);
      for (var i = 0, length = obj.length; i < length; i++) {
        value = obj[i];
        if (value != null && value < result2) {
          result2 = value;
        }
      }
    } else {
      iteratee2 = cb(iteratee2, context);
      each(obj, function(v, index, list) {
        computed = iteratee2(v, index, list);
        if (computed < lastComputed || computed === Infinity && result2 === Infinity) {
          result2 = v;
          lastComputed = computed;
        }
      });
    }
    return result2;
  }

  // node_modules/underscore/modules/toArray.js
  var reStrSymbol = /[^\ud800-\udfff]|[\ud800-\udbff][\udc00-\udfff]|[\ud800-\udfff]/g;
  function toArray(obj) {
    if (!obj) return [];
    if (isArray_default(obj)) return slice.call(obj);
    if (isString_default(obj)) {
      return obj.match(reStrSymbol);
    }
    if (isArrayLike_default(obj)) return map(obj, identity);
    return values(obj);
  }

  // node_modules/underscore/modules/sample.js
  function sample(obj, n, guard) {
    if (n == null || guard) {
      if (!isArrayLike_default(obj)) obj = values(obj);
      return obj[random(obj.length - 1)];
    }
    var sample2 = toArray(obj);
    var length = getLength_default(sample2);
    n = Math.max(Math.min(n, length), 0);
    var last2 = length - 1;
    for (var index = 0; index < n; index++) {
      var rand = random(index, last2);
      var temp = sample2[index];
      sample2[index] = sample2[rand];
      sample2[rand] = temp;
    }
    return sample2.slice(0, n);
  }

  // node_modules/underscore/modules/shuffle.js
  function shuffle(obj) {
    return sample(obj, Infinity);
  }

  // node_modules/underscore/modules/sortBy.js
  function sortBy(obj, iteratee2, context) {
    var index = 0;
    iteratee2 = cb(iteratee2, context);
    return pluck(map(obj, function(value, key, list) {
      return {
        value,
        index: index++,
        criteria: iteratee2(value, key, list)
      };
    }).sort(function(left, right) {
      var a = left.criteria;
      var b = right.criteria;
      if (a !== b) {
        if (a > b || a === void 0) return 1;
        if (a < b || b === void 0) return -1;
      }
      return left.index - right.index;
    }), "value");
  }

  // node_modules/underscore/modules/_group.js
  function group(behavior, partition) {
    return function(obj, iteratee2, context) {
      var result2 = partition ? [[], []] : {};
      iteratee2 = cb(iteratee2, context);
      each(obj, function(value, index) {
        var key = iteratee2(value, index, obj);
        behavior(result2, value, key);
      });
      return result2;
    };
  }

  // node_modules/underscore/modules/groupBy.js
  var groupBy_default = group(function(result2, value, key) {
    if (has(result2, key)) result2[key].push(value);
    else result2[key] = [value];
  });

  // node_modules/underscore/modules/indexBy.js
  var indexBy_default = group(function(result2, value, key) {
    result2[key] = value;
  });

  // node_modules/underscore/modules/countBy.js
  var countBy_default = group(function(result2, value, key) {
    if (has(result2, key)) result2[key]++;
    else result2[key] = 1;
  });

  // node_modules/underscore/modules/partition.js
  var partition_default = group(function(result2, value, pass) {
    result2[pass ? 0 : 1].push(value);
  }, true);

  // node_modules/underscore/modules/size.js
  function size(obj) {
    if (obj == null) return 0;
    return isArrayLike_default(obj) ? obj.length : keys(obj).length;
  }

  // node_modules/underscore/modules/_keyInObj.js
  function keyInObj(value, key, obj) {
    return key in obj;
  }

  // node_modules/underscore/modules/pick.js
  var pick_default = restArguments(function(obj, keys2) {
    var result2 = {}, iteratee2 = keys2[0];
    if (obj == null) return result2;
    if (isFunction_default(iteratee2)) {
      if (keys2.length > 1) iteratee2 = optimizeCb(iteratee2, keys2[1]);
      keys2 = allKeys(obj);
    } else {
      iteratee2 = keyInObj;
      keys2 = flatten(keys2, false, false);
      obj = Object(obj);
    }
    for (var i = 0, length = keys2.length; i < length; i++) {
      var key = keys2[i];
      var value = obj[key];
      if (iteratee2(value, key, obj)) result2[key] = value;
    }
    return result2;
  });

  // node_modules/underscore/modules/omit.js
  var omit_default = restArguments(function(obj, keys2) {
    var iteratee2 = keys2[0], context;
    if (isFunction_default(iteratee2)) {
      iteratee2 = negate(iteratee2);
      if (keys2.length > 1) context = keys2[1];
    } else {
      keys2 = map(flatten(keys2, false, false), String);
      iteratee2 = function(value, key) {
        return !contains(keys2, key);
      };
    }
    return pick_default(obj, iteratee2, context);
  });

  // node_modules/underscore/modules/initial.js
  function initial(array, n, guard) {
    return slice.call(array, 0, Math.max(0, array.length - (n == null || guard ? 1 : n)));
  }

  // node_modules/underscore/modules/first.js
  function first(array, n, guard) {
    if (array == null || array.length < 1) return n == null || guard ? void 0 : [];
    if (n == null || guard) return array[0];
    return initial(array, array.length - n);
  }

  // node_modules/underscore/modules/rest.js
  function rest(array, n, guard) {
    return slice.call(array, n == null || guard ? 1 : n);
  }

  // node_modules/underscore/modules/last.js
  function last(array, n, guard) {
    if (array == null || array.length < 1) return n == null || guard ? void 0 : [];
    if (n == null || guard) return array[array.length - 1];
    return rest(array, Math.max(0, array.length - n));
  }

  // node_modules/underscore/modules/compact.js
  function compact(array) {
    return filter(array, Boolean);
  }

  // node_modules/underscore/modules/flatten.js
  function flatten2(array, depth) {
    return flatten(array, depth, false);
  }

  // node_modules/underscore/modules/difference.js
  var difference_default = restArguments(function(array, rest2) {
    rest2 = flatten(rest2, true, true);
    return filter(array, function(value) {
      return !contains(rest2, value);
    });
  });

  // node_modules/underscore/modules/without.js
  var without_default = restArguments(function(array, otherArrays) {
    return difference_default(array, otherArrays);
  });

  // node_modules/underscore/modules/uniq.js
  function uniq(array, isSorted, iteratee2, context) {
    if (!isBoolean(isSorted)) {
      context = iteratee2;
      iteratee2 = isSorted;
      isSorted = false;
    }
    if (iteratee2 != null) iteratee2 = cb(iteratee2, context);
    var result2 = [];
    var seen = [];
    for (var i = 0, length = getLength_default(array); i < length; i++) {
      var value = array[i], computed = iteratee2 ? iteratee2(value, i, array) : value;
      if (isSorted && !iteratee2) {
        if (!i || seen !== computed) result2.push(value);
        seen = computed;
      } else if (iteratee2) {
        if (!contains(seen, computed)) {
          seen.push(computed);
          result2.push(value);
        }
      } else if (!contains(result2, value)) {
        result2.push(value);
      }
    }
    return result2;
  }

  // node_modules/underscore/modules/union.js
  var union_default = restArguments(function(arrays) {
    return uniq(flatten(arrays, true, true));
  });

  // node_modules/underscore/modules/intersection.js
  function intersection(array) {
    var result2 = [];
    var argsLength = arguments.length;
    for (var i = 0, length = getLength_default(array); i < length; i++) {
      var item = array[i];
      if (contains(result2, item)) continue;
      var j;
      for (j = 1; j < argsLength; j++) {
        if (!contains(arguments[j], item)) break;
      }
      if (j === argsLength) result2.push(item);
    }
    return result2;
  }

  // node_modules/underscore/modules/unzip.js
  function unzip(array) {
    var length = array && max(array, getLength_default).length || 0;
    var result2 = Array(length);
    for (var index = 0; index < length; index++) {
      result2[index] = pluck(array, index);
    }
    return result2;
  }

  // node_modules/underscore/modules/zip.js
  var zip_default = restArguments(unzip);

  // node_modules/underscore/modules/object.js
  function object(list, values2) {
    var result2 = {};
    for (var i = 0, length = getLength_default(list); i < length; i++) {
      if (values2) {
        result2[list[i]] = values2[i];
      } else {
        result2[list[i][0]] = list[i][1];
      }
    }
    return result2;
  }

  // node_modules/underscore/modules/range.js
  function range(start, stop, step) {
    if (stop == null) {
      stop = start || 0;
      start = 0;
    }
    if (!step) {
      step = stop < start ? -1 : 1;
    }
    var length = Math.max(Math.ceil((stop - start) / step), 0);
    var range2 = Array(length);
    for (var idx = 0; idx < length; idx++, start += step) {
      range2[idx] = start;
    }
    return range2;
  }

  // node_modules/underscore/modules/chunk.js
  function chunk(array, count) {
    if (count == null || count < 1) return [];
    var result2 = [];
    var i = 0, length = array.length;
    while (i < length) {
      result2.push(slice.call(array, i, i += count));
    }
    return result2;
  }

  // node_modules/underscore/modules/_chainResult.js
  function chainResult(instance, obj) {
    return instance._chain ? _(obj).chain() : obj;
  }

  // node_modules/underscore/modules/mixin.js
  function mixin(obj) {
    each(functions(obj), function(name) {
      var func = _[name] = obj[name];
      _.prototype[name] = function() {
        var args = [this._wrapped];
        push.apply(args, arguments);
        return chainResult(this, func.apply(_, args));
      };
    });
    return _;
  }

  // node_modules/underscore/modules/underscore-array-methods.js
  each(["pop", "push", "reverse", "shift", "sort", "splice", "unshift"], function(name) {
    var method = ArrayProto[name];
    _.prototype[name] = function() {
      var obj = this._wrapped;
      if (obj != null) {
        method.apply(obj, arguments);
        if ((name === "shift" || name === "splice") && obj.length === 0) {
          delete obj[0];
        }
      }
      return chainResult(this, obj);
    };
  });
  each(["concat", "join", "slice"], function(name) {
    var method = ArrayProto[name];
    _.prototype[name] = function() {
      var obj = this._wrapped;
      if (obj != null) obj = method.apply(obj, arguments);
      return chainResult(this, obj);
    };
  });
  var underscore_array_methods_default = _;

  // node_modules/underscore/modules/index-default.js
  var _2 = mixin(modules_exports);
  _2._ = _2;
  var index_default_default = _2;

  // vendor/kookit/src/libs/textProcessor.ts
  var cleanText = (str) => {
    return str.trim().replace(/(\r\n|\n|\r|\t)/gm, "").substring(0, 100).split("").filter(
      (item) => item !== "=" && item !== "-" && item !== "_" && item !== "+"
    ).join("");
  };

  // vendor/kookit/src/utils/navigationUtil.ts
  var lock = false;
  var getXPathForNode = (node2, doc2) => {
    if (!node2 || !doc2 || !doc2.body) return "";
    const parts = [];
    let current2 = node2;
    while (current2 && current2 !== doc2.body && current2 !== doc2) {
      const parent = current2.parentNode;
      if (!parent) break;
      if (current2.nodeType === Node.TEXT_NODE) {
        current2 = parent;
        continue;
      }
      const el = current2;
      const tag = el.tagName.toLowerCase();
      const siblings = Array.from(parent.childNodes).filter(
        (n) => n.nodeType === Node.ELEMENT_NODE && n.tagName.toLowerCase() === tag
      );
      const index = siblings.indexOf(el) + 1;
      parts.unshift(siblings.length > 1 ? `${tag}[${index}]` : tag);
      current2 = parent;
    }
    return "/body/" + parts.join("/");
  };
  var resolveXPath = (xpath, doc2) => {
    if (!xpath || !doc2 || !doc2.body) return null;
    try {
      let path = xpath;
      if (path.startsWith("/body/")) {
        path = path.slice("/body/".length);
      } else if (path.startsWith("/body")) {
        return doc2.body;
      }
      const segments = path.split("/").filter(Boolean);
      let current2 = doc2.body;
      for (const seg of segments) {
        const match = seg.match(/^([a-zA-Z0-9]+)(?:\[(\d+)\])?$/);
        if (!match) return null;
        const tag = match[1].toLowerCase();
        const idx = match[2] ? parseInt(match[2]) - 1 : 0;
        const children = Array.from(current2.children).filter(
          (c) => c.tagName.toLowerCase() === tag
        );
        if (!children[idx]) return null;
        current2 = children[idx];
      }
      return current2;
    } catch {
      return null;
    }
  };
  var playMimicalFlip = (animation, isMobile, delta, flipToNextPage, flipToPrevPage) => {
    if (animation !== "mimical" || isMobile === "yes") return false;
    const bookDiv = document.getElementById("book");
    if (!bookDiv) return false;
    bookDiv.style.display = "block";
    if (delta > 0) flipToPrevPage();
    else if (delta < 0) flipToNextPage();
    setTimeout(() => {
      bookDiv.style.display = "none";
    }, 1e3);
    return true;
  };
  var handleScrollPage = async (element, animation, delta, doc2, flipToNextPage, flipToPrevPage, isMobile) => {
    const vertical = isVerticalLayout();
    playMimicalFlip(animation, isMobile, delta, flipToNextPage, flipToPrevPage);
    if (vertical) {
      let section = Math.floor(element.clientHeight / 12);
      let gap = section % 2 === 0 ? section : section - 1;
      const height = element.clientHeight;
      const currentScrollTop = doc2.body.scrollTop;
      const scrollDistance = height + gap;
      if (delta > 0) {
        const currentPage = Math.round(currentScrollTop / scrollDistance);
        const targetPage = Math.max(0, currentPage - 1);
        const targetScrollTop = targetPage * scrollDistance;
        doc2.body.scrollTo({
          left: 0,
          top: targetScrollTop,
          behavior: animation === "sliding" && isMobile !== "yes" ? "smooth" : "auto"
        });
      } else if (delta < 0) {
        const currentPage = Math.round(currentScrollTop / scrollDistance);
        const targetPage = currentPage + 1;
        const targetScrollTop = targetPage * scrollDistance;
        doc2.body.scrollTo({
          left: 0,
          top: targetScrollTop,
          behavior: animation === "sliding" && isMobile !== "yes" ? "smooth" : "auto"
        });
      }
    } else {
      let section = Math.floor(element.clientWidth / 12);
      let gap = section % 2 === 0 ? section : section - 1;
      const width = element.clientWidth;
      const currentScrollLeft = doc2.body.scrollLeft;
      const scrollDistance = width + gap;
      if (delta > 0) {
        const currentPage = Math.round(currentScrollLeft / scrollDistance);
        const targetPage = Math.max(0, currentPage - 1);
        const targetScrollLeft = targetPage * scrollDistance;
        doc2.body.scrollTo({
          top: 0,
          left: targetScrollLeft,
          behavior: animation === "sliding" && isMobile !== "yes" ? "smooth" : "auto"
        });
      } else if (delta < 0) {
        const currentPage = Math.round(currentScrollLeft / scrollDistance);
        const targetPage = currentPage + 1;
        const targetScrollLeft = targetPage * scrollDistance;
        doc2.body.scrollTo({
          top: 0,
          left: targetScrollLeft,
          behavior: animation === "sliding" && isMobile !== "yes" ? "smooth" : "auto"
        });
      }
    }
  };
  var findValidChapter = (chapterDocIndex, chapterHref, chapterDocList, flag) => {
    let currentChapterIndex = index_default_default.findLastIndex(chapterDocList, (chapter2) => {
      return chapter2.href === chapterHref || chapter2.href && chapter2.href.includes("#") && chapter2.href.includes(chapterHref);
    });
    if (chapterHref && index_default_default.findLastIndex(chapterDocList, (chapter2) => {
      return chapter2.href === chapterHref || chapter2.href && chapter2.href.includes("#") && chapter2.href.includes(chapterHref);
    }) > -1) {
    } else {
      currentChapterIndex = chapterDocIndex;
    }
    if (flag === "prev") {
      return {
        ...chapterDocList[currentChapterIndex - 1],
        index: currentChapterIndex - 1
      };
    } else {
      return {
        ...chapterDocList[currentChapterIndex + 1],
        index: currentChapterIndex + 1
      };
    }
  };
  var handlePrevChapter = async (element, flattenChapters, chapterDocList, readerMode, format, tempLocation, doc2, iframe) => {
    let chapterDocIndex = parseInt(tempLocation.chapterDocIndex || "0");
    let chapterHref = tempLocation.chapterHref || "";
    if (chapterDocIndex === 0) {
      return;
    }
    let prevChapter = findValidChapter(
      chapterDocIndex,
      chapterHref,
      chapterDocList,
      "prev"
    );
    if (!prevChapter) return;
    tempLocation.text = "prevChapter";
    tempLocation.page = "";
    await handleRenderChapter(
      prevChapter.index,
      prevChapter.label,
      prevChapter.href,
      chapterDocList,
      element,
      readerMode,
      format,
      tempLocation,
      doc2,
      iframe
    );
  };
  var isElementFootnote = (element) => {
    if (!element) return false;
    if (element.tagName === "IMG") {
      return true;
    }
    if (element.textContent) {
      let textContent = element.textContent.trim();
      return isContentFootnote(textContent);
    }
    return false;
  };
  var isContentFootnote = (content) => {
    if (!content) return false;
    let textContent = content.trim();
    const footnotePattern = /^(\[|\(|〔|【|〈|《|〚)([a-zA-Z0-9零一二三四五六七八九十百千万]+)(\]|\)|〕|】|〉|》|〛)$|^\d+$|^(M{0,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3}))$|^[①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳㉑㉒㉓㉔㉕㉖㉗㉘㉙㉚㉛㉜㉝㉞㉟㊱㊲㊳㊴㊵㊶㊷㊸㊹㊺㊻㊼㊽㊾㊿]$/i;
    if (footnotePattern.test(textContent)) {
      return true;
    }
    if (textContent.toLowerCase().indexOf("footnote") > -1 || textContent.toLowerCase().indexOf("\u811A\u6CE8") > -1 || textContent.toLowerCase().indexOf("\u6CE8\u91CA") > -1 || textContent.toLowerCase().indexOf("\u6CE8") > -1 || textContent.toLowerCase().indexOf("fn") > -1) {
      return true;
    }
    if (textContent === "*" || textContent === "\u2020" || textContent === "\u2021" || textContent === "\u203B" || textContent === "\xA7") {
      return true;
    }
    return false;
  };
  var processHtml = async (html) => {
    const parser2 = new DOMParser();
    const doc2 = parser2.parseFromString(html, "text/html");
    const images = Array.from(doc2.getElementsByTagName("img"));
    for (const img of images) {
      if (img.src && img.src.startsWith("blob:")) {
        try {
          const dataUrl = await convertBlobToDataURL(img.src);
          img.src = dataUrl;
          img.style.maxWidth = "100%";
        } catch (error) {
          console.error("Error converting blob to data URL:", error);
        }
      }
    }
    return doc2.body.innerHTML;
  };
  var convertBlobToDataURL = async (blobUrl) => {
    const response = await fetch(blobUrl);
    const blob = await response.blob();
    return new Promise((resolve, reject2) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve(reader.result);
      reader.onerror = reject2;
      reader.readAsDataURL(blob);
    });
  };
  var handleRenderChapter = async (chapterDocIndex, chapterTitle, chapterHref, chapterDocList, element, readerMode, format, tempLocation, doc2, iframe) => {
    doc2.body.innerHTML = "";
    iframe.height = "0px";
    doc2.body.scrollTo(0, 0);
    if (chapterTitle && !chapterDocIndex || chapterDocList[chapterDocIndex] && chapterDocList[chapterDocIndex].label && chapterTitle && chapterTitle !== chapterDocList[chapterDocIndex].label && chapterHref.indexOf("#") === -1) {
      let tempChapterDocIndex = index_default_default.findLastIndex(chapterDocList, {
        label: chapterTitle
      });
      if (tempChapterDocIndex !== -1) {
        chapterDocIndex = tempChapterDocIndex;
      }
    }
    if (chapterDocIndex === -1 && chapterHref.indexOf("#") > -1) {
      let href = chapterHref.split("#")[0];
      let tempChapterDocIndex = index_default_default.findLastIndex(chapterDocList, (chapter2) => {
        return chapter2.href === href || chapter2.href && chapter2.href.includes("#") && chapter2.href.includes(href);
      });
      if (tempChapterDocIndex !== -1) {
        chapterDocIndex = tempChapterDocIndex;
      }
    }
    if (chapterDocIndex === -1 || chapterDocIndex > chapterDocList.length - 1) {
      chapterDocIndex = 0;
    }
    let chapterText = await handleOneChapterDoc(
      chapterDocList[chapterDocIndex].text,
      false
    );
    let bodyAttrs = getBodyAttributes(chapterText);
    const viewport = getViewportSize(chapterText);
    doc2.body.innerHTML = chapterText;
    if (bodyAttrs["class"]) {
      doc2.body.setAttribute("class", bodyAttrs["class"]);
    } else {
      doc2.body.removeAttribute("class");
    }
    if (bodyAttrs["id"]) {
      doc2.body.setAttribute("id", bodyAttrs["id"]);
    } else {
      doc2.body.removeAttribute("id");
    }
    let baseStyle = doc2.body.getAttribute("style") || "";
    if (baseStyle) {
      baseStyle = baseStyle.split(";").map((s) => s.trim()).filter((s) => s && !/^transform(-origin)?\s*:/i.test(s)).join("; ");
      if (baseStyle) baseStyle += ";";
    }
    const incomingStyle = bodyAttrs["style"] || "";
    const mergedStyle = mergeStyleStrings(baseStyle, incomingStyle);
    const chapterFixedWidth = viewport?.width || getStylePxNumber(incomingStyle, "width");
    const chapterFixedHeight = viewport?.height || getStylePxNumber(incomingStyle, "height");
    if (chapterFixedWidth && chapterFixedHeight) {
      const pageWidth = getPageWidth(element, readerMode);
      const iframeHeight = iframe?.getBoundingClientRect().height;
      const availableHeight = iframeHeight > 0 ? iframeHeight : element.clientHeight;
      if (pageWidth > 0 && availableHeight > 0 && getStylePxNumber(mergedStyle, "width") && getStylePxNumber(mergedStyle, "width") !== element.clientWidth) {
        const widthRatio = pageWidth / chapterFixedWidth;
        const heightRatio = availableHeight / chapterFixedHeight;
        const scaleValue = Math.min(1, widthRatio, heightRatio);
        const scaledStyle = mergeStyleStrings(
          mergedStyle,
          `transform: scale(${scaleValue}); transform-origin: left top;`
        );
        doc2.body.setAttribute("style", scaledStyle);
        doc2.body.setAttribute("data-kookit-fixed-scale", "true");
      } else {
        doc2.body.setAttribute("style", mergedStyle);
        doc2.body.removeAttribute("data-kookit-fixed-scale");
      }
    } else if (mergedStyle) {
      doc2.body.setAttribute("style", mergedStyle);
      doc2.body.removeAttribute("data-kookit-fixed-scale");
    } else {
      doc2.body.removeAttribute("style");
      doc2.body.removeAttribute("data-kookit-fixed-scale");
    }
    await handleCssLink(doc2);
    await handlePlainText(doc2);
    if (!chapterTitle) {
      let tempChapterDocIndex = chapterDocIndex;
      while (tempChapterDocIndex >= 0) {
        if (chapterDocList[tempChapterDocIndex].label) {
          chapterTitle = chapterDocList[tempChapterDocIndex].label;
          break;
        }
        tempChapterDocIndex--;
      }
    }
    tempLocation.chapterTitle = chapterTitle;
    tempLocation.chapterHref = chapterHref;
    tempLocation.chapterDocIndex = chapterDocIndex + "";
    tempLocation.percentage = chapterDocList.slice(0, chapterDocIndex).map((item) => item.text ? item.text.size || 1 : 1).reduce((a, b) => a + b, 0) / chapterDocList.map((item) => item.text ? item.text.size || 1 : 1).reduce((a, b) => a + b, 0) + "";
    tempLocation.text = "";
    tempLocation.xpath = `/body/DocFragment[${chapterDocIndex + 1}]`;
    tempLocation.timestamp = parseInt((/* @__PURE__ */ new Date()).getTime() / 1e3 + "");
    await handleIframeHeight(element, readerMode, format, iframe, doc2);
    await handleScrollPosition(element, readerMode, "", "", "", "", doc2);
  };
  function getBodyAttributes(htmlStr) {
    const bodyTagMatch = htmlStr.match(/<body\b([^>]*)>/i);
    if (!bodyTagMatch) return {};
    const attrStr = bodyTagMatch[1];
    const attributes = {};
    const attrRegex = /([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^>\s]+))/g;
    let match;
    while ((match = attrRegex.exec(attrStr)) !== null) {
      const value = match[2] || match[3] || match[4] || "";
      attributes[match[1]] = value;
    }
    return attributes;
  }
  var handleCssLink = async (doc2) => {
    let linkList = Array.from(doc2.getElementsByTagName("link"));
    if (linkList.length === 0) {
      return;
    }
    let styleSheetPromises = [];
    for (let index = 0; index < linkList.length; index++) {
      const link = linkList[index];
      if (!link.href.endsWith("null")) {
        styleSheetPromises.push(
          new Promise((resolve, reject2) => {
            link.addEventListener("load", resolve);
          })
        );
      }
    }
    try {
      await Promise.race([
        Promise.all(styleSheetPromises),
        new Promise((resolve, reject2) => {
          setTimeout(() => {
            resolve("css load timeout");
          }, 10);
        })
      ]);
    } catch (err) {
      console.error(err);
    }
  };
  var handlePlainText = async (doc2) => {
    let childNodes = Array.from(doc2.body.childNodes);
    for (let i = 0; i < childNodes.length; i++) {
      let node2 = childNodes[i];
      if (node2.nodeType === Node.TEXT_NODE && node2.textContent?.trim()) {
        let p = doc2.createElement("p");
        p.textContent = node2.textContent;
        p.style.display = "inline";
        doc2.body.replaceChild(p, node2);
      }
    }
  };
  var handleScrollPosition = async (element, readerMode, text, count, href, page, doc2) => {
    let left = 0;
    let top = 0;
    let targetNode = doc2.body;
    const vertical = isVerticalLayout() && readerMode !== "scroll";
    if (page && readerMode !== "scroll") {
      if (vertical) {
        let section = Math.floor(element.clientHeight / 12);
        let gap = section % 2 === 0 ? section : section - 1;
        let pageHeight = element.clientHeight + gap;
        top = pageHeight * (parseInt(page) - 1);
      } else {
        let section = Math.floor(element.clientWidth / 12);
        let gap = section % 2 === 0 ? section : section - 1;
        const width = convertComputedNum(getComputedStyle(element).width);
        let pageWidth = width + gap;
        left = pageWidth * (parseInt(page) - 1);
      }
    } else if (text) {
      let nodeList = getBlockElement(doc2.body);
      let targetNodeList = nodeList.filter((s, index) => {
        return cleanText(s.textContent) && (cleanText(s.textContent).includes(cleanText(text)) || cleanText(s.textContent).includes(
          zh_convert_default.t2s(cleanText(text))
        ) || cleanText(s.textContent).includes(
          zh_convert_default.s2t(cleanText(text))
        )) && (Math.abs(index - parseInt(count)) < (window.fullTranslationMode === "both" || window.fullTranslationMode === "target" ? 1 : 2) || count === "search" || count === "ignore" || count === "next");
      });
      if (targetNodeList.length === 0) {
        return;
      }
      targetNode = getCloestBlock(targetNodeList[0], element, readerMode);
      if (vertical) {
        top = targetNode ? getActualOffsetTop(targetNode) - convertStyleNum(
          targetNode.marginTop || parseFloat(getComputedStyle(targetNode).marginTop)
        ) : text === "prevChapter" ? doc2.body.scrollHeight : 0;
      } else {
        left = targetNode ? getActualOffsetLeft(targetNode) - convertStyleNum(
          targetNode.marginLeft || parseFloat(getComputedStyle(targetNode).marginLeft)
        ) : text === "prevChapter" ? doc2.body.scrollWidth : 0;
      }
    } else if (href && href.indexOf("#") > -1) {
      let id = CSS.escape(href.split("#").reverse()[0]);
      if (!doc2.body.querySelector("#" + CSS.escape(id))) {
        return;
      }
      targetNode = getCloestBlock(
        doc2.body.querySelector("#" + CSS.escape(id)) || doc2.body,
        element,
        readerMode
      );
      if (vertical) {
        top = targetNode ? getActualOffsetTop(targetNode) - convertStyleNum(
          targetNode.marginTop || parseFloat(getComputedStyle(targetNode).marginTop)
        ) : 0;
      } else {
        left = targetNode ? getActualOffsetLeft(targetNode) - convertStyleNum(
          targetNode.marginLeft || parseFloat(getComputedStyle(targetNode).marginLeft)
        ) : 0;
      }
    }
    if (readerMode !== "scroll") {
      if (vertical) {
        doc2.body.scrollTo(0, top);
      } else {
        doc2.body.scrollTo(left, 0);
      }
    } else {
      targetNode.scrollIntoView();
    }
  };
  var getCloestBlock = (targetNode, element, readerMode) => {
    const vertical = isVerticalLayout() && readerMode !== "scroll";
    if (readerMode === "scroll") {
      return targetNode;
    }
    if (vertical) {
      let section = Math.floor(element.clientHeight / 12);
      let gap = section % 2 === 0 ? section : section - 1;
      let offsetTop = getActualOffsetTop(targetNode) - convertStyleNum(
        targetNode.marginTop || parseFloat(getComputedStyle(targetNode).marginTop)
      );
      if (checkDivisibleInRange(
        parseInt(offsetTop + ""),
        (element.clientHeight + gap) / 2
      )) {
        return targetNode;
      } else if (targetNode.parentElement) {
        return getCloestBlock(targetNode.parentElement, element, readerMode);
      } else {
        return targetNode;
      }
    } else {
      let section = Math.floor(element.clientWidth / 12);
      let gap = section % 2 === 0 ? section : section - 1;
      let offsetLeft = getActualOffsetLeft(targetNode) - convertStyleNum(
        targetNode.marginLeft || parseFloat(getComputedStyle(targetNode).marginLeft)
      );
      if (checkDivisibleInRange(
        parseInt(offsetLeft + ""),
        (element.clientWidth + gap) / 2
      )) {
        return targetNode;
      } else if (targetNode.parentElement) {
        return getCloestBlock(targetNode.parentElement, element, readerMode);
      } else {
        return targetNode;
      }
    }
  };
  var checkDivisibleInRange = (x, y) => {
    for (let i = x - 10; i <= x + 10; i++) {
      if (i % y === 0) {
        return true;
      }
    }
    return false;
  };
  var handleRecord = async (element, readerMode, flattenChapters, chapterDocList, tempLocation, doc2, targetNode) => {
    if (lock) return;
    let nodeList = getBlockElement(doc2.body);
    let visibleNode = nodeList.filter(
      (s) => isScrolledIntoView(element, s, readerMode) && (s.textContent || "").trim()
    );
    let firstVisibleNode = visibleNode[0];
    if (targetNode) {
      firstVisibleNode = targetNode;
    }
    let count = 0;
    for (let i = 0; i < nodeList.length; i++) {
      if (isScrolledIntoView(element, nodeList[i], readerMode) && firstVisibleNode && nodeList[i].innerHTML === firstVisibleNode.innerHTML) {
        count = i;
        break;
      }
    }
    handleHashChapter(visibleNode, flattenChapters, tempLocation);
    if (firstVisibleNode && !isCurrentNodeFarFromParrent(firstVisibleNode, element, readerMode)) {
      tempLocation.text = firstVisibleNode.textContent.substring(0, 200) || "";
      tempLocation.count = count + "";
      tempLocation.page = "";
      tempLocation.xpath = `/body/DocFragment[${parseInt(tempLocation.chapterDocIndex) + 1}]` + getXPathForNode(firstVisibleNode, doc2);
      tempLocation.timestamp = parseInt((/* @__PURE__ */ new Date()).getTime() / 1e3 + "");
      let totalSize = chapterDocList.map((item) => item.text ? item.text.size || 1 : 1).reduce((a, b) => a + b, 0);
      tempLocation.percentage = chapterDocList.slice(0, parseInt(tempLocation.chapterDocIndex)).map((item) => item.text ? item.text.size || 1 : 1).reduce((a, b) => a + b, 0) / totalSize + (chapterDocList.find(
        (_item, index) => index === parseInt(tempLocation.chapterDocIndex)
      )?.text.size || 0) / totalSize * (count / nodeList.length) + "";
    } else {
      tempLocation.page = (await progressInfo(readerMode, doc2, element))?.currentPage + "";
    }
    lock = true;
    setTimeout(() => {
      lock = false;
    }, 100);
  };
  var isCurrentNodeFarFromParrent = (targetNode, element, readerMode) => {
    const vertical = isVerticalLayout() && readerMode !== "scroll";
    if (vertical) {
      let section = Math.floor(element.clientHeight / 12);
      let gap = section % 2 === 0 ? section : section - 1;
      if (Math.abs(
        getActualOffsetTop(targetNode) - getActualOffsetTop(getCloestBlock(targetNode, element, readerMode))
      ) > (element.clientHeight + gap) / 2) {
        return true;
      } else {
        return false;
      }
    } else {
      let section = Math.floor(element.clientWidth / 12);
      let gap = section % 2 === 0 ? section : section - 1;
      if (Math.abs(
        getActualOffsetLeft(targetNode) - getActualOffsetLeft(getCloestBlock(targetNode, element, readerMode))
      ) > (element.clientWidth + gap) / 2) {
        return true;
      } else {
        return false;
      }
    }
  };
  var handleHashChapter = (visibleNode, flattenChapters, tempLocation) => {
    let chapterHref = tempLocation.chapterHref || "";
    let lastIndexOfHash = chapterHref.lastIndexOf("#");
    let beforeHash = "";
    if (lastIndexOfHash === -1) {
      beforeHash = chapterHref;
    } else {
      beforeHash = chapterHref.substring(0, lastIndexOfHash);
    }
    for (let index = 0; index < visibleNode.length; index++) {
      const element = visibleNode[index];
      if (element.id) {
        let newHref = beforeHash + "#" + element.id;
        let newIndex = index_default_default.findLastIndex(flattenChapters, {
          href: newHref
        });
        if (newIndex > -1) {
          tempLocation.chapterHref = newHref;
          tempLocation.chapterTitle = flattenChapters[newIndex].label;
        }
      }
    }
  };
  var handleNextChapter = async (element, flattenChapters, chapterDocList, readerMode, format, tempLocation, doc2, iframe) => {
    let chapterDocIndex = parseInt(tempLocation.chapterDocIndex || "0");
    let chapterHref = tempLocation.chapterHref || "";
    if (chapterDocIndex >= chapterDocList.length - 1) {
      tempLocation.percentage = "1";
      return;
    }
    let nextChapter = findValidChapter(
      chapterDocIndex,
      chapterHref,
      chapterDocList,
      "next"
    );
    if (!nextChapter) return;
    tempLocation.page = "";
    await handleRenderChapter(
      nextChapter.index,
      nextChapter.label,
      nextChapter.href,
      chapterDocList,
      element,
      readerMode,
      format,
      tempLocation,
      doc2,
      iframe
    );
  };
  var getAudioText = (element, readerMode, doc2, isBackground) => {
    let nodeList = getBlockElement(doc2.body).filter(
      (item) => !isParentBlock(item)
    );
    let audioNode = nodeList.filter((s) => {
      if (!(s.textContent || "").trim()) {
        return false;
      }
      let parent = s.parentElement;
      while (parent && parent !== doc2.body) {
        if (nodeList.includes(parent)) {
          return false;
        }
        parent = parent.parentElement;
      }
      return true;
    });
    let audioText = audioNode.filter(
      (item) => item.textContent !== "img" && !item.textContent?.startsWith("img")
    ).map((item) => item.textContent);
    if (isBackground) {
      return audioText.filter((s) => s);
    }
    let firstSliceIndex = 0;
    let visibleText = getVisibleText(element, readerMode, doc2);
    if (visibleText && visibleText.length > 0) {
      let trimmedVisibleText = visibleText.map((s) => s.trim());
      firstSliceIndex = audioText.findIndex((item) => {
        return item && trimmedVisibleText.includes(item.trim());
      });
    }
    if (firstSliceIndex === -1) {
      firstSliceIndex = 0;
    }
    return audioText.slice(firstSliceIndex).filter((s) => s);
  };
  var ZERO_WIDTH_QUOTE_CHARS = /["'\u201d\u2019」』]/;
  var getTextSentences = (text, lang) => {
    if (typeof Intl.Segmenter === "undefined") {
      return [{ start: 0, end: text.length }];
    }
    const segmenter = new Intl.Segmenter(lang, {
      granularity: "sentence"
    });
    const segments = segmenter.segment(text);
    return Array.from(segments).map((s) => ({
      start: s.index,
      end: s.index + s.segment.length
    })).filter(
      (sentence) => text.slice(sentence.start, sentence.end).trim() !== ""
    );
  };
  var snapRangeToSentences = (text, start, end) => {
    const lang = detectLocalLanguage(text);
    const sentences = getTextSentences(text, lang);
    if (sentences.length === 0) {
      return { start, end };
    }
    const overlapping = sentences.filter((s) => s.end > start && s.start < end);
    if (overlapping.length === 0) {
      return { start, end };
    }
    return {
      start: overlapping[0].start,
      end: overlapping[overlapping.length - 1].end
    };
  };
  var isTextVisibleInViewport = (rect, element, readerMode) => {
    if (readerMode === "scroll") {
      const scrollTop = element.scrollTop;
      return rect.width > 0 && rect.height > 0 && rect.bottom > scrollTop && rect.top < scrollTop + element.clientHeight && rect.right > 0 && rect.left < element.clientWidth;
    }
    return rect.width > 0 && rect.height > 0 && rect.bottom > 0 && rect.top < element.clientHeight && rect.right > 0 && rect.left < element.clientWidth;
  };
  var isNodeVisibleInViewport = (element, el, readerMode) => {
    const computedStyle = getComputedStyle(el);
    if (computedStyle.display === "none" || computedStyle.visibility === "hidden" || computedStyle.opacity === "0") {
      return false;
    }
    const rect = el.getBoundingClientRect();
    return isTextVisibleInViewport(rect, element, readerMode);
  };
  var isNodePartiallyVisibleInViewport = (element, el, readerMode) => {
    if (!isNodeVisibleInViewport(element, el, readerMode)) {
      return false;
    }
    const rect = el.getBoundingClientRect();
    if (readerMode === "scroll") {
      const scrollTop = element.scrollTop;
      return rect.top < scrollTop || rect.left < 0 || rect.bottom > scrollTop + element.clientHeight || rect.right > element.clientWidth;
    }
    return rect.top < 0 || rect.left < 0 || rect.bottom > element.clientHeight || rect.right > element.clientWidth;
  };
  var getVisibleCharRange = (element, root2, readerMode) => {
    const text = root2.textContent || "";
    if (!text.trim()) {
      return null;
    }
    const walker = document.createTreeWalker(root2, NodeFilter.SHOW_TEXT);
    let currentNode = walker.nextNode();
    let offset = 0;
    let start = -1;
    let end = -1;
    while (currentNode) {
      const content = currentNode.textContent || "";
      if (content.length > 0) {
        const nodeRange = document.createRange();
        nodeRange.selectNodeContents(currentNode);
        const nodeRects = Array.from(nodeRange.getClientRects());
        const nodeMayBeVisible = nodeRects.some(
          (rect) => isTextVisibleInViewport(rect, element, readerMode)
        );
        if (nodeMayBeVisible) {
          let prevCharVisible = false;
          for (let i = 0; i < content.length; i++) {
            const charRange = document.createRange();
            charRange.setStart(currentNode, i);
            charRange.setEnd(currentNode, i + 1);
            const charRects = Array.from(charRange.getClientRects());
            let visible = charRects.some(
              (rect) => isTextVisibleInViewport(rect, element, readerMode)
            );
            if (!visible && prevCharVisible && ZERO_WIDTH_QUOTE_CHARS.test(content[i])) {
              visible = true;
            }
            if (visible) {
              if (start === -1) {
                start = offset + i;
              }
              end = offset + i + 1;
            }
            prevCharVisible = visible;
          }
        }
      }
      offset += content.length;
      currentNode = walker.nextNode();
    }
    if (start === -1 || end === -1) {
      return null;
    }
    return { start, end, text };
  };
  var detectLocalLanguage = (text) => {
    const chinesePattern = /[\u4e00-\u9fff\u3000-\u303f\uf900-\ufaff]/g;
    const japanesePattern = /[\u3040-\u309f\u30a0-\u30ff]/g;
    const koreanPattern = /[\uac00-\ud7af\u1100-\u11ff]/g;
    const chineseCount = (text.match(chinesePattern) || []).length;
    const japaneseCount = (text.match(japanesePattern) || []).length;
    const koreanCount = (text.match(koreanPattern) || []).length;
    const cjkTotal = chineseCount + japaneseCount + koreanCount;
    if (cjkTotal / text.length <= 0.3) return "en";
    if (chineseCount >= japaneseCount && chineseCount >= koreanCount) return "zh";
    if (japaneseCount >= chineseCount && japaneseCount >= koreanCount)
      return "ja";
    return "ko";
  };
  var getNodeVisibleText = (element, item, readerMode) => {
    const text = item.textContent || "";
    if (!text.trim()) {
      return text;
    }
    if (!isNodePartiallyVisibleInViewport(element, item, readerMode)) {
      return text;
    }
    const visibleRange = getVisibleCharRange(element, item, readerMode);
    if (!visibleRange) {
      return text;
    }
    const { start, end } = snapRangeToSentences(
      text,
      visibleRange.start,
      visibleRange.end
    );
    if (end <= start) {
      return text.substring(visibleRange.start, visibleRange.end);
    }
    return text.substring(start, end);
  };
  var getVisibleText = (element, readerMode, doc2) => {
    let nodeList = getBlockElement(doc2.body).filter(
      (item) => !isParentBlock(item)
    );
    let visibleNode = nodeList.filter(
      (s) => isNodeVisibleInViewport(element, s, readerMode) && (s.textContent || "").trim()
    );
    visibleNode = visibleNode.filter((s) => {
      if (!(s.textContent || "").trim()) {
        return false;
      }
      let parent = s.parentElement;
      while (parent && parent !== doc2.body) {
        if (nodeList.includes(parent)) {
          return false;
        }
        parent = parent.parentElement;
      }
      return true;
    });
    return visibleNode.filter(
      (item) => item.textContent !== "img" && !item.textContent?.startsWith("img")
    ).map((item) => getNodeVisibleText(element, item, readerMode)).filter((s) => s);
  };
  var handleHighlightSearchNode = (text, style, doc2) => {
    const existingHighlights = doc2.querySelectorAll(
      `span[data-highlight="true"]`
    );
    existingHighlights.forEach((highlight) => {
      const parent = highlight.parentNode;
      if (parent) {
        parent.replaceChild(
          doc2.createTextNode(highlight.textContent || ""),
          highlight
        );
      }
    });
    if (!text.trim()) return;
    let nodeList = Array.from(
      doc2.body.querySelectorAll("span, p, div, h1, h2, h3, h4, h5, h6 ")
    );
    let nodes = nodeList.filter((node2) => {
      const content = node2.textContent || "";
      return content.trim() && content.toLowerCase().indexOf(text.toLowerCase()) > -1;
    });
    nodes.forEach((node2) => {
      const processNode = (node3) => {
        if (node3.nodeType === Node.TEXT_NODE) {
          const content = node3.textContent || "";
          let lowerContent = content.toLowerCase();
          let lowerText = text.toLowerCase();
          let processedContent = content;
          let offset = 0;
          let matches = [];
          let index = lowerContent.indexOf(lowerText);
          while (index > -1) {
            matches.push({
              start: index,
              end: index + text.length,
              originalText: content.substring(index, index + text.length)
            });
            index = lowerContent.indexOf(lowerText, index + 1);
          }
          if (matches.length > 0) {
            const fragment = doc2.createDocumentFragment();
            let lastEnd = 0;
            matches.forEach((match) => {
              if (match.start > lastEnd) {
                fragment.appendChild(
                  doc2.createTextNode(content.substring(lastEnd, match.start))
                );
              }
              const highlightSpan = doc2.createElement("span");
              highlightSpan.setAttribute("style", style);
              highlightSpan.setAttribute("data-highlight", "true");
              highlightSpan.setAttribute("class", "kookit-highlight-text");
              highlightSpan.textContent = match.originalText;
              fragment.appendChild(highlightSpan);
              lastEnd = match.end;
            });
            if (lastEnd < content.length) {
              fragment.appendChild(
                doc2.createTextNode(content.substring(lastEnd))
              );
            }
            node3.parentNode?.replaceChild(fragment, node3);
            return true;
          }
        }
        return false;
      };
      const walkAndProcess = (node3) => {
        let hasReplaced = processNode(node3);
        if (!hasReplaced) {
          const childNodes = Array.from(node3.childNodes);
          for (const child of childNodes) {
            walkAndProcess(child);
          }
        }
      };
      walkAndProcess(node2);
    });
  };
  var handleHighlightAudioNode = (text, style, doc2, element, readerMode) => {
    const existingHighlights = doc2.querySelectorAll(
      `span[data-highlight="true"]`
    );
    existingHighlights.forEach((highlight) => {
      const parent = highlight.parentNode;
      if (parent) {
        parent.replaceChild(
          doc2.createTextNode(highlight.textContent || ""),
          highlight
        );
      }
    });
    if (!text.trim()) return;
    let nodeList = getBlockElement(doc2.body);
    let nodes = nodeList.filter((node2) => {
      const content = node2.textContent || "";
      return content.trim() && content.indexOf(text) > -1;
    });
    if (nodes.length > 0) {
      const processNode = (node2) => {
        if (node2.nodeType === Node.TEXT_NODE) {
          const content = node2.textContent || "";
          const index = content.indexOf(text);
          if (index > -1) {
            const before2 = content.substring(0, index);
            const after2 = content.substring(index + text.length);
            const highlightSpan = doc2.createElement("span");
            highlightSpan.setAttribute("style", style);
            highlightSpan.setAttribute("data-highlight", "true");
            highlightSpan.textContent = text;
            highlightSpan.setAttribute("class", "kookit-highlight-text");
            const fragment = doc2.createDocumentFragment();
            if (before2) fragment.appendChild(doc2.createTextNode(before2));
            fragment.appendChild(highlightSpan);
            if (after2) fragment.appendChild(doc2.createTextNode(after2));
            node2.parentNode?.replaceChild(fragment, node2);
            return true;
          }
        }
        return false;
      };
      const walkAndProcess = (node2) => {
        if (processNode(node2)) return true;
        const childNodes = Array.from(node2.childNodes);
        for (const child of childNodes) {
          if (walkAndProcess(child)) return true;
        }
        return false;
      };
      walkAndProcess(nodes[0]);
    }
  };
  var getSearchResult = async (keyword, chapterDocList) => {
    let searchResult = [];
    for (let i = 0; i < chapterDocList.length; i++) {
      let chapterDoc = new DOMParser().parseFromString(
        await handleOneChapterDoc(chapterDocList[i].text, true),
        "text/html"
      );
      let nodeList = getBlockElement(chapterDoc.body).filter(
        (item) => !isParentBlock(item)
      );
      for (let j = 0; j < nodeList.length; j++) {
        let keyWordIndex = (nodeList[j].textContent?.toLowerCase() || "").indexOf(keyword.toLowerCase());
        if (keyWordIndex > -1) {
          searchResult.push({
            excerpt: nodeList[j].textContent?.substring(
              keyWordIndex - 100,
              keyWordIndex + 100
            ) || "",
            cfi: JSON.stringify({
              text: nodeList[j].textContent,
              chapterTitle: chapterDocList[i].label,
              chapterDocIndex: i,
              chapterHref: chapterDocList[i].href,
              count: "search",
              percentage: i / chapterDocList.length,
              keyword
            })
          });
        }
      }
    }
    return searchResult;
  };
  var isScrolledIntoView = (element, el, readerMode) => {
    var isVisible = false;
    const computedStyle = getComputedStyle(el);
    if (computedStyle.display === "none" || computedStyle.visibility === "hidden" || computedStyle.opacity === "0") {
      return false;
    }
    var rect = el.getBoundingClientRect();
    const vertical = isVerticalLayout() && readerMode !== "scroll";
    if (vertical && el.textContent && el.textContent.trim()) {
      let elemTop = rect.top;
      isVisible = elemTop > -10 && elemTop <= element.clientHeight;
    } else if (readerMode !== "scroll" && !vertical && el.textContent && el.textContent.trim()) {
      let elemLeft = rect.left;
      isVisible = elemLeft > -10 && elemLeft <= element.clientWidth;
    } else if (readerMode === "scroll" && el.textContent && el.textContent.trim()) {
      let elemTop = rect.top;
      isVisible = elemTop >= element.scrollTop && elemTop <= element.scrollTop + element.clientHeight;
    } else if (readerMode !== "scroll" && !vertical) {
      let elemLeft = rect.left;
      isVisible = elemLeft >= 0 && elemLeft <= element.clientWidth;
    } else if (vertical) {
      let elemTop = rect.top;
      isVisible = elemTop >= 0 && elemTop <= element.clientHeight;
    }
    return isVisible;
  };

  // vendor/kookit/src/utils/EventEmitter.ts
  var EventEmitter_default = class {
    /**
     * Constructor
     */
    callbacks;
    constructor() {
      this.callbacks = {};
      this.callbacks.base = {};
    }
    /**
     * On
     */
    on(_names, callback) {
      const that = this;
      if (typeof _names === "undefined" || _names === "") {
        console.warn("wrong names");
        return false;
      }
      if (typeof callback === "undefined") {
        console.warn("wrong callback");
        return false;
      }
      const names = this.resolveNames(_names);
      names.forEach(function(_name) {
        const name = that.resolveName(_name);
        if (!(that.callbacks[name.namespace] instanceof Object))
          that.callbacks[name.namespace] = {};
        if (!(that.callbacks[name.namespace][name.value] instanceof Array))
          that.callbacks[name.namespace][name.value] = [];
        that.callbacks[name.namespace][name.value].push(callback);
      });
      return this;
    }
    /**
     * Off
     */
    off(_names) {
      const that = this;
      if (typeof _names === "undefined" || _names === "") {
        console.warn("wrong name");
        return false;
      }
      const names = this.resolveNames(_names);
      names.forEach(function(_name) {
        const name = that.resolveName(_name);
        if (name.namespace !== "base" && name.value === "") {
          delete that.callbacks[name.namespace];
        } else {
          if (name.namespace === "base") {
            for (const namespace in that.callbacks) {
              if (that.callbacks[namespace] instanceof Object && that.callbacks[namespace][name.value] instanceof Array) {
                delete that.callbacks[namespace][name.value];
                if (Object.keys(that.callbacks[namespace]).length === 0)
                  delete that.callbacks[namespace];
              }
            }
          } else if (that.callbacks[name.namespace] instanceof Object && that.callbacks[name.namespace][name.value] instanceof Array) {
            delete that.callbacks[name.namespace][name.value];
            if (Object.keys(that.callbacks[name.namespace]).length === 0)
              delete that.callbacks[name.namespace];
          }
        }
      });
      return this;
    }
    /**
     * Trigger
     */
    trigger(_name, _args = []) {
      if (typeof _name === "undefined" || _name === "") {
        console.warn("wrong name");
        return false;
      }
      const that = this;
      let finalResult = null;
      let result2 = null;
      const args = !(_args instanceof Array) ? [] : _args;
      let name = this.resolveNames(_name);
      name = this.resolveName(name[0]);
      setTimeout(() => {
        if (name.namespace === "base") {
          for (const namespace in that.callbacks) {
            if (that.callbacks[namespace] instanceof Object && that.callbacks[namespace][name.value] instanceof Array && that.callbacks[namespace][name.value]) {
              that.callbacks[namespace][name.value].forEach(function(callback) {
                result2 = callback.apply(that, args);
                if (typeof finalResult === "undefined") {
                  finalResult = result2;
                }
              });
            } else if (this.callbacks[name.namespace] instanceof Object && that.callbacks[name.namespace][name.value]) {
              if (name.value === "") {
                console.warn("wrong name");
                return this;
              }
              that.callbacks[name.namespace][name.value].forEach(
                function(callback) {
                  result2 = callback.apply(that, args);
                  if (typeof finalResult === "undefined") finalResult = result2;
                }
              );
            }
            return finalResult;
          }
        }
      }, 100);
    }
    /**
     * Resolve names
     */
    resolveNames(_names) {
      let names = _names;
      names = names.replace(/[^a-zA-Z0-9 ,/.]/g, "");
      names = names.replace(/[,/]+/g, " ");
      names = names.split(" ");
      return names;
    }
    /**
     * Resolve name
     */
    resolveName(name) {
      const newName = {};
      const parts = name.split(".");
      newName.original = name;
      newName.value = parts[0];
      newName.namespace = "base";
      if (parts.length > 1 && parts[1] !== "") {
        newName.namespace = parts[1];
      }
      return newName;
    }
  };

  // vendor/kookit/src/libs/cfi.ts
  var ELEMENT_NODE = Node.ELEMENT_NODE;
  var TEXT_NODE = Node.TEXT_NODE;
  var CDATA_SECTION_NODE = Node.CDATA_SECTION_NODE;
  function cfiEscape(str) {
    return str.replace(/[\[\]\^,();]/g, `^$&`);
  }
  function matchAll(str, regExp, add) {
    add = add || 0;
    const matches = [];
    let offset = 0;
    let m;
    do {
      m = str.match(regExp);
      if (!m) break;
      matches.push(m.index + add);
      offset += m.index + m.length;
      str = str.slice(m.index + m.length);
    } while (offset < str.length);
    return matches;
  }
  function closest(a, n) {
    let minDiff;
    let closest2;
    let i, diff;
    for (i = 0; i < a.length; i++) {
      diff = Math.abs(a[i] - n);
      if (!i || diff < minDiff) {
        diff = minDiff;
        closest2 = a[i];
      }
    }
    return closest2;
  }
  function calcSiblingCount(nodes, n, offset) {
    let count = 0;
    let lastWasElement;
    let prevOffset = 0;
    let firstNode = true;
    let i, node2;
    for (i = 0; i < nodes.length; i++) {
      node2 = nodes[i];
      if (node2.nodeType === ELEMENT_NODE) {
        if (lastWasElement || firstNode) {
          count += 2;
          firstNode = false;
        } else {
          count++;
        }
        if (n === node2) {
          if (node2.tagName.toLowerCase() === `img`) {
            return { count, offset };
          } else {
            return { count };
          }
        }
        prevOffset = 0;
        lastWasElement = true;
      } else if (node2?.nodeType === TEXT_NODE || node2?.nodeType === CDATA_SECTION_NODE) {
        if (lastWasElement || firstNode) {
          count++;
          firstNode = false;
        }
        if (n === node2) {
          return { count, offset: offset + prevOffset };
        }
        prevOffset += node2.textContent.length;
        lastWasElement = false;
      } else {
        continue;
      }
    }
    throw new Error(`The specified node was not found in the array of siblings`);
  }
  function compareTemporal(a, b) {
    const isA = typeof a === `number`;
    const isB = typeof b === `number`;
    if (!isA && !isB) return 0;
    if (!isA && isB) return -1;
    if (isA && !isB) return 1;
    return (a || 0) - (b || 0);
  }
  function compareSpatial(a, b) {
    if (!a && !b) return 0;
    if (!a && b) return -1;
    if (a && !b) return 1;
    const diff = (a.y || 0) - (b.y || 0);
    if (diff) return diff;
    return (a.x || 0) - (b.x || 0);
  }
  var CFI = class {
    isRange = false;
    parts;
    opts;
    cfi;
    constructor(str, opts) {
      this.opts = Object.assign(
        {
          // If CFI is a Simple Range, pretend it isn't
          // by parsing only the start of the range
          flattenRange: false,
          // Strip temporal, spatial, offset and textLocationAssertion
          // from places where they don't make sense
          stricter: true
        },
        opts || {}
      );
      this.cfi = str;
      this.parts = [];
      const isCFI2 = /^epubcfi\((.*)\)$/;
      str = str.trim();
      const m = str.match(isCFI2);
      if (!m) throw new Error(`Not a valid CFI`);
      if (m.length < 2) return;
      str = m[1] || ``;
      let parsed, offset, newDoc;
      let subParts = [];
      let sawComma = 0;
      while (str.length) {
        ({ parsed, offset, newDoc } = this.parse(str));
        if (!parsed || offset === null) throw new Error(`Parsing failed`);
        if (sawComma && newDoc)
          throw new Error(
            `CFI is a range that spans multiple documents. This is not allowed`
          );
        subParts.push(parsed);
        if (newDoc || str.length - offset <= 0) {
          if (sawComma === 2) {
            this.to = subParts;
          } else {
            this.parts.push(subParts);
          }
          subParts = [];
        }
        str = str.slice(offset);
        if (str[0] === `,`) {
          if (sawComma === 0) {
            if (subParts.length) {
              this.parts.push(subParts);
            }
            subParts = [];
          } else if (sawComma === 1) {
            if (subParts.length) {
              this.from = subParts;
            }
            subParts = [];
          }
          str = str.slice(1);
          sawComma++;
        }
      }
      if (this.from && this.from.length) {
        if (this.opts.flattenRange || !this.to || !this.to.length) {
          this.parts = this.parts.concat(this.from);
          delete this.from;
          delete this.to;
        } else {
          this.isRange = true;
        }
      }
      if (this.opts.stricter) {
        this.removeIllegalOpts();
      }
    }
    removeIllegalOpts(parts) {
      if (!parts) {
        if (this.from) {
          this.removeIllegalOpts(this.from);
          if (!this.to) return;
          parts = this.to;
        } else {
          parts = this.parts;
        }
      }
      let i, j, part, subpart;
      for (i = 0; i < parts.length; i++) {
        part = parts[i];
        for (j = 0; j < part.length - 1; j++) {
          subpart = part[j];
          delete subpart.temporal;
          delete subpart.spatial;
          delete subpart.offset;
          delete subpart.textLocationAssertion;
        }
      }
    }
    static generatePart(node2, offset, extra) {
      void extra;
      let cfi = ``;
      let o;
      while (node2.parentNode) {
        o = calcSiblingCount(node2.parentNode.childNodes, node2, offset);
        if (!cfi && o.offset) cfi = `:` + o.offset;
        cfi = `/` + o.count + (node2.id ? `[` + cfiEscape(node2.id) + `]` : ``) + cfi;
        node2 = node2.parentNode;
      }
      return cfi;
    }
    static generate(node2, offset, extra) {
      let cfi;
      if (Array.isArray(node2)) {
        const strs = [];
        for (const o of node2) {
          strs.push(this.generatePart(o.node, o.offset, extra));
        }
        cfi = strs.join(`!`);
      } else {
        cfi = this.generatePart(node2, offset, extra);
      }
      if (extra) cfi += extra;
      return `epubcfi(` + cfi + `)`;
    }
    static toParsed(cfi) {
      if (typeof cfi === `string`) {
      }
      if (cfi.isRange) {
        return cfi.getFrom();
      } else {
        return cfi.get();
      }
    }
    // Takes two CFI paths and compares them
    static comparePath(a, b) {
      const max2 = Math.max(a.length, b.length);
      let i, cA, cB, diff;
      for (i = 0; i < max2; i++) {
        cA = a[i];
        cB = b[i];
        if (!cA) return -1;
        if (!cB) return 1;
        diff = this.compareParts(cA, cB);
        if (diff) return diff;
      }
      return 0;
    }
    // Sort an array of CFI objects
    static sort(a) {
      a.sort((a2, b) => {
        return this.compare(a2, b);
      });
    }
    // Takes two CFI objects and compares them.
    static compare(a, b) {
      let oA = a.get();
      let oB = b.get();
      if (a.isRange || b.isRange) {
        if (a.isRange && b.isRange) {
          const diff = this.comparePath(oA.from, oB.from);
          if (diff) return diff;
          return this.comparePath(oA.to, oB.to);
        }
        if (a.isRange) oA = oA.from;
        if (b.isRange) oB = oB.from;
        return this.comparePath(oA, oB);
      } else {
        return this.comparePath(oA, oB);
      }
    }
    // Takes two parsed path parts (assuming path is split on '!') and compares them.
    static compareParts(a, b) {
      const max2 = Math.max(a.length, b.length);
      let i, cA, cB, diff;
      for (i = 0; i < max2; i++) {
        cA = a[i];
        cB = b[i];
        if (!cA) return -1;
        if (!cB) return 1;
        diff = cA.nodeIndex - cB.nodeIndex;
        if (diff) return diff;
        if (cA.nodeIndex === 0) {
          return 0;
        }
        if (i < max2 - 1) continue;
        if (cA.nodeIndex % 2 === 0) {
          diff = compareTemporal(cA.temporal, cB.temporal);
          if (diff) return diff;
          diff = compareSpatial(cA.spatial, cB.spatial);
          if (diff) return diff;
        }
        diff = (cA.offset || 0) - (cB.offset || 0);
        if (diff) return diff;
      }
      return 0;
    }
    decodeEntities(dom, str) {
      try {
        const el = dom.createElement(`textarea`);
        el.innerHTML = str;
        return el.value || ``;
      } catch (err) {
        return str;
      }
    }
    // decode HTML/XML entities and compute length
    trueLength(dom, str) {
      return this.decodeEntities(dom, str).length;
    }
    getFrom() {
      if (!this.isRange)
        throw new Error(`Trying to get beginning of non-range CFI`);
      if (!this.from) {
        return this.deepClone(this.parts);
      }
      const parts = this.deepClone(this.parts);
      parts[parts.length - 1] = parts[parts.length - 1].concat(this.from);
      return parts;
    }
    getTo() {
      if (!this.isRange) throw new Error(`Trying to get end of non-range CFI`);
      const parts = this.deepClone(this.parts);
      parts[parts.length - 1] = parts[parts.length - 1].concat(this.to);
      return parts;
    }
    get() {
      if (this.isRange) {
        return {
          from: this.getFrom(),
          to: this.getTo(),
          isRange: true
        };
      }
      return this.deepClone(this.parts);
    }
    parseSideBias(o, loc) {
      if (!loc) return;
      const m = loc.trim().match(/^(.*);s=([ba])$/);
      if (!m || m.length < 3) {
        if (typeof o.textLocationAssertion === `object`) {
          o.textLocationAssertion.post = loc;
        } else {
          o.textLocationAssertion = loc;
        }
        return;
      }
      if (m[1]) {
        if (typeof o.textLocationAssertion === `object`) {
          o.textLocationAssertion.post = m[1];
        } else {
          o.textLocationAssertion = m[1];
        }
      }
      if (m[2] === `a`) {
        o.sideBias = `after`;
      } else {
        o.sideBias = `before`;
      }
    }
    parseSpatialRange(range2) {
      if (!range2) return void 0;
      const m = range2.trim().match(/^([\d\.]+):([\d\.]+)$/);
      if (!m || m.length < 3) return void 0;
      const o = {
        x: parseInt(m[1]),
        y: parseInt(m[2])
      };
      if (typeof o.x !== `number` || typeof o.y !== `number`) {
        return void 0;
      }
      return o;
    }
    parse(cfi) {
      const o = {};
      const isNumber2 = /[\d]/;
      let f;
      let state2;
      let prevState;
      let cur, escape;
      let seenColon = false;
      let seenSlash = false;
      let i;
      for (i = 0; i <= cfi.length; i++) {
        if (i < cfi.length) {
          cur = cfi[i];
        } else {
          cur = ``;
        }
        if (cur === `^` && !escape) {
          escape = true;
          continue;
        }
        if (state2 === `/`) {
          if (cur.match(isNumber2)) {
            if (!f) {
              f = cur;
            } else {
              f += cur;
            }
            escape = false;
            continue;
          } else {
            if (f) {
              o.nodeIndex = parseInt(f);
              f = null;
            }
            prevState = state2;
            state2 = null;
          }
        }
        if (state2 === `:`) {
          if (cur.match(isNumber2)) {
            if (!f) {
              f = cur;
            } else {
              f += cur;
            }
            escape = false;
            continue;
          } else {
            if (f) {
              o.offset = parseInt(f);
              f = null;
            }
            prevState = state2;
            state2 = null;
          }
        }
        if (state2 === `@`) {
          let done = false;
          if (cur.match(isNumber2) || cur === `.` || cur === `:`) {
            if (cur === `:`) {
              if (!seenColon) {
                seenColon = true;
              } else {
                done = true;
              }
            }
          } else {
            done = true;
          }
          if (!done) {
            if (!f) {
              f = cur;
            } else {
              f += cur;
            }
            escape = false;
            continue;
          } else {
            prevState = state2;
            state2 = null;
            if (f && seenColon) o.spatial = this.parseSpatialRange(f);
            f = null;
          }
        }
        if (state2 === `~`) {
          if (cur.match(isNumber2) || cur === `.`) {
            if (!f) {
              f = cur;
            } else {
              f += cur;
            }
            escape = false;
            continue;
          } else {
            if (f) {
              o.temporal = parseFloat(f);
            }
            prevState = state2;
            state2 = null;
            f = null;
          }
        }
        if (!state2) {
          if (cur === `!`) {
            i++;
            state2 = cur;
            break;
          }
          if (cur === `,`) {
            break;
          }
          if (cur === `/`) {
            if (seenSlash) {
              break;
            } else {
              seenSlash = true;
              prevState = state2;
              state2 = cur;
              escape = false;
              continue;
            }
          }
          if (cur === `:` || cur === `~` || cur === `@`) {
            if (this.opts.stricter) {
              if (cur === `:` && (typeof o.temporal !== `undefined` || typeof o.spatial !== `undefined`)) {
                break;
              }
              if ((cur === `~` || cur === `@`) && typeof o.offset !== `undefined`) {
                break;
              }
            }
            prevState = state2;
            state2 = cur;
            escape = false;
            seenColon = false;
            continue;
          }
          if (cur === `[` && !escape && prevState === `:`) {
            prevState = state2;
            state2 = `[`;
            escape = false;
            continue;
          }
          if (cur === `[` && !escape && prevState === `/`) {
            prevState = state2;
            state2 = `nodeID`;
            escape = false;
            continue;
          }
        }
        if (state2 === `[`) {
          if (cur === `]` && !escape) {
            prevState = state2;
            state2 = null;
            this.parseSideBias(o, f);
            f = null;
          } else if (cur === `,` && !escape) {
            o.textLocationAssertion = {};
            if (f) {
              o.textLocationAssertion.pre = f;
            }
            f = null;
          } else {
            if (!f) {
              f = cur;
            } else {
              f += cur;
            }
          }
          escape = false;
          continue;
        }
        if (state2 === `nodeID`) {
          if (cur === `]` && !escape) {
            prevState = state2;
            state2 = null;
            o.nodeID = f;
            f = null;
          } else {
            if (!f) {
              f = cur;
            } else {
              f += cur;
            }
          }
          escape = false;
          continue;
        }
        escape = false;
      }
      if (!o.nodeIndex && o.nodeIndex !== 0)
        throw new Error(`Missing child node index in CFI`);
      return { parsed: o, offset: i, newDoc: state2 === `!` };
    }
    // The CFI counts child nodes differently from the DOM
    // Retrieve the child of parentNode at the specified index
    // according to the CFI standard way of counting
    getChildNodeByCFIIndex(dom, parentNode, index, offset) {
      const children = parentNode.childNodes;
      if (!children.length) return { node: parentNode, offset: 0 };
      if (index <= 0) {
        return { node: children[0], relativeToNode: `before`, offset: 0 };
      }
      let cfiCount = 0;
      let lastChild;
      let i, child;
      for (i = 0; i < children.length; i++) {
        child = children[i];
        switch (child.nodeType) {
          case ELEMENT_NODE:
            if (cfiCount % 2 === 0) {
              cfiCount += 2;
              if (cfiCount >= index) {
                if (child.tagName.toLowerCase() === `img` && offset) {
                  return { node: child, offset };
                }
                return { node: child, offset: 0 };
              }
            } else {
              cfiCount += 1;
              if (cfiCount === index) {
                if (child.tagName.toLowerCase() === `img` && offset) {
                  return { node: child, offset };
                }
                return { node: child, offset: 0 };
              } else if (cfiCount > index) {
                if (!lastChild) {
                  return { node: parentNode, offset: 0 };
                }
                return {
                  node: lastChild,
                  offset: this.trueLength(dom, lastChild.textContent)
                };
              }
            }
            lastChild = child;
            break;
          case TEXT_NODE:
          case CDATA_SECTION_NODE:
            if (cfiCount === 0 || cfiCount % 2 === 0) {
              cfiCount += 1;
            } else {
            }
            if (cfiCount === index) {
              const trueLength = this.trueLength(dom, child.textContent);
              if (offset >= trueLength) {
                offset -= trueLength;
              } else {
                return { node: child, offset };
              }
            }
            lastChild = child;
            break;
          default:
            continue;
        }
      }
      if (index > cfiCount) {
        const o = { relativeToNode: `after`, offset: 0 };
        if (!lastChild) {
          o.node = parentNode;
        } else {
          o.node = lastChild;
        }
        if (this.isTextNode(o.node)) {
          o.offset = this.trueLength(dom, o.node.textContent.length);
        }
        return o;
      }
    }
    isTextNode(node2) {
      if (!node2) return false;
      if (node2.nodeType === TEXT_NODE || node2.nodeType === CDATA_SECTION_NODE) {
        return true;
      }
      return false;
    }
    // Use a Text Location Assertion to correct and offset
    correctOffset(dom, node2, offset, assertion) {
      let curNode = node2;
      let matchStr;
      if (typeof assertion === `string`) {
        matchStr = this.decodeEntities(dom, assertion);
      } else {
        assertion.pre = this.decodeEntities(dom, assertion.pre);
        assertion.post = this.decodeEntities(dom, assertion.post);
        matchStr = assertion.pre + `.` + assertion.post;
      }
      if (!this.isTextNode(node2)) {
        return { node: node2, offset: 0 };
      }
      while (this.isTextNode(curNode.previousSibling)) {
        curNode = curNode.previousSibling;
      }
      const startNode = curNode;
      let str;
      const nodeLengths = [];
      let txt = ``;
      let i = 0;
      while (this.isTextNode(curNode)) {
        str = this.decodeEntities(dom, curNode.textContent);
        nodeLengths[i] = str.length;
        txt += str;
        if (!curNode.nextSibling) break;
        curNode = curNode.nextSibling;
        i++;
      }
      const matchOffset = assertion.pre ? assertion.pre.length : 0;
      const m = matchAll(txt, new RegExp(matchStr), matchOffset);
      if (!m.length) return { node: node2, offset };
      let newOffset = closest(m, offset);
      if (curNode === node2 && newOffset === offset) {
        return { node: node2, offset };
      }
      i = 0;
      curNode = startNode;
      while (newOffset >= nodeLengths[i]) {
        newOffset -= nodeLengths[i];
        if (newOffset < 0) return { node: node2, offset };
        const nodeOffsets = [];
        if (!curNode.nextSibling || i + 1 >= nodeOffsets.length)
          return { node: node2, offset };
        i++;
        curNode = curNode.nextSibling;
      }
      return { node: curNode, offset: newOffset };
    }
    resolveNode(index, subparts, dom, opts) {
      opts = Object.assign({}, opts || {});
      if (!dom) throw new Error(`Missing DOM argument`);
      let startNode;
      if (index === 0) {
        startNode = dom.querySelector(`package`);
      }
      if (!startNode) {
        for (const n of dom.childNodes) {
          if (n.nodeType === ELEMENT_NODE) {
            startNode = n;
            break;
          }
        }
      }
      startNode = dom;
      if (!startNode) throw new Error(`Document incompatible with CFIs`);
      let node2 = startNode;
      let startFrom = 0;
      let i;
      let subpart;
      for (i = subparts.length - 1; i >= 0; i--) {
        subpart = subparts[i];
        if (!opts.ignoreIDs && subpart.nodeID && (node2 = dom.getElementById(subpart.nodeID))) {
          startFrom = i + 1;
          break;
        }
      }
      if (!node2) {
        node2 = startNode;
      }
      let o = { node: node2, offset: 0 };
      for (i = startFrom; i < subparts.length; i++) {
        subpart = subparts[i];
        if (subpart) {
          o = this.getChildNodeByCFIIndex(
            dom,
            o.node,
            subpart.nodeIndex,
            subpart.offset
          );
          if (subpart.textLocationAssertion) {
            o = this.correctOffset(
              dom,
              o.node,
              subpart.offset,
              subpart.textLocationAssertion
            );
          }
        }
      }
      return o;
    }
    // Each part of a CFI (as separated by '!')
    // references a separate HTML/XHTML/XML document.
    // This function takes an index specifying the part
    // of the CFI and the appropriate Document or XMLDocument
    // that is referenced by the specified part of the CFI
    // and returns the URI for the document referenced by
    // the next part of the CFI
    // If the opt `ignoreIDs` is true then IDs
    // will not be used while resolving
    resolveURI(index, dom, opts) {
      opts = opts || {};
      if (index < 0 || index > this.parts.length - 2) {
        throw new Error(`index is out of bounds`);
      }
      const subparts = this.parts[index];
      if (!subparts) throw new Error(`Missing CFI part for index: ` + index);
      const o = this.resolveNode(index, subparts, dom, opts);
      let node2 = o.node;
      const tagName = node2.tagName.toLowerCase();
      if (tagName === `itemref` && // @ts-ignore
      node2.parentNode.tagName.toLowerCase() === `spine`) {
        const idref = node2.getAttribute(`idref`);
        if (!idref) throw new Error(`Referenced node had not 'idref' attribute`);
        node2 = dom.getElementById(idref);
        if (!node2) throw new Error(`Specified node is missing from manifest`);
        const href = node2.getAttribute(`href`);
        if (!href) throw new Error(`Manifest item is missing href attribute`);
        return href;
      }
      if (tagName === `iframe` || tagName === `embed`) {
        const src = node2.getAttribute(`src`);
        if (!src)
          throw new Error(tagName + ` element is missing 'src' attribute`);
        return src;
      }
      if (tagName === `object`) {
        const data = node2.getAttribute(`data`);
        if (!data)
          throw new Error(tagName + ` element is missing 'data' attribute`);
        return data;
      }
      if (tagName === `image` || tagName === `use`) {
        const href = node2.getAttribute(`xlink:href`);
        if (!href)
          throw new Error(tagName + ` element is missing 'xlink:href' attribute`);
        return href;
      }
      throw new Error(`No URI found`);
    }
    deepClone(o) {
      return JSON.parse(JSON.stringify(o));
    }
    resolveLocation(dom, parts) {
      const index = parts.length - 1;
      const subparts = parts[index];
      if (!subparts) throw new Error(`Missing CFI part for index: ` + index);
      const o = this.resolveNode(index, subparts, dom);
      const lastPart = this.deepClone(subparts[subparts.length - 1]);
      delete lastPart.nodeIndex;
      if (!lastPart.offset) delete o.offset;
      return { ...lastPart, ...o };
    }
    // Takes the Document or XMLDocument for the final
    // document referenced by the CFI
    // and returns the node and offset into that node
    resolveLast(dom, opts) {
      opts = Object.assign(
        {
          range: false
        },
        opts || {}
      );
      if (!this.isRange) {
        return this.resolveLocation(dom, this.parts);
      }
      if (opts.range) {
        const range2 = dom.createRange();
        const from = this.getFrom();
        if (from.relativeToNode === `before`) {
          range2.setStartBefore(from.node, from.offset);
        } else if (from.relativeToNode === `after`) {
          range2.setStartAfter(from.node, from.offset);
        } else {
          range2.setStart(from.node, from.offset);
        }
        const to = this.getTo();
        if (to.relativeToNode === `before`) {
          range2.setEndBefore(to.node, to.offset);
        } else if (to.relativeToNode === `after`) {
          range2.setEndAfter(to.node, to.offset);
        } else {
          range2.setEnd(to.node, to.offset);
        }
        return range2;
      }
      return {
        from: this.resolveLocation(dom, this.getFrom()),
        to: this.resolveLocation(dom, this.getTo()),
        isRange: true
      };
    }
    resolve(doc2, opts) {
      return this.resolveLast(doc2, opts);
    }
  };

  // vendor/kookit/src/utils/noteUtil.ts
  var import_rangy_core = __toESM(require_rangy_core(), 1);
  var import_rangy_textrange = __toESM(require_rangy_textrange(), 1);
  var TOOLTIP_ID = "kookit-note-tooltip";
  var getTooltipAnchorRect = (element) => {
    const rect = element.getBoundingClientRect();
    return {
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
      width: rect.width,
      height: rect.height
    };
  };
  var mergeTooltipAnchorRects = (elements) => {
    if (elements.length === 0) return null;
    const rects = elements.map((element) => getTooltipAnchorRect(element)).filter((rect) => rect.width > 0 || rect.height > 0);
    if (rects.length === 0) return null;
    const left = Math.min(...rects.map((rect) => rect.left));
    const top = Math.min(...rects.map((rect) => rect.top));
    const right = Math.max(...rects.map((rect) => rect.right));
    const bottom = Math.max(...rects.map((rect) => rect.bottom));
    return {
      left,
      top,
      right,
      bottom,
      width: right - left,
      height: bottom - top
    };
  };
  var positionTooltipAboveRect = (tooltip, rect, doc2, offset) => {
    tooltip.style.left = "0px";
    tooltip.style.top = "0px";
    requestAnimationFrame(() => {
      const vpW = doc2.documentElement.clientWidth || window.innerWidth;
      const vpH = doc2.documentElement.clientHeight || window.innerHeight;
      const tw = tooltip.offsetWidth;
      const th = tooltip.offsetHeight;
      let left = rect.left + rect.width / 2 - tw / 2;
      let top = rect.top - th - offset;
      if (left < 0) left = 0;
      if (left + tw > vpW) left = Math.max(0, vpW - tw);
      if (top < 0) {
        top = rect.bottom + offset;
        if (top + th > vpH) {
          top = Math.max(0, vpH - th);
        }
      }
      tooltip.style.left = left + "px";
      tooltip.style.top = top + "px";
    });
  };
  var getNoteTooltipAnchorRect = (target, doc2) => {
    const noteKey = target.getAttribute("data-key");
    if (!noteKey) return getTooltipAnchorRect(target);
    const noteElements = Array.from(
      doc2.querySelectorAll(".kookit-note[data-key], .kookit-note-icon[data-key]")
    ).filter((element) => {
      return element.getAttribute("data-key") === noteKey;
    });
    return mergeTooltipAnchorRects(noteElements) || getTooltipAnchorRect(target);
  };
  var showNoteTooltip = (content, target, doc2) => {
    let tooltip = doc2.getElementById(TOOLTIP_ID);
    if (!tooltip) {
      tooltip = doc2.createElement("span");
      tooltip.setAttribute("id", TOOLTIP_ID);
      tooltip.setAttribute("class", "kookit-note-tooltip");
      tooltip.setAttribute(
        "style",
        "position: fixed; z-index: 9999; max-width: 280px; padding: 6px 10px; background: #383838; color: #fff; font-size: 15px !important; border-radius: 6px; pointer-events: none; word-break: break-word; white-space: pre-wrap; line-height: 1.5;"
      );
      doc2.body.appendChild(tooltip);
    }
    tooltip.textContent = content;
    tooltip.style.display = "block";
    positionTooltipAboveRect(
      tooltip,
      getNoteTooltipAnchorRect(target, doc2),
      doc2,
      10
    );
  };
  var hideNoteTooltip = (doc2) => {
    const tooltip = doc2.getElementById(TOOLTIP_ID);
    tooltip?.remove();
  };
  var BATCH_CHUNK_SIZE = 20;
  var BATCH_CHUNK_TIME_BUDGET = 8;
  var noteBatchGen = /* @__PURE__ */ new WeakMap();
  var bumpNoteBatchGen = (doc2) => {
    const gen = (noteBatchGen.get(doc2) || 0) + 1;
    noteBatchGen.set(doc2, gen);
    return gen;
  };
  var resolveNoteRanges = (notes2, selection2, doc2, iWin) => {
    const resolved = new Array(
      notes2.length
    );
    const indices = [];
    for (let i = 0; i < notes2.length; i++) {
      const cr = notes2[i]?.range?.characterRange;
      if (cr && typeof cr.start === "number" && typeof cr.end === "number") {
        indices.push(i);
      }
    }
    indices.sort(
      (a, b) => notes2[a].range.characterRange.start - notes2[b].range.characterRange.start
    );
    let range2 = null;
    let prevStart = 0;
    for (let k = 0; k < indices.length; k++) {
      const i = indices[k];
      const item = notes2[i];
      const cr = item.range.characterRange;
      try {
        if (!range2) {
          range2 = import_rangy_core.default.createRange(doc2);
          range2.selectNodeContents(doc2);
          range2.collapse(true);
          prevStart = 0;
        }
        range2.collapse(true);
        range2.moveStart("character", cr.start - prevStart);
        range2.collapse(true);
        range2.moveEnd("character", cr.end - cr.start);
        resolved[i] = {
          nativeRange: range2.nativeRange.cloneRange(),
          colorCode: item.colorCode,
          noteKey: item.noteKey,
          isNote: item.isNote,
          noteContent: item.noteContent
        };
        prevStart = cr.start;
      } catch (e) {
        console.warn(
          "Failed to restore character range for note:",
          item.noteKey,
          e
        );
        range2 = null;
        try {
          selection2.restoreCharacterRanges(doc2, [item.range]);
          resolved[i] = {
            nativeRange: selection2.getRangeAt(0).nativeRange.cloneRange(),
            colorCode: item.colorCode,
            noteKey: item.noteKey,
            isNote: item.isNote,
            noteContent: item.noteContent
          };
        } catch (e2) {
          console.warn(
            "Failed to restore character range for note:",
            item.noteKey,
            e2
          );
        }
        if (iWin?.getSelection()) iWin.getSelection().empty();
      }
    }
    selection2.removeAllRanges();
    if (iWin?.getSelection()) iWin.getSelection().empty();
    return resolved;
  };
  var showNoteHighlightBatch = (notes2, handleNoteClick, doc2, iframe, isMobile) => {
    let iWin = iframe.contentWindow || iframe.contentDocument?.defaultView;
    let selection2 = import_rangy_core.default.getSelection(iframe);
    const resolved = resolveNoteRanges(notes2, selection2, doc2, iWin);
    return new Promise((resolvePromise) => {
      if (resolved.length === 0) {
        resolvePromise();
        return;
      }
      const gen = bumpNoteBatchGen(doc2);
      const schedule = iWin && typeof iWin.requestAnimationFrame === "function" ? iWin.requestAnimationFrame.bind(iWin) : (callback) => setTimeout(callback, 0);
      let index = 0;
      const applyChunk = () => {
        if (noteBatchGen.get(doc2) !== gen) {
          resolvePromise();
          return;
        }
        const chunkStart = Date.now();
        let applied = 0;
        while (index < resolved.length && applied < BATCH_CHUNK_SIZE && Date.now() - chunkStart < BATCH_CHUNK_TIME_BUDGET) {
          const r = resolved[index++];
          if (!r) continue;
          highlightRange(
            { nativeRange: r.nativeRange },
            r.colorCode,
            r.noteKey,
            handleNoteClick,
            doc2,
            r.isNote,
            isMobile,
            r.noteContent
          );
          applied++;
        }
        if (index < resolved.length) {
          schedule(applyChunk);
        } else {
          resolvePromise();
        }
      };
      schedule(applyChunk);
    });
  };
  var showNoteHighlight = (range2, colorCode, noteKey, handleNoteClick, doc2, iframe, isNote, isMobile, noteContent = "") => {
    let iWin = iframe.contentWindow || iframe.contentDocument?.defaultView;
    let temp = range2;
    temp = [temp];
    let selection2 = import_rangy_core.default.getSelection(iframe);
    selection2.restoreCharacterRanges(doc2, temp);
    let newRange = selection2.getRangeAt(0);
    highlightRange(
      newRange,
      colorCode,
      noteKey,
      handleNoteClick,
      doc2,
      isNote,
      isMobile,
      noteContent
    );
    if (!iWin || !iWin.getSelection()) return;
    iWin.getSelection()?.empty();
  };
  var clearHighlight = (doc2) => {
    bumpNoteBatchGen(doc2);
    const icons = doc2.querySelectorAll(".kookit-note-icon");
    for (let index = 0; index < icons.length; index++) {
      icons[index].parentNode?.removeChild(icons[index]);
    }
    const elements = doc2.querySelectorAll(".kookit-note");
    const parentsToNormalize = /* @__PURE__ */ new Set();
    for (let index = elements.length - 1; index >= 0; index--) {
      const element = elements[index];
      const parent = element.parentNode;
      if (!parent) {
        continue;
      }
      if (element.tagName === "SPAN" && element.childNodes.length > 0) {
        while (element.firstChild) {
          parent.insertBefore(element.firstChild, element);
        }
        parentsToNormalize.add(parent);
      }
      parent.removeChild(element);
    }
    parentsToNormalize.forEach((parent) => {
      parent.normalize();
    });
  };
  var highlightRange = (range2, colorCode, noteKey, handleNoteClick, doc2, isNote = false, isMobile = false, noteContent = "") => {
    if (isMobile && window.isSwiping) {
      const waitAndHighlight = () => {
        if (window.isSwiping) {
          requestAnimationFrame(waitAndHighlight);
        } else {
          highlightRange(
            range2,
            colorCode,
            noteKey,
            handleNoteClick,
            doc2,
            isNote,
            isMobile,
            noteContent
          );
        }
      };
      requestAnimationFrame(waitAndHighlight);
      return;
    }
    const nativeRange = range2.nativeRange;
    const textNodes = [];
    const walker = doc2.createTreeWalker(
      nativeRange.commonAncestorContainer,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode: (node2) => {
          return nativeRange.intersectsNode(node2) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
        }
      }
    );
    while (walker.nextNode()) {
      textNodes.push(walker.currentNode);
    }
    if (textNodes.length === 0 && nativeRange.commonAncestorContainer.nodeType === Node.TEXT_NODE) {
      textNodes.push(nativeRange.commonAncestorContainer);
    }
    const wrappedSpans = [];
    const promotedSpans = /* @__PURE__ */ new Set();
    for (let i = 0; i < textNodes.length; i++) {
      const textNode = textNodes[i];
      if (!textNode.textContent || !textNode.textContent.trim()) continue;
      if (textNode.parentElement && textNode.parentElement.classList.contains("kookit-note") && textNode.parentElement.getAttribute("data-key") === noteKey) {
        wrappedSpans.push(textNode.parentElement);
        continue;
      }
      const existingNoteParent = textNode.parentElement?.closest?.(
        ".kookit-note[data-key]"
      );
      if (existingNoteParent && existingNoteParent.getAttribute("data-key") !== noteKey) {
        const parentRange = doc2.createRange();
        parentRange.selectNodeContents(existingNoteParent);
        const newStartBeforeOrAt = nativeRange.compareBoundaryPoints(Range.START_TO_START, parentRange) <= 0;
        const newEndAfterOrAt = nativeRange.compareBoundaryPoints(Range.END_TO_END, parentRange) >= 0;
        const parentFullyContained = newStartBeforeOrAt && newEndAfterOrAt;
        if (parentFullyContained) {
          if (promotedSpans.has(existingNoteParent)) continue;
          promotedSpans.add(existingNoteParent);
          const alreadyOuter = existingNoteParent.parentElement?.closest?.(
            `.kookit-note[data-key="${noteKey}"]`
          );
          if (alreadyOuter) {
            wrappedSpans.push(alreadyOuter);
            continue;
          }
          const span2 = doc2.createElement("span");
          span2.setAttribute(
            "style",
            buildHighlightStyleForType(colorCode, false, isVerticalLayout())
          );
          span2.setAttribute("class", "kookit-note");
          span2.setAttribute("data-key", noteKey);
          if (isNote && noteContent) {
            span2.setAttribute("data-note-content", noteContent);
          }
          existingNoteParent.parentNode.insertBefore(span2, existingNoteParent);
          span2.appendChild(existingNoteParent);
          wrappedSpans.push(span2);
          continue;
        }
      }
      let startOffset = 0;
      let endOffset = textNode.textContent.length;
      if (textNode === nativeRange.startContainer) {
        startOffset = nativeRange.startOffset;
      }
      if (textNode === nativeRange.endContainer) {
        endOffset = nativeRange.endOffset;
      }
      let targetNode = textNode;
      if (startOffset > 0) {
        targetNode = textNode.splitText(startOffset);
        endOffset -= startOffset;
      }
      if (endOffset < targetNode.textContent.length) {
        targetNode.splitText(endOffset);
      }
      const span = doc2.createElement("span");
      span.setAttribute(
        "style",
        buildHighlightStyleForType(colorCode, false, isVerticalLayout())
      );
      span.setAttribute("class", "kookit-note");
      span.setAttribute("data-key", noteKey);
      if (isNote && noteContent) {
        span.setAttribute("data-note-content", noteContent);
      }
      targetNode.parentNode.insertBefore(span, targetNode);
      span.appendChild(targetNode);
      wrappedSpans.push(span);
    }
    if (!doc2.body.__kookitDelegated) {
      doc2.body.__kookitDelegated = true;
      let delegateDownX = 0;
      let delegateDownY = 0;
      doc2.body.addEventListener(
        "mousemove",
        (e) => {
          const target = e.target?.closest?.(
            ".kookit-note[data-key]"
          );
          if (target) {
            doc2.body.style.cursor = "pointer";
            const nc = target.getAttribute("data-note-content") || "";
            if (nc) {
              showNoteTooltip(nc, target, doc2);
            } else {
              hideNoteTooltip(doc2);
            }
          } else {
            doc2.body.style.cursor = "";
            hideNoteTooltip(doc2);
          }
        },
        true
      );
      doc2.body.addEventListener(
        "mousedown",
        (e) => {
          delegateDownX = e.clientX;
          delegateDownY = e.clientY;
        },
        true
      );
      doc2.body.addEventListener(
        "click",
        (e) => {
          if (Math.abs(e.clientX - delegateDownX) > 5 || Math.abs(e.clientY - delegateDownY) > 5)
            return;
          const target = e.target?.closest?.(
            ".kookit-note[data-key]"
          );
          if (target) {
            handleNoteClick({ target });
          }
        },
        true
      );
      doc2.body.addEventListener(
        "touchend",
        (e) => {
          if (window.isSwiping) return;
          const touch = e.changedTouches[0];
          if (!touch) return;
          const el = doc2.elementFromPoint(touch.clientX, touch.clientY);
          const target = el?.closest?.(
            ".kookit-note[data-key]"
          );
          let selectedText = "";
          if (doc2 && doc2.getSelection()) {
            selectedText = doc2.getSelection()?.toString().trim() || "";
          }
          if (target && !selectedText) {
            handleNoteClick({ target });
            e.preventDefault();
            e.stopPropagation();
          }
        },
        true
      );
    }
    if (isNote && wrappedSpans.length > 0) {
      const firstSpan = wrappedSpans[0];
      const iconNode = doc2.createElement("span");
      iconNode.setAttribute("class", "kookit-note-icon");
      iconNode.setAttribute("data-key", noteKey);
      iconNode.setAttribute(
        "style",
        "position: relative; z-index: 2; font-size: 14px; line-height: 1; cursor: pointer; pointer-events: auto;"
      );
      firstSpan.parentNode?.insertBefore(iconNode, firstSpan);
    }
  };
  var WORD_TOOLTIP_ID = "kookit-word-tooltip";
  var showWordTooltip = (content, target, doc2) => {
    let tooltip = doc2.getElementById(WORD_TOOLTIP_ID);
    if (!tooltip) {
      tooltip = doc2.createElement("span");
      tooltip.setAttribute("id", WORD_TOOLTIP_ID);
      tooltip.setAttribute("class", WORD_TOOLTIP_ID);
      tooltip.setAttribute(
        "style",
        "position: fixed; z-index: 9999; max-width: 280px; padding: 6px 10px; background: #383838; color: #fff; font-size: 15px !important; border-radius: 6px; pointer-events: none; word-break: break-word; white-space: pre-wrap; line-height: 1.5;"
      );
      doc2.body.appendChild(tooltip);
    }
    tooltip.textContent = content;
    tooltip.style.display = "block";
    positionTooltipAboveRect(tooltip, getTooltipAnchorRect(target), doc2, 6);
  };
  var hideWordTooltip = (doc2) => {
    const tooltip = doc2.getElementById(WORD_TOOLTIP_ID);
    tooltip?.remove();
  };
  var clearWordDefinitions = (doc2) => {
    const spans = doc2.querySelectorAll(".kookit-word-def");
    for (let i = 0; i < spans.length; i++) {
      const span = spans[i];
      const parent = span.parentNode;
      if (!parent) continue;
      while (span.firstChild) {
        parent.insertBefore(span.firstChild, span);
      }
      parent.removeChild(span);
      parent.normalize();
    }
  };
  var applyWordDefinitions = (definitionMap, doc2, lang = "en", locale = "en", rootElement) => {
    const words = Object.keys(definitionMap);
    if (words.length === 0) return;
    const isCJK = lang === "zh" || lang === "ja";
    const sortedWords = isCJK ? [...words].sort((a, b) => b.length - a.length) : words;
    const escapedWords = sortedWords.map(
      (w) => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    );
    const pattern = isCJK ? new RegExp("(" + escapedWords.join("|") + ")", "g") : new RegExp("\\b(" + escapedWords.join("|") + ")\\b", "gi");
    const walker = doc2.createTreeWalker(
      rootElement || doc2.body,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode: (node2) => {
          let parent = node2.parentElement;
          while (parent) {
            const tag = parent.tagName;
            if (tag === "SCRIPT" || tag === "STYLE" || tag === "RUBY" || parent.classList.contains("kookit-note") || parent.classList.contains("kookit-word-def") || parent.classList.contains("kookit-text-rule-replace") || parent.classList.contains("kookit-text-rule-delete") || parent.classList.contains("kookit-note-tooltip") || parent.classList.contains("kookit-word-tooltip")) {
              return NodeFilter.FILTER_REJECT;
            }
            parent = parent.parentElement;
          }
          return NodeFilter.FILTER_ACCEPT;
        }
      }
    );
    const textNodes = [];
    while (walker.nextNode()) {
      textNodes.push(walker.currentNode);
    }
    for (const textNode of textNodes) {
      const text = textNode.textContent || "";
      pattern.lastIndex = 0;
      if (!pattern.test(text)) continue;
      pattern.lastIndex = 0;
      const fragment = doc2.createDocumentFragment();
      let lastIndex = 0;
      let match;
      while ((match = pattern.exec(text)) !== null) {
        const before2 = text.slice(lastIndex, match.index);
        if (before2) fragment.appendChild(doc2.createTextNode(before2));
        const word = match[0];
        const defKey = word.toLowerCase();
        const def = definitionMap[defKey] || definitionMap[word];
        const span = doc2.createElement("span");
        span.className = "kookit-word-def";
        let meaning = def.meaning || "";
        if (locale === "zhCN" && def.cn_meaning) {
          meaning = def.cn_meaning;
        }
        span.setAttribute("data-meaning", meaning || "");
        let fullDef;
        if (lang === "zh") {
          fullDef = [
            "[" + def.pinyin + "]" || "",
            meaning || "",
            def.level ? "[HSK" + def.level + "]" : ""
          ].filter(Boolean).join("  ");
        } else if (lang === "ja") {
          const reading = [
            def.furigana || "",
            def.romaji ? "(" + def.romaji + ")" : ""
          ].filter(Boolean).join("");
          fullDef = [
            reading,
            meaning || "",
            def.level ? "[N" + def.level + "]" : ""
          ].filter(Boolean).join("  ");
        } else {
          fullDef = [
            def.pronunciation || "",
            meaning || "",
            def.level ? "[" + def.level + "]" : ""
          ].filter(Boolean).join("  ");
        }
        span.setAttribute("data-def-full", fullDef);
        span.appendChild(doc2.createTextNode(word));
        fragment.appendChild(span);
        lastIndex = match.index + word.length;
      }
      if (lastIndex === 0) continue;
      const after2 = text.slice(lastIndex);
      if (after2) fragment.appendChild(doc2.createTextNode(after2));
      textNode.parentNode?.replaceChild(fragment, textNode);
    }
    if (!doc2.body.__kookitWordDefDelegated) {
      doc2.body.__kookitWordDefDelegated = true;
      doc2.body.addEventListener(
        "mousemove",
        (e) => {
          const target = e.target?.closest?.(
            ".kookit-word-def"
          );
          if (target) {
            const fullDef = target.getAttribute("data-def-full") || "";
            showWordTooltip(fullDef, target, doc2);
          } else {
            hideWordTooltip(doc2);
          }
        },
        true
      );
      doc2.body.addEventListener(
        "mouseleave",
        () => {
          hideWordTooltip(doc2);
        },
        true
      );
      doc2.body.addEventListener(
        "touchend",
        (e) => {
          const target = e.target?.closest?.(
            ".kookit-word-def"
          );
          if (target) {
            const fullDef = target.getAttribute("data-def-full") || "";
            showWordTooltip(fullDef, target, doc2);
            e?.preventDefault();
            e?.stopPropagation();
          } else {
            let tooltip = doc2.getElementById(
              WORD_TOOLTIP_ID
            );
            if (tooltip) {
              hideWordTooltip(doc2);
              e?.preventDefault();
              e?.stopPropagation();
            }
          }
        },
        true
      );
    }
  };

  // vendor/kookit/src/utils/animationUtil.ts
  function createBookElement(sectionCount) {
    let tempDiv = document.getElementById("book");
    if (tempDiv) {
      tempDiv.remove();
    }
    const bookDiv = document.createElement("div");
    bookDiv.id = "book";
    const canvas = document.createElement("canvas");
    canvas.id = "pageflip-canvas";
    const pagesDiv = document.createElement("div");
    pagesDiv.id = "pages";
    for (let i = 0; i < sectionCount; i++) {
      const section = document.createElement("section");
      pagesDiv.appendChild(section);
    }
    bookDiv.appendChild(canvas);
    bookDiv.appendChild(pagesDiv);
    document.body.appendChild(bookDiv);
    let css2 = `
      #book {
        position: fixed;
        width: 200vw;
        height: 100vh;
        left: -100vw;
        top: 0vh;
        float: left;
        margin: 0;
        display: none;
      }

      #pages section {
        display: block;
        width: 100vw;
        height: 100vh;
        position: absolute;
        left: 100vw;
        top: 0px;
        overflow: hidden;
        margin: 0;
      }

      #pageflip-canvas {
        position: absolute;
        z-index: 100;
        margin: 0;
      }
    `;
    let style = document.createElement("style");
    style.innerHTML = css2;
    document.head.appendChild(style);
  }
  var flipRenderTimer = null;
  var flipAnimFrameId = null;
  var flipAnimating = false;
  var addPageAnimation = (totalPage, isDarkMode, backgroundColor, pageIndex = 0) => {
    if (flipRenderTimer) {
      clearInterval(flipRenderTimer);
      flipRenderTimer = null;
    }
    if (flipAnimFrameId) {
      cancelAnimationFrame(flipAnimFrameId);
      flipAnimFrameId = null;
    }
    flipAnimating = false;
    createBookElement(Math.max(1, Math.floor(totalPage) + 1));
    var WINDOW_WIDTH = window.innerWidth;
    var WINDOW_HEIGHT = window.innerHeight;
    var CANVAS_PADDING = 0;
    var BOOK_WIDTH = 2 * WINDOW_WIDTH - CANVAS_PADDING;
    var BOOK_HEIGHT = WINDOW_HEIGHT - CANVAS_PADDING;
    var PAGE_WIDTH = WINDOW_WIDTH;
    var PAGE_HEIGHT = WINDOW_HEIGHT;
    var touchStartX = 0;
    var touchEndX = 0;
    var CANVAS_SCALE = 0.5;
    var PAGE_Y = (BOOK_HEIGHT - PAGE_HEIGHT) / 2;
    var pageNum = 0;
    var canvas = document.getElementById("pageflip-canvas");
    if (!canvas) return;
    var context = canvas.getContext("2d");
    var mouse = { x: 0, y: 0 };
    var flips = [];
    var book = document.getElementById("book");
    if (!book) return;
    var pages = book.getElementsByTagName("section");
    for (var i = 0, len = pages.length; i < len; i++) {
      pages[i].style.zIndex = len - i + "";
      flips.push({
        // Current progress of the flip (left -1 to right +1)
        progress: 1,
        // The target value towards which progress is always moving
        target: 1,
        // The page DOM element related to this flip
        page: pages[i],
        // True while the page is being dragged
        dragging: false
      });
    }
    canvas.width = (BOOK_WIDTH + CANVAS_PADDING * 2) * CANVAS_SCALE;
    canvas.height = (BOOK_HEIGHT + CANVAS_PADDING * 2) * CANVAS_SCALE;
    canvas.style.width = BOOK_WIDTH + CANVAS_PADDING * 2 + "px";
    canvas.style.height = BOOK_HEIGHT + CANVAS_PADDING * 2 + "px";
    canvas.style.willChange = "transform";
    canvas.style.transform = "translateZ(0)";
    canvas.style.top = -CANVAS_PADDING + "px";
    canvas.style.left = -CANVAS_PADDING + "px";
    flipAnimating = true;
    function animationLoop() {
      if (!flipAnimating) return;
      render();
      flipAnimFrameId = requestAnimationFrame(animationLoop);
    }
    flipAnimFrameId = requestAnimationFrame(animationLoop);
    book.addEventListener("touchmove", mouseMoveHandler, false);
    book.addEventListener("touchstart", mouseDownHandler, false);
    book.addEventListener("touchend", mouseUpHandler, false);
    function mouseMoveHandler(event) {
      if (!book || !event.touches?.[0]) return;
      const touch = event.touches[0];
      const bookRect = book.getBoundingClientRect();
      mouse.x = touch.screenX - bookRect.left - BOOK_WIDTH / 2;
      mouse.y = touch.screenY - bookRect.top;
    }
    function mouseDownHandler(event) {
      const touch = event.touches?.[0];
      if (!touch) return;
      touchStartX = touch.screenX;
      if (touch.screenX < window.screen.width / 2 && pageNum - 1 >= 0) {
        flips[pageNum - 1].dragging = true;
      } else if (touch.screenX > window.screen.width / 2 && pageNum + 1 < flips.length) {
        flips[pageNum].dragging = true;
      }
      event.preventDefault();
    }
    function mouseUpHandler(event) {
      const touch = event.changedTouches?.[0];
      if (!touch) return;
      touchEndX = touch.screenX;
      for (var i2 = 0; i2 < flips.length; i2++) {
        if (flips[i2].dragging) {
          if (mouse.x < PAGE_WIDTH / 4 * 3 && touchEndX - touchStartX < 0) {
            flips[i2].target = -1;
            pageNum = Math.min(pageNum + 1, flips.length);
          } else if (mouse.x > PAGE_WIDTH / 4 * 1 && touchEndX - touchStartX > 0) {
            flips[i2].target = 1;
            pageNum = Math.max(pageNum - 1, 0);
          } else {
            if (i2 === pageNum) {
              flips[i2].target = 1;
            } else if (i2 === pageNum - 1) {
              flips[i2].target = -1;
            }
          }
        }
        flips[i2].dragging = false;
      }
    }
    function render() {
      context.save();
      context.setTransform(CANVAS_SCALE, 0, 0, CANVAS_SCALE, 0, 0);
      context.clearRect(0, 0, BOOK_WIDTH + CANVAS_PADDING * 2, BOOK_HEIGHT + CANVAS_PADDING * 2);
      for (var i2 = 0; i2 < flips.length; i2++) {
        var flip = flips[i2];
        if (flip.dragging) {
          flip.target = Math.max(Math.min(mouse.x / PAGE_WIDTH, 1), -1);
        }
        flip.progress += (flip.target - flip.progress) * 0.2;
        if (flip.dragging || Math.abs(flip.progress) < 0.997) {
          drawFlip(flip);
        }
      }
      context.restore();
    }
    function drawFlip(flip) {
      var strength = 1 - Math.abs(flip.progress);
      var foldWidth = PAGE_WIDTH * 0.5 * (1 - flip.progress);
      var foldX = PAGE_WIDTH * flip.progress + foldWidth;
      var verticalOutdent = 20 * strength;
      var paperShadowWidth = PAGE_WIDTH * 0.5 * Math.max(Math.min(1 - flip.progress, 0.5), 0);
      var rightShadowWidth = PAGE_WIDTH * 0.5 * Math.max(Math.min(strength, 0.5), 0);
      var leftShadowWidth = PAGE_WIDTH * 0.5 * Math.max(Math.min(strength, 0.5), 0);
      flip.page.style.width = Math.max(foldX, 0) + "px";
      context.save();
      context.translate(CANVAS_PADDING + BOOK_WIDTH / 2, PAGE_Y + CANVAS_PADDING);
      context.strokeStyle = (isDarkMode === "no" ? "rgba(0,0,0," : "rgba(255,255,255,") + 0.05 * strength + ")";
      context.lineWidth = 30 * strength;
      context.beginPath();
      context.moveTo(foldX - foldWidth, -verticalOutdent * 0.5);
      context.lineTo(foldX - foldWidth, PAGE_HEIGHT + verticalOutdent * 0.5);
      context.stroke();
      var rightShadowGradient = context.createLinearGradient(
        foldX,
        0,
        foldX + rightShadowWidth,
        0
      );
      rightShadowGradient.addColorStop(
        0,
        (isDarkMode === "no" ? "rgba(0,0,0," : "rgba(255,255,255,") + strength * 0.2 + ")"
      );
      rightShadowGradient.addColorStop(
        0.8,
        (isDarkMode === "no" ? "rgba(0,0,0," : "rgba(255,255,255,") + "0.0)"
      );
      context.fillStyle = rightShadowGradient;
      context.beginPath();
      context.moveTo(foldX, 0);
      context.lineTo(foldX + rightShadowWidth, 0);
      context.lineTo(foldX + rightShadowWidth, PAGE_HEIGHT);
      context.lineTo(foldX, PAGE_HEIGHT);
      context.fill();
      var leftShadowGradient = context.createLinearGradient(
        foldX - foldWidth - leftShadowWidth,
        0,
        foldX - foldWidth,
        0
      );
      leftShadowGradient.addColorStop(
        0,
        (isDarkMode === "no" ? "rgba(0,0,0," : "rgba(255,255,255,") + "0.0)"
      );
      leftShadowGradient.addColorStop(
        1,
        (isDarkMode === "no" ? "rgba(0,0,0," : "rgba(255,255,255,") + +strength * 0.15 + ")"
      );
      context.fillStyle = leftShadowGradient;
      context.beginPath();
      context.moveTo(foldX - foldWidth - leftShadowWidth, 0);
      context.lineTo(foldX - foldWidth, 0);
      context.lineTo(foldX - foldWidth, PAGE_HEIGHT);
      context.lineTo(foldX - foldWidth - leftShadowWidth, PAGE_HEIGHT);
      context.fill();
      var foldGradient = context.createLinearGradient(
        foldX - paperShadowWidth,
        0,
        foldX,
        0
      );
      if (backgroundColor) {
        foldGradient.addColorStop(0.35, backgroundColor);
        foldGradient.addColorStop(0.73, backgroundColor);
        foldGradient.addColorStop(0.9, backgroundColor);
        foldGradient.addColorStop(1, backgroundColor);
      } else if (isDarkMode === "no") {
        foldGradient.addColorStop(0.35, "#fafafa");
        foldGradient.addColorStop(0.73, "#eeeeee");
        foldGradient.addColorStop(0.9, "#fafafa");
        foldGradient.addColorStop(1, "#e2e2e2");
      } else {
        foldGradient.addColorStop(0.35, "#333");
        foldGradient.addColorStop(0.73, "#444");
        foldGradient.addColorStop(0.9, "#333");
        foldGradient.addColorStop(1, "#444");
      }
      context.fillStyle = foldGradient;
      context.strokeStyle = (isDarkMode === "no" ? "rgba(0,0,0," : "rgba(255,255,255,") + "0.06)";
      context.lineWidth = 0.5;
      context.beginPath();
      context.moveTo(foldX, 0);
      context.lineTo(foldX, PAGE_HEIGHT);
      context.quadraticCurveTo(
        foldX,
        PAGE_HEIGHT + verticalOutdent * 2,
        foldX - foldWidth,
        PAGE_HEIGHT + verticalOutdent
      );
      context.lineTo(foldX - foldWidth, -verticalOutdent);
      context.quadraticCurveTo(foldX, -verticalOutdent * 2, foldX, 0);
      context.fill();
      context.stroke();
      context.restore();
    }
    function resetFlips() {
      for (var i2 = 0; i2 < flips.length; i2++) {
        var flip = flips[i2];
        flip.dragging = false;
        if (i2 < pageNum) {
          flip.progress = -1;
          flip.target = -1;
          flip.page.style.width = "0px";
        } else {
          flip.progress = 1;
          flip.target = 1;
          flip.page.style.width = PAGE_WIDTH + "px";
        }
      }
    }
    return {
      flipToNextPage: () => {
        if (!flips.length || pageNum >= flips.length) return;
        if (pageNum + 1 < flips.length) {
          flips[pageNum].target = -1;
          pageNum = Math.min(pageNum + 1, flips.length);
        }
      },
      flipToPrevPage: () => {
        if (!flips.length || pageNum <= 0) return;
        if (pageNum - 1 >= 0 && flips[pageNum - 1]) {
          flips[pageNum - 1].target = 1;
          pageNum = Math.max(pageNum - 1, 0);
        }
      },
      setPageNum: (n) => {
        if (!flips.length) return;
        pageNum = Math.max(0, Math.min(n, flips.length - 1));
        resetFlips();
      },
      resetFlips,
      cleanup: () => {
        flipAnimating = false;
        if (flipAnimFrameId) {
          cancelAnimationFrame(flipAnimFrameId);
          flipAnimFrameId = null;
        }
        if (flipRenderTimer) {
          clearInterval(flipRenderTimer);
          flipRenderTimer = null;
        }
        const canvasEl = document.getElementById("pageflip-canvas");
        if (canvasEl) {
          canvasEl.style.willChange = "";
          canvasEl.style.transform = "";
        }
      },
      mouseDownHandler,
      mouseUpHandler,
      mouseMoveHandler
    };
  };

  // vendor/kookit/src/renders/GeneralRender.ts
  var import_rangy_core3 = __toESM(require_rangy_core(), 1);
  var import_rangy_textrange2 = __toESM(require_rangy_textrange(), 1);

  // disabled-feature:pdfUtil
  function getPDFSearchResult() {
    throw Error("PDF uses native PDFKit");
  }

  // vendor/kookit/src/utils/touchUtil.ts
  var import_rangy_core2 = __toESM(require_rangy_core(), 1);

  // vendor/kookit/src/utils/selectionAutoTurn.ts
  var AUTO_TURN_DWELL_MS = 500;
  var AUTO_TURN_CORNER_RADIUS = 50;
  var cornerOf = (x, y, w, h) => {
    if (w <= 0 || h <= 0) return null;
    const rx = AUTO_TURN_CORNER_RADIUS;
    const ry = AUTO_TURN_CORNER_RADIUS;
    const inEllipse = (dx, dy) => (dx / rx) ** 2 + (dy / ry) ** 2 <= 1;
    if (inEllipse(w - x, h - y)) return "br";
    if (inEllipse(x, y)) return "tl";
    return null;
  };
  var cornerAt = (x, y, w, h) => {
    if (w <= 0 || h <= 0) return null;
    if (x < 0 || x > w || y < 0 || y > h) return null;
    return cornerOf(x, y, w, h);
  };
  var focusCaretPos = (doc2, sel) => {
    const focusNode = sel.focusNode;
    if (!focusNode) return null;
    let rect;
    try {
      const range2 = doc2.createRange();
      const offset = focusNode.nodeType === Node.TEXT_NODE ? Math.min(sel.focusOffset, (focusNode.textContent ?? "").length) : sel.focusOffset;
      range2.setStart(focusNode, offset);
      range2.collapse(true);
      rect = range2.getBoundingClientRect();
    } catch {
      return null;
    }
    if (rect.width === 0 && rect.height === 0 && rect.left === 0 && rect.top === 0) {
      return null;
    }
    return {
      x: (rect.left + rect.right) / 2,
      y: (rect.top + rect.bottom) / 2
    };
  };
  var isValidSelection = (sel) => !!(sel && sel.toString().trim().length > 0 && sel.rangeCount > 0);
  var createSelectionAutoTurn = (options) => {
    const {
      iframe,
      doc: doc2,
      render,
      readerMode,
      format,
      enableScrollPin = false
    } = options;
    if (readerMode === "scroll" || format === "PDF") {
      return null;
    }
    let autoTurnTimer = null;
    let engagedCorner = null;
    let isAutoTurning = false;
    let pinnedScrollLeft = null;
    let pinnedScrollTop = null;
    let pointerPos = null;
    let isTextSelected = false;
    let outerTouchCleanup = null;
    let pointerOnlyUntilClear = false;
    const viewportSize = () => {
      const w = doc2.documentElement.clientWidth || doc2.body.clientWidth || iframe.clientWidth;
      const h = doc2.documentElement.clientHeight || doc2.body.clientHeight || iframe.clientHeight;
      return { w, h };
    };
    const toIframeCoords = (clientX, clientY) => {
      const iframeRect = iframe.getBoundingClientRect();
      return {
        x: clientX - iframeRect.left,
        y: clientY - iframeRect.top
      };
    };
    const pointerCornerNow = () => {
      const p = pointerPos;
      if (!p) return null;
      const { w, h } = viewportSize();
      return cornerAt(p.x, p.y, w, h);
    };
    const caretCornerNow = () => {
      const sel = doc2.getSelection();
      if (!sel || !isValidSelection(sel)) return null;
      const pos = focusCaretPos(doc2, sel);
      if (!pos) return null;
      const { w, h } = viewportSize();
      return cornerAt(pos.x, pos.y, w, h);
    };
    const activeCornerNow = () => {
      const pointerCorner = pointerCornerNow();
      if (pointerCorner) return pointerCorner;
      if (pointerOnlyUntilClear) return null;
      return caretCornerNow();
    };
    const inCorner = (c) => activeCornerNow() === c;
    const cancelAutoTurn = () => {
      engagedCorner = null;
      if (autoTurnTimer) {
        clearTimeout(autoTurnTimer);
        autoTurnTimer = null;
      }
    };
    const detachOuterTouch = () => {
      outerTouchCleanup?.();
      outerTouchCleanup = null;
    };
    const attachOuterTouch = () => {
      detachOuterTouch();
      const parentWin = iframe.ownerDocument?.defaultView;
      const iframeWin = doc2.defaultView;
      if (!parentWin && !iframeWin) return;
      const onIframeTouch = (event) => {
        if (!isTextSelected) return;
        const touch = event.touches[0];
        if (!touch) return;
        pointerPos = { x: touch.clientX, y: touch.clientY };
        noteCorner(pointerCornerNow());
      };
      const onOuterTouch = (event) => {
        if (!isTextSelected) return;
        const touch = event.touches[0];
        if (!touch) return;
        const coords = toIframeCoords(touch.clientX, touch.clientY);
        pointerPos = coords;
        noteCorner(pointerCornerNow());
      };
      const onPointer = (event) => {
        if (!isTextSelected) return;
        const coords = event.view === iframeWin ? { x: event.clientX, y: event.clientY } : toIframeCoords(event.clientX, event.clientY);
        pointerPos = coords;
        noteCorner(pointerCornerNow());
      };
      iframeWin?.addEventListener("touchmove", onIframeTouch, {
        capture: true,
        passive: true
      });
      iframeWin?.addEventListener("pointermove", onPointer, {
        capture: true,
        passive: true
      });
      parentWin?.addEventListener("touchmove", onOuterTouch, {
        capture: true,
        passive: true
      });
      if (parentWin && parentWin !== iframeWin) {
        parentWin.addEventListener("pointermove", onPointer, {
          capture: true,
          passive: true
        });
      }
      outerTouchCleanup = () => {
        iframeWin?.removeEventListener("touchmove", onIframeTouch, {
          capture: true
        });
        iframeWin?.removeEventListener("pointermove", onPointer, {
          capture: true
        });
        parentWin?.removeEventListener("touchmove", onOuterTouch, {
          capture: true
        });
        if (parentWin && parentWin !== iframeWin) {
          parentWin.removeEventListener("pointermove", onPointer, {
            capture: true
          });
        }
      };
    };
    const armDwell = (corner) => {
      if (autoTurnTimer) return;
      autoTurnTimer = setTimeout(() => {
        autoTurnTimer = null;
        const sel = doc2.getSelection();
        if (isAutoTurning || !sel || !isValidSelection(sel) || !inCorner(corner)) {
          return;
        }
        isAutoTurning = true;
        const turning = corner === "br" ? render.next() : render.prev();
        Promise.resolve(turning).finally(() => {
          pinnedScrollLeft = doc2.body.scrollLeft;
          pinnedScrollTop = doc2.body.scrollTop;
          isAutoTurning = false;
          engagedCorner = corner;
          pointerOnlyUntilClear = true;
        });
      }, AUTO_TURN_DWELL_MS);
    };
    const noteCorner = (corner) => {
      if (isAutoTurning) return;
      if (corner) {
        if (engagedCorner !== corner) {
          engagedCorner = corner;
          armDwell(corner);
        }
      } else if (engagedCorner && !inCorner(engagedCorner)) {
        engagedCorner = null;
        if (autoTurnTimer) {
          clearTimeout(autoTurnTimer);
          autoTurnTimer = null;
        }
      }
    };
    const onSelectStart = () => {
      pinnedScrollLeft = doc2.body.scrollLeft;
      pinnedScrollTop = doc2.body.scrollTop;
      pointerPos = null;
      isTextSelected = false;
      pointerOnlyUntilClear = false;
      cancelAutoTurn();
      attachOuterTouch();
    };
    const onSelectionChange = () => {
      const sel = doc2.getSelection();
      if (isValidSelection(sel)) {
        isTextSelected = true;
        if (pinnedScrollLeft === null) {
          pinnedScrollLeft = doc2.body.scrollLeft;
          pinnedScrollTop = doc2.body.scrollTop;
        }
        if (!outerTouchCleanup) {
          attachOuterTouch();
        }
        if (!pointerOnlyUntilClear) {
          noteCorner(caretCornerNow());
        }
      } else {
        onSelectionCleared();
      }
    };
    const onTouchMove = (clientX, clientY) => {
      pointerPos = { x: clientX, y: clientY };
      noteCorner(pointerCornerNow());
    };
    const onSelectionCleared = () => {
      isTextSelected = false;
      pointerOnlyUntilClear = false;
      cancelAutoTurn();
      detachOuterTouch();
      pinnedScrollLeft = null;
      pinnedScrollTop = null;
      pointerPos = null;
    };
    const applyScrollPin = () => {
      if (!enableScrollPin || !isTextSelected || isAutoTurning || pinnedScrollLeft === null) {
        return;
      }
      if (doc2.body.scrollLeft !== pinnedScrollLeft) {
        doc2.body.scrollLeft = pinnedScrollLeft;
      }
      if (pinnedScrollTop !== null && pinnedScrollTop > 0) {
        if (doc2.body.scrollTop !== pinnedScrollTop) {
          doc2.body.scrollTop = pinnedScrollTop;
        }
      }
    };
    return {
      onSelectStart,
      onSelectionChange,
      onTouchMove,
      onSelectionCleared,
      cancelAutoTurn,
      applyScrollPin,
      hasActiveSelection: () => isTextSelected
    };
  };

  // vendor/kookit/src/utils/touchUtil.ts
  var isDragging = false;
  var lastPinchZoomTime = 0;
  var pinchZoomed = false;
  var isPaginatedFormat = (format) => {
    return format === "PDF" || format && format.startsWith("CB");
  };
  var onPinchZoomEnd = function(event, render, format) {
    if (!pinchZoomed) return;
    pinchZoomed = false;
    if (format !== "PDF") return;
    if (window.visualViewport.scale <= 1.01) return;
    let now = Date.now();
    if (now - lastPinchZoomTime < 1e3) return;
    lastPinchZoomTime = now;
    let target = event.target;
    let ownerDoc = target.ownerDocument;
    let targetIframe = ownerDoc?.defaultView?.frameElement;
    let id = targetIframe?.getAttribute("id") || "";
    let chapterDocIndex = id ? parseInt(id.split("-").reverse()[0]) : 0;
    window.ReactNativeWebView.postMessage(
      JSON.stringify({
        event: "pinch-zoom",
        chapterDocIndex,
        scale: window.visualViewport.scale
      })
    );
    render.handleRenderPDFChapter(chapterDocIndex, true);
  };
  var slideAnimateTo = (direction, format, doc2, outerDoc, element, render, gap) => {
    let pageWidth = element.clientWidth + gap;
    let tempDoc = isPaginatedFormat(format) ? outerDoc : doc2;
    isDragging = false;
    if (window.scrollAnimationId) {
      cancelAnimationFrame(window.scrollAnimationId);
      window.scrollAnimationId = null;
    }
    if (Math.abs(
      tempDoc.body.scrollWidth - tempDoc.body.scrollLeft - element.clientWidth
    ) < 10 && direction === "right") {
      render.next();
      return;
    }
    if (tempDoc.body.scrollLeft === 0 && direction === "left") {
      render.prev();
      return;
    }
    let scrollLeft = tempDoc.body.scrollLeft;
    let snapX;
    const currentPage = Math.round(scrollLeft / pageWidth);
    if (direction === "left") {
      snapX = (currentPage - 1) * pageWidth;
    } else if (direction === "right") {
      snapX = (currentPage + 1) * pageWidth;
    } else {
      snapX = currentPage * pageWidth;
    }
    const maxScroll = tempDoc.body.scrollWidth - element.clientWidth;
    if (snapX >= maxScroll || tempDoc.body.scrollWidth - snapX < pageWidth + gap) {
      snapX = maxScroll;
    }
    snapX = Math.max(0, snapX);
    const startLeft = tempDoc.body.scrollLeft;
    const distance = snapX - startLeft;
    if (Math.abs(distance) < 0.5) {
      render.record();
      return;
    }
    const duration = 250;
    const body = tempDoc.body;
    const docElement = tempDoc.documentElement;
    window.isSwiping = true;
    docElement.style.willChange = "transform";
    docElement.style.transform = "translateX(0px)";
    docElement.style.transition = "none";
    docElement.getBoundingClientRect();
    docElement.style.transition = `transform ${duration}ms cubic-bezier(0.25, 0.46, 0.45, 0.94)`;
    docElement.style.transform = `translateX(${-distance}px)`;
    let resolved = false;
    const cleanup = () => {
      if (resolved) return;
      resolved = true;
      docElement.style.willChange = "";
      docElement.style.transform = "";
      docElement.style.transition = "";
      body.scrollLeft = snapX;
      if (Math.abs(body.scrollLeft - snapX) > 0.5) {
        requestAnimationFrame(() => {
          body.scrollLeft = snapX;
          render.record();
          isDragging = false;
          window.isSwiping = false;
        });
        return;
      }
      render.record();
      isDragging = false;
      window.isSwiping = false;
    };
    const onTransitionEnd = (e) => {
      if (e.target === docElement && e.propertyName === "transform") {
        docElement.removeEventListener("transitionend", onTransitionEnd);
        cleanup();
      }
    };
    docElement.addEventListener("transitionend", onTransitionEnd);
    window.scrollAnimationId = setTimeout(cleanup, duration + 50);
  };
  async function blobUrlToBase64(blobUrl) {
    try {
      const response = await fetch(blobUrl);
      const blob = await response.blob();
      const base64 = await new Promise((resolve, reject2) => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(reader.result);
        reader.onerror = reject2;
        reader.readAsDataURL(blob);
      });
      return base64;
    } catch (error) {
      console.error("\u8F6C\u6362\u5931\u8D25:", error);
      throw error;
    }
  }
  function getScreenLeftOffset() {
    if (window.visualViewport) {
      return window.visualViewport.offsetLeft;
    } else {
      return window.pageXOffset || document.documentElement.scrollLeft || 0;
    }
  }
  function getScreenTopOffset() {
    if (window.visualViewport) {
      return window.visualViewport.offsetTop;
    } else {
      return window.pageYOffset || document.documentElement.scrollTop || 0;
    }
  }
  var preventLinkNavigation = async (event, doc2, render) => {
    const target = event.target;
    if (!target) return;
    let href = render.getTargetHref(event);
    if (!href) return;
    event.preventDefault();
    event.stopPropagation();
    let beforeLocation = { ...render.getPosition() };
    let result2 = await render.handleLinkJump(href, event);
    if (!result2.handled) {
      return false;
    }
    if (result2.external) {
      window.ReactNativeWebView.postMessage(
        JSON.stringify({
          event: "link-clicked",
          href,
          footnote: "",
          ...result2
        })
      );
      return true;
    }
    if (result2.redirectChapter) {
      window.ReactNativeWebView.postMessage(
        JSON.stringify({
          event: "link-clicked",
          bookLocation: beforeLocation,
          ...result2
        })
      );
      return true;
    }
    if (!result2.node) {
      return true;
    }
    let footnoteResult = await render.getFootnoteContent(result2.node);
    window.ReactNativeWebView.postMessage(
      JSON.stringify({
        event: "link-clicked",
        href,
        footnote: !footnoteResult.handled ? "" : footnoteResult.content,
        rect: event.target.getBoundingClientRect(),
        ...result2
      })
    );
    return true;
  };
  function findLinkElement(element) {
    if (element.tagName === "A") {
      return element;
    }
    let currentElement = element;
    while (currentElement && currentElement.tagName !== "BODY") {
      if (currentElement.tagName === "A") {
        return currentElement;
      }
      currentElement = currentElement.parentElement;
    }
    return null;
  }
  function getTouchAction(col, row, touchControlRule) {
    const areaIndex = row * 3 + col + 1;
    if (touchControlRule.layout["A"].area.includes(areaIndex)) {
      return touchControlRule["touchControlA"];
    } else if (touchControlRule.layout["B"].area.includes(areaIndex)) {
      return touchControlRule["touchControlB"];
    } else if (touchControlRule.layout["C"].area.includes(areaIndex)) {
      return touchControlRule["touchControlC"];
    }
    return "right";
  }
  var getSelectionSentence = (doc2) => {
    let sel = doc2.getSelection();
    if (!sel || !sel.toString().trim()) return "";
    try {
      let range2 = sel.getRangeAt(0);
      let container = range2.commonAncestorContainer;
      let el = container.nodeType === Node.TEXT_NODE ? container.parentElement : container;
      let fullText = el?.textContent || "";
      let selectedText = sel.toString().trim();
      let sentences = fullText.match(/[^.!?。！？]*[.!?。！？]?/g)?.filter((s) => s.length > 0) ?? [];
      for (let s of sentences) {
        if (s.includes(selectedText)) {
          return s.trim();
        }
      }
      return fullText.trim().substring(0, 200);
    } catch {
    }
    return "";
  };
  var addAndroidTouchEvent = (doc2, iframe, element, readerMode, animation, format, touchControlRule, render) => {
    let iWin = iframe.contentWindow || iframe.contentDocument?.defaultView;
    let outerDoc = render.getDocument();
    let touchStartTime = 0;
    let touchStartX = 0;
    let touchStartY = 0;
    let lastTouchEnd = 0;
    const swipeThreshold = 30;
    const timeThreshold = 500;
    let section = Math.floor(element.clientWidth / 12);
    let gap = section % 2 === 0 ? section : section - 1;
    let pageWidth = element.clientWidth + gap;
    const selectionAutoTurn = createSelectionAutoTurn({
      element,
      iframe,
      doc: doc2,
      render,
      readerMode,
      format,
      enableScrollPin: true
    });
    let onTouchEnd = function(event) {
      window.isSwiping = false;
      doc2.body.style.transform = "";
      let now = (/* @__PURE__ */ new Date()).getTime();
      if (now - lastTouchEnd <= 300) {
        event.preventDefault();
        if (render.isParagraphMode !== "yes" && render.isSpeedReading !== "yes" && render.isReadingRuler !== "yes") {
          return;
        }
      }
      lastTouchEnd = now;
      onPinchZoomEnd(event, render, format);
      const touch = event.changedTouches[0];
      const touchEndTime = Date.now();
      let touchEndX = touch.screenX;
      let touchEndY = touch.screenY;
      const timeDiff = touchEndTime - touchStartTime;
      const distX = touchEndX - touchStartX;
      const distY = touchEndY - touchStartY;
      if (isDragging && (animation === "mimical" || animation === "none") && readerMode !== "scroll") {
        isDragging = false;
        render.mouseUpHandler(event);
        if (touch.screenX < window.innerWidth / 4 * 3 && touchEndX - touchStartX < 0) {
          render.next();
          isDragging = false;
        } else if (touch.screenX > window.innerWidth / 4 * 1 && touchEndX - touchStartX > 0) {
          render.prev();
          isDragging = false;
        }
        setTimeout(() => {
          let bookDiv = document.getElementById("book");
          if (bookDiv) {
            bookDiv.style.display = "none";
          }
        }, 400);
        return;
      }
      if (isDragging && animation === "sliding" && readerMode !== "scroll") {
        const dragPercentage = Math.abs(distX) / window.innerWidth;
        const dragThreshold = 0.1;
        if (distX > 0 && dragPercentage > dragThreshold) {
          slideAnimateTo("left", format, doc2, outerDoc, element, render, gap);
        } else if (distX < 0 && dragPercentage > dragThreshold) {
          slideAnimateTo("right", format, doc2, outerDoc, element, render, gap);
        } else {
          slideAnimateTo("stay", format, doc2, outerDoc, element, render, gap);
        }
        return;
      }
      var selectedText = iWin.getSelection().toString();
      var isSwiping = Math.abs(distX) >= swipeThreshold || Math.abs(distY) >= swipeThreshold;
      if (selectedText && (!isPaginatedFormat(format) || !isSwiping)) {
        window.ReactNativeWebView.postMessage(
          JSON.stringify({
            event: "select-text-after-touch",
            selectedText
          })
        );
        return;
      }
      if (!selectedText) {
        selectionAutoTurn?.onSelectionCleared();
      }
      if (timeDiff > timeThreshold) {
        const target = event.target;
        if (!target) return;
        let linkElement = findLinkElement(target);
        if (linkElement) {
          return;
        }
        if (target.tagName === "IMG" || target.tagName === "image") {
          const imgSrc = target.src || target.getAttribute("xlink:href");
          if (imgSrc.startsWith("blob:")) {
            blobUrlToBase64(imgSrc).then((base64) => {
              window.ReactNativeWebView.postMessage(
                JSON.stringify({ event: "view-image", imgSrc: base64 })
              );
            });
          }
          return;
        }
      }
      if (timeDiff < timeThreshold && Math.abs(distX) < swipeThreshold && Math.abs(distY) < swipeThreshold) {
        var width = window.innerWidth;
        var height = window.innerHeight;
        var cellWidth = width / 3;
        var cellHeight = height / 3;
        var col = Math.floor(touchEndX / cellWidth);
        var row = Math.floor(touchEndY / cellHeight);
        var result2 = getTouchAction(col, row, touchControlRule);
        if (render.isParagraphMode === "yes" || render.isSpeedReading === "yes" || render.isReadingRuler === "yes") {
          if (result2 === "right") {
            render.next();
            return;
          } else if (result2 === "left") {
            render.prev();
            return;
          }
        }
        if (animation === "sliding" && readerMode !== "scroll") {
          if (result2 === "right") {
            slideAnimateTo("right", format, doc2, outerDoc, element, render, gap);
            return;
          } else if (result2 === "left") {
            slideAnimateTo("left", format, doc2, outerDoc, element, render, gap);
            return;
          }
        }
        window.ReactNativeWebView.postMessage(JSON.stringify({ event: result2 }));
      } else if (Math.abs(distX) >= swipeThreshold || Math.abs(distY) >= swipeThreshold) {
        window.ReactNativeWebView.postMessage(JSON.stringify({ event: "swipe" }));
        if (readerMode === "scroll" && Math.abs(
          element.scrollHeight - element.scrollTop - element.clientHeight
        ) < 10) {
          window.ReactNativeWebView.postMessage(
            JSON.stringify({ event: "scroll-bottom" })
          );
        }
        if (readerMode === "scroll" && element.scrollTop === 0) {
          window.ReactNativeWebView.postMessage(
            JSON.stringify({ event: "scroll-top" })
          );
        }
      }
    };
    let onTouchStart = function(event) {
      touchStartTime = Date.now();
      const target = event.target;
      if (!target) return;
      const linkElement = findLinkElement(target);
      if (linkElement) {
        return;
      }
      if (event.touches.length > 1) {
        event.preventDefault();
        pinchZoomed = true;
      }
      const touch = event.touches[0];
      touchStartX = touch.screenX;
      touchStartY = touch.screenY;
    };
    let lastTouchX = 0;
    let onTouchMove = function(event) {
      const selectedText = iWin.getSelection().toString().trim();
      if (selectedText) {
        const touch2 = event.touches[0];
        selectionAutoTurn?.onTouchMove(touch2.clientX, touch2.clientY);
        return;
      }
      if (!isDragging && Math.abs(event.touches[0].screenX - touchStartX) <= 10) {
        return;
      }
      event.preventDefault();
      if (window.visualViewport.scale > 1 && isPaginatedFormat(format)) {
        event.preventDefault();
        return;
      }
      const touch = event.touches[0];
      const touchCurrentX = touch.screenX;
      const touchCurrentY = touch.screenY;
      const distX = touchCurrentX - touchStartX;
      const distY = touchCurrentY - touchStartY;
      if (Math.abs(distX) > 10 || Math.abs(distY) > 10) {
        window.isSwiping = true;
      }
      if (!isDragging && Math.abs(distX) > Math.abs(distY) && Math.abs(distX) > 10) {
        isDragging = true;
        lastTouchX = touchCurrentX;
        doc2.body.style.transform = "translateZ(0)";
        if (animation === "mimical" && readerMode !== "scroll") {
          let bookDiv = document.getElementById("book");
          if (bookDiv) {
            bookDiv.style.display = "block";
            render.mouseDownHandler(event);
          }
        }
        return;
      }
      if (isDragging && animation === "mimical" && readerMode !== "scroll") {
        render.mouseMoveHandler(event);
      }
      if (isDragging && animation === "sliding" && readerMode !== "scroll") {
        let tempDoc = isPaginatedFormat(format) ? outerDoc : doc2;
        const deltaX = touchCurrentX - lastTouchX;
        const currentScrollLeft = tempDoc.body.scrollLeft;
        tempDoc.body.scrollLeft = currentScrollLeft - deltaX;
        lastTouchX = touchCurrentX;
        requestAnimationFrame(() => {
        });
      }
    };
    doc2.addEventListener("touchend", onTouchEnd, false);
    doc2.addEventListener("touchstart", onTouchStart, false);
    doc2.addEventListener("touchmove", onTouchMove, false);
    doc2.addEventListener(
      "pointermove",
      (event) => {
        if (!iWin.getSelection().toString().trim()) return;
        selectionAutoTurn?.onTouchMove(event.clientX, event.clientY);
      },
      { passive: true }
    );
    doc2.addEventListener(
      "click",
      (event) => {
        preventLinkNavigation(event, doc2, render);
      },
      true
    );
    let startSelectionTime = 0;
    let selectionCount = 0;
    let triggerSelectionMenu = async (event) => {
      const selectedText = iWin.getSelection().toString().trim();
      if (selectedText) {
        var range2 = iWin.getSelection().getRangeAt(0);
        let pageSize = render.getPageSize();
        var rect = range2.getBoundingClientRect();
        if (format === "PDF") {
          let clientRects = range2.getClientRects();
          if (clientRects.length > 0) {
            clientRects = Array.from(clientRects).filter((item) => {
              return Math.abs(item.height - pageSize.sectionHeight) > 10 && Math.abs(item.width - pageSize.sectionWidth) > 10 && item.height > 0 && item.width > 0;
            });
            let minTop = Infinity;
            let minLeft = Infinity;
            let maxBottom = -Infinity;
            let maxRight = -Infinity;
            for (let i = 0; i < clientRects.length; i++) {
              const rect2 = clientRects[i];
              minTop = Math.min(minTop, rect2.top);
              minLeft = Math.min(minLeft, rect2.left);
              maxBottom = Math.max(maxBottom, rect2.bottom);
              maxRight = Math.max(maxRight, rect2.right);
            }
            const combinedRect = {
              top: minTop,
              left: minLeft,
              bottom: maxBottom,
              right: maxRight,
              width: maxRight - minLeft,
              height: maxBottom - minTop
            };
            rect = combinedRect;
          }
        }
        var position = {
          top: rect.top - element.scrollTop,
          left: rect.left,
          width: rect.width,
          height: rect.height,
          screenWidth: window.innerWidth,
          screenHeight: window.innerHeight,
          sectionHeight: pageSize.sectionHeight,
          sectionWidth: pageSize.sectionWidth,
          gap: pageSize.gap,
          scale: window.visualViewport.scale,
          offsetLeft,
          offsetTop
        };
        import_rangy_core2.default.init();
        let charRange = null;
        if (format === "PDF") {
          try {
            let target = event.target;
            let targetIframe = target.ownerDocument?.defaultView?.frameElement;
            let id = targetIframe?.getAttribute("id") || "";
            let chapterDocIndex = id ? parseInt(id.split("-").reverse()[0]) : 0;
            charRange = await render.getHighlightCoords(chapterDocIndex);
            position.chapterDocIndex = chapterDocIndex + "";
            let subContainer = targetIframe.parentElement;
            if (subContainer) {
              position.top = position.top + parseFloat(subContainer.getBoundingClientRect().top);
            }
          } catch (error) {
            console.error("Error getting highlight coords:", error);
          }
        } else {
          charRange = await render.getHighlightCoords();
        }
        let sentence = getSelectionSentence(doc2);
        window.ReactNativeWebView.postMessage(
          JSON.stringify({
            event: "select-text",
            selectedText,
            sentence,
            position,
            range: charRange
          })
        );
      }
    };
    doc2.body.oncontextmenu = function(event) {
      const target = event.target;
      if (!target) return;
      let linkElement = findLinkElement(target);
      if (linkElement) {
        return;
      }
      if (target.tagName === "IMG" || target.tagName === "image") {
        const imgSrc = target.src || target.getAttribute("xlink:href");
        if (imgSrc.startsWith("blob:")) {
          blobUrlToBase64(imgSrc).then((base64) => {
            window.ReactNativeWebView.postMessage(
              JSON.stringify({ event: "view-image", imgSrc: base64 })
            );
          });
        }
        return;
      }
      if (Date.now() - startSelectionTime < 100) {
        setTimeout(() => {
          if (selectionCount === 1) {
            triggerSelectionMenu(event);
          }
        }, 600);
      } else {
        triggerSelectionMenu(event);
      }
      event.preventDefault();
      event.stopPropagation();
      return false;
    };
    let scrollLeft = 0;
    let scrollTop = 0;
    let offsetLeft = 0;
    let offsetTop = 0;
    doc2.addEventListener(
      "selectstart",
      (event) => {
        selectionCount = 0;
        startSelectionTime = Date.now();
        offsetLeft = getScreenLeftOffset();
        offsetTop = getScreenTopOffset();
        if (readerMode === "scroll") return;
        selectionAutoTurn?.onSelectStart();
        if (format === "PDF") {
          scrollLeft = doc2.body.scrollLeft;
          scrollTop = doc2.body.scrollTop;
        }
      },
      false
    );
    let lastSelectionChangeTime = 0;
    const SELECTION_THROTTLE_DELAY = 3e3;
    let selectionMenuTimer = null;
    doc2.addEventListener(
      "selectionchange",
      (event) => {
        if (format !== "PDF") {
          if (selectionMenuTimer) {
            clearTimeout(selectionMenuTimer);
          }
          selectionMenuTimer = setTimeout(() => {
            triggerSelectionMenu(event);
            selectionMenuTimer = null;
          }, 1e3);
        }
        const selectedText = iWin.getSelection().toString().trim();
        if (!selectedText) {
          selectionAutoTurn?.onSelectionCleared();
          return;
        }
        if (selectionAutoTurn) {
          selectionAutoTurn.onSelectionChange();
        } else {
          if (scrollLeft > 0) {
            doc2.body.scrollLeft = scrollLeft;
          }
          if (scrollTop > 0) {
            doc2.body.scrollTop = scrollTop;
          }
        }
        selectionCount++;
        const now = Date.now();
        if (now - lastSelectionChangeTime >= SELECTION_THROTTLE_DELAY) {
          lastSelectionChangeTime = now;
          window.ReactNativeWebView.postMessage(
            JSON.stringify({ event: "selection-change" })
          );
        }
      },
      false
    );
    doc2.addEventListener("scroll", () => {
      if (readerMode === "single" || readerMode === "double") {
        if (selectionAutoTurn) {
          selectionAutoTurn.applyScrollPin();
        } else {
          const selectedText = iWin.getSelection().toString().trim();
          if (selectedText && scrollLeft > 0) {
            doc2.body.scrollLeft = scrollLeft;
          }
          if (selectedText && scrollTop > 0) {
            doc2.body.scrollTop = scrollTop;
          }
        }
      }
    });
  };
  var addAppleTouchEvent = (doc2, iframe, element, readerMode, animation, format, touchControlRules, render) => {
    let iWin = iframe.contentWindow || iframe.contentDocument?.defaultView;
    let outerDoc = render.getDocument();
    let touchStartTime = 0;
    let touchStartX = 0;
    let touchStartY = 0;
    let lastTouchEnd = 0;
    let lastSelectEnd = 0;
    let swipeThreshold = 30;
    const timeThreshold = 500;
    let section = Math.floor(element.clientWidth / 12);
    let gap = section % 2 === 0 ? section : section - 1;
    const selectionAutoTurn = createSelectionAutoTurn({
      element,
      iframe,
      doc: doc2,
      render,
      readerMode,
      format,
      enableScrollPin: false
    });
    let onTouchEnd = async function(event) {
      window.isSwiping = false;
      let now = (/* @__PURE__ */ new Date()).getTime();
      if (now - lastTouchEnd <= 300) {
        event.preventDefault();
        if (render.isParagraphMode !== "yes" && render.isSpeedReading !== "yes" && render.isReadingRuler !== "yes") {
          return;
        }
      }
      lastTouchEnd = now;
      const touch = event.changedTouches[0];
      const touchEndTime = Date.now();
      const touchEndX = touch.screenX;
      const touchEndY = touch.screenY;
      const timeDiff = touchEndTime - touchStartTime;
      const distX = touchEndX - touchStartX;
      const distY = touchEndY - touchStartY;
      if (isDragging && (animation === "mimical" || animation === "none") && readerMode !== "scroll") {
        isDragging = false;
        render.mouseUpHandler(event);
        if (touchEndX < window.innerWidth / 4 * 3 && touchEndX - touchStartX < 0) {
          render.next();
          isDragging = false;
        } else if (touchEndX > window.innerWidth / 4 * 1 && touchEndX - touchStartX > 0) {
          render.prev();
          isDragging = false;
        }
        setTimeout(() => {
          let bookDiv = document.getElementById("book");
          if (bookDiv) {
            bookDiv.style.display = "none";
          }
        }, 400);
        return;
      }
      if (isDragging && animation === "sliding" && readerMode !== "scroll") {
        const dragPercentage = Math.abs(distX) / window.innerWidth;
        const dragThreshold = 0.1;
        if (distX > 0 && dragPercentage > dragThreshold) {
          slideAnimateTo("left", format, doc2, outerDoc, element, render, gap);
        } else if (distX < 0 && dragPercentage > dragThreshold) {
          slideAnimateTo("right", format, doc2, outerDoc, element, render, gap);
        } else {
          slideAnimateTo("stay", format, doc2, outerDoc, element, render, gap);
        }
        return;
      }
      const selectedText = iWin.getSelection().toString().trim();
      if (selectedText) {
        var range2 = iWin.getSelection().getRangeAt(0);
        var rect = range2.getBoundingClientRect();
        var pageSize = render.getPageSize();
        var position = {
          top: rect.top - element.scrollTop,
          left: rect.left,
          width: rect.width,
          height: rect.height,
          screenWidth: window.innerWidth,
          screenHeight: window.innerHeight,
          sectionHeight: pageSize.sectionHeight,
          sectionWidth: pageSize.sectionWidth,
          gap: pageSize.gap,
          scale: window.visualViewport.scale,
          offsetLeft: getScreenLeftOffset(),
          offsetTop: getScreenTopOffset()
        };
        import_rangy_core2.default.init();
        let charRange = null;
        if (format === "PDF") {
          let target = event.target;
          let ownerDoc = target.ownerDocument;
          let targetIframe = ownerDoc?.defaultView?.frameElement;
          let id = targetIframe?.getAttribute("id") || "";
          let chapterDocIndex = id ? parseInt(id.split("-").reverse()[0]) : 0;
          position.chapterDocIndex = chapterDocIndex + "";
          charRange = await render.getHighlightCoords(chapterDocIndex);
          let subContainer = targetIframe.parentElement;
          if (subContainer) {
            position.top = position.top + parseFloat(subContainer.getBoundingClientRect().top);
          }
        } else {
          charRange = await render.getHighlightCoords();
        }
        let sentence = getSelectionSentence(doc2);
        window.ReactNativeWebView.postMessage(
          JSON.stringify({
            event: "select-text",
            selectedText,
            sentence,
            position,
            range: charRange
          })
        );
        return;
      }
      if (!selectedText) {
        selectionAutoTurn?.onSelectionCleared();
      }
      if (timeDiff > timeThreshold) {
        const target = event.target;
        if (!target) return;
        let linkElement = findLinkElement(target);
        if (linkElement) {
          return;
        }
        if (target.tagName === "IMG" || target.tagName === "image") {
          const imgSrc = target.src || target.getAttribute("xlink:href");
          if (imgSrc.startsWith("blob:")) {
            blobUrlToBase64(imgSrc).then((base64) => {
              window.ReactNativeWebView.postMessage(
                JSON.stringify({ event: "view-image", imgSrc: base64 })
              );
            });
          }
          return;
        }
      }
      if (timeDiff < timeThreshold && Math.abs(distX) < swipeThreshold && Math.abs(distY) < swipeThreshold) {
        const width = document.documentElement.clientWidth;
        const height = document.documentElement.clientHeight;
        let normalizedX = Math.min(Math.max(touchEndX, 0), width);
        let normalizedY = Math.min(Math.max(touchEndY, 0), height);
        if (isPaginatedFormat(format) && readerMode === "double") {
          let target = event.target;
          let ownerDoc = target.ownerDocument;
          let targetIframe = ownerDoc?.defaultView?.frameElement;
          let id = targetIframe?.getAttribute("id") || "";
          let chapterDocIndex = id ? parseInt(id.split("-").reverse()[0]) : 0;
          if (chapterDocIndex % 2 === 1) {
            normalizedX = normalizedX + width / 2;
          }
        }
        const cellWidth = width / 3;
        const cellHeight = height / 3;
        const col = Math.min(Math.floor(normalizedX / cellWidth), 2);
        const row = Math.min(Math.floor(normalizedY / cellHeight), 2);
        let result2 = getTouchAction(col, row, touchControlRules);
        if (render.isParagraphMode === "yes" || render.isSpeedReading === "yes" || render.isReadingRuler === "yes") {
          if (result2 === "right") {
            render.next();
            return;
          } else if (result2 === "left") {
            render.prev();
            return;
          }
        }
        if (animation === "sliding" && readerMode !== "scroll") {
          if (result2 === "right") {
            slideAnimateTo("right", format, doc2, outerDoc, element, render, gap);
            return;
          } else if (result2 === "left") {
            slideAnimateTo("left", format, doc2, outerDoc, element, render, gap);
            return;
          }
        }
        window.ReactNativeWebView.postMessage(JSON.stringify({ event: result2 }));
      } else if (Math.abs(distX) >= swipeThreshold || Math.abs(distY) >= swipeThreshold) {
        window.ReactNativeWebView.postMessage(
          JSON.stringify({
            event: "swipe"
          })
        );
        if (readerMode === "scroll" && Math.abs(
          element.scrollHeight - element.scrollTop - element.clientHeight
        ) < 10) {
          window.ReactNativeWebView.postMessage(
            JSON.stringify({ event: "scroll-bottom" })
          );
        }
        if (readerMode === "scroll" && element.scrollTop === 0) {
          window.ReactNativeWebView.postMessage(
            JSON.stringify({ event: "scroll-top" })
          );
        }
      }
    };
    let onTouchStart = function(event) {
      const target = event.target;
      if (!target) return;
      const linkElement = findLinkElement(target);
      if (linkElement) {
        return;
      }
      if (event.touches.length > 1) {
        pinchZoomed = true;
      }
      const touch = event.touches[0];
      touchStartTime = Date.now();
      touchStartX = touch.screenX;
      touchStartY = touch.screenY;
    };
    let lastTouchX = 0;
    let onTouchMove = function(event) {
      const selectedText = iWin.getSelection().toString().trim();
      if (selectedText) {
        const touch2 = event.touches[0];
        selectionAutoTurn?.onTouchMove(touch2.clientX, touch2.clientY);
        return;
      }
      if (!isDragging && Math.abs(event.touches[0].screenX - touchStartX) <= 10) {
        return;
      }
      if (window.visualViewport.scale > 1 && isPaginatedFormat(format)) {
        return;
      }
      if (readerMode !== "scroll") {
        event.preventDefault();
      }
      const touch = event.touches[0];
      const touchCurrentX = touch.screenX;
      const touchCurrentY = touch.screenY;
      const distX = touchCurrentX - touchStartX;
      const distY = touchCurrentY - touchStartY;
      if (!isDragging && Math.abs(distX) > Math.abs(distY) && Math.abs(distX) > 10) {
        isDragging = true;
        lastTouchX = touchCurrentX;
        if (animation === "mimical" && readerMode !== "scroll") {
          window.isSwiping = true;
          let bookDiv = document.getElementById("book");
          if (bookDiv) {
            bookDiv.style.display = "block";
            render.mouseDownHandler(event);
          }
        }
        return;
      }
      if (isDragging && animation === "mimical" && readerMode !== "scroll") {
        render.mouseMoveHandler(event);
      }
      if (isDragging && animation === "sliding" && readerMode !== "scroll") {
        window.isSwiping = true;
        let tempDoc = isPaginatedFormat(format) ? outerDoc : doc2;
        const deltaX = touchCurrentX - lastTouchX;
        const currentScrollLeft = tempDoc.body.scrollLeft;
        tempDoc.body.scrollLeft = currentScrollLeft - deltaX;
        lastTouchX = touchCurrentX;
        requestAnimationFrame(() => {
        });
      }
    };
    doc2.addEventListener("touchend", onTouchEnd, { passive: false });
    doc2.addEventListener("touchstart", onTouchStart, { passive: false });
    doc2.addEventListener("touchmove", onTouchMove, { passive: false });
    doc2.addEventListener(
      "pointermove",
      (event) => {
        if (!iWin.getSelection().toString().trim()) return;
        selectionAutoTurn?.onTouchMove(event.clientX, event.clientY);
      },
      { passive: true }
    );
    doc2.addEventListener(
      "click",
      (event) => {
        preventLinkNavigation(event, doc2, render);
      },
      true
    );
    doc2.body.oncontextmenu = function(event) {
      event.preventDefault();
      event.stopPropagation();
      return false;
    };
    doc2.addEventListener(
      "selectstart",
      () => {
        if (readerMode === "scroll") return;
        selectionAutoTurn?.onSelectStart();
      },
      false
    );
    let lastSelectionChangeTime = 0;
    const SELECTION_THROTTLE_DELAY = 3e3;
    doc2.addEventListener(
      "selectionchange",
      (event) => {
        const selectedText = iWin.getSelection().toString().trim();
        if (!selectedText) {
          selectionAutoTurn?.onSelectionCleared();
          return;
        }
        selectionAutoTurn?.onSelectionChange();
        const now = Date.now();
        if (now - lastSelectionChangeTime >= SELECTION_THROTTLE_DELAY) {
          lastSelectionChangeTime = now;
          window.ReactNativeWebView.postMessage(
            JSON.stringify({ event: "selection-change" })
          );
        }
      },
      { passive: false }
    );
  };

  // vendor/kookit/src/utils/speedReadingUtil.ts
  var NO_SPACE_SCRIPT_REGEX = /[\u3000-\u303f\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff00-\uff9f\u0e00-\u0e7f\u0e80-\u0eff\u1000-\u109f\u1780-\u17ff]/;
  var segmenterCache = {};
  var getWordSegmenter = (lang) => {
    if (typeof Intl.Segmenter === "undefined") return null;
    const key = lang || "default";
    if (!segmenterCache[key]) {
      segmenterCache[key] = new Intl.Segmenter(lang || void 0, {
        granularity: "word"
      });
    }
    return segmenterCache[key];
  };
  var isNoSpaceScript = (text) => {
    if (!text) return false;
    return NO_SPACE_SCRIPT_REGEX.test(text);
  };
  var isPunctuationOnly = (word) => /^[^\w\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uac00-\ud7af\u1100-\u11ff\u3130-\u318f\u0e01-\u0e3a\u0e40-\u0e4e\u0e50-\u0e59\u0e80-\u0eff\u1000-\u109f\u1780-\u17b3\u17e0-\u17e9\uff10-\uff19\uff21-\uff3a\uff41-\uff5a]+$/.test(
    word
  );
  var mergePunctuationToPrevWord = (words) => {
    const merged = [];
    for (const word of words) {
      if (merged.length > 0 && isPunctuationOnly(word)) {
        merged[merged.length - 1] += word;
      } else {
        merged.push(word);
      }
    }
    return merged;
  };
  var segmentSpeedReadingWords = (text) => {
    if (!text || !text.trim()) return [];
    if (isNoSpaceScript(text)) {
      const segmenter = getWordSegmenter();
      if (segmenter) {
        const words = Array.from(segmenter.segment(text)).map((segment) => segment.segment).filter((segment) => segment.trim().length > 0);
        return mergePunctuationToPrevWord(words);
      }
      return mergePunctuationToPrevWord(
        Array.from(text).filter((char) => char.trim().length > 0)
      );
    }
    return text.split(/\s+/).filter((word) => word.length > 0);
  };
  var getSpeedReadingORPIndex = (word) => {
    const length = Array.from(word).length;
    if (length <= 3) return 0;
    if (length <= 6) return 1;
    if (length <= 9) return 2;
    if (length <= 13) return 3;
    return 4;
  };
  var getSpeedReadingWordDelay = (word, wpm) => {
    const base = 6e4 / Math.max(1, wpm);
    const token = word.trim();
    const length = Array.from(token).length;
    let factor = 1;
    if (length >= 13) {
      factor = 1.8;
    } else if (length >= 9) {
      factor = 1.5;
    } else if (length >= 6) {
      factor = 1.2;
    }
    if (token && /^[.!?。！？；：…，,、()]$/.test(token)) {
      factor = 2.5;
    } else if (/[.!?。！？…]["'」』）)]?$/.test(token)) {
      factor = Math.max(factor, 2);
    } else if (/[,，、;；:]["'」』）)]?$/.test(token)) {
      factor = Math.max(factor, 1.5);
    }
    return Math.round(base * factor);
  };
  var PIVOT_COLOR = "#ff3b30";
  var COUNTDOWN_COLOR = "#77A1D9";
  var SpeedReadingManager = class {
    // 配置与运行时状态
    isSpeedReading = "no";
    speedReadingSpeed = 300;
    isDarkMode = "no";
    readerMode = "single";
    words = [];
    index = 0;
    timer = null;
    countdownTimer = null;
    playing = false;
    autoStarted = false;
    hasStartedOnce = false;
    overlayEl = null;
    skipFlip = false;
    // 由 GeneralRender 注入的回调，与渲染实例解耦
    getDoc = () => null;
    getElement = () => ({});
    getOverlayBackground = () => "#ffffff";
    getProgress = () => null;
    getChapterDocIndex = () => "0";
    nextPage = async () => {
    };
    prevPage = async () => {
    };
    constructor(config = {}) {
      this.isSpeedReading = config.isSpeedReading || "no";
      this.speedReadingSpeed = config.speedReadingSpeed || 300;
      this.isDarkMode = config.isDarkMode || "no";
      this.readerMode = config.readerMode || "single";
    }
    applyConfig(config = {}) {
      if (config.isSpeedReading != null) {
        this.isSpeedReading = config.isSpeedReading;
      }
      if (config.speedReadingSpeed != null) {
        this.speedReadingSpeed = config.speedReadingSpeed;
      }
      if (config.isDarkMode != null) {
        this.isDarkMode = config.isDarkMode;
      }
    }
    isSpeedReadingActive() {
      return this.isSpeedReading === "yes";
    }
    extractWords() {
      let doc2 = this.getDoc();
      let element = this.getElement();
      if (!doc2 || !doc2.body || !element) return [];
      let texts = getVisibleText(element, this.readerMode, doc2);
      let words = [];
      for (let index = 0; index < texts.length; index++) {
        words = words.concat(segmentSpeedReadingWords(texts[index]));
      }
      return words;
    }
    getPageHeight() {
      let element = this.getElement();
      return element && element.clientHeight || 600;
    }
    getWordFontSize() {
      return Math.max(28, Math.min(72, Math.round(this.getPageHeight() * 0.06)));
    }
    getTextColor(doc2) {
      const base = this.getOverlayBackground(doc2);
      const match = base.match(/rgba?\(([^)]+)\)/);
      if (match) {
        const parts = match[1].split(/[\s,/]+/).filter((item) => item !== "").map((item) => parseFloat(item));
        if (parts.length >= 3 && parts.slice(0, 3).every((item) => !isNaN(item))) {
          const luminance = 0.299 * parts[0] + 0.587 * parts[1] + 0.114 * parts[2];
          return luminance > 128 ? "#333333" : "#f5f5f5";
        }
      }
      const hex = base.trim().replace(/^#/, "");
      if (/^[0-9a-fA-F]{6}$/.test(hex) || /^[0-9a-fA-F]{3}$/.test(hex)) {
        const full = hex.length === 3 ? hex.split("").map((item) => item + item).join("") : hex;
        const r = parseInt(full.slice(0, 2), 16);
        const g = parseInt(full.slice(2, 4), 16);
        const b = parseInt(full.slice(4, 6), 16);
        const luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        return luminance > 128 ? "#333333" : "#f5f5f5";
      }
      return this.isDarkMode === "yes" ? "#f5f5f5" : "#333333";
    }
    updateOverlay() {
      let doc2 = this.getDoc();
      if (!doc2 || !doc2.body) return;
      let overlay = doc2.getElementById("kookit-speed-reading-overlay");
      if (!this.isSpeedReadingActive()) {
        if (overlay && overlay.parentNode) {
          overlay.parentNode.removeChild(overlay);
        }
        if (overlay === this.overlayEl) {
          this.overlayEl = null;
        }
        return;
      }
      if (!overlay) {
        overlay = doc2.createElement("div");
        overlay.id = "kookit-speed-reading-overlay";
        this.overlayEl = overlay;
        const pageHeight = this.getPageHeight();
        const isScrollMode = this.readerMode === "scroll";
        const position = isScrollMode ? "absolute" : "fixed";
        const visibilityTop = isScrollMode ? convertStyleNum(this.getElement().scrollTop) : 0;
        const element = this.getElement();
        const height = isScrollMode ? element.clientHeight : doc2.defaultView ? doc2.defaultView.innerHeight : pageHeight;
        overlay.style.cssText = `position:${position};left:0;width:100%;top:${isScrollMode ? visibilityTop : 0}px;height:${Math.max(0, height)}px;z-index:2147483000;display:flex;flex-direction:column;align-items:center;justify-content:center;padding-bottom:${Math.round(
          pageHeight * 0.2
        )}px;user-select:none;transition:background-color 0.3s ease;margin:0 !important;padding:0 !important;pointer-events:none;`;
        overlay.style.backgroundColor = this.getOverlayBackground(doc2);
        let wordArea = doc2.createElement("div");
        wordArea.id = "kookit-speed-reading-word-area";
        wordArea.style.cssText = `position:relative;display:flex;align-items:baseline;width:80%;max-width:900px;font-weight:600;line-height:1.6;font-size:${this.getWordFontSize()}px !important;transition:background-color 0.3s ease;pointer-events:none;`;
        let left = doc2.createElement("span");
        left.id = "kookit-speed-reading-word-left";
        left.style.cssText = `flex:1;text-align:right;white-space:pre;overflow:visible;font-size:${this.getWordFontSize()}px !important;`;
        let pivot = doc2.createElement("span");
        pivot.id = "kookit-speed-reading-word-pivot";
        pivot.style.cssText = `color:${PIVOT_COLOR} !important;white-space:pre;position:relative;font-size:${this.getWordFontSize()}px !important;overflow:visible;`;
        let right = doc2.createElement("span");
        right.id = "kookit-speed-reading-word-right";
        right.style.cssText = `flex:1;text-align:left;white-space:pre;overflow:visible;font-size:${this.getWordFontSize()}px !important;`;
        let tickTop = doc2.createElement("span");
        tickTop.id = "kookit-speed-reading-tick-top";
        let tickBottom = doc2.createElement("span");
        tickBottom.id = "kookit-speed-reading-tick-bottom";
        const textColor = this.getTextColor(doc2);
        const fontPx = this.getWordFontSize();
        const tickCss = `position:absolute;left:50%;transform:translateX(-50%);width:2px;height:${Math.round(
          fontPx * 0.3
        )}px;background:rgba(128,128,128,0.6);`;
        tickTop.style.cssText = tickCss + `top:-${Math.round(fontPx * 0.45)}px;`;
        tickBottom.style.cssText = tickCss + `bottom:-${Math.round(fontPx * 0.45)}px;`;
        wordArea.appendChild(left);
        wordArea.appendChild(pivot);
        wordArea.appendChild(right);
        wordArea.appendChild(tickTop);
        wordArea.appendChild(tickBottom);
        wordArea.style.cssText += `font-size:${fontPx}px !important;`;
        wordArea.style.color = textColor;
        let status = doc2.createElement("div");
        status.id = "kookit-speed-reading-status";
        status.style.cssText = "display:none;font-size:" + Math.round(fontPx * 0.6) + "px !important;opacity:0.7;";
        status.textContent = "The End";
        status.style.color = textColor;
        let toggle = doc2.createElement("div");
        toggle.id = "kookit-speed-reading-toggle";
        toggle.style.cssText = `margin-top:${Math.round(fontPx * 0.8)}px;width:56px;height:56px;border-radius:50%;display:flex;align-items:center;justify-content:center;cursor:pointer;font-size:22px !important;border:1px solid rgba(128,128,128,0.5);color:${textColor};pointer-events:auto;user-select:none;-webkit-user-select:none;-webkit-tap-highlight-color:transparent;`;
        toggle.appendChild(this.createToggleIcon(doc2, this.playing));
        overlay.appendChild(wordArea);
        overlay.appendChild(status);
        overlay.appendChild(toggle);
        doc2.body.appendChild(overlay);
        toggle.addEventListener("click", (event) => {
          event.stopPropagation();
          this.toggle();
        });
        overlay.addEventListener("click", (event) => {
          event.stopPropagation();
          this.toggle();
        });
        const blockEvent = (event) => {
          event.stopPropagation();
        };
        overlay.addEventListener("touchstart", blockEvent, { passive: false });
        overlay.addEventListener("touchmove", blockEvent, { passive: false });
        overlay.addEventListener("touchend", blockEvent, { passive: false });
        overlay.addEventListener("wheel", blockEvent, { passive: false });
        overlay.addEventListener("mousedown", blockEvent, false);
        overlay.addEventListener("dblclick", blockEvent, false);
      } else if (overlay !== this.overlayEl) {
        this.overlayEl = overlay;
      }
      if (this.readerMode === "scroll" && this.getElement()) {
        overlay.style.top = convertStyleNum(this.getElement().scrollTop) + "px";
        overlay.style.height = this.getElement().clientHeight + "px";
      }
    }
    removeOverlay() {
      let doc2 = this.getDoc();
      if (!doc2) return;
      let overlay = doc2.getElementById("kookit-speed-reading-overlay");
      if (overlay && overlay.parentNode) {
        overlay.parentNode.removeChild(overlay);
      }
      this.overlayEl = null;
      this.cancelCountdown();
      if (this.timer) {
        clearTimeout(this.timer);
        this.timer = null;
      }
    }
    isOverlayValid(doc2) {
      if (!this.overlayEl || doc2.getElementById("kookit-speed-reading-overlay") !== this.overlayEl) {
        return false;
      }
      return true;
    }
    createToggleIcon(doc2, playing) {
      const svg = doc2.createElementNS("http://www.w3.org/2000/svg", "svg");
      svg.setAttribute("viewBox", "0 0 24 24");
      svg.setAttribute("width", "22");
      svg.setAttribute("height", "22");
      svg.style.cssText = "display:block;fill:currentColor;";
      const path = doc2.createElementNS("http://www.w3.org/2000/svg", "path");
      path.setAttribute(
        "d",
        playing ? "M7 5h4v14H7zM13 5h4v14h-4z" : "M9 5v14l11-7z"
      );
      svg.appendChild(path);
      return svg;
    }
    updateToggleIcon() {
      let doc2 = this.getDoc();
      if (!doc2) return;
      let toggle = doc2.getElementById("kookit-speed-reading-toggle");
      if (!toggle) return;
      while (toggle.firstChild) {
        toggle.removeChild(toggle.firstChild);
      }
      toggle.appendChild(this.createToggleIcon(doc2, this.playing));
    }
    showEndState() {
      let doc2 = this.getDoc();
      if (!doc2) return;
      let wordArea = doc2.getElementById("kookit-speed-reading-word-area");
      let status = doc2.getElementById("kookit-speed-reading-status");
      if (wordArea) wordArea.style.display = "none";
      if (status) status.style.display = "block";
    }
    showWordArea() {
      let doc2 = this.getDoc();
      if (!doc2) return;
      let wordArea = doc2.getElementById("kookit-speed-reading-word-area");
      let status = doc2.getElementById("kookit-speed-reading-status");
      if (wordArea) wordArea.style.display = "flex";
      if (status) status.style.display = "none";
    }
    renderWord() {
      let doc2 = this.getDoc();
      if (!doc2) return;
      this.updateOverlay();
      this.showWordArea();
      let left = doc2.getElementById("kookit-speed-reading-word-left");
      let pivot = doc2.getElementById("kookit-speed-reading-word-pivot");
      let right = doc2.getElementById("kookit-speed-reading-word-right");
      if (!left || !pivot || !right) return;
      pivot.style.setProperty("color", PIVOT_COLOR, "important");
      pivot.style.cssText += `font-size:${this.getWordFontSize()}px !important;`;
      right.style.setProperty("color", this.getTextColor(doc2), "important");
      right.style.cssText += `font-size:${this.getWordFontSize()}px !important;`;
      left.style.setProperty("color", this.getTextColor(doc2), "important");
      left.style.cssText += `font-size:${this.getWordFontSize()}px !important;`;
      let word = this.words[this.index] || "";
      let chars = Array.from(word);
      if (chars.length === 0) {
        left.textContent = "";
        pivot.textContent = "";
        right.textContent = "";
        this.showEndState();
        return;
      }
      let orp = Math.min(getSpeedReadingORPIndex(word), chars.length - 1);
      left.textContent = chars.slice(0, orp).join("");
      pivot.textContent = chars[orp];
      right.textContent = chars.slice(orp + 1).join("");
    }
    // 供外部调用的公开接口
    start() {
      if (!this.isSpeedReadingActive() || this.playing) return;
      let doc2 = this.getDoc();
      if (!doc2) return;
      this.playing = true;
      this.updateOverlay();
      this.updateToggleIcon();
      if (this.words.length === 0) {
        this.words = this.extractWords();
        this.index = 0;
      }
      if (this.words.length === 0) {
        this.pause();
        this.showEndState();
        return;
      }
      if (this.hasStartedOnce) {
        this.renderWord();
        this.scheduleNext();
        return;
      }
      this.hasStartedOnce = true;
      this.startCountdown();
    }
    cancelCountdown() {
      if (this.countdownTimer) {
        clearInterval(this.countdownTimer);
        this.countdownTimer = null;
      }
    }
    // 开始播放前展示 3 秒倒计时，给用户留出准备时间，结束后进入逐词轮播
    startCountdown() {
      this.cancelCountdown();
      let count = 3;
      this.renderCountdown(count);
      this.countdownTimer = setInterval(() => {
        let currentDoc = this.getDoc();
        if (!this.playing || !currentDoc || !this.isOverlayValid(currentDoc)) {
          this.cancelCountdown();
          return;
        }
        count--;
        if (count <= 0) {
          this.cancelCountdown();
          this.renderWord();
          this.scheduleNext();
          return;
        }
        this.renderCountdown(count);
      }, 1e3);
    }
    // 倒计时数字复用 ORP 高亮位置展示，使用独立颜色并放大字号
    renderCountdown(count) {
      let doc2 = this.getDoc();
      if (!doc2) return;
      this.updateOverlay();
      this.showWordArea();
      let left = doc2.getElementById("kookit-speed-reading-word-left");
      let pivot = doc2.getElementById("kookit-speed-reading-word-pivot");
      let right = doc2.getElementById("kookit-speed-reading-word-right");
      if (!left || !pivot || !right) return;
      const countdownPx = Math.round(this.getWordFontSize() * 1.6);
      left.textContent = "";
      pivot.style.setProperty("color", COUNTDOWN_COLOR, "important");
      pivot.style.cssText += `font-size:${countdownPx}px !important;`;
      pivot.textContent = String(count);
      right.textContent = "";
    }
    pause() {
      const hadCountdown = this.countdownTimer != null;
      this.playing = false;
      this.cancelCountdown();
      if (this.timer) {
        clearTimeout(this.timer);
        this.timer = null;
      }
      if (hadCountdown) {
        this.renderWord();
      }
      this.updateToggleIcon();
    }
    toggle() {
      let doc2 = this.getDoc();
      if (!doc2) return;
      if (this.playing) {
        this.pause();
      } else {
        this.start();
      }
    }
    scheduleNext() {
      this.cancelCountdown();
      if (this.timer) {
        clearTimeout(this.timer);
        this.timer = null;
      }
      if (!this.playing) return;
      let doc2 = this.getDoc();
      if (!doc2 || !this.isOverlayValid(doc2)) return;
      const word = this.words[this.index] || "";
      const wpm = this.speedReadingSpeed || 300;
      const delay = getSpeedReadingWordDelay(word, wpm);
      this.timer = setTimeout(async () => {
        this.timer = null;
        let currentDoc = this.getDoc();
        if (!this.playing || !currentDoc || !this.isOverlayValid(currentDoc)) {
          return;
        }
        await this.showNextWord();
      }, delay);
    }
    async showNextWord() {
      if (!this.playing) return;
      if (this.index < this.words.length - 1) {
        this.index++;
        this.renderWord();
        this.scheduleNext();
        return;
      }
      await this.flipPage(1);
    }
    getPageKey() {
      let progress2 = this.getProgress();
      return JSON.stringify([
        this.getChapterDocIndex(),
        progress2?.currentPage,
        progress2?.totalPage
      ]);
    }
    async flipPage(direction) {
      let doc2 = this.getDoc();
      if (!doc2) {
        this.pause();
        return;
      }
      this.skipFlip = true;
      try {
        let attempts = 0;
        while (attempts < 5 && this.playing) {
          const beforeKey = this.getPageKey();
          if (direction > 0) {
            await this.nextPage();
          } else {
            await this.prevPage();
          }
          await new Promise(
            (r) => setTimeout(r, this.readerMode === "scroll" ? 400 : 150)
          );
          const afterKey = this.getPageKey();
          this.words = this.extractWords();
          if (this.words.length > 0) {
            this.index = direction > 0 ? 0 : this.words.length - 1;
            this.updateOverlay();
            this.renderWord();
            break;
          }
          if (beforeKey === afterKey) {
            this.pause();
            this.words = [];
            this.index = 0;
            this.showEndState();
            return;
          }
          attempts++;
        }
      } finally {
        this.skipFlip = false;
      }
      this.scheduleNext();
    }
    // 由 GeneralRender 的 rendered 事件驱动
    handleRendered() {
      if (!this.isSpeedReadingActive()) {
        this.pause();
        this.removeOverlay();
        return;
      }
      let doc2 = this.getDoc();
      if (!doc2 || !doc2.body) return;
      this.words = this.extractWords();
      this.index = 0;
      this.updateOverlay();
      this.updateToggleIcon();
      if (this.words.length === 0) {
        this.showEndState();
        this.cancelCountdown();
        if (this.timer) {
          clearTimeout(this.timer);
          this.timer = null;
        }
        return;
      }
      this.showWordArea();
      this.renderWord();
      if (!this.autoStarted) {
        this.autoStarted = true;
        this.start();
      } else if (this.playing) {
        this.cancelCountdown();
        this.scheduleNext();
      }
    }
  };
  var speedReadingUtil_default = SpeedReadingManager;

  // vendor/kookit/src/utils/readingRulerUtil.ts
  var ReadingRulerManager = class {
    // 配置
    isReadingRuler = "no";
    readingRulerLineHeight = 3;
    readingRulerBackgroundOpacity = 0.6;
    readerMode = "single";
    isMobile;
    // 运行时状态
    index = 0;
    column = 0;
    skipFlip = false;
    // 由 GeneralRender 注入的回调，与渲染实例解耦
    getDoc = () => null;
    getElement = () => ({});
    getIframe = () => null;
    getIsVertical = () => false;
    getOverlayBackground = () => "#ffffff";
    nextPage = async () => {
    };
    prevPage = async () => {
    };
    constructor(config = {}) {
      this.isReadingRuler = config.isReadingRuler || "no";
      this.readingRulerLineHeight = config.readingRulerLineHeight || 3;
      this.readingRulerBackgroundOpacity = config.readingRulerBackgroundOpacity != null ? config.readingRulerBackgroundOpacity : 0.6;
      this.readerMode = config.readerMode || "single";
      this.isMobile = config.isMobile;
    }
    applyConfig(config = {}) {
      if (config.isReadingRuler != null) {
        this.isReadingRuler = config.isReadingRuler;
      }
      if (config.readingRulerLineHeight != null) {
        this.readingRulerLineHeight = config.readingRulerLineHeight;
      }
      if (config.readingRulerBackgroundOpacity != null) {
        this.readingRulerBackgroundOpacity = config.readingRulerBackgroundOpacity;
      }
    }
    isReadingRulerActive() {
      return this.isReadingRuler === "yes";
    }
    getStep() {
      return Math.max(1, Math.round(this.readingRulerLineHeight || 3));
    }
    getVisibleBounds() {
      let iframe = this.getIframe();
      let top = 0;
      let bottom = iframe ? iframe.clientHeight : 0;
      if (this.readerMode === "scroll" && this.getElement()) {
        const element = this.getElement();
        top = element.scrollTop;
        bottom = top + element.clientHeight;
      }
      return { top, bottom };
    }
    getColumnBounds() {
      if (this.readerMode !== "double") return null;
      let iframe = this.getIframe();
      if (!iframe) return null;
      const width = iframe.clientWidth;
      if (!width) return null;
      let section = Math.floor(width / 12);
      let gap = section % 2 === 0 ? section : section - 1;
      const sectionWidth = Math.max(0, (width - gap) / 2);
      if (this.column === 0) {
        return { left: 0, right: sectionWidth };
      }
      return { left: Math.min(width, sectionWidth + gap), right: width };
    }
    getLines(columnBounds) {
      let doc2 = this.getDoc();
      let iframe = this.getIframe();
      if (!doc2 || !doc2.body || !iframe) return [];
      if (this.getIsVertical()) return [];
      const view = doc2.defaultView || window;
      const visible = this.getVisibleBounds();
      const visibleLeft = columnBounds ? columnBounds.left : 0;
      const visibleRight = columnBounds ? columnBounds.right : iframe.clientWidth;
      const allRects = [];
      const parentCache = /* @__PURE__ */ new Map();
      const walker = doc2.createTreeWalker(doc2.body, NodeFilter.SHOW_TEXT);
      let currentNode = walker.nextNode();
      while (currentNode) {
        const text = currentNode.textContent || "";
        if (text.trim()) {
          const parent = currentNode.parentElement;
          if (parent) {
            let parentVisible = parentCache.get(parent);
            if (parentVisible === void 0) {
              const style = view.getComputedStyle(parent);
              parentVisible = style.display !== "none" && style.visibility !== "hidden";
              parentCache.set(parent, parentVisible);
            }
            if (parentVisible) {
              const range2 = doc2.createRange();
              range2.selectNodeContents(currentNode);
              const rects = range2.getClientRects();
              for (let index = 0; index < rects.length; index++) {
                const rect = rects[index];
                if (rect.height <= 0 || rect.width <= 0) continue;
                if (rect.bottom <= visible.top || rect.top >= visible.bottom)
                  continue;
                if (rect.right <= visibleLeft || rect.left >= visibleRight)
                  continue;
                allRects.push({
                  top: rect.top,
                  bottom: rect.bottom,
                  left: rect.left,
                  right: rect.right
                });
              }
            }
          }
        }
        currentNode = walker.nextNode();
      }
      allRects.sort((a, b) => a.top - b.top || a.bottom - b.bottom);
      const lines2 = [];
      for (let index = 0; index < allRects.length; index++) {
        const rect = allRects[index];
        const last2 = lines2[lines2.length - 1];
        if (last2 && rect.top < last2.bottom - 2) {
          last2.bottom = Math.max(last2.bottom, rect.bottom);
          last2.left = Math.min(last2.left, rect.left);
          last2.right = Math.max(last2.right, rect.right);
        } else {
          lines2.push({
            top: rect.top,
            bottom: rect.bottom,
            left: rect.left,
            right: rect.right
          });
        }
      }
      return lines2;
    }
    getMaskColor(doc2) {
      const alpha = Math.min(1, Math.max(0, this.readingRulerBackgroundOpacity));
      const base = this.getOverlayBackground(doc2);
      const match = base.match(/rgba?\(([^)]+)\)/);
      if (match) {
        const parts = match[1].split(/[\s,/]+/).filter((item) => item !== "").map((item) => parseFloat(item));
        if (parts.length >= 3 && parts.slice(0, 3).every((item) => !isNaN(item))) {
          return `rgba(${parts[0]},${parts[1]},${parts[2]},${alpha})`;
        }
      }
      const hex = base.trim().replace(/^#/, "");
      if (/^[0-9a-fA-F]{6}$/.test(hex) || /^[0-9a-fA-F]{3}$/.test(hex)) {
        const full = hex.length === 3 ? hex.split("").map((item) => item + item).join("") : hex;
        return `rgba(${parseInt(full.slice(0, 2), 16)},${parseInt(
          full.slice(2, 4),
          16
        )},${parseInt(full.slice(4, 6), 16)},${alpha})`;
      }
      return `rgba(0,0,0,${alpha})`;
    }
    updateOverlay(animate, lines2) {
      let doc2 = this.getDoc();
      let iframe = this.getIframe();
      if (!doc2 || !doc2.body || !iframe) return;
      if (!this.isReadingRulerActive()) {
        this.removeOverlay();
        return;
      }
      let windowEl = doc2.getElementById("kookit-reading-ruler-window");
      let columnBounds = this.getColumnBounds();
      let lineList = lines2 || this.getLines(columnBounds);
      if (lineList.length === 0) {
        this.removeOverlay();
        return;
      }
      const step = this.getStep();
      const totalChunks = Math.ceil(lineList.length / step);
      if (this.index >= totalChunks) {
        this.index = totalChunks - 1;
      }
      if (this.index < 0) {
        this.index = 0;
      }
      const startIndex = this.index * step;
      const endIndex = Math.min(startIndex + step, lineList.length);
      const visible = this.getVisibleBounds();
      const top = Math.max(visible.top, lineList[startIndex].top - 4);
      const bottom = Math.min(visible.bottom, lineList[endIndex - 1].bottom + 4);
      const offset = this.isMobile === "yes" ? 0 : 16;
      const bounds = columnBounds || {
        left: 0,
        right: iframe.clientWidth
      };
      let minLeft = lineList[startIndex].left;
      let maxRight = lineList[startIndex].right;
      for (let index = startIndex + 1; index < endIndex; index++) {
        minLeft = Math.min(minLeft, lineList[index].left);
        maxRight = Math.max(maxRight, lineList[index].right);
      }
      const left = Math.max(bounds.left, minLeft - offset);
      const width = Math.max(0, Math.min(bounds.right, maxRight + offset) - left);
      const position = this.readerMode === "scroll" ? "absolute" : "fixed";
      if (!windowEl) {
        windowEl = doc2.createElement("div");
        windowEl.id = "kookit-reading-ruler-window";
        doc2.body.appendChild(windowEl);
      }
      windowEl.style.cssText = `position:${position};left:${left}px;width:${width}px;top:${top}px;height:${Math.max(
        0,
        bottom - top
      )}px;border-radius:10px;border:1px solid rgba(128,128,128,0.5);box-shadow:0 0 0 100000px ${this.getMaskColor(
        doc2
      )};box-sizing:border-box;z-index:2147483000;pointer-events:none;transition:${animate ? "top 0.3s ease, height 0.3s ease, left 0.3s ease, width 0.3s ease" : "none"};margin:0 !important;padding:0 !important;`;
    }
    removeOverlay() {
      let doc2 = this.getDoc();
      if (doc2) {
        let windowEl = doc2.getElementById("kookit-reading-ruler-window");
        if (windowEl && windowEl.parentNode) {
          windowEl.parentNode.removeChild(windowEl);
        }
      }
    }
    async handleChange(direction) {
      const columnBounds = this.getColumnBounds();
      const lines2 = this.getLines(columnBounds);
      if (lines2.length === 0) return false;
      const step = this.getStep();
      const totalChunks = Math.ceil(lines2.length / step);
      if (this.index >= totalChunks) {
        this.index = 0;
      }
      if (direction > 0) {
        if (this.index < totalChunks - 1) {
          this.index++;
        } else if (columnBounds && this.column === 0) {
          this.column = 1;
          this.index = 0;
        } else {
          await this.flipPage(1);
          return true;
        }
      } else {
        if (this.index > 0) {
          this.index--;
        } else if (columnBounds && this.column === 1) {
          this.column = 0;
          this.index = Number.MAX_SAFE_INTEGER;
        } else {
          await this.flipPage(-1);
          return true;
        }
      }
      this.updateOverlay(true, void 0);
      return true;
    }
    async flipPage(direction) {
      this.skipFlip = true;
      try {
        if (direction > 0) {
          await this.nextPage();
        } else {
          await this.prevPage();
        }
        await new Promise(
          (r) => setTimeout(r, this.readerMode === "scroll" ? 400 : 150)
        );
      } finally {
        this.skipFlip = false;
      }
      this.index = direction > 0 ? 0 : Number.MAX_SAFE_INTEGER;
      this.column = direction > 0 ? 0 : this.readerMode === "double" ? 1 : 0;
      let doc2 = this.getDoc();
      let windowEl = doc2 ? doc2.getElementById("kookit-reading-ruler-window") : null;
      this.updateOverlay(true, void 0);
      if (doc2 && !windowEl) {
        let newWindowEl = doc2.getElementById("kookit-reading-ruler-window");
        if (newWindowEl) {
          const fadeEl = newWindowEl;
          fadeEl.style.transition = "none";
          fadeEl.style.opacity = "0";
          fadeEl.style.transform = "translateY(-20px)";
          void fadeEl.offsetHeight;
          fadeEl.style.transition = "opacity 0.3s ease, top 0.3s ease, height 0.3s ease, left 0.3s ease, width 0.3s ease";
          fadeEl.style.opacity = "1";
          fadeEl.style.transform = "translateY(0)";
          setTimeout(() => {
            fadeEl.style.opacity = "";
            fadeEl.style.transform = "";
            fadeEl.style.transition = "";
          }, 350);
        }
      }
    }
    // 由 GeneralRender 的 rendered 事件驱动
    handleRendered() {
      if (!this.isReadingRulerActive() || this.skipFlip) return;
      this.index = 0;
      this.column = 0;
      this.updateOverlay();
    }
  };
  var readingRulerUtil_default = ReadingRulerManager;

  // vendor/kookit/src/utils/paragraphModeUtil.ts
  var OVERLAY_RESERVED_PX = 180;
  var ParagraphModeManager = class {
    // 配置
    isParagraphMode = "no";
    readerMode = "single";
    isMobile;
    // 运行时状态
    // 当前段落在章节段落列表中的索引
    index = 0;
    // 超长段落经 CSS 多列分屏后的屏索引/总屏数/单屏位移步长
    sliceIndex = 0;
    sliceCount = 1;
    sliceStep = 0;
    skipFlip = false;
    // 当前展示的原始段落节点，用于章节渲染后判断章节是否发生变化
    currentParagraph = null;
    // 由 GeneralRender 注入的回调，与渲染实例解耦
    getDoc = () => null;
    getElement = () => ({});
    getIframe = () => null;
    getOverlayBackground = () => "#ffffff";
    getIsVertical = () => false;
    // 静默同步底层页面到指定段落所在页，用于阅读进度记录
    locateParagraph = () => {
    };
    // 获取当前章节索引，用于判断章节切换是否真实发生
    getChapterDocIndex = () => "";
    nextPage = async () => {
    };
    prevPage = async () => {
    };
    constructor(config = {}) {
      this.isParagraphMode = config.isParagraphMode || "no";
      this.readerMode = config.readerMode || "single";
      this.isMobile = config.isMobile;
    }
    applyConfig(config = {}) {
      if (config.isParagraphMode != null) {
        this.isParagraphMode = config.isParagraphMode;
      }
    }
    isParagraphModeActive() {
      return this.isParagraphMode === "yes";
    }
    // 章级段落列表：整个章节文档的块级叶子节点，按文档顺序排列。
    // 不做视口过滤，每个段落只出现一次，
    // 避免跨页段落在相邻两页的列表中重复出现导致需要两次 next 才能切换段落
    getParagraphNodes() {
      let doc2 = this.getDoc();
      let element = this.getElement();
      if (!doc2 || !doc2.body || !element) return [];
      let overlay = doc2.getElementById("kookit-paragraph-overlay");
      let nodeList = getBlockElement(doc2.body).filter(
        (item) => !isParentBlock(item)
      );
      return nodeList.filter(
        (el) => (!overlay || !overlay.contains(el)) && (el.textContent || "").trim() && this.isParagraphVisible(el)
      );
    }
    // 仅过滤不可见元素（display:none 等），不做视口判断，
    // 分页列布局中未滚入视口的段落同样是有效段落
    isParagraphVisible(el) {
      const view = el.ownerDocument?.defaultView || window;
      const style = view.getComputedStyle(el);
      if (style.display === "none" || style.visibility === "hidden" || style.opacity === "0") {
        return false;
      }
      const rect = el.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0;
    }
    isParagraphInViewport(doc2, el) {
      const view = doc2.defaultView || window;
      const style = view.getComputedStyle(el);
      if (style.display === "none" || style.visibility === "hidden" || style.opacity === "0") {
        return false;
      }
      const rect = el.getBoundingClientRect();
      if (!(rect.width > 0 && rect.height > 0)) return false;
      if (this.readerMode === "scroll") {
        let element = this.getElement();
        return rect.bottom > element.scrollTop && rect.top < element.scrollTop + element.clientHeight;
      }
      let iframe = this.getIframe();
      if (!iframe) return false;
      return rect.bottom > 0 && rect.top < iframe.clientHeight && rect.right > 0 && rect.left < iframe.clientWidth;
    }
    // 定位当前视口内的第一个段落，用于章节渲染/跳转后的初始定位
    findFirstViewportParagraph(list) {
      let doc2 = this.getDoc();
      if (!doc2) return 0;
      for (let i = 0; i < list.length; i++) {
        if (this.isParagraphInViewport(doc2, list[i])) {
          return i;
        }
      }
      return 0;
    }
    updateOverlay(paragraphs) {
      let doc2 = this.getDoc();
      if (!doc2 || !doc2.body) return;
      let overlay = doc2.getElementById("kookit-paragraph-overlay");
      if (!this.isParagraphModeActive()) {
        if (overlay) {
          overlay.parentNode?.removeChild(overlay);
        }
        return;
      }
      let list = paragraphs || this.getParagraphNodes();
      if (list.length === 0) {
        this.currentParagraph = null;
        if (overlay) {
          overlay.parentNode?.removeChild(overlay);
        }
        return;
      }
      if (this.index >= list.length) {
        this.index = list.length - 1;
        this.sliceIndex = Number.MAX_SAFE_INTEGER;
      }
      if (!overlay) {
        overlay = doc2.createElement("div");
        overlay.id = "kookit-paragraph-overlay";
        overlay.style.cssText = `position:fixed;top:0;left:0;right:0;bottom:0;display:flex;align-items:center;justify-content:center;z-index:2147483000;pointer-events:none;text-align:center;transition:background-color 0.3s ease;margin:0 !important;padding:0 !important;`;
        let content2 = doc2.createElement("div");
        content2.id = "kookit-paragraph-overlay-content";
        content2.style.cssText = `width:calc(100% - 40px);max-width:600px;max-height:calc(100% - ${OVERLAY_RESERVED_PX}px);overflow:hidden;text-align:center;transition:background-color 0.3s ease;`;
        overlay.appendChild(content2);
        overlay.appendChild(this.createControls(doc2));
        doc2.body.appendChild(overlay);
      }
      overlay.style.backgroundColor = this.getOverlayBackground(doc2);
      let content = doc2.getElementById("kookit-paragraph-overlay-content");
      if (!content) return;
      content.innerHTML = "";
      content.style.height = "";
      let inner = doc2.createElement("div");
      inner.id = "kookit-paragraph-overlay-inner";
      inner.style.cssText = "width:100%;column-gap:40px;column-fill:auto;transition:transform 0.3s ease;";
      inner.appendChild(list[this.index].cloneNode(true));
      content.appendChild(inner);
      this.currentParagraph = list[this.index] || null;
      this.measureSlice(content, inner);
      this.sliceIndex = Math.min(this.sliceIndex, this.sliceCount - 1);
      this.showSlice();
      inner.querySelectorAll("img").forEach((img) => {
        if (!img.complete) {
          img.addEventListener("load", () => this.remeasureSlice(), {
            once: true
          });
        }
      });
      this.refreshControls(doc2);
    }
    // 图片加载完成后基于当前 DOM 重新测量分屏
    remeasureSlice() {
      let doc2 = this.getDoc();
      if (!doc2) return;
      let content = doc2.getElementById("kookit-paragraph-overlay-content");
      let inner = doc2.getElementById("kookit-paragraph-overlay-inner");
      if (!content || !inner || !inner.isConnected) return;
      this.measureSlice(content, inner);
      this.sliceIndex = Math.min(this.sliceIndex, this.sliceCount - 1);
      this.showSlice();
    }
    // 段落自然高度超出遮罩容量时，切换为定高 + 多列布局并计算总屏数
    measureSlice(content, inner) {
      this.sliceCount = 1;
      this.sliceStep = 0;
      if (content.scrollHeight <= content.clientHeight + 1) return;
      content.style.height = `calc(100% - ${OVERLAY_RESERVED_PX}px)`;
      inner.style.height = "100%";
      inner.style.columnWidth = content.clientWidth + "px";
      let gap = 40;
      inner.style.overflow = "hidden";
      let extent = Math.max(content.scrollWidth, inner.scrollWidth);
      inner.style.overflow = "";
      let step = content.clientWidth + gap;
      this.sliceCount = Math.max(1, Math.round((extent + gap) / step));
      this.sliceStep = (extent + gap) / this.sliceCount;
    }
    showSlice() {
      let doc2 = this.getDoc();
      if (!doc2) return;
      let content = doc2.getElementById("kookit-paragraph-overlay-content");
      let inner = doc2.getElementById("kookit-paragraph-overlay-inner");
      if (!content || !inner) return;
      let step = this.sliceStep || content.clientWidth + 40;
      inner.style.transform = `translateX(${-this.sliceIndex * step}px)`;
    }
    createControls(doc2) {
      let controls = doc2.createElement("div");
      controls.id = "kookit-paragraph-overlay-controls";
      let css2 = "position:fixed;left:0;right:0;bottom:" + (this.isMobile === "yes" ? 32 : 20) + "px;display:flex;justify-content:center;gap:48px;z-index:2147483001;pointer-events:none;";
      if (this.readerMode === "scroll") {
        let element = this.getElement();
        css2 = "position:absolute;left:0;width:100%;top:" + (element ? element.scrollTop + element.clientHeight - 80 : 0) + "px;display:flex;justify-content:center;gap:48px;z-index:2147483001;pointer-events:none;";
      }
      controls.style.cssText = css2;
      const btnCss = "pointer-events:auto;width:44px;height:44px;padding:0;margin:0;background:transparent;border-radius:50%;border:1px solid rgba(128,128,128,1);color:rgba(128,128,128,1);display:flex;align-items:center;justify-content:center;cursor:pointer;user-select:none;-webkit-user-select:none;-webkit-tap-highlight-color:transparent;";
      const bindButton = (btn, direction) => {
        const handler = (event) => {
          event.preventDefault();
          event.stopPropagation();
          this.handleChange(direction).catch(() => {
          });
        };
        btn.addEventListener("touchend", handler, { passive: false });
        btn.addEventListener("mousedown", handler);
        btn.addEventListener("click", (event) => {
          event.preventDefault();
          event.stopPropagation();
        });
        btn.addEventListener("dblclick", (event) => event.stopPropagation());
        btn.addEventListener(
          "touchstart",
          (event) => event.stopPropagation(),
          { passive: false }
        );
        btn.addEventListener(
          "touchmove",
          (event) => event.stopPropagation(),
          { passive: false }
        );
      };
      let prevBtn = doc2.createElement("button");
      prevBtn.id = "kookit-paragraph-overlay-prev";
      prevBtn.style.cssText = btnCss;
      prevBtn.appendChild(this.createArrowIcon(doc2, -1));
      let nextBtn = doc2.createElement("button");
      nextBtn.id = "kookit-paragraph-overlay-next";
      nextBtn.style.cssText = btnCss;
      nextBtn.appendChild(this.createArrowIcon(doc2, 1));
      bindButton(prevBtn, -1);
      bindButton(nextBtn, 1);
      controls.appendChild(prevBtn);
      controls.appendChild(nextBtn);
      return controls;
    }
    createArrowIcon(doc2, direction) {
      const svg = doc2.createElementNS("http://www.w3.org/2000/svg", "svg");
      svg.setAttribute("viewBox", "0 0 24 24");
      svg.setAttribute("width", "20");
      svg.setAttribute("height", "20");
      svg.style.cssText = "display:block;fill:none;stroke:currentColor;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;";
      const line = doc2.createElementNS("http://www.w3.org/2000/svg", "path");
      line.setAttribute("d", direction < 0 ? "M19 12H5" : "M5 12h14");
      const head = doc2.createElementNS("http://www.w3.org/2000/svg", "path");
      head.setAttribute("d", direction < 0 ? "M12 19l-7-7 7-7" : "M12 5l7 7-7 7");
      svg.appendChild(line);
      svg.appendChild(head);
      return svg;
    }
    refreshControls(doc2) {
      let controls = doc2.getElementById("kookit-paragraph-overlay-controls");
      if (!controls) return;
      let color = "rgba(128,128,128,1)";
      let prevBtn = doc2.getElementById("kookit-paragraph-overlay-prev");
      let nextBtn = doc2.getElementById("kookit-paragraph-overlay-next");
      if (prevBtn) prevBtn.style.color = color;
      if (nextBtn) nextBtn.style.color = color;
      if (this.readerMode === "scroll") {
        let element = this.getElement();
        if (element) {
          controls.style.top = element.scrollTop + element.clientHeight - 80 + "px";
        }
      }
    }
    removeOverlay() {
      let doc2 = this.getDoc();
      if (!doc2) return;
      let overlay = doc2.getElementById("kookit-paragraph-overlay");
      if (overlay && overlay.parentNode) {
        overlay.parentNode.removeChild(overlay);
      }
    }
    async handleChange(direction) {
      let list = this.getParagraphNodes();
      if (list.length === 0) return false;
      if (direction > 0) {
        if (this.sliceIndex < this.sliceCount - 1) {
          this.sliceIndex++;
          this.showSlice();
          return true;
        } else if (this.index < list.length - 1) {
          this.index++;
          this.sliceIndex = 0;
        } else {
          await this.flipChapter(1);
          return true;
        }
      } else {
        if (this.sliceIndex > 0) {
          this.sliceIndex--;
          this.showSlice();
          return true;
        } else if (this.index > 0) {
          this.index--;
          this.sliceIndex = Number.MAX_SAFE_INTEGER;
        } else {
          await this.flipChapter(-1);
          return true;
        }
      }
      this.updateOverlay(list);
      this.locateParagraph(list[this.index]);
      return true;
    }
    // 仅在章节段落耗尽时触发真实翻页，此时 next()/prev() 会因
    // 底层页面已位于章节边界而走章节切换逻辑
    async flipChapter(direction) {
      let previousChapterDocIndex = this.getChapterDocIndex();
      let previousIndex = this.index;
      let previousSliceIndex = this.sliceIndex;
      this.skipFlip = true;
      try {
        let doc2 = this.getDoc();
        if (doc2 && doc2.body && this.readerMode !== "scroll") {
          if (this.getIsVertical()) {
            doc2.body.scrollTo(0, direction > 0 ? doc2.body.scrollHeight : 0);
          } else {
            doc2.body.scrollTo(direction > 0 ? doc2.body.scrollWidth : 0, 0);
          }
        }
        if (direction > 0) {
          await this.nextPage();
        } else {
          await this.prevPage();
        }
        await new Promise(
          (r) => setTimeout(r, this.readerMode === "scroll" ? 400 : 150)
        );
      } finally {
        this.skipFlip = false;
      }
      let list = this.getParagraphNodes();
      if (this.getChapterDocIndex() === previousChapterDocIndex) {
        this.index = previousIndex;
        this.sliceIndex = previousSliceIndex;
        this.updateOverlay(list);
        return;
      }
      this.index = direction > 0 ? 0 : Math.max(0, list.length - 1);
      this.sliceIndex = direction > 0 ? 0 : Number.MAX_SAFE_INTEGER;
      this.updateOverlay(list);
      if (list.length > 0) {
        this.locateParagraph(list[this.index]);
      }
    }
    // 由 GeneralRender 的 rendered 事件驱动
    handleRendered() {
      if (!this.isParagraphModeActive() || this.skipFlip) return;
      let list = this.getParagraphNodes();
      if (list.length === 0) {
        this.index = 0;
        this.sliceIndex = 0;
        this.currentParagraph = null;
        this.updateOverlay(list);
        return;
      }
      if (this.currentParagraph && this.currentParagraph.isConnected) {
        let newIndex = list.indexOf(this.currentParagraph);
        let doc2 = this.getDoc();
        if (newIndex > -1 && doc2 && this.isParagraphInViewport(doc2, this.currentParagraph)) {
          this.index = newIndex;
          this.sliceIndex = Math.min(this.sliceIndex, this.sliceCount - 1);
          this.updateOverlay(list);
          return;
        }
      }
      this.index = this.findFirstViewportParagraph(list);
      this.sliceIndex = 0;
      this.updateOverlay(list);
    }
  };
  var paragraphModeUtil_default = ParagraphModeManager;

  // vendor/kookit/src/renders/GeneralRender.ts
  var GeneralRender = class _GeneralRender extends EventEmitter_default {
    readerMode;
    format;
    animation = "none";
    convertChinese;
    isIndent;
    bookLayout;
    textRules;
    codeHighlight;
    isHyphenation;
    isDarkMode;
    textOrientation;
    backgroundColor;
    book;
    tempLocation;
    chapterList;
    flattenChapters;
    chapterDocList;
    element;
    flipToNextPage;
    flipToPrevPage;
    mouseDownHandler;
    mouseUpHandler;
    mouseMoveHandler;
    isMobile;
    isBionic = "no";
    isParagraphMode = "no";
    isReadingRuler = "no";
    isSpeedReading = "no";
    isShowTotalPage = "no";
    chapterSizeCache = null;
    estimatedSizePerPage = null;
    speedReadingSpeed = 300;
    platform = "web";
    isAllowScript = "no";
    touchEventSet;
    scrollTimer;
    recordTimer;
    transMap;
    fullTranslationMode = "no";
    readingRulerManager;
    speedReadingManager;
    paragraphModeManager;
    constructor(config) {
      super();
      if (config.isParagraphMode === "yes" || config.isSpeedReading === "yes" || config.isReadingRuler === "yes") {
        if (config.readerMode === "scroll") {
          config.readerMode = "single";
        }
      }
      this.readerMode = config.readerMode;
      window.readerMode = config.readerMode;
      this.animation = config.animation || "none";
      this.format = config.format;
      this.convertChinese = config.convertChinese;
      window.convertChinese = config.convertChinese;
      this.isIndent = config.isIndent;
      window.isIndent = config.isIndent;
      this.isHyphenation = config.isHyphenation || "no";
      window.isHyphenation = this.isHyphenation;
      this.isDarkMode = config.isDarkMode;
      this.isMobile = config.isMobile;
      this.backgroundColor = config.backgroundColor || "";
      this.textOrientation = config.textOrientation;
      window.textOrientation = config.textOrientation;
      this.isShowTotalPage = config.isShowTotalPage || "no";
      this.chapterList = [];
      this.chapterDocList = [];
      this.flattenChapters = [];
      this.book = "";
      this.element = "";
      this.tempLocation = {};
      this.isBionic = config.isBionic || "no";
      this.isReadingRuler = config.isReadingRuler || "no";
      this.isParagraphMode = config.isParagraphMode || "no";
      this.isSpeedReading = config.isSpeedReading || "no";
      this.speedReadingSpeed = config.speedReadingSpeed || 300;
      this.platform = config.platform || "web";
      window.platform = this.platform;
      window.isBionic = this.isBionic;
      this.transMap = {};
      window.transMap = this.transMap;
      this.fullTranslationMode = config.fullTranslationMode || "no";
      window.fullTranslationMode = this.fullTranslationMode;
      this.bookLayout = config.bookLayout || "";
      window.bookLayout = this.bookLayout;
      this.codeHighlight = config.codeHighlight || "";
      window.codeHighlight = this.codeHighlight;
      this.textRules = config.textRules || [];
      window.textRules = this.textRules;
      this.isAllowScript = "no";
      this.flipToNextPage = () => {
      };
      this.flipToPrevPage = () => {
      };
      this.readingRulerManager = new readingRulerUtil_default({
        isReadingRuler: this.isReadingRuler,
        readingRulerLineHeight: config.readingRulerLineHeight,
        readingRulerBackgroundOpacity: config.readingRulerBackgroundOpacity,
        readerMode: this.readerMode,
        isMobile: this.isMobile
      });
      this.readingRulerManager.getDoc = () => this.getDocument();
      this.readingRulerManager.getElement = () => this.element;
      this.readingRulerManager.getIframe = () => this.getIframe();
      this.readingRulerManager.getIsVertical = () => this.isVertical();
      this.readingRulerManager.getOverlayBackground = (doc2) => this.getParagraphOverlayBackground(doc2);
      this.readingRulerManager.nextPage = () => this.next();
      this.readingRulerManager.prevPage = () => this.prev();
      this.speedReadingManager = new speedReadingUtil_default({
        isSpeedReading: this.isSpeedReading,
        speedReadingSpeed: this.speedReadingSpeed,
        isDarkMode: this.isDarkMode,
        readerMode: this.readerMode
      });
      this.speedReadingManager.getDoc = () => this.getDocument();
      this.speedReadingManager.getElement = () => this.element;
      this.speedReadingManager.getOverlayBackground = (doc2) => this.getParagraphOverlayBackground(doc2);
      this.speedReadingManager.getProgress = () => this.getProgress();
      this.speedReadingManager.getChapterDocIndex = () => this.tempLocation.chapterDocIndex;
      this.speedReadingManager.nextPage = () => this.next();
      this.speedReadingManager.prevPage = () => this.prev();
      this.paragraphModeManager = new paragraphModeUtil_default({
        isParagraphMode: this.isParagraphMode,
        readerMode: this.readerMode,
        isMobile: this.isMobile
      });
      this.paragraphModeManager.getDoc = () => this.getDocument();
      this.paragraphModeManager.getElement = () => this.element;
      this.paragraphModeManager.getIframe = () => this.getIframe();
      this.paragraphModeManager.getOverlayBackground = (doc2) => this.getParagraphOverlayBackground(doc2);
      this.paragraphModeManager.getIsVertical = () => this.isVertical();
      this.paragraphModeManager.getChapterDocIndex = () => this.tempLocation.chapterDocIndex || "";
      this.paragraphModeManager.locateParagraph = (el) => this.locateParagraph(el);
      this.paragraphModeManager.nextPage = () => this.next();
      this.paragraphModeManager.prevPage = () => this.prev();
      this.on("rendered", () => {
        this.paragraphModeManager.handleRendered();
        this.readingRulerManager.handleRendered();
        if (!this.speedReadingManager.skipFlip) {
          this.speedReadingManager.handleRendered();
        }
        if (this.estimatedSizePerPage === null) {
          const value = this.computeEstimatedSizePerPage();
          if (value > 1) {
            this.estimatedSizePerPage = value;
          }
        }
      });
      this.mouseDownHandler = () => {
      };
      this.mouseUpHandler = () => {
      };
      this.mouseMoveHandler = (event) => {
      };
      this.touchEventSet = {};
      if (this.isMobile === "yes") {
        console.log = function(...args) {
          window.ReactNativeWebView.postMessage(
            args.map((arg) => String(arg)).join(", ")
          );
        };
        console.info = function(...args) {
          window.ReactNativeWebView.postMessage(
            args.map((arg) => String(arg)).join(", ")
          );
        };
        console.error = function(...args) {
          window.ReactNativeWebView.postMessage(
            args.map((arg) => String(arg)).join(", ")
          );
        };
      }
    }
    isVertical() {
      return this.textOrientation === "vertical" && this.readerMode !== "scroll";
    }
    getPageSize() {
      let scale = this.readerMode === "double" ? 2 : 1;
      let iframe = this.getIframe();
      if (!iframe) return;
      let iframeHeight = iframe?.getBoundingClientRect().height;
      if (this.isVertical()) {
        let section2 = Math.floor(this.element.clientHeight / 12);
        let gap2 = section2 % 2 === 0 ? section2 : section2 - 1;
        return {
          width: this.element.clientWidth,
          height: this.element.clientHeight,
          left: getActualOffsetLeft(this.element),
          top: getActualOffsetTop(this.element),
          scrollTop: this.element.scrollTop,
          scrollLeft: this.element.scrollWidth / 2 - this.element.clientWidth / 2,
          sectionWidth: this.element.clientWidth,
          sectionHeight: (this.element.clientHeight - gap2) / scale,
          gap: gap2
        };
      }
      let section = Math.floor(this.element.clientWidth / 12);
      let gap = section % 2 === 0 ? section : section - 1;
      return {
        width: this.element.clientWidth,
        height: this.element.clientHeight,
        left: getActualOffsetLeft(this.element),
        top: getActualOffsetTop(this.element),
        scrollTop: this.element.scrollTop,
        scrollLeft: this.element.scrollWidth / 2 - this.element.clientWidth / 2,
        sectionWidth: (this.element.clientWidth - gap) / scale,
        sectionHeight: iframeHeight,
        gap
      };
    }
    async scrollToText(text) {
      let doc2 = this.getDocument();
      if (!doc2) return;
      let nodeList = getBlockElement(doc2.body).filter(
        (item) => !isParentBlock(item)
      );
      let audioNodes = nodeList.filter(
        (s) => (s.textContent || "").indexOf(text) > -1
      );
      if (audioNodes.length > 0) {
        let targetNode = audioNodes[0];
        let left = targetNode ? getActualOffsetLeft(targetNode) - convertStyleNum(
          targetNode.marginLeft || parseFloat(getComputedStyle(targetNode).marginLeft)
        ) : 0;
        let top = targetNode ? getActualOffsetTop(targetNode) - convertStyleNum(
          targetNode.marginTop || parseFloat(getComputedStyle(targetNode).marginTop)
        ) : 0;
        if (this.readerMode !== "scroll") {
          if (this.isVertical()) {
            doc2.body.scrollTo(0, top);
          } else {
            doc2.body.scrollTo(left, 0);
          }
        } else {
          this.element.scrollTo(0, top);
        }
      }
      if (this.animation !== "none" && this.isMobile !== "yes") {
        await new Promise((r) => setTimeout(r, 1e3));
      }
      await handleRecord(
        this.element,
        this.readerMode,
        this.flatChapter(this.chapterList),
        this.chapterDocList,
        this.tempLocation,
        doc2,
        null
      );
      this.trigger("scroll-text");
    }
    async goToPage(targetPage) {
      if (this.readerMode === "scroll") {
        if (targetPage < 0) {
          targetPage = 1;
        }
        let top = (targetPage - 1) * (this.element.clientHeight - 50);
        this.element.scrollTo(0, top);
      } else {
        let doc2 = this.getDocument();
        if (!doc2) return;
        if (this.isVertical()) {
          let section = Math.floor(this.element.clientHeight / 12);
          let gap = section % 2 === 0 ? section : section - 1;
          const height = this.element.clientHeight;
          const scrollDistance = height + gap;
          if (this.readerMode === "double") {
            targetPage = (targetPage % 2 === 0 ? targetPage - 2 : targetPage - 1) / 2;
          } else {
            targetPage = targetPage - 1;
          }
          if (targetPage < 0) {
            targetPage = 0;
          }
          const targetScrollTop = targetPage * scrollDistance;
          doc2.body.scrollTo({
            left: 0,
            top: targetScrollTop,
            behavior: this.animation === "sliding" && this.isMobile !== "yes" ? "smooth" : "auto"
          });
        } else {
          let section = Math.floor(this.element.clientWidth / 12);
          let gap = section % 2 === 0 ? section : section - 1;
          const width = this.element.clientWidth;
          const scrollDistance = width + gap;
          if (this.readerMode === "double") {
            targetPage = (targetPage % 2 === 0 ? targetPage - 2 : targetPage - 1) / 2;
          } else {
            targetPage = targetPage - 1;
          }
          if (targetPage < 0) {
            targetPage = 0;
          }
          const targetScrollLeft = targetPage * scrollDistance;
          doc2.body.scrollTo({
            top: 0,
            left: targetScrollLeft,
            behavior: this.animation === "sliding" && this.isMobile !== "yes" ? "smooth" : "auto"
          });
        }
      }
      await this.record();
    }
    resolveChapter(href) {
      let path = href;
      path = path.replace(/^#/, "").replace(/^\.\//, "").replace(/^\//, "");
      if (path.startsWith("../")) {
        path = path.replace(/^\.\.\//, "");
      }
      let chapterIndex = -1;
      if (this.flattenChapters.length === 0) {
        this.flatChapter(this.chapterList);
      }
      for (let index = 0; index < this.flattenChapters.length; index++) {
        if (this.flattenChapters[index].href.includes(path)) {
          chapterIndex = index;
          break;
        }
      }
      if (chapterIndex > -1) {
        let chapter2 = this.flattenChapters[chapterIndex];
        if (href.startsWith("kindle")) {
          if (this.chapterDocList[chapter2.index].href === href) {
            return chapter2;
          } else {
            return null;
          }
        } else {
          return chapter2;
        }
      }
      for (let index = 0; index < this.chapterDocList.length; index++) {
        if (this.chapterDocList[index].href.includes(path)) {
          chapterIndex = index;
          break;
        }
      }
      if (chapterIndex > -1) {
        let chapterDoc = this.chapterDocList[chapterIndex];
        return {
          label: chapterDoc.label || "",
          href: chapterDoc.href,
          index: chapterIndex
        };
      }
      for (let index = 0; index < this.chapterDocList.length; index++) {
        if (this.chapterDocList[index].text && this.chapterDocList[index].text.id && (this.chapterDocList[index].text.id + "").includes(path)) {
          chapterIndex = index;
          break;
        }
      }
      if (chapterIndex > -1) {
        return {
          label: this.chapterDocList[chapterIndex].label || "",
          href: this.chapterDocList[chapterIndex].href,
          index: chapterIndex
        };
      } else {
        return null;
      }
    }
    flatChapter(chapters) {
      let newChapter = [];
      for (let i = 0; i < chapters.length; i++) {
        if (chapters[i].subitems && chapters[i].subitems.length > 0) {
          newChapter.push(chapters[i]);
          newChapter = newChapter.concat(this.flatChapter(chapters[i].subitems));
        } else {
          newChapter.push(chapters[i]);
        }
      }
      this.flattenChapters = newChapter;
      return newChapter;
    }
    getChapter() {
      return this.chapterList;
    }
    getChapterDoc() {
      return this.chapterDocList;
    }
    async goToPercentage(percentage) {
      if (this.flattenChapters.length === 0) {
        this.flatChapter(this.chapterList);
      }
      if (this.flattenChapters.length > 0) {
        if (this.flattenChapters.length === 1) {
          let progressInfo2 = this.getChapterProgress();
          if (!progressInfo2) return;
          let pageNumber = Math.floor(progressInfo2.totalPage * percentage);
          await this.goToPage(pageNumber);
          return;
        }
        let chapterIndex = percentage === 1 ? this.flattenChapters.length - 1 : Math.floor(this.flattenChapters.length * percentage);
        await this.goToChapter(
          this.flattenChapters[chapterIndex].index.toString(),
          this.flattenChapters[chapterIndex].href,
          this.flattenChapters[chapterIndex].label
        );
      }
    }
    async goToChapterIndex(targetChapterIndex) {
      if (this.flattenChapters.length === 0) {
        this.flatChapter(this.chapterList);
      }
      if (this.flattenChapters.length > 0) {
        await this.goToChapter(
          this.flattenChapters[targetChapterIndex].index,
          this.flattenChapters[targetChapterIndex].href,
          this.flattenChapters[targetChapterIndex].label
        );
      }
    }
    async goToChapterDocIndex(chapterDocIndex) {
      if (this.chapterDocList.length > 0) {
        await this.goToChapter(
          chapterDocIndex,
          this.chapterDocList[chapterDocIndex].href,
          this.chapterDocList[chapterDocIndex].label
        );
      }
    }
    async goToChapter(chapterDocIndex, chapterHref, chapterTitle) {
      let doc2 = this.getDocument();
      let iframe = this.getIframe();
      if (!doc2 || !iframe) return;
      await handleRenderChapter(
        parseInt(chapterDocIndex),
        chapterTitle,
        chapterHref,
        this.chapterDocList,
        this.element,
        this.readerMode,
        this.format,
        this.tempLocation,
        doc2,
        iframe
      );
      if (chapterHref && chapterHref.startsWith("kindle")) {
        let result2 = await this.book.resolveHref(chapterHref);
        if (result2.anchor) {
          let node2 = result2.anchor(doc2);
          if (node2) {
            await this.goToNode(node2);
          }
        }
      }
      if (chapterHref && chapterHref.indexOf("#") > -1) {
        await handleScrollPosition(
          this.element,
          this.readerMode,
          "",
          "",
          chapterHref,
          "",
          doc2
        );
      }
      await this.record();
      this.trigger("rendered");
      this.addPageAnimation();
    }
    async goToPosition(bookLocationStr) {
      let doc2 = this.getDocument();
      let iframe = this.getIframe();
      if (!doc2 || !iframe) return;
      let bookLocation = JSON.parse(bookLocationStr);
      this.tempLocation = {
        text: bookLocation.text,
        chapterTitle: bookLocation.chapterTitle,
        chapterDocIndex: bookLocation.chapterDocIndex,
        chapterHref: bookLocation.chapterHref,
        count: bookLocation.count,
        page: bookLocation.page,
        percentage: bookLocation.percentage
      };
      let { text, chapterTitle, chapterDocIndex, chapterHref, count, page, cfi } = bookLocation;
      await handleRenderChapter(
        parseInt(chapterDocIndex),
        chapterTitle,
        chapterHref,
        this.chapterDocList,
        this.element,
        this.readerMode,
        this.format,
        this.tempLocation,
        doc2,
        iframe
      );
      if (cfi) {
        const cfiInfo = new CFI(cfi, {});
        let doc3 = this.getDocument();
        if (!doc3) {
          return;
        }
        const { node: node2, offset } = cfiInfo.resolve(doc3, {});
        if (node2) {
          let element = null;
          let currentNode = node2;
          while (currentNode) {
            const temp = currentNode;
            if (temp.tagName && "h1,h2,h3,h4,h5,h6,p,div,ul,dl,ol,pre,li,dt,dd,blockquote,address,kookitmarker".indexOf(
              temp.tagName.toLowerCase()
            ) > -1) {
              element = temp;
              break;
            }
            currentNode = currentNode.parentNode;
          }
          if (element) {
            count = "ignore";
            text = element.textContent;
          }
        }
      }
      await handleScrollPosition(
        this.element,
        this.readerMode,
        text,
        count,
        "",
        page,
        doc2
      );
      import_rangy_core3.default.init();
      await this.record();
      this.trigger("rendered");
      this.addPageAnimation();
    }
    getDocument() {
      let pageArea = document.getElementById("page-area");
      if (!pageArea) return null;
      let iframe = pageArea.getElementsByTagName("iframe")[0];
      if (!iframe) return null;
      let doc2 = iframe.contentDocument;
      if (!doc2) {
        return null;
      }
      return doc2;
    }
    getIframe() {
      let pageArea = document.getElementById("page-area");
      if (!pageArea) return null;
      let iframe = pageArea.getElementsByTagName("iframe")[0];
      if (!iframe) return null;
      return iframe;
    }
    async goToNode(node2) {
      let doc2 = this.getDocument();
      if (!doc2) {
        return;
      }
      if (!node2) {
        return;
      }
      let targetNode = getCloestBlock(node2, this.element, this.readerMode);
      let left = targetNode ? getActualOffsetLeft(targetNode) - convertStyleNum(
        targetNode.marginLeft || parseFloat(getComputedStyle(targetNode).marginLeft)
      ) : 0;
      let top = targetNode ? getActualOffsetTop(targetNode) - convertStyleNum(
        targetNode.marginTop || parseFloat(getComputedStyle(targetNode).marginTop)
      ) : 0;
      if (this.readerMode !== "scroll") {
        if (this.isVertical()) {
          doc2.body.scrollTo(0, top);
        } else {
          doc2.body.scrollTo(left, 0);
        }
      } else {
        this.element.scrollTo(0, top);
      }
      await this.record();
      this.trigger("rendered");
    }
    async goToXpath(xpath) {
      let doc2 = this.getDocument();
      if (!doc2) return;
      let chapterDocIndexMatch = xpath.match(/\/body\/DocFragment\[(\d+)\]/);
      let chapterDocIndex = chapterDocIndexMatch ? parseInt(chapterDocIndexMatch[1] || "1") - 1 : 0;
      let chapterDoc = this.chapterDocList[chapterDocIndex];
      await handleRenderChapter(
        chapterDocIndex,
        chapterDoc.label || "",
        chapterDoc.href,
        this.chapterDocList,
        this.element,
        this.readerMode,
        this.format,
        this.tempLocation,
        doc2,
        this.getIframe()
      );
      doc2 = this.getDocument();
      if (!doc2) return;
      let newXpath = xpath.replace(/\/body\/DocFragment\[\d+\]/, "");
      newXpath = newXpath.split("/text()")[0];
      const node2 = resolveXPath(newXpath, doc2);
      await this.goToNode(node2);
      import_rangy_core3.default.init();
      await this.record();
      this.trigger("rendered");
    }
    removeContent() {
      this.element.innerHTML = "";
    }
    getParagraphOverlayBackground(doc2) {
      const view = doc2.defaultView || window;
      let color = view.getComputedStyle(doc2.body).backgroundColor;
      if (!color || color === "transparent" || color.replace(/\s/g, "") === "rgba(0,0,0,0)") {
        color = this.backgroundColor;
      }
      return color || "#ffffff";
    }
    // 段落模式下将底层页面静默同步到指定段落所在页，保证阅读进度与
    // 退出段落模式后的位置正确；瞬时滚动，不触发 rendered 事件
    locateParagraph(el) {
      let doc2 = this.getDocument();
      if (!doc2 || !doc2.body || !el) return;
      let left = getActualOffsetLeft(el);
      let top = getActualOffsetTop(el);
      if (this.readerMode !== "scroll") {
        if (this.isVertical()) {
          let section = Math.floor(this.element.clientHeight / 12);
          let gap = section % 2 === 0 ? section : section - 1;
          let scrollDistance = this.element.clientHeight + gap;
          doc2.body.scrollTo(
            0,
            Math.max(0, Math.round(top / scrollDistance)) * scrollDistance
          );
        } else {
          let section = Math.floor(this.element.clientWidth / 12);
          let gap = section % 2 === 0 ? section : section - 1;
          let scrollDistance = this.element.clientWidth + gap;
          doc2.body.scrollTo(
            Math.max(0, Math.round(left / scrollDistance)) * scrollDistance,
            0
          );
        }
      } else {
        this.element.scrollTo(0, top);
      }
      this.record();
    }
    async prev() {
      let doc2 = this.getDocument();
      let iframe = this.getIframe();
      if (!doc2 || !iframe) {
        return;
      }
      if (this.isSpeedReading === "yes" && !this.speedReadingManager.skipFlip) {
        return;
      }
      if (this.isReadingRuler === "yes" && !this.readingRulerManager.skipFlip) {
        const handled = await this.readingRulerManager.handleChange(-1);
        if (handled) return;
      }
      if (this.isParagraphMode === "yes" && !this.paragraphModeManager.skipFlip) {
        const handled = await this.paragraphModeManager.handleChange(-1);
        if (handled) return;
      }
      if (this.readerMode === "scroll" && convertStyleNum(this.element.scrollTop) === 0 || this.isVertical() && convertStyleNum(doc2.body.scrollTop) === 0 || this.readerMode !== "scroll" && !this.isVertical() && convertStyleNum(doc2.body.scrollLeft) === 0) {
        if (this.tempLocation.chapterDocIndex === "0") {
          return;
        }
        await handlePrevChapter(
          this.element,
          this.flatChapter(this.chapterList),
          this.chapterDocList,
          this.readerMode,
          this.format,
          this.tempLocation,
          doc2,
          iframe
        );
        let chapterDocIndex = parseInt(this.tempLocation.chapterDocIndex || "-1");
        if (chapterDocIndex > -1) {
          if (this.readerMode === "scroll") {
            this.element.scrollTo(0, doc2.body.scrollHeight);
          } else if (this.isVertical()) {
            doc2.body.scrollTo(0, doc2.body.scrollHeight);
          } else {
            doc2.body.scrollTo(doc2.body.scrollWidth, 0);
          }
        }
        this.trigger("rendered");
      } else if (this.readerMode === "scroll") {
        this.element.scrollBy({
          left: 0,
          top: -(this.element.clientHeight - 50),
          behavior: "smooth"
        });
      } else {
        await handleScrollPage(
          this.element,
          this.animation,
          1,
          doc2,
          this.flipToNextPage,
          this.flipToPrevPage,
          this.isMobile
        );
      }
      await this.record();
    }
    async next() {
      let doc2 = this.getDocument();
      let iframe = this.getIframe();
      if (!doc2 || !iframe) {
        return;
      }
      if (this.isSpeedReading === "yes" && !this.speedReadingManager.skipFlip) {
        return;
      }
      if (this.isReadingRuler === "yes" && !this.readingRulerManager.skipFlip) {
        const handled = await this.readingRulerManager.handleChange(1);
        if (handled) return;
      }
      if (this.isParagraphMode === "yes" && !this.paragraphModeManager.skipFlip) {
        const handled = await this.paragraphModeManager.handleChange(1);
        if (handled) return;
      }
      if (this.isVertical() && Math.abs(
        doc2.body.scrollHeight - convertStyleNum(doc2.body.scrollTop) - doc2.body.clientHeight
      ) < 50 || Math.abs(
        doc2.body.scrollWidth - convertStyleNum(doc2.body.scrollLeft) - doc2.body.clientWidth
      ) < 50 && this.readerMode !== "scroll" && !this.isVertical() || Math.abs(
        this.element.scrollHeight - convertStyleNum(this.element.scrollTop) - this.element.clientHeight
      ) < 20 && this.readerMode === "scroll") {
        await handleNextChapter(
          this.element,
          this.flatChapter(this.chapterList),
          this.chapterDocList,
          this.readerMode,
          this.format,
          this.tempLocation,
          doc2,
          iframe
        );
        this.trigger("rendered");
        return;
      } else if (this.readerMode === "scroll") {
        if (Math.abs(
          this.element.scrollHeight - convertStyleNum(this.element.scrollTop) - this.element.clientHeight
        ) - (this.element.clientHeight - 50) < 20 && Math.abs(
          this.element.scrollHeight - convertStyleNum(this.element.scrollTop) - this.element.clientHeight
        ) > 20) {
          this.element.scrollTo({
            left: 0,
            top: this.element.scrollHeight - 20,
            behavior: "smooth"
          });
        } else {
          this.element.scrollBy({
            left: 0,
            top: this.element.clientHeight - 50,
            behavior: "smooth"
          });
        }
      } else {
        await handleScrollPage(
          this.element,
          this.animation,
          -1,
          doc2,
          this.flipToNextPage,
          this.flipToPrevPage,
          this.isMobile
        );
      }
      await this.record();
    }
    async slideTo(direction) {
      let doc2 = this.getDocument();
      if (!doc2) return;
      if (this.isPageAnimationDisabled()) {
        if (direction === "left") {
          await this.prev();
        } else if (direction === "right") {
          await this.next();
        }
        return;
      }
      let section = Math.floor(this.element.clientWidth / 12);
      let gap = section % 2 === 0 ? section : section - 1;
      slideAnimateTo(direction, this.format, doc2, doc2, this.element, this, gap);
    }
    async prevChapter() {
      let doc2 = this.getDocument();
      let iframe = this.getIframe();
      if (!doc2 || !iframe) return;
      await handlePrevChapter(
        this.element,
        this.flatChapter(this.chapterList),
        this.chapterDocList,
        this.readerMode,
        this.format,
        this.tempLocation,
        doc2,
        iframe
      );
      await this.record();
      this.trigger("rendered");
    }
    async nextChapter() {
      let doc2 = this.getDocument();
      let iframe = this.getIframe();
      if (!doc2 || !iframe) return;
      await handleNextChapter(
        this.element,
        this.flatChapter(this.chapterList),
        this.chapterDocList,
        this.readerMode,
        this.format,
        this.tempLocation,
        doc2,
        iframe
      );
      await this.record();
      this.trigger("rendered");
    }
    async visibleText() {
      let doc2 = this.getDocument();
      if (!doc2) return "";
      return getVisibleText(this.element, this.readerMode, doc2);
    }
    async audioText() {
      let doc2 = this.getDocument();
      if (!doc2) return [];
      let audioTexts = await getAudioText(
        this.element,
        this.readerMode,
        doc2,
        false
      );
      return audioTexts;
    }
    async getRestAudioText(count) {
      const currentIndex = parseInt(this.tempLocation.chapterDocIndex || "0");
      const result2 = [];
      const startIndex = currentIndex + 1;
      const endIndex = Math.min(startIndex + count, this.chapterDocList.length);
      for (let i = startIndex; i < endIndex; i++) {
        const chapterText = await handleOneChapterDoc(
          this.chapterDocList[i].text,
          true
        );
        if (!chapterText) continue;
        const chapterDoc = new DOMParser().parseFromString(
          chapterText,
          "text/html"
        );
        const audioText = getAudioText(
          this.element,
          this.readerMode,
          chapterDoc,
          true
        );
        result2.push({
          chapterDocIndex: i,
          audioText: audioText.filter((s) => !!s)
        });
      }
      return result2;
    }
    async chapterText() {
      let doc2 = this.getDocument();
      if (!doc2) return "";
      return doc2.body.textContent || "";
    }
    async getImageList(chapterDocIndex) {
      if (this.format === "PDF") return [];
      let urls;
      if (chapterDocIndex === void 0 || chapterDocIndex === null) {
        const doc2 = this.getDocument();
        if (!doc2) return [];
        urls = collectChapterImageUrls(doc2.body);
      } else {
        if (chapterDocIndex < 0 || chapterDocIndex > this.chapterDocList.length - 1) {
          return [];
        }
        const chapterText = await handleOneChapterDoc(
          this.chapterDocList[chapterDocIndex].text,
          false
        );
        if (!chapterText) return [];
        const chapterDoc = new DOMParser().parseFromString(
          chapterText,
          "text/html"
        );
        urls = collectChapterImageUrls(chapterDoc.body);
      }
      if (this.isMobile !== "yes") {
        return urls;
      }
      return Promise.all(
        urls.map(async (url) => {
          if (!url.startsWith("blob:")) return url;
          try {
            return await blobUrlToBase64(url);
          } catch {
            return url;
          }
        })
      );
    }
    autoScroll(rate, isStart) {
      let doc2 = this.getDocument();
      if (!doc2) return;
      if (this.scrollTimer) {
        cancelAnimationFrame(this.scrollTimer);
        this.scrollTimer = null;
      }
      if (this.recordTimer) {
        clearInterval(this.recordTimer);
        this.recordTimer = null;
      }
      if (isStart === "no" || this.readerMode !== "scroll") {
        return;
      }
      let accumulatedScroll = 0;
      let frameCount = 0;
      const scrollStep = () => {
        accumulatedScroll += rate;
        frameCount++;
        if (Math.abs(rate) < 1) {
          const shouldScroll = Math.abs(accumulatedScroll) >= 0.5 || frameCount % Math.max(1, Math.floor(30 / Math.abs(rate))) === 0;
          if (shouldScroll && Math.abs(accumulatedScroll) >= 0.1) {
            const scrollAmount = Math.round(accumulatedScroll * 10) / 10;
            this.element.scrollBy({
              left: 0,
              top: scrollAmount,
              behavior: "auto"
            });
            accumulatedScroll = 0;
            frameCount = 0;
          }
        } else {
          if (Math.abs(accumulatedScroll) >= 1) {
            const scrollAmount = Math.floor(accumulatedScroll);
            this.element.scrollBy({
              left: 0,
              top: scrollAmount,
              behavior: "auto"
            });
            accumulatedScroll -= scrollAmount;
          }
        }
        this.scrollTimer = requestAnimationFrame(scrollStep);
      };
      this.scrollTimer = requestAnimationFrame(scrollStep);
      this.recordTimer = setInterval(() => {
        if (this.readerMode === "scroll" && Math.abs(
          this.element.scrollHeight - this.element.scrollTop - this.element.clientHeight
        ) < 10) {
          this.nextChapter();
        }
        this.record();
      }, 3e3);
    }
    autoScrollIOS(rate, isStart) {
      let doc2 = this.getDocument();
      if (!doc2) return;
      if (this.scrollTimer) {
        clearInterval(this.scrollTimer);
        this.scrollTimer = null;
      }
      if (this.recordTimer) {
        clearInterval(this.recordTimer);
        this.recordTimer = null;
      }
      if (isStart === "no" || this.readerMode !== "scroll") {
        return;
      }
      let accumulatedScroll = 0;
      let realScrollTop = this.element.scrollTop;
      this.scrollTimer = setInterval(() => {
        accumulatedScroll += rate;
        if (doc2) {
          doc2.body.style.transform = `translateY(-${accumulatedScroll}px)`;
          if (Math.abs(accumulatedScroll) >= 50) {
            doc2.body.style.transform = "translateY(0px)";
            realScrollTop += accumulatedScroll;
            this.element.scrollTo({
              left: 0,
              top: realScrollTop,
              behavior: "auto"
            });
            accumulatedScroll = 0;
          }
        }
      }, 30);
      this.recordTimer = setInterval(() => {
        if (this.readerMode === "scroll" && Math.abs(
          this.element.scrollHeight - this.element.scrollTop - this.element.clientHeight
        ) < 10) {
          this.nextChapter();
        }
        this.record();
      }, 3e3);
    }
    highlightSearchNode(text, style) {
      let doc2 = this.getDocument();
      if (!doc2) return;
      handleHighlightSearchNode(text, style, doc2);
    }
    highlightAudioNode(text, style) {
      let doc2 = this.getDocument();
      if (!doc2) return;
      handleHighlightAudioNode(text, style, doc2, this.element, this.readerMode);
    }
    async doSearch(keyword) {
      if (this.format === "PDF") {
        return await getPDFSearchResult(keyword, this.chapterDocList);
      } else {
        return await getSearchResult(keyword, this.chapterDocList);
      }
    }
    getChapterSizes() {
      if (this.chapterSizeCache) return this.chapterSizeCache;
      if (this.isShowTotalPage !== "yes") {
        return { sizes: [], total: 0, pages: [] };
      }
      const sizes = this.chapterDocList.map(
        (item) => item?.text ? item.text.size || item.text.length || 1 : 1
      );
      const sizeList = cumulativeSumWithPrevious(sizes);
      const pages = sizeList.map(
        (size2) => Math.round(size2 / this.getEstimatedSizePerPage()) * (this.readerMode === "double" ? 2 : 1) + 1
      );
      const total = sizes.reduce((a, b) => a + b, 0);
      this.chapterSizeCache = { sizes, total, pages };
      this.trigger("chapter-pages");
      return this.chapterSizeCache;
    }
    // 每个可见字符对应的"章节文件大小"单位数（size 源自源文件，已包含文字内容与标记开销）
    static SIZE_PER_CHAR = {
      TXT: 1.5,
      MD: 2,
      DOCX: 2.5,
      HTML: 3,
      MHTML: 3,
      XHTML: 3,
      HTM: 3,
      XML: 3,
      EPUB: 4.5,
      MOBI: 4.5,
      FB2: 5,
      PDFTEXT: 0.5
    };
    getEstimatedSizePerPage() {
      if (this.estimatedSizePerPage !== null) {
        return this.estimatedSizePerPage;
      }
      return this.computeEstimatedSizePerPage();
    }
    computeEstimatedSizePerPage() {
      const doc2 = this.getDocument();
      if (!doc2 || !doc2.body) return 1;
      if (this.format === "CACHE") return 1;
      const bytesPerChar = _GeneralRender.SIZE_PER_CHAR[(this.format || "").toUpperCase()] || 3;
      const vertical = isVerticalLayout() && this.readerMode !== "scroll";
      const scroll = this.readerMode === "scroll";
      let inlinePx = 0;
      let blockPx = 0;
      if (scroll) {
        inlinePx = this.element.clientWidth;
        blockPx = this.element.clientHeight - 50;
      } else if (vertical) {
        inlinePx = doc2.body.clientHeight;
        blockPx = doc2.body.clientWidth;
      } else {
        inlinePx = doc2.body.clientWidth;
        blockPx = doc2.body.clientHeight;
      }
      if (inlinePx <= 0 || blockPx <= 0) return 1;
      const view = doc2.defaultView || window;
      const bodyStyle = view.getComputedStyle(doc2.body);
      const sampleEl = doc2.body.querySelector(
        "div,p:not(.hide),li,blockquote,dd,dt,pre,td"
      );
      if (!sampleEl) return 1;
      const style = view.getComputedStyle(sampleEl);
      const fontSize = parseFloat(style.fontSize) || parseFloat(bodyStyle.fontSize) || 18;
      let lineHeightPx = parseFloat(style.lineHeight);
      if (!lineHeightPx || style.lineHeight === "normal") {
        lineHeightPx = fontSize * 1.25;
      }
      const letterSpacing = parseFloat(style.letterSpacing) || 0;
      const marginBlock = (parseFloat(style.marginTop) || 0) + (parseFloat(style.marginBottom) || 0);
      const charAdvancePx = Math.max(fontSize + letterSpacing, 1);
      const charsPerLine = Math.max(Math.floor(inlinePx / charAdvancePx), 1);
      const effectiveLineHeight = lineHeightPx + marginBlock / 3;
      const charsPerPage = Math.max(
        Math.floor(blockPx / effectiveLineHeight) * charsPerLine,
        1
      );
      const value = Math.max(charsPerPage * bytesPerChar, 1);
      if (this.readerMode === "double") {
        return value / 2;
      }
      return value;
    }
    getChapterProgress() {
      let doc2 = this.getDocument();
      if (!doc2) return null;
      return {
        ...progressInfo(this.readerMode, doc2, this.element),
        percentage: this.tempLocation.percentage
      };
    }
    getProgress() {
      const chapterProgress = this.getChapterProgress();
      if (!chapterProgress) return;
      if (this.isShowTotalPage !== "yes") {
        return { ...chapterProgress };
      }
      let sizePerPage = this.getEstimatedSizePerPage();
      if (sizePerPage === 1) {
        return { ...chapterProgress };
      }
      const { total } = this.getChapterSizes();
      const totalPage = Math.max(
        Math.round(total / sizePerPage),
        chapterProgress.totalPage
      );
      const currentPage = Math.round(totalPage * parseFloat(chapterProgress.percentage || "0")) + 1;
      return {
        totalPage: totalPage * (this.readerMode === "double" ? 2 : 1),
        currentPage,
        percentage: chapterProgress.percentage
      };
    }
    getPages() {
      if (this.chapterSizeCache) {
        const { pages } = this.chapterSizeCache;
        return pages;
      }
      return [];
    }
    async record() {
      if (this.animation !== "none" && this.isMobile !== "yes") {
        await new Promise((r) => setTimeout(r, 1e3));
      }
      let doc2 = this.getDocument();
      if (!doc2) return;
      await handleRecord(
        this.element,
        this.readerMode,
        this.flatChapter(this.chapterList),
        this.chapterDocList,
        this.tempLocation,
        doc2,
        null
      );
      this.trigger("page-changed");
    }
    getPosition() {
      return this.tempLocation;
    }
    async getBatchTransTexts() {
      let restTexts = await this.audioText();
      restTexts = restTexts.slice(0, 200);
      let totalLength = 0;
      restTexts = restTexts.filter((item) => {
        totalLength += item.length;
        return totalLength <= 1e4;
      });
      restTexts = restTexts.filter(
        (item) => !this.transMap[item] || !this.transMap[item].text
      );
      return restTexts.filter((item) => item.trim().length > 0);
    }
    async getNotePosition() {
      let doc2 = this.getDocument();
      if (!doc2) return;
      let selectedElement = getSelectedElement(doc2);
      if (!selectedElement) return;
      await handleRecord(
        this.element,
        this.readerMode,
        this.flatChapter(this.chapterList),
        this.chapterDocList,
        this.tempLocation,
        doc2,
        selectedElement
      );
      return this.tempLocation;
    }
    setStyle(css2) {
      let doc2 = this.getDocument();
      if (!doc2) return;
      const styleId = "kookit-default-style";
      let existingStyle = doc2.head.querySelector(`style#${styleId}`);
      if (existingStyle) {
        existingStyle.innerHTML = css2;
      } else {
        var defaultStyle = document.createElement("style");
        defaultStyle.id = styleId;
        defaultStyle.innerHTML = css2;
        doc2.head.appendChild(defaultStyle);
      }
    }
    async getHighlightCoords() {
      let doc2 = this.getDocument();
      let iframe = this.getIframe();
      if (!doc2 || !iframe) return;
      let charRange = import_rangy_core3.default.getSelection(iframe).saveCharacterRanges(doc2.body)[0];
      return charRange;
    }
    async renderHighlighters(notes2, handleNoteClick) {
      notes2 = notes2.reverse();
      let doc2 = this.getDocument();
      let iframe = this.getIframe();
      if (!doc2 || !iframe) return;
      clearHighlight(doc2);
      const batchItems = notes2.map((item) => ({
        range: JSON.parse(item.range),
        colorCode: item.color,
        noteKey: item.key,
        isNote: item.notes !== "",
        noteContent: item.notes || ""
      }));
      try {
        await showNoteHighlightBatch(
          batchItems,
          handleNoteClick,
          doc2,
          iframe,
          this.isMobile === "yes"
        );
      } catch (e) {
        console.error(
          e,
          "Exception has been caught when restore character ranges."
        );
      }
    }
    removeOneNote(key, chapterDocIndex) {
      let doc2 = this.getDocument();
      if (!doc2) return;
      const icons = doc2.querySelectorAll(
        ".kookit-note-icon[data-key='" + key + "']"
      );
      for (let index = 0; index < icons.length; index++) {
        icons[index].parentNode?.removeChild(icons[index]);
      }
      const elements = doc2.querySelectorAll(
        "span.kookit-note[data-key='" + key + "']"
      );
      for (let index = 0; index < elements.length; index++) {
        const element = elements[index];
        const parent = element.parentNode;
        if (!parent) continue;
        while (element.firstChild) {
          parent.insertBefore(element.firstChild, element);
        }
        parent.removeChild(element);
        parent.normalize();
      }
    }
    async createOneNote(item, handleNoteClick) {
      let doc2 = this.getDocument();
      let iframe = this.getIframe();
      if (!doc2 || !iframe) return;
      showNoteHighlight(
        JSON.parse(item.range),
        item.color,
        item.key,
        handleNoteClick,
        doc2,
        iframe,
        item.notes !== "",
        this.isMobile === "yes",
        item.notes || ""
      );
    }
    isPageAnimationDisabled() {
      return this.isMobile === "yes" && (this.isParagraphMode === "yes" || this.isReadingRuler === "yes" || this.isSpeedReading === "yes");
    }
    addPageAnimation = (backgroundColor) => {
      if (this.animation !== "mimical") return;
      if (this.isPageAnimationDisabled()) return;
      const progress2 = this.getChapterProgress();
      if (!progress2?.totalPage) return;
      const pageAnimation = addPageAnimation(
        progress2.totalPage,
        this.isDarkMode,
        backgroundColor || this.backgroundColor,
        Math.max(0, Math.floor(progress2.currentPage || 1) - 1)
      );
      if (!pageAnimation) return;
      this.flipToNextPage = pageAnimation.flipToNextPage;
      this.flipToPrevPage = pageAnimation.flipToPrevPage;
      this.mouseDownHandler = pageAnimation.mouseDownHandler;
      this.mouseUpHandler = pageAnimation.mouseUpHandler;
      this.mouseMoveHandler = pageAnimation.mouseMoveHandler;
    };
    async displayFontBase64(fontName, fontBase64, fontFormat, fontType) {
      let doc2 = this.getDocument();
      if (!doc2 || fontBase64.length === 0) return;
      const font = new FontFace(
        fontName,
        `url(data:font/${fontType};charset=utf-8;base64,${fontBase64})`
      );
      let loadedFont = await font.load();
      document.fonts.add(loadedFont);
      const fontFaceCSS = "@font-face {  font-family: '" + fontName + "';  src: url('data:font/" + fontType + ";charset=utf-8;base64," + fontBase64 + "') format('" + fontFormat + "');}";
      const styleElement = document.createElement("style");
      styleElement.type = "text/css";
      styleElement.appendChild(document.createTextNode(fontFaceCSS));
      doc2.head.appendChild(styleElement);
    }
    async displayFontUrl(fontName, fontUrl) {
      let doc2 = this.getDocument();
      if (!doc2 || fontUrl.length === 0) return;
      const font = new FontFace(fontName, `url(${fontUrl})`);
      let loadedFont = await font.load();
      document.fonts.add(loadedFont);
      const fontFaceCSS = "@font-face {  font-family: '" + fontName + "';  src: url('" + fontUrl + "') format('truetype');}";
      const styleElement = document.createElement("style");
      styleElement.type = "text/css";
      styleElement.appendChild(document.createTextNode(fontFaceCSS));
      doc2.head.appendChild(styleElement);
    }
    getAllDocuments() {
      let doc2 = this.getDocument();
      if (!doc2) return [];
      if (this.format !== "PDF" && !this.format?.startsWith("CB")) {
        return [doc2];
      }
      let iframes = doc2.querySelectorAll("iframe");
      let documents = [];
      iframes.forEach((iframe) => {
        let iframeDoc = iframe.contentDocument;
        if (iframeDoc) {
          documents.push(iframeDoc);
        }
      });
      return [doc2, ...documents];
    }
    getAllIframes() {
      let iframe = this.getIframe();
      if (!iframe) return [];
      if (this.format !== "PDF" && !this.format?.startsWith("CB")) {
        return [iframe];
      }
      let doc2 = this.getDocument();
      if (!doc2) return [];
      let iframes = doc2.querySelectorAll("iframe");
      let iframeElements = [];
      iframes.forEach((iframe2) => {
        let iframeElement = iframe2;
        iframeElements.push(iframeElement);
      });
      return [iframe, ...iframeElements];
    }
    addTouchEvent(isAndroid, touchControlRule) {
      let docs = this.getAllDocuments();
      let iframes = this.getAllIframes();
      const animation = this.isPageAnimationDisabled() ? "none" : this.animation;
      for (let index = 0; index < docs.length; index++) {
        const doc2 = docs[index];
        const iframe = iframes[index];
        if (!doc2 || !iframe) continue;
        let iframeId = iframe.id;
        if (this.touchEventSet[iframeId]) {
          continue;
        }
        this.touchEventSet[iframeId] = true;
        if (isAndroid === "yes") {
          addAndroidTouchEvent(
            doc2,
            iframe,
            this.element,
            this.readerMode,
            animation,
            this.format,
            touchControlRule,
            this
          );
        } else {
          addAppleTouchEvent(
            doc2,
            iframe,
            this.element,
            this.readerMode,
            animation,
            this.format,
            touchControlRule,
            this
          );
        }
      }
    }
    clearSelection() {
      let iframes = this.getAllIframes();
      for (let index = 0; index < iframes.length; index++) {
        const iframe = iframes[index];
        if (!iframe) continue;
        let iWin = iframe.contentWindow || iframe.contentDocument?.defaultView;
        if (!iWin || !iWin.getSelection()) return;
        iWin.getSelection()?.empty();
      }
    }
    getTargetHref(event) {
      let href = "";
      if (!event || !event.target) return href;
      if (event.target.innerText && event.target.innerText.startsWith("http")) {
        href = event.target.innerText;
      }
      let currentElement = event.target;
      while (currentElement && currentElement.tagName !== "BODY") {
        if (currentElement.getAttribute) {
          const elementHref = currentElement.getAttribute("href");
          if (elementHref) {
            href = elementHref || "";
            break;
          }
        }
        currentElement = currentElement.parentNode;
      }
      return href;
    }
    async handleLinkJump(href, event) {
      let doc2 = this.getDocument();
      if (!doc2) return { handled: false };
      if (href && this.format === "MOBI" && (href.startsWith("kindle:") || href.indexOf("filepos") > -1)) {
        let chapterInfo = this.resolveChapter(href);
        if (chapterInfo) {
          await this.goToChapter(
            chapterInfo.index,
            chapterInfo.href,
            chapterInfo.label
          );
          return { handled: true, redirectChapter: true };
        }
        let result2 = await this.book.resolveHref(href);
        let chapterDocIndex = this.tempLocation.chapterDocIndex;
        if (result2.index === parseInt(chapterDocIndex)) {
          let element = result2.anchor(doc2);
          if (!element) return { handled: false };
          let id = element.getAttribute("id") || "";
          result2 = { ...result2, id };
        }
        if (!result2.anchor) {
          return { handled: false };
        }
        let currentPosition = this.getPosition();
        if (result2.index === parseInt(currentPosition.chapterDocIndex)) {
          let node2 = result2.anchor(doc2);
          if (node2) {
            href = "#" + node2.getAttribute("id");
          }
        } else {
          if (isElementFootnote(event.target)) {
            let blob = await fetch(
              await this.chapterDocList[result2.index].text.load()
            ).then((r) => r.blob());
            let chapterText = await blob.text();
            let node2 = result2.anchor(
              new DOMParser().parseFromString(chapterText, "text/html")
            );
            if (!node2) {
              return { handled: false };
            }
            return {
              handled: true,
              isShowMenu: true,
              isJump: false,
              href: "",
              node: node2
            };
          }
          return { handled: true };
        }
      }
      if (href && href.indexOf("../") === -1 && (href.indexOf("http") === 0 || href.indexOf("mailto") === 0) && href.indexOf("OEBPF") === -1 && href.indexOf("OEBPS") === -1 && href.indexOf("footnote") === -1 && href.indexOf("blob") === -1 && href.indexOf("data:application") === -1) {
        return { handled: true, href, external: true };
      } else if (href && this.resolveChapter(href)) {
        let chapterInfo = this.resolveChapter(href);
        if (!chapterInfo) return { handled: false };
        await this.goToChapter(
          chapterInfo.index,
          chapterInfo.href,
          chapterInfo.label
        );
        return { handled: true, redirectChapter: true };
      } else if (href && href.indexOf("#") > -1) {
        let id = href.split("#").reverse()[0];
        let node2 = doc2.body.querySelector("#" + CSS.escape(id));
        let rect = event.target.getBoundingClientRect();
        let isJump = false;
        if (!node2 || event.target === node2 || node2.contains(event.target)) {
          if (href.indexOf("#") !== 0) {
            while (href.startsWith(".")) {
              href = href.substring(1);
            }
            let chapterInfo = this.resolveChapter(href.split("#")[0]);
            if (!chapterInfo) return { handled: false };
            if (isElementFootnote(event.target)) {
              let blob = await fetch(
                await this.chapterDocList[chapterInfo.index].text.load()
              ).then((r) => r.blob());
              let chapterText = await blob.text();
              node2 = new DOMParser().parseFromString(chapterText, "text/html").body.querySelector("#" + CSS.escape(id));
              if (!node2) {
                return { handled: false };
              }
              return {
                handled: true,
                isShowMenu: true,
                isJump: false,
                href: "",
                node: node2
              };
            } else {
              await this.goToChapter(
                chapterInfo.index,
                chapterInfo.href,
                chapterInfo.label
              );
            }
          }
          node2 = doc2.body.querySelector("#" + CSS.escape(id));
          if (!node2) {
            return { handled: false };
          }
          isJump = true;
          await this.goToNode(node2);
        }
        if (isElementFootnote(event.target)) {
          return {
            handled: true,
            isShowMenu: true,
            isJump,
            href,
            node: node2
          };
        }
        return { handled: true };
      } else if (href && this.book.resolveHref && this.book.resolveHref(href)) {
        let chapterInfo = await this.book.resolveHref(href);
        if (!chapterInfo) return { handled: false };
        await this.goToChapter(
          chapterInfo.index,
          chapterInfo.href,
          chapterInfo.label
        );
        return { handled: true, redirectChapter: true };
      }
      return { handled: false };
    }
    async getFootnoteContent(node2) {
      if (isElementFootnote(node2) || !node2.textContent.trim() || node2.tagName === "A") {
        let next = node2.nextSibling;
        let content = node2.textContent;
        while (next && (next.tagName !== node2.tagName || !content.trim())) {
          content += next.textContent;
          next = next.nextSibling;
        }
        if (!content.trim() || isContentFootnote(content)) {
          let candidate = node2.parentNode;
          while (candidate && candidate.tagName !== "BODY") {
            const candidateText = candidate.textContent || "";
            if (candidateText.trim() && !isContentFootnote(candidateText)) {
              break;
            }
            candidate = candidate.parentNode;
          }
          if (!candidate) {
            return { handled: false };
          }
          node2 = candidate;
        } else if (content.trim() && content.trim().length <= 3e3) {
          node2 = document.createElement("div");
          node2.innerHTML = content;
        }
      }
      let htmlContent = node2.innerHTML;
      if (!node2.textContent.trim()) {
        return { handled: false };
      }
      if (node2.textContent.trim() && node2.textContent.trim().length > 3e3) {
        return { handled: false };
      }
      htmlContent = await processHtml(htmlContent);
      return { handled: true, content: htmlContent };
    }
    handleBatchTransResult(sourcetexts, targetTexts) {
      let doc2 = this.getDocument();
      let iframe = this.getIframe();
      if (!doc2 || !iframe) return;
      for (let index = 0; index < sourcetexts.length; index++) {
        const sourceText = sourcetexts[index];
        if (this.transMap[sourceText]) {
          this.transMap[sourceText].text = targetTexts[index];
          let elements = doc2.querySelectorAll(
            "#" + CSS.escape(this.transMap[sourceText].id)
          );
          for (let i = 0; i < elements.length; i++) {
            const element = elements[i];
            if (element) {
              element.setAttribute(
                "data-kookit-translation",
                targetTexts[index] || ""
              );
              element.classList.remove("kookit-translation-loading");
              if (this.fullTranslationMode === "target") {
                element.setAttribute(
                  "style",
                  (element.getAttribute("style") || "") + ";font-size:0px !important;"
                );
                let childElements = element.querySelectorAll("*");
                childElements.forEach((child) => {
                  child.setAttribute(
                    "style",
                    (child.getAttribute("style") || "") + ";font-size:0px !important;"
                  );
                });
              }
            }
          }
        }
      }
      if (this.readerMode === "scroll") {
        iframe.height = doc2.body.scrollHeight + "px";
        iframe.height = doc2.body.scrollHeight + 300 + "px";
      }
    }
    handleWordDefinitionResult(results, lang, locale) {
      let doc2 = this.getDocument();
      let iframe = this.getIframe();
      if (!doc2 || !iframe) return;
      clearWordDefinitions(doc2);
      const nodeList = getBlockElement(doc2.body).filter(
        (item) => !isParentBlock(item)
      );
      for (const result2 of results) {
        const { text, words } = result2;
        if (!words || words.length === 0) continue;
        const targetNode = nodeList.find(
          (n) => n.textContent === text
        );
        if (!targetNode) continue;
        const nodeDefMap = {};
        for (const def of words) {
          if (lang === "zh") {
            const simplified = def.simplified || "";
            const traditional = def.traditional || "";
            if (simplified) nodeDefMap[simplified] = def;
            if (traditional && traditional !== simplified)
              nodeDefMap[traditional] = def;
          } else {
            const key = (def.word || "").toLowerCase();
            if (key) nodeDefMap[key] = def;
          }
        }
        applyWordDefinitions(
          nodeDefMap,
          doc2,
          lang,
          locale,
          targetNode
        );
      }
      if (this.readerMode === "scroll") {
        iframe.height = doc2.body.scrollHeight + "px";
        iframe.height = doc2.body.scrollHeight + 300 + "px";
      }
    }
    clearWordDefinitionResult() {
      let doc2 = this.getDocument();
      if (!doc2) return;
      clearWordDefinitions(doc2);
    }
  };
  var GeneralRender_default = GeneralRender;

  // vendor/kookit/src/utils/generalParser.ts
  var isString = (value) => {
    return typeof value === "string" || value instanceof String;
  };
  var GeneralParser = class {
    book;
    chapterList;
    flattenChapters;
    chapterDocList;
    constructor(book) {
      this.book = book;
      this.chapterList = [];
      this.flattenChapters = [];
      this.chapterDocList = [];
    }
    unescapeHtml(htmlStr) {
      if (!htmlStr) return "";
      const doc2 = new DOMParser().parseFromString(htmlStr, "text/html");
      return doc2.documentElement.textContent || "";
    }
    async getChapter(toc) {
      if (toc) {
        this.chapterList = await Promise.all(
          toc.map(async (item, index) => {
            let chapterIndex = index;
            try {
              if (item.href) {
                const resolved = await this.book.resolveHrefIndex(item.href);
                if (resolved) {
                  chapterIndex = resolved.index;
                }
              }
            } catch (error) {
              console.error(error);
            }
            return {
              label: this.unescapeHtml(item.label) ? this.unescapeHtml(item.label) : chapterIndex + "",
              href: item.href ? item.href : "title" + chapterIndex,
              index: chapterIndex,
              subitems: item.subitems ? await this.getChapter(item.subitems) : []
            };
          })
        );
      } else {
        this.chapterList = await Promise.all(
          this.book.sections.map(async (item, index) => {
            return {
              label: item && item.label && this.unescapeHtml(item.label) ? this.unescapeHtml(item.label) : index + "",
              href: item && item.href ? item.href : "title" + index,
              index,
              subitems: item && item.subitems ? await this.getChapter(item.subitems) : []
            };
          })
        );
      }
      this.flattenChapters = this.flatChapter(this.chapterList);
      return this.chapterList;
    }
    async getChapterDoc() {
      const chapterIndexList = this.flattenChapters.map((item) => item.index);
      return this.book.sections.map((item, index) => {
        if (chapterIndexList.indexOf(index) > -1) {
          return {
            label: this.unescapeHtml(
              this.flattenChapters[chapterIndexList.indexOf(index)].label
            ),
            href: this.flattenChapters[chapterIndexList.indexOf(index)].href,
            text: item
          };
        } else {
          return {
            label: "",
            href: "",
            text: item
          };
        }
      });
    }
    flatChapter(chapters) {
      let newChapter = [];
      for (let i = 0; i < chapters.length; i++) {
        if (chapters[i].subitems && chapters[i].subitems.length > 0) {
          newChapter.push(chapters[i]);
          newChapter = newChapter.concat(this.flatChapter(chapters[i].subitems));
        } else {
          newChapter.push(chapters[i]);
        }
      }
      return newChapter;
    }
    getMetadata() {
      return new Promise(async (resolve, reject2) => {
        const metadata = this.book.metadata;
        let author = metadata.author && metadata.author[0] && metadata.author[0].name && isString(metadata.author[0].name) ? metadata.author[0].name : metadata.author && metadata.author[0] && isString(metadata.author[0]) ? metadata.author[0] : metadata.author && isString(metadata.author) ? metadata.author : "";
        try {
          const blob = await this.book.getCover();
          var reader = new FileReader();
          reader.readAsDataURL(blob);
          reader.onloadend = () => {
            resolve({
              ...metadata,
              name: metadata.title,
              author,
              description: metadata.description,
              publisher: metadata.publisher,
              cover: reader.result
            });
          };
        } catch (error) {
          console.error(error);
          try {
            resolve({
              ...metadata,
              name: metadata.title,
              author,
              description: metadata.description,
              publisher: metadata.publisher,
              cover: ""
            });
          } catch (error2) {
            console.error(error2);
            reject2(error2);
          }
        }
      });
    }
  };
  var generalParser_default = GeneralParser;

  // vendor/kookit/src/libs/epubcfi.js
  var findIndices = (arr, f) => arr.map((x, i, a) => f(x, i, a) ? i : null).filter((x) => x != null);
  var splitAt = (arr, is) => [-1, ...is, arr.length].reduce(
    ({ xs, a }, b) => ({ xs: xs?.concat([arr.slice(a + 1, b)]) ?? [], a: b }),
    {}
  ).xs;
  var concatArrays = (a, b) => a.slice(0, -1).concat([a[a.length - 1].concat(b[0])]).concat(b.slice(1));
  var isNumber = /\d/;
  var isCFI = /^epubcfi\((.*)\)$/;
  var escapeCFI = (str) => str.replace(/[\^[\](),;=]/g, "^$&");
  var wrap2 = (x) => isCFI.test(x) ? x : `epubcfi(${x})`;
  var unwrap = (x) => x.match(isCFI)?.[1] ?? x;
  var lift = (f) => (...xs) => `epubcfi(${f(...xs.map((x) => x.match(isCFI)?.[1] ?? x))})`;
  var joinIndir = lift((...xs) => xs.join("!"));
  var tokenizer = (str) => {
    const tokens = [];
    let state2, escape, value = "";
    const push2 = (x) => (tokens.push(x), state2 = null, value = "");
    const cat = (x) => (value += x, escape = false);
    for (const char of Array.from(str.trim()).concat("")) {
      if (char === "^" && !escape) {
        escape = true;
        continue;
      }
      if (state2 === "!") push2(["!"]);
      else if (state2 === ",") push2([","]);
      else if (state2 === "/" || state2 === ":") {
        if (isNumber.test(char)) {
          cat(char);
          continue;
        } else push2([state2, parseInt(value)]);
      } else if (state2 === "~") {
        if (isNumber.test(char) || char === ".") {
          cat(char);
          continue;
        } else push2(["~", parseFloat(value)]);
      } else if (state2 === "@") {
        if (char === ":") {
          push2(["@", parseFloat(value)]);
          state2 = "@";
          continue;
        }
        if (isNumber.test(char) || char === ".") {
          cat(char);
          continue;
        } else push2(["@", parseFloat(value)]);
      } else if (state2 === "[") {
        if (char === ";" && !escape) {
          push2(["[", value]);
          state2 = ";";
        } else if (char === "," && !escape) {
          push2(["[", value]);
          state2 = "[";
        } else if (char === "]" && !escape) push2(["[", value]);
        else cat(char);
        continue;
      } else if (state2?.startsWith(";")) {
        if (char === "=" && !escape) {
          state2 = `;${value}`;
          value = "";
        } else if (char === ";" && !escape) {
          push2([state2, value]);
          state2 = ";";
        } else if (char === "]" && !escape) push2([state2, value]);
        else cat(char);
        continue;
      }
      if (char === "/" || char === ":" || char === "~" || char === "@" || char === "[" || char === "!" || char === ",")
        state2 = char;
    }
    return tokens;
  };
  var findTokens = (tokens, x) => findIndices(tokens, ([t]) => t === x);
  var parser = (tokens) => {
    const parts = [];
    let state2;
    for (const [type, val] of tokens) {
      if (type === "/") parts.push({ index: val });
      else {
        const last2 = parts[parts.length - 1];
        if (type === ":") last2.offset = val;
        else if (type === "~") last2.temporal = val;
        else if (type === "@") last2.spatial = (last2.spatial ?? []).concat(val);
        else if (type === ";s") last2.side = val;
        else if (type === "[") {
          if (state2 === "/" && val) last2.id = val;
          else {
            last2.text = (last2.text ?? []).concat(val);
            continue;
          }
        }
      }
      state2 = type;
    }
    return parts;
  };
  var parserIndir = (tokens) => splitAt(tokens, findTokens(tokens, "!")).map(parser);
  var parse = (cfi) => {
    const tokens = tokenizer(unwrap(cfi));
    const commas = findTokens(tokens, ",");
    if (!commas.length) return parserIndir(tokens);
    const [parent, start, end] = splitAt(tokens, commas).map(parserIndir);
    return { parent, start, end };
  };
  var partToString = ({ index, id, offset, temporal, spatial, text, side }) => {
    const param = side ? `;s=${side}` : "";
    return `/${index}` + (id ? `[${escapeCFI(id)}${param}]` : "") + // "CFI expressions [..] SHOULD include an explicit character offset"
    (offset != null && index % 2 ? `:${offset}` : "") + (temporal ? `~${temporal}` : "") + (spatial ? `@${spatial.join(":")}` : "") + (text || !id && side ? "[" + (text?.map(escapeCFI)?.join(",") ?? "") + param + "]" : "");
  };
  var toInnerString = (parsed) => parsed.parent ? [parsed.parent, parsed.start, parsed.end].map(toInnerString).join(",") : parsed.map((parts) => parts.map(partToString).join("")).join("!");
  var toString2 = (parsed) => wrap2(toInnerString(parsed));
  var collapse = (x, toEnd) => typeof x === "string" ? toString2(collapse(parse(x), toEnd)) : x.parent ? concatArrays(x.parent, x[toEnd ? "end" : "start"]) : x;
  var isTextNode = ({ nodeType }) => nodeType === 3 || nodeType === 4;
  var isElementNode = ({ nodeType }) => nodeType === 1;
  var indexChildNodes = (node2) => {
    const nodes = Array.from(node2.childNodes).filter((node3) => isTextNode(node3) || isElementNode(node3)).reduce((arr, node3) => {
      let last2 = arr[arr.length - 1];
      if (!last2) arr.push(node3);
      else if (isTextNode(node3)) {
        if (Array.isArray(last2)) last2.push(node3);
        else if (isTextNode(last2)) arr[arr.length - 1] = [last2, node3];
        else arr.push(node3);
      } else {
        if (isElementNode(last2)) arr.push(null, node3);
        else arr.push(node3);
      }
      return arr;
    }, []);
    if (isElementNode(nodes[0])) nodes.unshift("first");
    if (isElementNode(nodes[nodes.length - 1])) nodes.push("last");
    nodes.unshift("before");
    nodes.push("after");
    return nodes;
  };
  var getNodeByIndex = (node2, index) => node2 ? indexChildNodes(node2)[index] : null;
  var partsToNode = (node2, parts) => {
    const { id } = parts[parts.length - 1];
    if (id) {
      const el = node2.ownerDocument.getElementById(id);
      if (el) return { node: el, offset: 0 };
    }
    for (const { index } of parts) {
      const newNode = getNodeByIndex(node2, index);
      if (newNode === "first") return { node: node2.firstChild ?? node2 };
      if (newNode === "last") return { node: node2.lastChild ?? node2 };
      if (newNode === "before") return { node: node2, before: true };
      if (newNode === "after") return { node: node2, after: true };
      node2 = newNode;
    }
    const { offset } = parts[parts.length - 1];
    if (!Array.isArray(node2)) return { node: node2, offset };
    let sum = 0;
    for (const n of node2) {
      const { length } = n.nodeValue;
      if (sum + length >= offset) return { node: n, offset: offset - sum };
      sum += length;
    }
  };
  var nodeToParts = (node2, offset) => {
    const { parentNode, id } = node2;
    const indexed = indexChildNodes(parentNode);
    const index = indexed.findIndex(
      (x) => Array.isArray(x) ? x.some((x2) => x2 === node2) : x === node2
    );
    const chunk2 = indexed[index];
    if (Array.isArray(chunk2)) {
      let sum = 0;
      for (const x of chunk2) {
        if (x === node2) {
          sum += offset;
          break;
        } else sum += x.nodeValue.length;
      }
      offset = sum;
    }
    const part = { id, index, offset };
    return parentNode !== node2.ownerDocument.documentElement ? nodeToParts(parentNode).concat(part) : [part];
  };
  var toRange = (doc2, parts) => {
    const startParts = collapse(parts);
    const endParts = collapse(parts, true);
    const root2 = doc2.documentElement;
    const start = partsToNode(root2, startParts[0]);
    const end = partsToNode(root2, endParts[0]);
    const range2 = doc2.createRange();
    if (start.before) range2.setStartBefore(start.node);
    else if (start.after) range2.setStartAfter(start.node);
    else range2.setStart(start.node, start.offset);
    if (end.before) range2.setEndBefore(end.node);
    else if (end.after) range2.setEndAfter(end.node);
    else range2.setEnd(end.node, end.offset);
    return range2;
  };
  var fromElements = (elements) => {
    const results = [];
    const { parentNode } = elements[0];
    const parts = nodeToParts(parentNode);
    for (const [index, node2] of indexChildNodes(parentNode).entries()) {
      const el = elements[results.length];
      if (node2 === el)
        results.push(toString2([parts.concat({ id: el.id, index })]));
    }
    return results;
  };
  var toElement = (doc2, parts) => partsToNode(doc2.documentElement, collapse(parts)).node;

  // vendor/kookit/src/libs/epub.js
  var NS = {
    CONTAINER: "urn:oasis:names:tc:opendocument:xmlns:container",
    XHTML: "http://www.w3.org/1999/xhtml",
    OPF: "http://www.idpf.org/2007/opf",
    EPUB: "http://www.idpf.org/2007/ops",
    DC: "http://purl.org/dc/elements/1.1/",
    DCTERMS: "http://purl.org/dc/terms/",
    ENC: "http://www.w3.org/2001/04/xmlenc#",
    NCX: "http://www.daisy.org/z3986/2005/ncx/",
    XLINK: "http://www.w3.org/1999/xlink",
    SMIL: "http://www.w3.org/ns/SMIL"
  };
  var MIME = {
    XML: "application/xml",
    NCX: "application/x-dtbncx+xml",
    XHTML: "application/xhtml+xml",
    HTML: "text/html",
    CSS: "text/css",
    SVG: "image/svg+xml",
    JS: /\/(x-)?(javascript|ecmascript)/
  };
  var camel = (x) => x.toLowerCase().replace(/[-:](.)/g, (_3, g) => g.toUpperCase());
  var whitespacePreLine = (str) => str ? str.trim().replace(/\s{2,}/g, " ") : "";
  var filterAttribute = (attr, value, isList) => isList ? (el) => el.getAttribute(attr)?.split(/\s/)?.includes(value) : typeof value === "function" ? (el) => value(el.getAttribute(attr)) : (el) => el.getAttribute(attr) === value;
  var getAttributes = (...xs) => (el) => el ? Object.fromEntries(xs.map((x) => [camel(x), el.getAttribute(x)])) : null;
  var getElementText = (el) => whitespacePreLine(el?.textContent);
  var childGetter = (doc2, ns) => {
    const useNS = doc2.lookupNamespaceURI(null) === ns || doc2.lookupPrefix(ns);
    const f = useNS ? (el, name) => (el2) => el2.namespaceURI === ns && el2.localName === name : (el, name) => (el2) => el2.localName === name;
    return {
      $: (el, name) => [...el.children].find(f(el, name)),
      $$: (el, name) => [...el.children].filter(f(el, name)),
      $$$: useNS ? (el, name) => [...el.getElementsByTagNameNS(ns, name)] : (el, name) => [...el.getElementsByTagName(ns, name)]
    };
  };
  var resolveURL = (url, relativeTo) => {
    try {
      url = url.replace(/%2c/gi, ",").replace(/%3a/gi, ":");
      const root2 = "whatever://whatever/";
      return decodeURI(new URL(url, root2 + relativeTo).href.replace(root2, ""));
    } catch (e) {
      console.warn(e);
      return url;
    }
  };
  var isExternal = (uri) => /^(?!blob)\w+:/i.test(uri);
  var pathRelative = (from, to) => {
    if (!from) return to;
    const as = from.replace(/\/$/, "").split("/");
    const bs = to.replace(/\/$/, "").split("/");
    const i = (as.length > bs.length ? as : bs).findIndex(
      (_3, i2) => as[i2] !== bs[i2]
    );
    return i < 0 ? "" : Array(as.length - i).fill("..").concat(bs.slice(i)).join("/");
  };
  var pathDirname = (str) => str.slice(0, str.lastIndexOf("/") + 1);
  var replaceSeries = async (str, regex, f) => {
    const matches = [];
    str.replace(regex, (...args) => (matches.push(args), null));
    const results = [];
    for (const args of matches) results.push(await f(...args));
    return str.replace(regex, () => results.shift());
  };
  var regexEscape = (str) => str.replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&");
  var LANGS = { attrs: ["dir", "xml:lang"] };
  var ALTS = {
    name: "alternate-script",
    many: true,
    ...LANGS,
    props: ["file-as"]
  };
  var CONTRIB = {
    many: true,
    ...LANGS,
    props: [{ name: "role", many: true, attrs: ["scheme"] }, "file-as", ALTS]
  };
  var METADATA = [
    {
      name: "title",
      many: true,
      ...LANGS,
      props: ["title-type", "display-seq", "file-as", ALTS]
    },
    {
      name: "identifier",
      many: true,
      props: [{ name: "identifier-type", attrs: ["scheme"] }]
    },
    { name: "language", many: true },
    { name: "creator", ...CONTRIB },
    { name: "contributor", ...CONTRIB },
    { name: "publisher", ...LANGS, props: ["file-as", ALTS] },
    { name: "description", ...LANGS, props: [ALTS] },
    { name: "rights", ...LANGS, props: [ALTS] },
    { name: "date" },
    { name: "dcterms:modified", type: "meta" },
    { name: "subject", many: true, ...LANGS, props: ["term", "authority", ALTS] },
    {
      name: "belongs-to-collection",
      type: "meta",
      many: true,
      ...LANGS,
      props: [
        "collection-type",
        "group-position",
        "dcterms:identifier",
        "file-as",
        ALTS,
        { name: "belongs-to-collection", recursive: true }
      ]
    }
  ];
  var getMetadata = (opf) => {
    const { $, $$ } = childGetter(opf, NS.OPF);
    const $metadata = $(opf.documentElement, "metadata");
    const els = Array.from($metadata.children);
    const getValue = (obj, el) => {
      if (!el) return null;
      const { props = [], attrs = [] } = obj;
      const value = getElementText(el);
      if (!props.length && !attrs.length) return value;
      const id = el.getAttribute("id");
      const refines = id ? els.filter(filterAttribute("refines", "#" + id)) : [];
      return Object.fromEntries(
        [["value", value]].concat(
          props.map((prop) => {
            const { many, recursive } = prop;
            const name = typeof prop === "string" ? prop : prop.name;
            const filter2 = filterAttribute("property", name);
            const subobj = recursive ? obj : prop;
            return [
              camel(name),
              many ? refines.filter(filter2).map((el2) => getValue(subobj, el2)) : getValue(subobj, refines.find(filter2))
            ];
          })
        ).concat(attrs.map((attr) => [camel(attr), el.getAttribute(attr)]))
      );
    };
    const arr = els.filter(filterAttribute("refines", null));
    const metadata = Object.fromEntries(
      METADATA.map((obj) => {
        const { type, name, many } = obj;
        const filter2 = type === "meta" ? (el) => el.namespaceURI === NS.OPF && el.getAttribute("property") === name : (el) => el.namespaceURI === NS.DC && el.localName === name;
        return [
          camel(name),
          many ? arr.filter(filter2).map((el) => getValue(obj, el)) : getValue(obj, arr.find(filter2))
        ];
      })
    );
    const getProperties = (prefix) => Object.fromEntries(
      $$($metadata, "meta").filter(filterAttribute("property", (x) => x?.startsWith(prefix))).map((el) => [
        el.getAttribute("property").replace(prefix, ""),
        getElementText(el)
      ])
    );
    const rendition = getProperties("rendition:");
    const media = getProperties("media:");
    return { metadata, rendition, media };
  };
  var parseNav = (doc2, resolve = (f) => f) => {
    const { $, $$, $$$ } = childGetter(doc2, NS.XHTML);
    const resolveHref = (href) => href ? decodeURI(resolve(href)) : null;
    const parseLI = (getType) => ($li) => {
      const $a = $($li, "a") ?? $($li, "span");
      const $ol = $($li, "ol");
      const href = resolveHref($a?.getAttribute("href"));
      const label = getElementText($a) || $a?.getAttribute("title");
      const result2 = { label, href, subitems: parseOL($ol) };
      if (getType) result2.type = $a?.getAttributeNS(NS.EPUB, "type")?.split(/\s/);
      return result2;
    };
    const parseOL = ($ol, getType) => $ol ? $$($ol, "li").map(parseLI(getType)) : null;
    const parseNav2 = ($nav, getType) => parseOL($($nav, "ol"), getType);
    const $$nav = $$$(doc2, "nav");
    let toc = null, pageList = null, landmarks = null, others = [];
    for (const $nav of $$nav) {
      const type = $nav.getAttributeNS(NS.EPUB, "type")?.split(/\s/) ?? [];
      if (type.includes("toc")) toc ??= parseNav2($nav);
      else if (type.includes("page-list")) pageList ??= parseNav2($nav);
      else if (type.includes("landmarks")) landmarks ??= parseNav2($nav, true);
      else
        others.push({
          label: getElementText($nav.firstElementChild),
          type,
          list: parseNav2($nav)
        });
    }
    return { toc, pageList, landmarks, others };
  };
  var parseNCX = (doc2, resolve = (f) => f) => {
    const { $, $$ } = childGetter(doc2, NS.NCX);
    const resolveHref = (href) => href ? decodeURI(resolve(href)) : null;
    const parseItem = (el) => {
      const $label = $(el, "navLabel");
      const $content = $(el, "content");
      const label = getElementText($label);
      const href = resolveHref($content.getAttribute("src"));
      if (el.localName === "navPoint") {
        const els = $$(el, "navPoint");
        return { label, href, subitems: els.length ? els.map(parseItem) : null };
      }
      return { label, href };
    };
    const parseList = (el, itemName) => $$(el, itemName).map(parseItem);
    const getSingle = (container, itemName) => {
      const $container = $(doc2.documentElement, container);
      return $container ? parseList($container, itemName) : null;
    };
    return {
      toc: getSingle("navMap", "navPoint"),
      pageList: getSingle("pageList", "pageTarget"),
      others: $$(doc2.documentElement, "navList").map((el) => ({
        label: getElementText($(el, "navLabel")),
        list: parseList(el, "navTarget")
      }))
    };
  };
  var parseClock = (str) => {
    if (!str) return;
    const parts = str.split(":").map((x2) => parseFloat(x2));
    if (parts.length === 3) {
      const [h, m, s] = parts;
      return h * 60 * 60 + m * 60 + s;
    }
    if (parts.length === 2) {
      const [m, s] = parts;
      return m * 60 + s;
    }
    const [x, unit] = str.split(/(?=[^\d.])/);
    const n = parseFloat(x);
    const f = unit === "h" ? 60 * 60 : unit === "min" ? 60 : unit === "ms" ? 1e-3 : 1;
    return n * f;
  };
  var parseSMIL = (doc2, resolve = (f) => f) => {
    const { $, $$$ } = childGetter(doc2, NS.SMIL);
    const resolveHref = (href) => href ? decodeURI(resolve(href)) : null;
    return $$$(doc2, "par").map(($par) => {
      const id = $($par, "text")?.getAttribute("src")?.split("#")?.[1];
      const $audio = $($par, "audio");
      return $audio ? {
        id,
        audio: {
          src: resolveHref($audio.getAttribute("src")),
          clipBegin: parseClock($audio.getAttribute("clipBegin")),
          clipEnd: parseClock($audio.getAttribute("clipEnd"))
        }
      } : { id };
    });
  };
  var isUUID = /([0-9a-f]{8})-([0-9a-f]{4})-([0-9a-f]{4})-([0-9a-f]{4})-([0-9a-f]{12})/;
  var getUUID = (opf) => {
    for (const el of opf.getElementsByTagNameNS(NS.DC, "identifier")) {
      const [id] = getElementText(el).split(":").slice(-1);
      if (isUUID.test(id)) return id;
    }
    return "";
  };
  var getIdentifier = (opf) => getElementText(
    opf.getElementById(opf.documentElement.getAttribute("unique-identifier")) ?? opf.getElementsByTagNameNS(NS.DC, "identifier")[0]
  );
  var deobfuscate = async (key, length, blob) => {
    const array = new Uint8Array(await blob.slice(0, length).arrayBuffer());
    length = Math.min(length, array.length);
    for (var i = 0; i < length; i++) array[i] = array[i] ^ key[i % key.length];
    return new Blob([array, blob.slice(length)], { type: blob.type });
  };
  var WebCryptoSHA1 = async (str) => {
    const data = new TextEncoder().encode(str);
    const buffer = await globalThis.crypto.subtle.digest("SHA-1", data);
    return new Uint8Array(buffer);
  };
  var deobfuscators = (sha1 = WebCryptoSHA1) => ({
    "http://www.idpf.org/2008/embedding": {
      key: (opf) => sha1(
        getIdentifier(opf).replaceAll(/[\u0020\u0009\u000d\u000a]/g, "")
      ),
      decode: (key, blob) => deobfuscate(key, 1040, blob)
    },
    "http://ns.adobe.com/pdf/enc#RC": {
      key: (opf) => {
        const uuid = getUUID(opf).replaceAll("-", "");
        return Uint8Array.from(
          { length: 16 },
          (_3, i) => parseInt(uuid.slice(i * 2, i * 2 + 2), 16)
        );
      },
      decode: (key, blob) => deobfuscate(key, 1024, blob)
    }
  });
  var Encryption = class {
    #uris = /* @__PURE__ */ new Map();
    #decoders = /* @__PURE__ */ new Map();
    #algorithms;
    constructor(algorithms) {
      this.#algorithms = algorithms;
    }
    async init(encryption, opf) {
      if (!encryption) return;
      const data = Array.from(
        encryption.getElementsByTagNameNS(NS.ENC, "EncryptedData"),
        (el) => ({
          algorithm: el.getElementsByTagNameNS(NS.ENC, "EncryptionMethod")[0]?.getAttribute("Algorithm"),
          uri: el.getElementsByTagNameNS(NS.ENC, "CipherReference")[0]?.getAttribute("URI")
        })
      );
      for (const { algorithm, uri } of data) {
        if (!this.#decoders.has(algorithm)) {
          const algo = this.#algorithms[algorithm];
          if (!algo) {
            console.warn("Unknown encryption algorithm");
            continue;
          }
          const key = await algo.key(opf);
          this.#decoders.set(algorithm, (blob) => algo.decode(key, blob));
        }
        this.#uris.set(uri, algorithm);
      }
    }
    getDecoder(uri) {
      return this.#decoders.get(this.#uris.get(uri)) ?? ((x) => x);
    }
  };
  var Resources = class {
    constructor({ opf, resolveHref }) {
      this.opf = opf;
      const { $, $$, $$$ } = childGetter(opf, NS.OPF);
      const $manifest = $(opf.documentElement, "manifest");
      const $spine = $(opf.documentElement, "spine");
      const $$itemref = $$($spine, "itemref");
      this.manifest = $$($manifest, "item").map(
        getAttributes("href", "id", "media-type", "properties", "media-overlay")
      ).map((item) => {
        item.href = resolveHref(item.href);
        item.properties = item.properties?.split(/\s/);
        return item;
      });
      if (this.manifest.length === 0) {
        this.manifest = Array.from($manifest.children).map((item) => {
          const attrs = getAttributes(
            "href",
            "id",
            "media-type",
            "properties",
            "media-overlay"
          )(item);
          attrs.href = resolveHref(attrs.href);
          attrs.properties = attrs.properties?.split(/\s/);
          return attrs;
        });
      }
      this.spine = $$itemref.map(getAttributes("idref", "id", "linear", "properties")).map((item) => (item.properties = item.properties?.split(/\s/), item));
      this.pageProgressionDirection = $spine.getAttribute(
        "page-progression-direction"
      );
      this.navPath = this.getItemByProperty("nav")?.href;
      this.ncxPath = (this.getItemByID($spine.getAttribute("toc")) ?? this.manifest.find((item) => item.mediaType === MIME.NCX))?.href;
      const $guide = $(opf.documentElement, "guide");
      if ($guide)
        this.guide = $$($guide, "reference").map(getAttributes("type", "title", "href")).map(({ type, title, href }) => ({
          label: title,
          type: type.split(/\s/),
          href: resolveHref(href)
        }));
      this.cover = this.getItemByProperty("cover-image") ?? this.getItemByID("cover-image") ?? // EPUB 2 compat
      this.getItemByID(
        $$$(opf, "meta").find(filterAttribute("name", "cover"))?.getAttribute("content")
      ) ?? this.getItemByHref(
        $$$(opf, "meta").find(filterAttribute("name", "cover"))?.getAttribute("content")
      ) ?? this.getItemByID("cover.jpg") ?? this.getItemByID("cover.png") ?? this.getItemByID("cover.jpeg") ?? this.getItemByHref(
        this.guide?.find(
          (ref) => ref.type.includes("cover") && !ref.href.includes("html") && !ref.href.includes("xhtml") && !ref.href.includes("xml")
        )?.href
      ) ?? this.getItemByID("cover");
      if (this.cover && this.cover.href) {
        if (this.cover.href.includes("xml") || this.cover.href.includes("xhtml") || this.cover.href.includes("html")) {
          this.cover = this.manifest.find(
            (item) => item.href.toLowerCase().includes("cover") && (item.href.includes("png") || item.href.includes("jpg") || item.href.includes("jpeg"))
          );
        }
      }
      if (!this.cover) {
        this.cover = this.manifest.find(
          (item) => item.href.toLowerCase().includes("cover") && (item.mediaType?.startsWith("image/") || item.href.toLowerCase().includes("png") || item.href.toLowerCase().includes("jpg") || item.href.toLowerCase().includes("svg") || item.href.toLowerCase().includes("jpeg"))
        );
      }
      if (!this.cover) {
        this.cover = this.manifest.find(
          (item) => item.mediaType?.startsWith("image/") || item.href.toLowerCase().includes("png") || item.href.toLowerCase().includes("jpg") || item.href.toLowerCase().includes("svg") || item.href.toLowerCase().includes("jpeg")
        );
      }
      this.cfis = fromElements($$itemref);
    }
    getItemByID(id) {
      return this.manifest.find((item) => item.id === id);
    }
    getItemByHref(href) {
      return this.manifest.find((item) => item.href === href);
    }
    getItemByProperty(prop) {
      return this.manifest.find((item) => item.properties?.includes(prop));
    }
    resolveCFI(cfi) {
      const parts = parse(cfi);
      const top = (parts.parent ?? parts).shift();
      let $itemref = toElement(this.opf, top);
      if ($itemref && $itemref.nodeName !== "idref") {
        top.at(-1).id = null;
        $itemref = toElement(this.opf, top);
      }
      const idref = $itemref?.getAttribute("idref");
      const index = this.spine.findIndex((item) => item.idref === idref);
      const anchor = (doc2) => toRange(doc2, parts);
      return { index, anchor };
    }
  };
  var Loader = class {
    #cache = /* @__PURE__ */ new Map();
    #children = /* @__PURE__ */ new Map();
    #refCount = /* @__PURE__ */ new Map();
    allowScript = false;
    constructor({ loadText, loadBlob, resources }) {
      this.loadText = loadText;
      this.loadBlob = loadBlob;
      this.manifest = resources.manifest;
      this.assets = resources.manifest;
    }
    createURL(href, data, type, parent) {
      if (!data) return "";
      const url = URL.createObjectURL(new Blob([data], { type }));
      this.#cache.set(href, url);
      this.#refCount.set(href, 1);
      if (parent) {
        const childList = this.#children.get(parent);
        if (childList) childList.push(href);
        else this.#children.set(parent, [href]);
      }
      return url;
    }
    ref(href, parent) {
      const childList = this.#children.get(parent);
      if (!childList?.includes(href)) {
        this.#refCount.set(href, this.#refCount.get(href) + 1);
        if (childList) childList.push(href);
        else this.#children.set(parent, [href]);
      }
      return this.#cache.get(href);
    }
    unref(href) {
      if (!this.#refCount.has(href)) return;
      const count = this.#refCount.get(href) - 1;
      if (count < 1) {
        URL.revokeObjectURL(this.#cache.get(href));
        this.#cache.delete(href);
        this.#refCount.delete(href);
        const childList = this.#children.get(href);
        if (childList) while (childList.length) this.unref(childList.pop());
        this.#children.delete(href);
      } else this.#refCount.set(href, count);
    }
    // load manifest item, recursively loading all resources as needed
    async loadItem(item, parents = []) {
      if (!item) return null;
      const { href, mediaType } = item;
      const isScript = MIME.JS.test(item.mediaType);
      if (isScript && !this.allowScript) return null;
      const parent = parents.at(-1);
      if (this.#cache.has(href)) return this.ref(href, parent);
      const shouldReplace = (isScript || [MIME.XHTML, MIME.HTML, MIME.CSS, MIME.SVG].includes(mediaType)) && // prevent circular references
      parents.every((p) => p !== href);
      if (shouldReplace) return this.loadReplaced(item, parents);
      return this.createURL(href, await this.loadBlob(href), mediaType, parent);
    }
    async loadHref(href, base, parents = []) {
      if (isExternal(href)) return href;
      const path = resolveURL(href, base);
      let item = this.manifest.find((item2) => item2.href === path);
      if (!item) {
        item = { href: path, mediaType: "" };
      }
      return this.loadItem(item, parents.concat(base));
    }
    async loadReplaced(item, parents = []) {
      const { href, mediaType } = item;
      const parent = parents.at(-1);
      const str = await this.loadText(href);
      if (!str) return null;
      if ([MIME.XHTML, MIME.HTML, MIME.SVG].includes(mediaType)) {
        let doc2 = new DOMParser().parseFromString(str.trim(), mediaType);
        if (mediaType === MIME.XHTML && doc2.querySelector("parsererror")) {
          console.warn(doc2.querySelector("parsererror").innerText);
          item.mediaType = MIME.HTML;
          doc2 = new DOMParser().parseFromString(str.trim(), item.mediaType);
        }
        if ([MIME.XHTML, MIME.SVG].includes(item.mediaType)) {
          let child = doc2.firstChild;
          while (child instanceof ProcessingInstruction) {
            if (child.data) {
              const replacedData = await replaceSeries(
                child.data,
                /(?:^|\s*)(href\s*=\s*['"])([^'"]*)(['"])/i,
                (_3, p1, p2, p3) => this.loadHref(p2, href, parents).then((p22) => `${p1}${p22}${p3}`)
              );
              child.replaceWith(
                doc2.createProcessingInstruction(child.target, replacedData)
              );
            }
            child = child.nextSibling;
          }
        }
        const replace = async (el, attr) => el.setAttribute(
          attr,
          await this.loadHref(el.getAttribute(attr), href, parents)
        );
        for (const el of doc2.querySelectorAll("link[href]"))
          await replace(el, "href");
        for (const el of doc2.querySelectorAll("[src]")) await replace(el, "src");
        for (const el of doc2.querySelectorAll("[poster]"))
          await replace(el, "poster");
        for (const el of doc2.querySelectorAll("object[data]"))
          await replace(el, "data");
        for (const el of doc2.querySelectorAll("[*|href]:not([href]"))
          el.setAttributeNS(
            NS.XLINK,
            "href",
            await this.loadHref(
              el.getAttributeNS(NS.XLINK, "href"),
              href,
              parents
            )
          );
        for (const el of doc2.querySelectorAll("style"))
          if (el.textContent)
            el.textContent = await this.replaceCSS(el.textContent, href, parents);
        for (const el of doc2.querySelectorAll("[style]"))
          el.setAttribute(
            "style",
            await this.replaceCSS(el.getAttribute("style"), href, parents)
          );
        const result3 = new XMLSerializer().serializeToString(doc2);
        return this.createURL(href, result3, item.mediaType, parent);
      }
      const result2 = mediaType === MIME.CSS ? await this.replaceCSS(str, href, parents) : await this.replaceString(str, href, parents);
      return this.createURL(href, result2, mediaType, parent);
    }
    async replaceCSS(str, href, parents = []) {
      const replacedUrls = await replaceSeries(
        str,
        /url\(\s*["']?([^'"\n]*?)\s*["']?\s*\)/gi,
        (_3, url) => this.loadHref(url, href, parents).then((url2) => `url("${url2}")`)
      );
      const replacedImports = await replaceSeries(
        replacedUrls,
        /@import\s*["']([^"'\n]*?)["']/gi,
        (_3, url) => this.loadHref(url, href, parents).then((url2) => `@import "${url2}"`)
      );
      const w = window?.innerWidth ?? 800;
      const h = window?.innerHeight ?? 600;
      return replacedImports.replace(/-epub-/gi, "").replace(/(\d*\.?\d+)vw/gi, (_3, d) => parseFloat(d) * w / 100 + "px").replace(/(\d*\.?\d+)vh/gi, (_3, d) => parseFloat(d) * h / 100 + "px").replace(
        /page-break-(after|before|inside)/gi,
        (_3, x) => `-webkit-column-break-${x}`
      );
    }
    // find & replace all possible relative paths for all assets without parsing
    replaceString(str, href, parents = []) {
      const assetMap = /* @__PURE__ */ new Map();
      const urls = this.assets.map((asset) => {
        if (asset.href === href) return;
        const relative = pathRelative(pathDirname(href), asset.href);
        const relativeEnc = encodeURI(relative);
        const rootRelative = "/" + asset.href;
        const rootRelativeEnc = encodeURI(rootRelative);
        const set = /* @__PURE__ */ new Set([
          relative,
          relativeEnc,
          rootRelative,
          rootRelativeEnc
        ]);
        for (const url of set) assetMap.set(url, asset);
        return Array.from(set);
      }).flat().filter((x) => x);
      if (!urls.length) return str;
      const regex = new RegExp(urls.map(regexEscape).join("|"), "g");
      return replaceSeries(
        str,
        regex,
        async (match) => this.loadItem(
          assetMap.get(match.replace(/^\//, "")),
          parents.concat(href)
        )
      );
    }
    unloadItem(item) {
      this.unref(item?.href);
    }
  };
  var getHTMLFragment = (doc2, id) => doc2.getElementById(id) ?? doc2.querySelector(`[name="${CSS.escape(id)}"]`);
  var getPageSpread = (properties) => {
    for (const p of properties) {
      if (p === "page-spread-left" || p === "rendition:page-spread-left")
        return "left";
      if (p === "page-spread-right" || p === "rendition:page-spread-right")
        return "right";
      if (p === "rendition:page-spread-center") return "center";
    }
  };
  var EPUB = class {
    parser = new DOMParser();
    #encryption;
    constructor({ loadText, loadBlob, getSize, sha1 }) {
      this.loadText = loadText;
      this.loadBlob = loadBlob;
      this.getSize = getSize;
      this.#encryption = new Encryption(deobfuscators(sha1));
    }
    #parseXML(str) {
      if (str && str.includes("opf:scheme")) {
        str = str.replaceAll("opf:scheme", "scheme");
      }
      if (str) {
        str = str.replace(/^\uFEFF/, "").replace(/<!--([\s\S]*?)-->/g, (match, content) => {
          const fixedContent = content.replace(/--/g, "- -");
          return `<!--${fixedContent}-->`;
        }).replace(/&(?!(?:amp|lt|gt|quot|apos|#\d+|#x[\da-fA-F]+);)/g, "&amp;").replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "");
      }
      return str ? this.parser.parseFromString(str.trim(), MIME.XML) : null;
    }
    async #loadXML(uri) {
      return this.#parseXML(await this.loadText(uri));
    }
    async init() {
      const $container = await this.#loadXML("META-INF/container.xml");
      if (!$container) throw new Error("Failed to load container file");
      const opfs = Array.from(
        $container.getElementsByTagNameNS(NS.CONTAINER, "rootfile"),
        getAttributes("full-path", "media-type")
      ).filter((file) => file.mediaType === "application/oebps-package+xml");
      if (!opfs.length)
        throw new Error("No package document defined in container");
      const opfPath = opfs[0].fullPath;
      const opf = await this.#loadXML(opfPath);
      if (!opf) throw new Error("Failed to load package document");
      if (opf.querySelector("parsererror")) {
        throw new Error("Package document is not a valid XML");
      }
      const $encryption = await this.#loadXML("META-INF/encryption.xml");
      await this.#encryption.init($encryption, opf);
      this.resources = new Resources({
        opf,
        resolveHref: (url) => resolveURL(url, opfPath)
      });
      const loader = new Loader({
        loadText: this.loadText,
        loadBlob: (uri) => Promise.resolve(this.loadBlob(uri)).then(
          this.#encryption.getDecoder(uri)
        ),
        resources: this.resources
      });
      this.sections = this.resources.spine.map((spineItem, index) => {
        const { idref, linear, properties = [] } = spineItem;
        const item = this.resources.getItemByID(idref);
        if (!item) {
          console.warn(`Could not find item with ID "${idref}" in manifest`);
          return null;
        }
        return {
          id: this.resources.getItemByID(idref)?.href,
          load: () => loader.loadItem(item),
          unload: () => loader.unloadItem(item),
          createDocument: () => this.loadDocument(item),
          size: this.getSize(item.href),
          cfi: this.resources.cfis[index],
          linear,
          pageSpread: getPageSpread(properties),
          resolveHref: (href) => resolveURL(href, item.href),
          loadMediaOverlay: () => this.loadMediaOverlay(item)
        };
      });
      const { navPath, ncxPath } = this.resources;
      if (navPath)
        try {
          const resolve = (url) => resolveURL(url, navPath);
          const nav = parseNav(await this.#loadXML(navPath), resolve);
          this.toc = nav.toc;
          this.pageList = nav.pageList;
          this.landmarks = nav.landmarks;
        } catch (e) {
          console.warn(e);
        }
      if ((!this.toc || this.toc.length === 0) && ncxPath)
        try {
          const resolve = (url) => resolveURL(url, ncxPath);
          const ncx = parseNCX(await this.#loadXML(ncxPath), resolve);
          this.toc = ncx.toc;
          this.pageList = ncx.pageList;
        } catch (e) {
          console.warn(e);
        }
      this.landmarks ??= this.resources.guide;
      const { metadata, rendition, media } = getMetadata(opf);
      this.rendition = rendition;
      this.media = media;
      media.duration = parseClock(media.duration);
      this.dir = this.resources.pageProgressionDirection;
      this.rawMetadata = metadata;
      const title = metadata?.title?.[0];
      this.metadata = {
        title: title?.value,
        sortAs: title?.fileAs,
        language: metadata?.language,
        identifier: getIdentifier(opf),
        description: metadata?.description?.value,
        publisher: metadata?.publisher?.value,
        published: metadata?.date,
        modified: metadata?.dctermsModified,
        subject: metadata?.subject?.filter(({ value, code }) => value || code)?.map(({ value, code, scheme }) => ({ name: value, code, scheme })),
        rights: metadata?.rights?.value
      };
      const relators = {
        art: "artist",
        aut: "author",
        bkp: "producer",
        clr: "colorist",
        edt: "editor",
        ill: "illustrator",
        trl: "translator",
        pbl: "publisher"
      };
      const mapContributor = (defaultKey) => (obj) => {
        const keys2 = [
          ...new Set(
            obj.role?.map(
              ({ value: value2, scheme }) => (!scheme || scheme === "marc:relators" ? relators[value2] : null) ?? defaultKey
            )
          )
        ];
        const value = { name: obj.value, sortAs: obj.fileAs };
        return [keys2?.length ? keys2 : [defaultKey], value];
      };
      metadata?.creator?.map(mapContributor("author"))?.concat(metadata?.contributor?.map?.(mapContributor("contributor")))?.forEach(
        ([keys2, value]) => keys2.forEach((key) => {
          if (this.metadata[key]) this.metadata[key].push(value);
          else this.metadata[key] = [value];
        })
      );
      return this;
    }
    async loadDocument(item) {
      const str = await this.loadText(item.href);
      return this.parser.parseFromString(str.trim(), item.mediaType);
    }
    async loadMediaOverlay(item) {
      const id = item.mediaOverlay;
      if (!id) return null;
      const media = this.resources.getItemByID(id);
      const doc2 = await this.#loadXML(media.href);
      const parsed = parseSMIL(doc2, (url) => resolveURL(url, media.href));
      return parsed;
    }
    resolveCFI(cfi) {
      return this.resources.resolveCFI(cfi);
    }
    resolveHref(href) {
      const [path, hash] = href.split("#");
      const item = this.resources.getItemByHref(decodeURI(path));
      if (!item) return null;
      const index = this.resources.spine.findIndex(
        ({ idref }) => idref === item.id
      );
      const anchor = hash ? (doc2) => getHTMLFragment(doc2, hash) : () => 0;
      return { index, anchor };
    }
    resolveHrefIndex(href) {
      const [path, hash] = href.split("#");
      const item = this.resources.getItemByHref(decodeURI(path));
      if (!item) return null;
      const index = this.resources.spine.findIndex(
        ({ idref }) => idref === item.id
      );
      return { index };
    }
    splitTOCHref(href) {
      return href?.split("#") ?? [];
    }
    getTOCFragment(doc2, id) {
      return doc2.getElementById(id) ?? doc2.querySelector(`[name="${CSS.escape(id)}"]`);
    }
    isExternal(uri) {
      return isExternal(uri);
    }
    async getCover() {
      const cover = this.resources?.cover;
      const coverBlob = cover?.href ? await this.loadBlob(cover.href) : null;
      return cover?.href && coverBlob && coverBlob.size > 0 ? new Blob([coverBlob], { type: cover.mediaType }) : null;
    }
    async getCalibreBookmarks() {
      const txt = await this.loadText("META-INF/calibre_bookmarks.txt");
      const magic = "encoding=json+base64:";
      if (txt?.startsWith(magic)) {
        const json = atob(txt.slice(magic.length));
        return JSON.parse(json);
      }
    }
  };

  // loader.js
  var import_jszip = __toESM(require_jszip_min(), 1);
  var ENTRY = 4 * 1024 * 1024;
  var TOTAL = 50 * 1024 * 1024;
  var safePath = (name) => typeof name === "string" && name.length > 0 && name.length <= 1024 && !/^[\/]|[\\:%\x00-\x1f\x7f]/.test(name) && name.split("/").every((p, i, a) => p !== "." && p !== ".." && (p || i === a.length - 1));
  var safeReference = (value) => !/^[\/]|[\\:\x00-\x1f]/.test(value) && !/%(?:2e|2f|5c|00)/i.test(value);
  var mediaTypes = { xhtml: "application/xhtml+xml", html: "application/xhtml+xml", opf: "application/oebps-package+xml", ncx: "application/x-dtbncx+xml", css: "text/css", png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", xml: "application/xml" };
  function contentKind(name, mime) {
    const extension = name.split(".").pop().toLowerCase(), expected = mediaTypes[extension];
    if (!expected || mime && mime !== expected) throw Error("Unsupported publication resource or MIME/suffix mismatch");
    return extension;
  }
  function css(text) {
    return text.replace(/\/\*[\s\S]*?\*\//g, "").replace(/@import[^;]*(?:;|$)/gi, "").replace(/url\([^)]*\)/gi, "none").replace(/[^{};]*[\\][^{};]*(?:;|$)/g, "").replace(/(?:behavior|-moz-binding)\s*:[^;}]*/gi, "");
  }
  function sanitise(text, name) {
    const kind = contentKind(name);
    if (/<!DOCTYPE|<!ENTITY/i.test(text)) throw Error("XML declarations are not accepted");
    if (kind === "css") return css(text);
    if (!["xhtml", "html", "xml", "opf", "ncx"].includes(kind)) throw Error("Binary resource cannot be loaded as text");
    const isHTML = /\.(?:xhtml|html)$/i.test(name);
    const doc2 = new DOMParser().parseFromString(text, isHTML ? "application/xhtml+xml" : "application/xml");
    if (doc2.querySelector("parsererror")) throw Error("Invalid publication XML");
    const instructions = doc2.createTreeWalker(doc2, 64);
    if (instructions.nextNode()) throw Error("Publication processing instructions are not accepted");
    const namespaces = new Set(isHTML ? ["http://www.w3.org/1999/xhtml"] : ["urn:oasis:names:tc:opendocument:xmlns:container", "http://www.idpf.org/2007/opf", "http://purl.org/dc/elements/1.1/", "http://www.daisy.org/z3986/2005/ncx/"]);
    for (const node2 of [...doc2.querySelectorAll("*")]) {
      const tag = node2.localName.toLowerCase();
      if (["script", "iframe", "object", "embed", "form", "input", "button", "base", "svg", "math", "audio", "video"].includes(tag) || tag === "meta" && node2.hasAttribute("http-equiv")) {
        node2.remove();
        continue;
      }
      if (!namespaces.has(node2.namespaceURI)) throw Error("Unexpected publication namespace");
      if (kind === "opf" && tag === "item") {
        const href = node2.getAttribute("href"), mime = node2.getAttribute("media-type");
        if (!href || !safeReference(href) || href.includes("#") || !mime) throw Error("Invalid publication manifest resource");
        contentKind(href, mime);
      }
      for (const attr of [...node2.attributes]) {
        const key = attr.localName.toLowerCase();
        if (key.startsWith("on") || ["srcdoc", "action", "formaction", "srcset"].includes(key)) node2.removeAttributeNode(attr);
        else if (key === "style") attr.value = css(attr.value);
        else if (["href", "src", "poster", "data", "full-path"].includes(key) && !safeReference(attr.value)) node2.removeAttributeNode(attr);
      }
      if (tag === "style") node2.textContent = css(node2.textContent);
    }
    return new XMLSerializer().serializeToString(doc2);
  }
  async function makeLoader(buffer, allowedNames) {
    const zip = await import_jszip.default.loadAsync(buffer);
    const actual = Object.keys(zip.files).sort();
    if (actual.length > 1e3 || JSON.stringify(actual) !== JSON.stringify([...allowedNames].sort()) || actual.some((name) => !safePath(name) || zip.files[name].unsafeOriginalName && zip.files[name].unsafeOriginalName !== name)) throw Error("Archive path mismatch");
    const cache = /* @__PURE__ */ new Map(), checkedImages = /* @__PURE__ */ new Set();
    let total = 0, totalPixels = 0;
    const bytes = (name) => {
      if (!safePath(name)) throw Error("Resource outside publication");
      if (!zip.files[name]) return Promise.resolve(null);
      if (cache.has(name)) return cache.get(name);
      const pending = new Promise((resolve, reject2) => {
        const chunks = [];
        let size2 = 0;
        const stream = zip.files[name].internalStream("uint8array");
        stream.on("data", (chunk2) => {
          size2 += chunk2.byteLength;
          total += chunk2.byteLength;
          if (size2 > ENTRY || total > TOTAL) {
            stream.pause();
            reject2(Error("Decompression budget exceeded"));
            return;
          }
          chunks.push(chunk2);
        }).on("error", reject2).on("end", () => {
          const result2 = new Uint8Array(size2);
          let offset = 0;
          for (const chunk2 of chunks) {
            result2.set(chunk2, offset);
            offset += chunk2.length;
          }
          resolve(result2);
        }).resume();
      });
      cache.set(name, pending);
      return pending;
    };
    const loadText = async (name) => {
      contentKind(name);
      const data = await bytes(name);
      return data ? sanitise(new TextDecoder("utf-8", { fatal: true }).decode(data), name) : "";
    };
    const loadBlob = async (name) => {
      contentKind(name);
      if (/\.(?:xhtml|html|xml|opf|ncx|css)$/i.test(name)) return new Blob([await loadText(name)]);
      if (!/\.(?:png|jpe?g)$/i.test(name)) throw Error("Only bounded static PNG/JPEG image resources are currently accepted");
      const data = await bytes(name);
      if (data && !checkedImages.has(name)) {
        let width = 0, height = 0;
        if (data.length >= 24 && data[0] === 137 && data[1] === 80 && data[2] === 78 && data[3] === 71) {
          const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
          width = view.getUint32(16);
          height = view.getUint32(20);
          for (let p = 8; p + 12 <= data.length; ) {
            const length = view.getUint32(p), type = String.fromCharCode(...data.slice(p + 4, p + 8));
            if (type === "acTL") throw Error("Animated PNG is not accepted");
            if (p + 12 + length > data.length) throw Error("Invalid PNG");
            p += 12 + length;
          }
        } else if (data[0] === 255 && data[1] === 216) {
          for (let p = 2; p + 8 < data.length; ) {
            if (data[p] !== 255) break;
            const marker = data[p + 1], length = data[p + 2] << 8 | data[p + 3];
            if ([192, 193, 194].includes(marker)) {
              height = data[p + 5] << 8 | data[p + 6];
              width = data[p + 7] << 8 | data[p + 8];
              break;
            }
            if (length < 2 || p + 2 + length > data.length) break;
            p += 2 + length;
          }
        }
        if (!width || !height || width * height > 4e6 || totalPixels + width * height > 16e6) throw Error("Image pixel budget exceeded");
        totalPixels += width * height;
        checkedImages.add(name);
      }
      return new Blob(data ? [data] : []);
    };
    return {
      entries: actual.map((filename) => ({ filename })),
      loadText,
      loadBlob,
      getSize: (name) => zip.files[name]?._data?.uncompressedSize ?? 0
    };
  }

  // kookit-adapter.js
  var EpubRender = class extends GeneralRender_default {
    constructor(buffer, names) {
      super({
        format: "EPUB",
        readerMode: "single",
        textOrientation: "horizontal",
        isAllowScript: "no",
        isMobile: "no",
        animation: "none",
        isBionic: "no",
        isHyphenation: "no",
        convertChinese: "",
        bookLayout: "",
        codeHighlight: "",
        fullTranslationMode: "no",
        textRules: []
      });
      this.buffer = buffer;
      this.names = names;
    }
    async renderTo(element) {
      this.element = element;
      this.book = await new EPUB(await makeLoader(this.buffer, this.names)).init();
      if (!this.book.sections.length || this.book.sections.some((x) => !x)) throw Error("Empty or invalid spine");
      if (this.book.rendition?.layout === "pre-paginated") throw Error("Fixed layout not accepted in this first EPUB slice");
      const parser2 = new generalParser_default(this.book);
      this.chapterList = await parser2.getChapter(this.book.toc);
      this.chapterDocList = await parser2.getChapterDoc();
      createIframe(element, "no");
      const doc2 = this.getDocument();
      if (!doc2) throw Error("Reader document unavailable");
      handleLayout(element, this.readerMode, doc2);
    }
  };

  // reader.js
  var identity2;
  var renderer;
  var version = 0;
  var current = 0;
  var notes = [];
  var initialising = false;
  var lastSelection = "";
  var post = (value) => window.webkit?.messageHandlers.epub.postMessage(JSON.stringify(value));
  var envelope = (payload, requestID = "event") => ({ ...identity2, v: 1, documentVersion: version, requestID, payload });
  var doc = () => renderer.getDocument();
  function canonical() {
    const root2 = doc().body, nodes = [];
    let text = "";
    const walker = doc().createTreeWalker(root2, NodeFilter.SHOW_TEXT, { acceptNode(node2) {
      return node2.parentElement?.closest("rt,rp,script,style,noscript") ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
    } });
    while (walker.nextNode()) {
      const node2 = walker.currentNode;
      nodes.push({ node: node2, start: text.length, end: text.length + node2.length });
      text += node2.data;
    }
    return { text, nodes };
  }
  function makeAnchor(start, end) {
    const { text } = canonical();
    const low = (value) => value >= 56320 && value <= 57343;
    if (low(text.charCodeAt(start))) start--;
    if (low(text.charCodeAt(end))) end++;
    if (start < 0 || end > text.length || end <= start || end - start > 16e3) return null;
    let before2 = Math.max(0, start - 64), after2 = Math.min(text.length, end + 64);
    if (low(text.charCodeAt(before2))) before2++;
    if (low(text.charCodeAt(after2))) after2--;
    return {
      schemaVersion: 1,
      extractionVersion: "epub-canonical-utf16-1",
      editionID: identity2.editionID,
      fileSHA256: identity2.fileSHA256,
      spineIndex: current,
      resourceHref: renderer.book.sections[current].id,
      start,
      end,
      quote: text.slice(start, end),
      prefix: text.slice(before2, start),
      suffix: text.slice(end, after2),
      vertical: renderer.isVertical()
    };
  }
  function rangeFor(anchor) {
    if (anchor.editionID !== identity2.editionID || anchor.fileSHA256 !== identity2.fileSHA256 || anchor.extractionVersion !== "epub-canonical-utf16-1" || anchor.schemaVersion !== 1 || anchor.spineIndex !== current || anchor.resourceHref !== renderer.book.sections[current].id) throw Error("Source identity mismatch");
    const { text, nodes } = canonical();
    if (!Number.isSafeInteger(anchor.start) || !Number.isSafeInteger(anchor.end) || anchor.start < 0 || anchor.end <= anchor.start || text.slice(anchor.start, anchor.end) !== anchor.quote || !text.slice(0, anchor.start).endsWith(anchor.prefix) || !text.slice(anchor.end).startsWith(anchor.suffix)) throw Error("Source quote needs rebinding");
    const first2 = nodes.find((x) => x.end > anchor.start), last2 = nodes.find((x) => x.end >= anchor.end);
    if (!first2 || !last2) throw Error("Source range missing");
    const range2 = doc().createRange();
    range2.setStart(first2.node, anchor.start - first2.start);
    range2.setEnd(last2.node, anchor.end - last2.start);
    return range2;
  }
  function selection() {
    if (initialising || !renderer?.getDocument()) return;
    const selected = doc().getSelection();
    if (!selected?.rangeCount || selected.isCollapsed) return;
    const range2 = selected.getRangeAt(0), { nodes } = canonical();
    const included = nodes.filter((x) => range2.intersectsNode(x.node));
    if (!included.length) return;
    const first2 = included[0], last2 = included[included.length - 1];
    const start = first2.start + (range2.startContainer === first2.node ? range2.startOffset : 0);
    const end = last2.start + (range2.endContainer === last2.node ? range2.endOffset : last2.node.length);
    const anchor = makeAnchor(start, end), key = version + ":" + start + ":" + end;
    if (anchor && key !== lastSelection) {
      lastSelection = key;
      post(envelope({ kind: "selection", anchor }));
    }
  }
  function project() {
    const css2 = doc().defaultView.CSS;
    const ranges = [];
    for (const note of notes) if (note.anchor.spineIndex === current) {
      try {
        ranges.push(rangeFor(note.anchor));
      } catch {
      }
    }
    for (const old of doc().querySelectorAll("[data-pdfno-overlay]")) old.remove();
    if (css2?.highlights) {
      const Highlight = doc().defaultView.Highlight;
      css2.highlights.set("pdfno-notes", new Highlight(...ranges));
    } else {
      for (const range2 of ranges) for (const r of range2.getClientRects()) {
        const mark = doc().createElement("div");
        mark.dataset.pdfnoOverlay = "";
        mark.style.cssText = `position:fixed;pointer-events:none;left:${r.left}px;top:${r.top}px;width:${r.width}px;height:${r.height}px;background:#ffdc73;mix-blend-mode:multiply;z-index:5`;
        doc().body.appendChild(mark);
      }
    }
  }
  function decorate() {
    const d = doc();
    d.documentElement.lang = /[\u3040-\u30ff]/.test(d.body.textContent) ? "ja" : "en";
    const style = d.createElement("style");
    style.textContent = "body{font:20px/1.85 system-ui;padding:24px!important;color:#222;background:#fff} ruby{ruby-position:over} ::highlight(pdfno-notes){background:#ffdc73;color:#222}";
    d.head.appendChild(style);
    d.addEventListener("selectionchange", selection);
    d.addEventListener("mouseup", selection);
    d.addEventListener("keyup", selection);
    d.addEventListener("click", (event) => {
      if (event.target.closest?.("a")) event.preventDefault();
    }, true);
    project();
  }
  async function chapter(index, vertical = false) {
    if (!Number.isSafeInteger(index) || index < 0 || index >= renderer.book.sections.length) throw Error("Invalid chapter");
    initialising = true;
    try {
      current = index;
      renderer.textOrientation = vertical ? "vertical" : "horizontal";
      window.textOrientation = renderer.textOrientation;
      handleLayout(renderer.element, renderer.readerMode, doc());
      await renderer.goToChapterDocIndex(index);
      version++;
      lastSelection = "";
      decorate();
    } finally {
      initialising = false;
    }
  }
  function progress() {
    const { nodes } = canonical(), width = renderer.element.clientWidth, height = renderer.element.clientHeight;
    const visible = nodes.find((x) => {
      const range3 = doc().createRange();
      range3.selectNodeContents(x.node);
      return [...range3.getClientRects()].some((r) => r.width > 0 && r.height > 0 && r.left < width && r.right > 0 && r.top < height && r.bottom > 0);
    });
    if (!visible) return null;
    let low = 0, high = visible.node.length;
    const range2 = doc().createRange(), vertical = renderer.isVertical();
    const rectAt = (offset) => {
      if (offset > 0 && /[\uDC00-\uDFFF]/.test(visible.node.data[offset])) offset--;
      range2.setStart(visible.node, offset);
      range2.setEnd(visible.node, Math.min(visible.node.length, offset + (visible.node.data.codePointAt(offset) > 65535 ? 2 : 1)));
      return range2.getBoundingClientRect();
    };
    while (low < high) {
      const middle = Math.floor((low + high) / 2), r = rectAt(middle);
      if (vertical ? r.bottom <= 0 : r.right <= 0) low = middle + 1;
      else high = middle;
    }
    const start = visible.start + low;
    return makeAnchor(start, Math.min(visible.end, start + 128));
  }
  function state() {
    const page = progressInfo(renderer.readerMode, doc(), renderer.element)?.currentPage ?? 1;
    return {
      kind: "state",
      spineIndex: current,
      chapterCount: renderer.book.sections.length,
      page: String(page),
      vertical: renderer.isVertical(),
      progress: progress(),
      outline: renderer.flattenChapters.map((x) => ({ title: x.label, index: x.index })).slice(0, 1e3)
    };
  }
  async function navigate(anchor) {
    await chapter(anchor.spineIndex, anchor.vertical);
    const range2 = rangeFor(anchor), glyph = range2.cloneRange();
    glyph.setEnd(range2.startContainer, Math.min(range2.startContainer.length, range2.startOffset + (range2.startContainer.data.codePointAt(range2.startOffset) > 65535 ? 2 : 1)));
    const r = glyph.getBoundingClientRect(), d = doc(), vertical = renderer.isVertical();
    const section = Math.floor((vertical ? renderer.element.clientHeight : renderer.element.clientWidth) / 12), gap = section % 2 === 0 ? section : section - 1;
    const stride = (vertical ? d.body.clientHeight : d.body.clientWidth) + gap;
    if (!Number.isFinite(stride) || stride <= 0) throw Error("Reader viewport unavailable");
    const absolute = vertical ? r.top + d.body.scrollTop : r.left + d.body.scrollLeft;
    const offset = Math.max(0, Math.floor((absolute + 0.5) / stride) * stride);
    d.body.scrollTo(vertical ? 0 : offset, vertical ? offset : 0);
    await renderer.record();
    renderer.trigger("rendered");
    const selection2 = d.getSelection();
    selection2.removeAllRanges();
    selection2.addRange(range2);
  }
  window.PDFno = { async command(message) {
    if (message.v !== 1 || typeof message.requestID !== "string") throw Error("Invalid bridge version");
    if (message.command !== "open" && (!identity2 || ["session", "bookID", "editionID", "fileSHA256"].some((k) => message[k] !== identity2[k]) || message.documentVersion !== version)) throw Error("Stale reader request");
    if (message.command === "open") {
      if (identity2) throw Error("A session can only open one book");
      identity2 = { session: message.session, bookID: message.bookID, editionID: message.editionID, fileSHA256: message.fileSHA256 };
      const raw = atob(message.payload.data);
      const buffer = Uint8Array.from(raw, (c) => c.charCodeAt(0));
      renderer = new EpubRender(buffer.buffer, message.payload.names);
      notes = message.payload.notes;
      await renderer.renderTo(document.getElementById("page-area"));
      await chapter(0, false);
      if (message.payload.progress) await navigate(message.payload.progress);
    } else if (message.command === "next" || message.command === "previous") {
      initialising = true;
      try {
        await renderer[message.command === "next" ? "next" : "prev"]();
        const target = Number(renderer.getPosition().chapterDocIndex ?? current);
        if (target !== current) {
          current = target;
          version++;
          decorate();
        }
      } finally {
        initialising = false;
      }
    } else if (message.command === "chapter") await chapter(message.payload.index, false);
    else if (message.command === "vertical") {
      const anchor = progress();
      if (!anchor) throw Error("No visible source position");
      anchor.vertical = !renderer.isVertical();
      await navigate(anchor);
    } else if (message.command === "navigate") await navigate(message.payload.anchor);
    else if (message.command === "notes") {
      notes = message.payload.notes;
      project();
    } else if (message.command === "resize") {
      const anchor = progress();
      if (anchor) await navigate(anchor);
    } else if (message.command === "chapterText") {
      const { text } = canonical();
      const chapterText = {
        resourceHref: renderer.book.sections[current].id,
        spineIndex: current,
        chapterCount: renderer.book.sections.length,
        utf16Count: text.length,
        text: text.length <= 3e3 ? text : null,
        vertical: renderer.isVertical()
      };
      return JSON.stringify(envelope({ ...state(), chapterText }, message.requestID));
    } else if (message.command === "validateAnchor") rangeFor(message.payload.anchor);
    else throw Error("Command is not allowed");
    project();
    return JSON.stringify(envelope(state(), message.requestID));
  } };
  post({ v: 1, payload: { kind: "ready" } });
  setInterval(selection, 100);
})();
