// Kookit 95f602e MOBI/KF8/FB2 restricted profile; corresponding source engine-build/. See Notices.txt.
(() => {
  // ebook-index.js
  async function boundedIndexData(index, loadRecord) {
    const bytes = async (i) => new Uint8Array(await loadRecord(i));
    const uint = (b, p, n = 4) => {
      if (p < 0 || p + n > b.length) throw Error("Truncated INDX");
      let v = 0;
      for (let i = 0; i < n; i++) v = v * 256 + b[p + i];
      return v;
    };
    const magic = (b, p, s) => s.split("").every((c, i) => b[p + i] === c.charCodeAt(0));
    const variable = (b, p, end) => {
      let value = 0;
      for (let n = 0; n < 4; n++) {
        if (p + n >= end) throw Error("Truncated INDX integer");
        const x = b[p + n];
        value = value * 128 + (x & 127);
        if (x & 128) {
          if (value > 4194304) throw Error("INDX value budget");
          return { value, length: n + 1 };
        }
      }
      throw Error("INDX integer too long");
    };
    const master = await bytes(index), length = uint(master, 4), records = uint(master, 24), cncxRecords = uint(master, 52);
    if (!magic(master, 0, "INDX") || records > 1e3 || cncxRecords > 100 || length < 56 || !magic(master, length, "TAGX")) throw Error("INDX header");
    const tagLength = uint(master, length + 4), controls = uint(master, length + 8);
    if (tagLength < 12 || tagLength > 1024 || tagLength % 4 || length + tagLength > master.length || controls < 1 || controls > 8) throw Error("TAGX structure");
    const tags = [];
    for (let p = length + 12; p < length + tagLength; p += 4) {
      const t = Array.from(master.subarray(p, p + 4));
      if (t[1] < 1 || t[1] > 8 || !t[2]) throw Error("TAGX mask");
      tags.push(t);
    }
    const decoder2 = new TextDecoder(uint(master, 28) === 1252 ? "windows-1252" : "utf-8", { fatal: true }), cncx = /* @__PURE__ */ Object.create(null);
    for (let i = 0; i < cncxRecords; i++) {
      const b = await bytes(index + records + i + 1);
      for (let p = 0; p < b.length; ) {
        const start = p, v = variable(b, p, b.length);
        p += v.length;
        if (p + v.value > b.length) throw Error("CNCX range");
        cncx[i * 65536 + start] = decoder2.decode(b.subarray(p, p + v.value));
        p += v.value;
      }
    }
    const table = [];
    for (let i = 0; i < records; i++) {
      const b = await bytes(index + i + 1), idxt = uint(b, 20), count = uint(b, 24), header = uint(b, 4);
      if (!magic(b, 0, "INDX") || count > 1e3 || idxt < header || !magic(b, idxt, "IDXT") || idxt + 4 + count * 2 > b.length) throw Error("IDXT structure");
      const offsets = Array.from({ length: count }, (_, j) => uint(b, idxt + 4 + j * 2, 2));
      for (let j = 0; j < count; j++) {
        const offset = offsets[j], end = offsets[j + 1] ?? idxt;
        if (offset < header || offset >= end || end > idxt) throw Error("INDX entry range");
        const nameLength = uint(b, offset, 1), start = offset + 1 + nameLength;
        if (start + controls > end) throw Error("INDX control bytes");
        const name = decoder2.decode(b.subarray(offset + 1, start)), tagMap = /* @__PURE__ */ Object.create(null);
        let p = start + controls, control = 0;
        for (const [tag, numValues, mask, terminator] of tags) {
          if (terminator & 1) {
            control++;
            continue;
          }
          if (control >= controls) throw Error("TAGX control range");
          const masked = b[start + control] & mask;
          let count2 = 0, byteCount = null;
          if (masked === mask) {
            if ((mask & mask - 1) !== 0) {
              const v = variable(b, p, end);
              p += v.length;
              byteCount = v.value;
            } else {
              const v = variable(b, p, end);
              p += v.length;
              count2 = v.value;
            }
          } else {
            let shift = 0;
            while ((mask >> shift & 1) === 0) shift++;
            count2 = masked >> shift;
          }
          if (count2 * numValues > 1e3 || byteCount !== null && byteCount > end - p) throw Error("TAGX values budget");
          const values = [];
          if (byteCount !== null) {
            const until = p + byteCount;
            while (p < until) {
              const v = variable(b, p, until);
              p += v.length;
              values.push(v.value);
            }
            if (values.length > 1e3) throw Error("TAGX values budget");
          } else for (let n = 0; n < count2 * numValues; n++) {
            const v = variable(b, p, end);
            p += v.length;
            values.push(v.value);
          }
          tagMap[tag] = values;
        }
        if (table.length >= 1e3) throw Error("INDX entries budget");
        table.push({ name, tagMap });
      }
    }
    return { table, cncx };
  }
  function boundedPalmDOC(bytes) {
    const output = [];
    let i = 0;
    while (i < bytes.length) {
      const x = bytes[i++];
      if (x === 0) output.push(0);
      else if (x <= 8) {
        if (i + x > bytes.length) throw Error("Truncated PalmDOC literal");
        output.push(...bytes.subarray(i, i + x));
        i += x;
      } else if (x <= 127) output.push(x);
      else if (x <= 191) {
        if (i >= bytes.length) throw Error("Truncated PalmDOC pair");
        const pair = x << 8 | bytes[i++], distance = (pair & 16383) >> 3, length = (pair & 7) + 3;
        if (!distance || distance > output.length) throw Error("Invalid PalmDOC distance");
        for (let j = 0; j < length; j++) output.push(output[output.length - distance]);
      } else output.push(32, x ^ 128);
      if (output.length > 4096) throw Error("PalmDOC expansion budget");
    }
    return Uint8Array.from(output);
  }

  // vendor/kookit/src/libs/mobi.js
  var unescapeHTML = (str) => {
    if (!str) return "";
    const textarea = document.createElement("textarea");
    textarea.innerHTML = str;
    return textarea.value;
  };
  var MIME = {
    XML: "application/xml",
    XHTML: "application/xhtml+xml",
    HTML: "text/html",
    CSS: "text/css",
    SVG: "image/svg+xml"
  };
  var PDB_HEADER = {
    name: [0, 32, "string"],
    type: [60, 4, "string"],
    creator: [64, 4, "string"],
    numRecords: [76, 2, "uint"]
  };
  var PALMDOC_HEADER = {
    compression: [0, 2, "uint"],
    numTextRecords: [8, 2, "uint"],
    recordSize: [10, 2, "uint"],
    encryption: [12, 2, "uint"]
  };
  var MOBI_HEADER = {
    magic: [16, 4, "string"],
    length: [20, 4, "uint"],
    type: [24, 4, "uint"],
    encoding: [28, 4, "uint"],
    uid: [32, 4, "uint"],
    version: [36, 4, "uint"],
    titleOffset: [84, 4, "uint"],
    titleLength: [88, 4, "uint"],
    localeRegion: [94, 1, "uint"],
    localeLanguage: [95, 1, "uint"],
    resourceStart: [108, 4, "uint"],
    huffcdic: [112, 4, "uint"],
    numHuffcdic: [116, 4, "uint"],
    exthFlag: [128, 4, "uint"],
    trailingFlags: [240, 4, "uint"],
    indx: [244, 4, "uint"]
  };
  var KF8_HEADER = {
    resourceStart: [108, 4, "uint"],
    fdst: [192, 4, "uint"],
    numFdst: [196, 4, "uint"],
    frag: [248, 4, "uint"],
    skel: [252, 4, "uint"],
    guide: [260, 4, "uint"]
  };
  var EXTH_HEADER = {
    magic: [0, 4, "string"],
    length: [4, 4, "uint"],
    count: [8, 4, "uint"]
  };
  var FDST_HEADER = {
    magic: [0, 4, "string"],
    numEntries: [8, 4, "uint"]
  };
  var MOBI_ENCODING = {
    1252: "windows-1252",
    65001: "utf-8"
  };
  var EXTH_RECORD_TYPE = {
    100: ["creator", "string", true],
    101: ["publisher"],
    103: ["description"],
    104: ["isbn"],
    105: ["subject", "string", true],
    106: ["date"],
    108: ["contributor", "string", true],
    109: ["rights"],
    110: ["subjectCode", "string", true],
    112: ["source", "string", true],
    113: ["asin"],
    121: ["boundary", "uint"],
    122: ["fixedLayout"],
    125: ["numResources", "uint"],
    126: ["originalResolution"],
    127: ["zeroGutter"],
    128: ["zeroMargin"],
    129: ["coverURI"],
    132: ["regionMagnification"],
    201: ["coverOffset", "uint"],
    202: ["thumbnailOffset", "uint"],
    503: ["title"],
    524: ["language", "string", true],
    527: ["pageProgressionDirection"]
  };
  var MOBI_LANG = {
    1: [
      "ar",
      "ar-SA",
      "ar-IQ",
      "ar-EG",
      "ar-LY",
      "ar-DZ",
      "ar-MA",
      "ar-TN",
      "ar-OM",
      "ar-YE",
      "ar-SY",
      "ar-JO",
      "ar-LB",
      "ar-KW",
      "ar-AE",
      "ar-BH",
      "ar-QA"
    ],
    2: ["bg"],
    3: ["ca"],
    4: ["zh", "zh-TW", "zh-CN", "zh-HK", "zh-SG"],
    5: ["cs"],
    6: ["da"],
    7: ["de", "de-DE", "de-CH", "de-AT", "de-LU", "de-LI"],
    8: ["el"],
    9: [
      "en",
      "en-US",
      "en-GB",
      "en-AU",
      "en-CA",
      "en-NZ",
      "en-IE",
      "en-ZA",
      "en-JM",
      null,
      "en-BZ",
      "en-TT",
      "en-ZW",
      "en-PH"
    ],
    10: [
      "es",
      "es-ES",
      "es-MX",
      null,
      "es-GT",
      "es-CR",
      "es-PA",
      "es-DO",
      "es-VE",
      "es-CO",
      "es-PE",
      "es-AR",
      "es-EC",
      "es-CL",
      "es-UY",
      "es-PY",
      "es-BO",
      "es-SV",
      "es-HN",
      "es-NI",
      "es-PR"
    ],
    11: ["fi"],
    12: ["fr", "fr-FR", "fr-BE", "fr-CA", "fr-CH", "fr-LU", "fr-MC"],
    13: ["he"],
    14: ["hu"],
    15: ["is"],
    16: ["it", "it-IT", "it-CH"],
    17: ["ja"],
    18: ["ko"],
    19: ["nl", "nl-NL", "nl-BE"],
    20: ["no", "nb", "nn"],
    21: ["pl"],
    22: ["pt", "pt-BR", "pt-PT"],
    23: ["rm"],
    24: ["ro"],
    25: ["ru"],
    26: ["hr", null, "sr"],
    27: ["sk"],
    28: ["sq"],
    29: ["sv", "sv-SE", "sv-FI"],
    30: ["th"],
    31: ["tr"],
    32: ["ur"],
    33: ["id"],
    34: ["uk"],
    35: ["be"],
    36: ["sl"],
    37: ["et"],
    38: ["lv"],
    39: ["lt"],
    41: ["fa"],
    42: ["vi"],
    43: ["hy"],
    44: ["az"],
    45: ["eu"],
    46: ["hsb"],
    47: ["mk"],
    48: ["st"],
    49: ["ts"],
    50: ["tn"],
    52: ["xh"],
    53: ["zu"],
    54: ["af"],
    55: ["ka"],
    56: ["fo"],
    57: ["hi"],
    58: ["mt"],
    59: ["se"],
    62: ["ms"],
    63: ["kk"],
    65: ["sw"],
    67: ["uz", null, "uz-UZ"],
    68: ["tt"],
    69: ["bn"],
    70: ["pa"],
    71: ["gu"],
    72: ["or"],
    73: ["ta"],
    74: ["te"],
    75: ["kn"],
    76: ["ml"],
    77: ["as"],
    78: ["mr"],
    79: ["sa"],
    82: ["cy", "cy-GB"],
    83: ["gl", "gl-ES"],
    87: ["kok"],
    97: ["ne"],
    98: ["fy"]
  };
  var concatTypedArray = (a, b) => {
    const result = new a.constructor(a.length + b.length);
    result.set(a);
    result.set(b, a.length);
    return result;
  };
  var concatTypedArray3 = (a, b, c) => {
    const result = new a.constructor(a.length + b.length + c.length);
    result.set(a);
    result.set(b, a.length);
    result.set(c, a.length + b.length);
    return result;
  };
  var decoder = new TextDecoder();
  var getString = (buffer) => decoder.decode(buffer);
  var getUint = (buffer) => {
    if (!buffer) return;
    const l = buffer.byteLength;
    const func = l === 4 ? "getUint32" : l === 2 ? "getUint16" : "getUint8";
    return new DataView(buffer)[func](0);
  };
  var getStruct = (def, buffer) => Object.fromEntries(
    Array.from(Object.entries(def)).map(([key, [start, len, type]]) => [
      key,
      (type === "string" ? getString : getUint)(
        buffer.slice(start, start + len)
      )
    ])
  );
  var getDecoder = (x) => new TextDecoder(MOBI_ENCODING[x], { fatal: true });
  var getVarLenFromEnd = (byteArray) => {
    let value = 0;
    for (const byte of byteArray.subarray(-4)) {
      if (byte & 128) value = 0;
      value = value << 7 | byte & 127;
    }
    return value;
  };
  var countBitsSet = (x) => {
    let count = 0;
    for (; x > 0; x = x >> 1) if ((x & 1) === 1) count++;
    return count;
  };
  var decompressPalmDOC = boundedPalmDOC;
  var huffcdic = () => {
    throw Error("HUFF/CDIC not supported");
  };
  var getIndexData = boundedIndexData;
  var getNCX = async (indxIndex, loadRecord) => {
    const { table, cncx } = await getIndexData(indxIndex, loadRecord);
    const items = table.map(({ tagMap }, index) => ({
      index,
      offset: tagMap[1]?.[0],
      size: tagMap[2]?.[0],
      label: cncx[tagMap[3]] ?? "",
      headingLevel: tagMap[4]?.[0],
      pos: tagMap[6],
      parent: tagMap[21]?.[0],
      firstChild: tagMap[22]?.[0],
      lastChild: tagMap[23]?.[0]
    }));
    const getChildren = (item) => {
      if (item.firstChild == null) return item;
      item.children = items.filter((x) => x.parent === item.index).map(getChildren);
      return item;
    };
    return items.filter((item) => item.headingLevel === 0).map(getChildren);
  };
  var getEXTH = (buf, encoding) => {
    const { magic, count } = getStruct(EXTH_HEADER, buf);
    if (magic !== "EXTH") throw new Error("Invalid EXTH header");
    const decoder2 = getDecoder(encoding);
    const results = {};
    let offset = 12;
    for (let i = 0; i < count; i++) {
      const type = getUint(buf.slice(offset, offset + 4));
      const length = getUint(buf.slice(offset + 4, offset + 8));
      if (type in EXTH_RECORD_TYPE) {
        const [name, typ, many] = EXTH_RECORD_TYPE[type];
        const data = buf.slice(offset + 8, offset + length);
        const value = typ === "uint" ? getUint(data) : decoder2.decode(data);
        if (many) {
          results[name] ??= [];
          results[name].push(value);
        } else results[name] = value;
      }
      offset += length;
    }
    return results;
  };
  var getFont = () => {
    throw Error("Font decoding disabled");
  };
  var isMOBI = async (file) => {
    const magic = getString(await file.slice(60, 68).arrayBuffer());
    return magic === "BOOKMOBI";
  };
  var PDB = class {
    #file;
    #offsets;
    pdb;
    async open(file) {
      this.#file = file;
      const pdb = getStruct(PDB_HEADER, await file.slice(0, 78).arrayBuffer());
      this.pdb = pdb;
      const buffer = await file.slice(78, 78 + pdb.numRecords * 8).arrayBuffer();
      this.#offsets = Array.from(
        { length: pdb.numRecords },
        (_, i) => getUint(buffer.slice(i * 8, i * 8 + 4))
      ).map((x, i, a) => [x, a[i + 1]]);
    }
    loadRecord(index) {
      const offsets = this.#offsets[index];
      if (!offsets) throw new RangeError("Record index out of bounds");
      return this.#file.slice(...offsets).arrayBuffer();
    }
    async loadMagic(index) {
      const start = this.#offsets[index][0];
      return getString(await this.#file.slice(start, start + 4).arrayBuffer());
    }
  };
  var MOBI = class extends PDB {
    #start = 0;
    #resourceStart;
    #decoder;
    #encoder;
    #decompress;
    #removeTrailingEntries;
    constructor({ unzlib }) {
      super();
      this.unzlib = unzlib;
    }
    async open(file) {
      await super.open(file);
      this.headers = this.#getHeaders(await super.loadRecord(0));
      if (this.headers.palmdoc.encryption || ![1, 2].includes(this.headers.palmdoc.compression)) throw Error("DRM/compression rejected");
      this.#resourceStart = this.headers.mobi.resourceStart;
      let isKF8 = this.headers.mobi.version >= 8;
      if (!isKF8) {
        const boundary = this.headers.exth?.boundary;
        if (boundary < 4294967295)
          try {
            this.headers = this.#getHeaders(await super.loadRecord(boundary));
            this.#start = boundary;
            isKF8 = true;
          } catch (e) {
            console.warn(e);
            console.warn("Failed to open KF8; falling back to MOBI");
          }
      }
      await this.#setup();
      return isKF8 ? new KF8(this).init() : new MOBI6(this).init();
    }
    #getHeaders(buf) {
      const palmdoc = getStruct(PALMDOC_HEADER, buf);
      const mobi = getStruct(MOBI_HEADER, buf);
      if (mobi.magic !== "MOBI") throw new Error("Missing MOBI header");
      const { titleOffset, titleLength, localeLanguage, localeRegion } = mobi;
      mobi.title = buf.slice(titleOffset, titleOffset + titleLength);
      const lang = MOBI_LANG[localeLanguage];
      mobi.language = lang?.[localeRegion >> 2] ?? lang?.[0];
      const exth = mobi.exthFlag & 64 ? getEXTH(buf.slice(mobi.length + 16), mobi.encoding) : null;
      const kf8 = mobi.version >= 8 ? getStruct(KF8_HEADER, buf) : null;
      return { palmdoc, mobi, exth, kf8 };
    }
    async #setup() {
      const { palmdoc, mobi } = this.headers;
      this.#decoder = getDecoder(mobi.encoding);
      this.#encoder = new TextEncoder();
      const { compression } = palmdoc;
      this.#decompress = compression === 1 ? (f) => f : compression === 2 ? decompressPalmDOC : compression === 17480 ? await huffcdic(mobi, this.loadRecord.bind(this)) : null;
      if (!this.#decompress) throw new Error("Unknown compression type");
      const { trailingFlags } = mobi;
      const multibyte = trailingFlags & 1;
      const numTrailingEntries = countBitsSet(trailingFlags >>> 1);
      this.#removeTrailingEntries = (array) => {
        for (let i = 0; i < numTrailingEntries; i++) {
          const length = getVarLenFromEnd(array);
          array = array.subarray(0, -length);
        }
        if (multibyte) {
          const length = (array[array.length - 1] & 3) + 1;
          array = array.subarray(0, -length);
        }
        return array;
      };
    }
    decode(...args) {
      return this.#decoder.decode(...args);
    }
    encode(...args) {
      return this.#encoder.encode(...args);
    }
    loadRecord(index) {
      return super.loadRecord(this.#start + index);
    }
    loadMagic(index) {
      return super.loadMagic(this.#start + index);
    }
    loadText(index) {
      return this.loadRecord(index + 1).then((buf) => new Uint8Array(buf)).then(this.#removeTrailingEntries).then(this.#decompress).then((data) => {
        if (data.length > 4096) throw Error("Text record budget");
        return data;
      });
    }
    async loadResource(index) {
      const buf = await super.loadRecord(this.#resourceStart + index);
      const magic = getString(buf.slice(0, 4));
      if (magic === "FONT") return getFont(buf, this.unzlib);
      if (magic === "VIDE" || magic === "AUDI") return buf.slice(12);
      return buf;
    }
    getNCX() {
      const index = this.headers.mobi.indx;
      if (index < 4294967295) return getNCX(index, this.loadRecord.bind(this));
    }
    getMetadata() {
      const { mobi, exth } = this.headers;
      return {
        identifier: mobi.uid.toString(),
        title: unescapeHTML(exth?.title || this.decode(mobi.title)),
        author: exth?.creator?.map(unescapeHTML),
        publisher: unescapeHTML(exth?.publisher),
        language: exth?.language ?? mobi.language,
        published: exth?.date,
        description: unescapeHTML(exth?.description),
        subject: exth?.subject?.map(unescapeHTML),
        rights: unescapeHTML(exth?.rights)
      };
    }
    async getCover() {
      const { exth } = this.headers;
      const offset = exth?.coverOffset < 4294967295 ? exth?.coverOffset : exth?.thumbnailOffset < 4294967295 ? exth?.thumbnailOffset : null;
      if (offset != null) {
        const buf = await this.loadResource(offset);
        return new Blob([buf]);
      }
    }
  };
  var mbpPagebreakRegex = /<\s*(?:mbp:)?pagebreak[^>]*>/gi;
  var fileposRegex = /<[^<>]+filepos=['"]{0,1}(\d+)[^<>]*>/gi;
  var getIndent = (el) => {
    let x = 0;
    while (el) {
      const parent = el.parentElement;
      if (parent) {
        const tag = parent.tagName.toLowerCase();
        if (tag === "p") x += 1.5;
        else if (tag === "blockquote") x += 2;
      }
      el = parent;
    }
    return x;
  };
  function rawBytesToString(uint8Array) {
    const chunkSize = 32768;
    let result = "";
    for (let i = 0; i < uint8Array.length; i += chunkSize) {
      result += String.fromCharCode.apply(
        null,
        uint8Array.subarray(i, i + chunkSize)
      );
    }
    return result;
  }
  var MOBI6 = class {
    parser = new DOMParser();
    serializer = new XMLSerializer();
    #resourceCache = /* @__PURE__ */ new Map();
    #textCache = /* @__PURE__ */ new Map();
    #cache = /* @__PURE__ */ new Map();
    #sections;
    #fileposList = [];
    #type = MIME.HTML;
    constructor(mobi) {
      this.mobi = mobi;
    }
    async init() {
      const recordBuffers = [];
      for (let i = 0; i < this.mobi.headers.palmdoc.numTextRecords; i++) {
        const buf = await this.mobi.loadText(i);
        recordBuffers.push(buf);
      }
      const totalLength = recordBuffers.reduce(
        (sum, buf) => sum + buf.byteLength,
        0
      );
      const array = new Uint8Array(totalLength);
      recordBuffers.reduce((offset, buf) => {
        array.set(new Uint8Array(buf), offset);
        return offset + buf.byteLength;
      }, 0);
      const str = rawBytesToString(array);
      let sectionCount = 0;
      for (const match of str.matchAll(mbpPagebreakRegex)) {
        if (++sectionCount >= 1e3) throw Error("MOBI section budget");
      }
      this.#sections = [0].concat(Array.from(str.matchAll(mbpPagebreakRegex), (m) => m.index)).map((start, i, a) => {
        const end = a[i + 1] ?? array.length;
        return { book: this, raw: array.subarray(start, end) };
      }).map((section, i, arr) => {
        section.start = arr[i - 1]?.end ?? 0;
        section.end = section.start + section.raw.byteLength;
        return section;
      });
      this.sections = this.#sections.map((section, index) => ({
        id: index,
        load: () => this.loadSection(section),
        createDocument: () => this.createDocument(section),
        resolveHref: (href) => this.resolveHref(href),
        size: section.end - section.start
      }));
      try {
        this.landmarks = await this.getGuide();
        const tocHref = this.landmarks.find(
          ({ type }) => type?.includes("toc")
        )?.href;
        if (tocHref) {
          const { index } = this.resolveHref(tocHref);
          const doc = await this.sections[index].createDocument();
          let lastItem;
          let lastLevel = 0;
          let lastIndent = 0;
          const lastLevelOfIndent = /* @__PURE__ */ new Map();
          const lastParentOfLevel = /* @__PURE__ */ new Map();
          this.toc = Array.from(doc.querySelectorAll("a[filepos]")).reduce(
            (arr, a) => {
              const indent = getIndent(a);
              const item = {
                label: a.innerText?.trim() ?? "",
                href: `#filepos${a.getAttribute("filepos")}`
              };
              const level = indent > lastIndent ? lastLevel + 1 : indent === lastIndent ? lastLevel : lastLevelOfIndent.get(indent) ?? Math.max(0, lastLevel - 1);
              if (level > lastLevel) {
                if (lastItem) {
                  lastItem.subitems ??= [];
                  lastItem.subitems.push(item);
                  lastParentOfLevel.set(level, lastItem);
                } else arr.push(item);
              } else {
                const parent = lastParentOfLevel.get(level);
                if (parent) parent.subitems.push(item);
                else arr.push(item);
              }
              lastItem = item;
              lastLevel = level;
              lastIndent = indent;
              lastLevelOfIndent.set(indent, level);
              return arr;
            },
            []
          );
        }
      } catch (e) {
        console.warn(e);
      }
      this.#fileposList = [
        ...new Set(Array.from(str.matchAll(fileposRegex), (m) => m[1]))
      ].map((filepos) => ({ filepos, number: Number(filepos) })).sort((a, b) => a.number - b.number);
      this.metadata = this.mobi.getMetadata();
      this.getCover = this.mobi.getCover.bind(this.mobi);
      return this;
    }
    async getGuide() {
      const doc = await this.createDocument(this.#sections[0]);
      return Array.from(doc.getElementsByTagName("reference"), (ref) => ({
        label: ref.getAttribute("title"),
        type: ref.getAttribute("type")?.split(/\s/),
        href: `#filepos${ref.getAttribute("filepos")}`
      }));
    }
    async loadResource(index) {
      if (this.#resourceCache.has(index)) return this.#resourceCache.get(index);
      const raw = await this.mobi.loadResource(index);
      const url = URL.createObjectURL(new Blob([raw]));
      this.#resourceCache.set(index, url);
      return url;
    }
    async loadRecindex(recindex) {
      return this.loadResource(Number(recindex) - 1);
    }
    async replaceResources(doc) {
      for (const img of doc.querySelectorAll("img[recindex]")) {
        const recindex = img.getAttribute("recindex");
        try {
          img.src = await this.loadRecindex(recindex);
        } catch (e) {
          console.warn(`Failed to load image ${recindex}`);
        }
      }
      for (const media of doc.querySelectorAll("[mediarecindex]")) {
        const mediarecindex = media.getAttribute("mediarecindex");
        const recindex = media.getAttribute("recindex");
        try {
          media.src = await this.loadRecindex(mediarecindex);
          if (recindex) media.poster = await this.loadRecindex(recindex);
        } catch (e) {
          console.warn(`Failed to load media ${mediarecindex}`);
        }
      }
      for (const a of doc.querySelectorAll("[filepos]")) {
        const filepos = a.getAttribute("filepos");
        a.href = `#filepos${filepos}`;
      }
    }
    async loadText(section) {
      if (this.#textCache.has(section)) return this.#textCache.get(section);
      const { raw } = section;
      const fileposList = this.#fileposList.filter(({ number }) => number >= section.start && number < section.end).map((obj) => ({ ...obj, offset: obj.number - section.start }));
      let arr = raw;
      if (fileposList.length) {
        arr = raw.subarray(0, fileposList[0].offset);
        fileposList.forEach(({ filepos, offset }, i) => {
          const next = fileposList[i + 1];
          const a = this.mobi.encode(`<a id="filepos${filepos}"></a>`);
          arr = concatTypedArray3(arr, a, raw.subarray(offset, next?.offset));
        });
      }
      const str = this.mobi.decode(arr).replaceAll(mbpPagebreakRegex, "");
      this.#textCache.set(section, str);
      return str;
    }
    async createDocument(section) {
      const str = await this.loadText(section);
      if (/<!DOCTYPE|<!ENTITY/i.test(str)) throw Error("Book declarations rejected");
      return this.parser.parseFromString(str, this.#type);
    }
    async loadSection(section) {
      if (this.#cache.has(section)) return this.#cache.get(section);
      const doc = await this.createDocument(section);
      const style2 = doc.createElement("style");
      doc.head.append(style2);
      style2.append(
        doc.createTextNode(`blockquote {
            margin-block-start: 0;
            margin-block-end: 0;
            margin-inline-start: 1em;
            margin-inline-end: 0;
        }`)
      );
      await this.replaceResources(doc);
      const result = this.serializer.serializeToString(doc);
      const url = URL.createObjectURL(new Blob([result], { type: this.#type }));
      this.#cache.set(section, url);
      return url;
    }
    resolveHref(href) {
      const filepos = href.match(/#filepos(.*)/)[1];
      const number = Number(filepos);
      const index = this.#sections.findIndex((section) => section.end > number);
      const anchor = (doc) => doc.getElementById(`filepos${filepos}`);
      return { index, anchor };
    }
    resolveHrefIndex(href) {
      const filepos = href.match(/#filepos(.*)/)[1];
      const number = Number(filepos);
      const index = this.#sections.findIndex((section) => section.end > number);
      return { index };
    }
    splitTOCHref(href) {
      const filepos = href.match(/#filepos(.*)/)[1];
      const number = Number(filepos);
      const index = this.#sections.findIndex((section) => section.end > number);
      return [index, `filepos${filepos}`];
    }
    getTOCFragment(doc, id) {
      return doc.getElementById(id);
    }
    isExternal(uri) {
      return /^(?!blob|filepos)\w+:/i.test(uri);
    }
    destroy() {
      for (const url of this.#resourceCache.values()) URL.revokeObjectURL(url);
      for (const url of this.#cache.values()) URL.revokeObjectURL(url);
    }
  };
  var kindleResourceRegex = /kindle:(flow|embed):(\w+)(?:\?mime=(\w+\/[-+.\w]+))?/;
  var kindlePosRegex = /kindle:pos:fid:(\w+):off:(\w+)/;
  var parseResourceURI = (str) => {
    const [resourceType, id, type] = str.match(kindleResourceRegex).slice(1);
    return { resourceType, id: parseInt(id, 32), type };
  };
  var parsePosURI = (str) => {
    const [fid, off] = str.match(kindlePosRegex).slice(1);
    return { fid: parseInt(fid, 32), off: parseInt(off, 32) };
  };
  var makePosURI = (fid = 0, off = 0) => `kindle:pos:fid:${fid.toString(32).toUpperCase().padStart(4, "0")}:off:${off.toString(32).toUpperCase().padStart(10, "0")}`;
  var getFragmentSelector = (str) => {
    const match = str.match(/\s(id|name|aid)\s*=\s*['"]([^'"]*)['"]/i);
    if (!match) return;
    const [, attr, value] = match;
    return `[${attr}="${CSS.escape(value)}"]`;
  };
  var replaceSeries = async (str, regex, f) => {
    const matches = [];
    str.replace(regex, (...args) => (matches.push(args), null));
    const results = [];
    for (const args of matches) results.push(await f(...args));
    return str.replace(regex, () => results.shift());
  };
  var getPageSpread = (properties) => {
    for (const p of properties) {
      if (p === "page-spread-left" || p === "rendition:page-spread-left")
        return "left";
      if (p === "page-spread-right" || p === "rendition:page-spread-right")
        return "right";
      if (p === "rendition:page-spread-center") return "center";
    }
  };
  var KF8 = class {
    parser = new DOMParser();
    serializer = new XMLSerializer();
    #cache = /* @__PURE__ */ new Map();
    #fragmentOffsets = /* @__PURE__ */ new Map();
    #fragmentSelectors = /* @__PURE__ */ new Map();
    #tables = {};
    #sections;
    #fullRawLength;
    #rawHead = new Uint8Array();
    #rawTail = new Uint8Array();
    #lastLoadedHead = -1;
    #lastLoadedTail = -1;
    #type = MIME.XHTML;
    #inlineMap = /* @__PURE__ */ new Map();
    constructor(mobi) {
      this.mobi = mobi;
    }
    async init() {
      const loadRecord = this.mobi.loadRecord.bind(this.mobi);
      const { kf8 } = this.mobi.headers;
      try {
        const fdstBuffer = await loadRecord(kf8.fdst);
        const fdst = getStruct(FDST_HEADER, fdstBuffer);
        if (fdst.magic !== "FDST") throw new Error("Missing FDST record");
        if (fdst.numEntries < 1 || fdst.numEntries > 1e3 || 12 + fdst.numEntries * 8 > fdstBuffer.byteLength) throw Error("FDST budget");
        const fdstTable = Array.from(
          { length: fdst.numEntries },
          (_, i) => 12 + i * 8
        ).map((offset) => [
          getUint(fdstBuffer.slice(offset, offset + 4)),
          getUint(fdstBuffer.slice(offset + 4, offset + 8))
        ]);
        this.#tables.fdstTable = fdstTable;
        this.#fullRawLength = fdstTable[fdstTable.length - 1][1];
      } catch {
      }
      const skelTable = (await getIndexData(kf8.skel, loadRecord)).table.map(
        ({ name, tagMap }, index) => ({
          index,
          name,
          numFrag: tagMap[1][0],
          offset: tagMap[6][0],
          length: tagMap[6][1]
        })
      );
      const fragData = await getIndexData(kf8.frag, loadRecord);
      const fragTable = fragData.table.map(({ name, tagMap }) => ({
        insertOffset: parseInt(name),
        selector: fragData.cncx[tagMap[2][0]],
        index: tagMap[4][0],
        offset: tagMap[6][0],
        length: tagMap[6][1]
      }));
      this.#tables.skelTable = skelTable;
      this.#tables.fragTable = fragTable;
      this.#sections = skelTable.reduce((arr, skel) => {
        const last = arr[arr.length - 1];
        const fragStart = last?.fragEnd ?? 0, fragEnd = fragStart + skel.numFrag;
        const frags = fragTable.slice(fragStart, fragEnd);
        if (skel.numFrag < 1 || skel.numFrag > 1e3 || frags.length !== skel.numFrag || skel.offset + skel.length > 4194304 || frags.some((f) => f.length < 1 || f.length > 4194304 || f.offset > 4194304 || f.insertOffset < skel.offset || f.insertOffset > skel.offset + skel.length)) throw Error("KF8 fragment bounds");
        const length = skel.length + frags.map((f) => f.length).reduce((a, b) => a + b);
        const totalLength = (last?.totalLength ?? 0) + length;
        return arr.concat({ skel, frags, fragEnd, length, totalLength });
      }, []);
      const resources = await this.getResourcesByMagic(["RESC", "PAGE"]);
      const pageSpreads = /* @__PURE__ */ new Map();
      if (resources.RESC) {
        const buf = await this.mobi.loadRecord(resources.RESC);
        const str = this.mobi.decode(buf.slice(16)).replace(/\0/g, "");
        const index = str.search(/\?>/);
        const xmlStr = `<package>${str.slice(index)}</package>`;
        const opf = this.parser.parseFromString(xmlStr, MIME.XML);
        for (const $itemref of opf.querySelectorAll("spine > itemref")) {
          const i = parseInt($itemref.getAttribute("skelid"));
          pageSpreads.set(
            i,
            getPageSpread($itemref.getAttribute("properties")?.split(" ") ?? [])
          );
        }
      }
      this.sections = this.#sections.map(
        (section, index) => section.frags.length ? {
          id: index,
          load: () => this.loadSection(section),
          createDocument: () => this.createDocument(section),
          resolveHref: (href) => this.resolveHref(href),
          size: section.length,
          pageSpread: pageSpreads.get(index)
        } : { linear: "no" }
      );
      try {
        const ncx = await this.mobi.getNCX();
        const map = ({ label, pos, children }) => {
          const [fid, off] = pos;
          const href = makePosURI(fid, off);
          const arr = this.#fragmentOffsets.get(fid);
          if (arr) arr.push(off);
          else this.#fragmentOffsets.set(fid, [off]);
          return {
            label: unescapeHTML(label),
            href,
            subitems: children?.map(map)
          };
        };
        this.toc = ncx?.map(map);
        this.landmarks = await this.getGuide();
      } catch (e) {
        console.warn(e);
      }
      const { exth } = this.mobi.headers;
      this.dir = exth.pageProgressionDirection;
      this.rendition = {
        layout: exth.fixedLayout === "true" ? "pre-paginated" : "reflowable",
        viewport: Object.fromEntries(
          exth.originalResolution?.split("x")?.slice(0, 2)?.map((x, i) => [i ? "height" : "width", x]) ?? []
        )
      };
      this.metadata = this.mobi.getMetadata();
      this.getCover = this.mobi.getCover.bind(this.mobi);
      return this;
    }
    // is this really the only way of getting to RESC, PAGE, etc.?
    async getResourcesByMagic(keys) {
      const results = {};
      const start = this.mobi.headers.kf8.resourceStart;
      const end = this.mobi.pdb.numRecords;
      for (let i = start; i < end; i++) {
        try {
          const magic = await this.mobi.loadMagic(i);
          const match = keys.find((key) => key === magic);
          if (match) results[match] = i;
        } catch {
        }
      }
      return results;
    }
    async getGuide() {
      const index = this.mobi.headers.kf8.guide;
      if (index < 4294967295) {
        const loadRecord = this.mobi.loadRecord.bind(this.mobi);
        const { table, cncx } = await getIndexData(index, loadRecord);
        return table.map(({ name, tagMap }) => ({
          label: cncx[tagMap[1][0]] ?? "",
          type: name?.split(/\s/),
          href: makePosURI(tagMap[6]?.[0] ?? tagMap[3]?.[0])
        }));
      }
    }
    async loadResourceBlob(str) {
      let { resourceType, id, type } = parseResourceURI(str);
      if (type === "image/jpg") {
        type = "image/jpeg";
      }
      const raw = resourceType === "flow" ? await this.loadFlow(id) : await this.mobi.loadResource(id - 1);
      const result = [MIME.XHTML, MIME.HTML, MIME.CSS, MIME.SVG].includes(type) ? await this.replaceResources(this.mobi.decode(raw)) : raw;
      const doc = type === MIME.SVG ? this.parser.parseFromString(result, type) : null;
      return [
        new Blob([result], { type }),
        // SVG wrappers need to be inlined
        // as browsers don't allow external resources when loading SVG as an image
        doc?.getElementsByTagNameNS("http://www.w3.org/2000/svg", "image")?.length ? doc.documentElement : null
      ];
    }
    async loadResource(str) {
      if (this.#cache.has(str)) return this.#cache.get(str);
      const [blob, inline] = await this.loadResourceBlob(str);
      const url = inline ? str : URL.createObjectURL(blob);
      if (inline) this.#inlineMap.set(url, inline);
      this.#cache.set(str, url);
      return url;
    }
    replaceResources(str) {
      const regex = new RegExp(kindleResourceRegex, "g");
      return replaceSeries(str, regex, this.loadResource.bind(this));
    }
    // NOTE: there doesn't seem to be a way to access text randomly?
    // how to know the decompressed size of the records without decompressing?
    // 4096 is just the maximum size
    async loadRaw(start, end) {
      const distanceHead = end - this.#rawHead.length;
      const distanceEnd = this.#fullRawLength == null ? Infinity : this.#fullRawLength - this.#rawTail.length - start;
      if (distanceHead < 0 || distanceHead < distanceEnd) {
        if (start < 0 || end < start || end > 4194304) throw Error("KF8 raw range");
        while (this.#rawHead.length < end) {
          const index = ++this.#lastLoadedHead;
          if (index >= this.mobi.headers.palmdoc.numTextRecords) throw Error("KF8 text range");
          const data = await this.mobi.loadText(index);
          this.#rawHead = concatTypedArray(this.#rawHead, data);
        }
        return this.#rawHead.slice(start, end);
      }
      while (this.#fullRawLength - this.#rawTail.length > start) {
        const index = this.mobi.headers.palmdoc.numTextRecords - 1 - ++this.#lastLoadedTail;
        if (index < 0) throw Error("KF8 text range");
        const data = await this.mobi.loadText(index);
        this.#rawTail = concatTypedArray(data, this.#rawTail);
      }
      const rawTailStart = this.#fullRawLength - this.#rawTail.length;
      return this.#rawTail.slice(start - rawTailStart, end - rawTailStart);
    }
    loadFlow(index) {
      if (index < 4294967295)
        return this.loadRaw(...this.#tables.fdstTable[index]);
    }
    async loadText(section) {
      const { skel, frags, length } = section;
      const raw = await this.loadRaw(skel.offset, skel.offset + length);
      let skeleton = raw.slice(0, skel.length);
      for (const frag of frags) {
        const insertOffset = frag.insertOffset - skel.offset;
        const offset = skel.length + frag.offset;
        const fragRaw = raw.slice(offset, offset + frag.length);
        skeleton = concatTypedArray3(
          skeleton.slice(0, insertOffset),
          fragRaw,
          skeleton.slice(insertOffset)
        );
        const offsets = this.#fragmentOffsets.get(frag.index);
        if (offsets)
          for (const offset2 of offsets) {
            const str = this.mobi.decode(fragRaw.slice(offset2));
            const selector = getFragmentSelector(str);
            this.#setFragmentSelector(frag.index, offset2, selector);
          }
      }
      return this.mobi.decode(skeleton);
    }
    async createDocument(section) {
      const str = await this.loadText(section);
      if (/<!DOCTYPE|<!ENTITY/i.test(str)) throw Error("Book declarations rejected");
      return this.parser.parseFromString(str, this.#type);
    }
    async loadSection(section) {
      if (this.#cache.has(section)) return this.#cache.get(section);
      const str = await this.loadText(section);
      if (/<!DOCTYPE|<!ENTITY/i.test(str)) throw Error("Book declarations rejected");
      const replaced = await this.replaceResources(str);
      let doc = this.parser.parseFromString(replaced, this.#type);
      if (doc.querySelector("parsererror")) {
        this.#type = MIME.HTML;
        doc = this.parser.parseFromString(replaced, this.#type);
      }
      for (const [url2, node] of this.#inlineMap) {
        for (const el of doc.querySelectorAll(`img[src="${url2}"]`))
          el.replaceWith(node);
      }
      const url = URL.createObjectURL(
        new Blob([this.serializer.serializeToString(doc)], { type: this.#type })
      );
      this.#cache.set(section, url);
      return url;
    }
    getIndexByFID(fid) {
      return this.#sections.findIndex(
        (section) => section.frags.some((frag) => frag.index === fid)
      );
    }
    #setFragmentSelector(id, offset, selector) {
      const map = this.#fragmentSelectors.get(id);
      if (map) map.set(offset, selector);
      else {
        const map2 = /* @__PURE__ */ new Map();
        this.#fragmentSelectors.set(id, map2);
        map2.set(offset, selector);
      }
    }
    async resolveHref(href) {
      const { fid, off } = parsePosURI(href);
      const index = this.getIndexByFID(fid);
      if (index < 0) return;
      const saved = this.#fragmentSelectors.get(fid)?.get(off);
      if (saved) return { index, anchor: (doc) => doc.querySelector(saved) };
      const { skel, frags } = this.#sections[index];
      const frag = frags.find((frag2) => frag2.index === fid);
      const offset = skel.offset + skel.length + frag.offset;
      const fragRaw = await this.loadRaw(offset, offset + frag.length);
      const str = this.mobi.decode(fragRaw.slice(off));
      const selector = getFragmentSelector(str);
      this.#setFragmentSelector(fid, off, selector);
      const anchor = (doc) => doc.querySelector(selector);
      return { index, anchor };
    }
    async resolveHrefIndex(href) {
      const { fid, off } = parsePosURI(href);
      const index = this.getIndexByFID(fid);
      if (index < 0) return;
      return { index };
    }
    splitTOCHref(href) {
      const pos = parsePosURI(href);
      const index = this.getIndexByFID(pos.fid);
      return [index, pos];
    }
    getTOCFragment(doc, { fid, off }) {
      const selector = this.#fragmentSelectors.get(fid)?.get(off);
      return doc.querySelector(selector);
    }
    isExternal(uri) {
      return /^(?!blob|kindle)\w+:/i.test(uri);
    }
    destroy() {
      for (const url of this.#cache.values()) URL.revokeObjectURL(url);
    }
  };

  // vendor/kookit/src/libs/fb2.js
  var trim = (str) => str?.trim()?.replace(/\s{2,}/g, " ");
  var getElementText = (el) => trim(el?.textContent);
  var NS = {
    XLINK: "http://www.w3.org/1999/xlink",
    EPUB: "http://www.idpf.org/2007/ops"
  };
  var MIME2 = {
    XML: "application/xml",
    XHTML: "application/xhtml+xml"
  };
  var STYLE = {
    strong: ["strong", "self"],
    emphasis: ["em", "self"],
    style: ["span", "self"],
    a: "anchor",
    strikethrough: ["s", "self"],
    sub: ["sub", "self"],
    sup: ["sup", "self"],
    code: ["code", "self"],
    image: "image"
  };
  var TABLE = {
    tr: ["tr", ["align"]],
    th: ["th", ["colspan", "rowspan", "align", "valign"]],
    td: ["td", ["colspan", "rowspan", "align", "valign"]]
  };
  var POEM = {
    epigraph: ["blockquote"],
    subtitle: ["h2", STYLE],
    "text-author": ["p", STYLE],
    date: ["p", STYLE],
    stanza: "stanza"
  };
  var SECTION = {
    title: [
      "header",
      {
        p: ["h1", STYLE],
        "empty-line": ["br"]
      }
    ],
    epigraph: ["blockquote", "self"],
    image: "image",
    annotation: ["aside"],
    section: ["section", "self"],
    p: ["p", STYLE],
    poem: ["blockquote", POEM],
    subtitle: ["h2", STYLE],
    cite: ["blockquote", "self"],
    "empty-line": ["br"],
    table: ["table", TABLE],
    "text-author": ["p", STYLE]
  };
  POEM["epigraph"].push(SECTION);
  var BODY = {
    image: "image",
    title: [
      "section",
      {
        p: ["h1", STYLE],
        "empty-line": ["br"]
      }
    ],
    epigraph: ["section", SECTION],
    section: ["section", SECTION]
  };
  var getImageSrc = (el) => {
    const href = el.getAttributeNS(NS.XLINK, "href");
    const [, id] = href.split("#");
    const bin = el.getRootNode().getElementById(id);
    return bin ? `data:${bin.getAttribute("content-type")};base64,${bin.textContent}` : href;
  };
  var FB2Converter = class {
    constructor(fb2) {
      this.fb2 = fb2;
      this.doc = document.implementation.createDocument(NS.XHTML, "html");
    }
    image(node) {
      const el = this.doc.createElement("img");
      el.alt = node.getAttribute("alt");
      el.title = node.getAttribute("title");
      el.setAttribute("src", getImageSrc(node));
      return el;
    }
    anchor(node) {
      const el = this.convert(node, { a: ["a", STYLE] });
      el.setAttribute("href", node.getAttributeNS(NS.XLINK, "href"));
      if (node.getAttribute("type") === "note")
        el.setAttributeNS(NS.EPUB, "epub:type", "noteref");
      return el;
    }
    stanza(node) {
      const el = this.convert(node, {
        stanza: [
          "p",
          {
            title: [
              "header",
              {
                p: ["strong", STYLE],
                "empty-line": ["br"]
              }
            ],
            subtitle: ["p", STYLE]
          }
        ]
      });
      for (const child of node.children)
        if (child.nodeName === "v") {
          el.append(this.doc.createTextNode(child.textContent));
          el.append(this.doc.createElement("br"));
        }
      return el;
    }
    convert(node, def) {
      if (node.nodeType === 3) return this.doc.createTextNode(node.textContent);
      if (node.nodeType === 4)
        return this.doc.createCDATASection(node.textContent);
      if (node.nodeType === 8) return this.doc.createComment(node.textContent);
      const d = def?.[node.nodeName];
      if (!d) return null;
      if (typeof d === "string") return this[d](node);
      const [name, opts] = d;
      const el = this.doc.createElement(name);
      if (node.id) el.id = node.id;
      el.classList.add(node.nodeName);
      if (Array.isArray(opts))
        for (const attr of opts) el.setAttribute(attr, node.getAttribute(attr));
      const childDef = opts === "self" ? def : Array.isArray(opts) ? null : opts;
      let child = node.firstChild;
      while (child) {
        const childEl = this.convert(child, childDef);
        if (childEl) el.append(childEl);
        child = child.nextSibling;
      }
      return el;
    }
  };
  var parseXML = async (blob) => {
    const buffer = await blob.arrayBuffer();
    const str = new TextDecoder("utf-8").decode(buffer);
    const parser = new DOMParser();
    const doc = parser.parseFromString(str, MIME2.XML);
    const encoding = doc.xmlEncoding || // `Document.xmlEncoding` is deprecated, and already removed in Firefox
    // so parse the XML declaration manually
    str.match(
      /^<\?xml\s+version\s*=\s*["']1.\d+"\s+encoding\s*=\s*["']([A-Za-z0-9._-]*)["']/
    )?.[1];
    if (encoding && encoding.toLowerCase() !== "utf-8") {
      const str2 = new TextDecoder(encoding).decode(buffer);
      return parser.parseFromString(str2, MIME2.XML);
    }
    return doc;
  };
  var style = URL.createObjectURL(
    new Blob(
      [
        `
@namespace epub "http://www.idpf.org/2007/ops";
body > img, section > img {
    display: block;
    margin: auto;
}
.title {
    text-align: center;
}
body > section > .title, body.notesBodyType > .title {
    margin: 3em 0;
}
body.notesBodyType > section .title {
    text-align: left;
    margin: 1em 0;
}
p {
    text-indent: 1em;
    margin: 0;
}
:not(p) + p, p:first-child {
    text-indent: 0;
}
.poem p {
    text-indent: 0;
    margin: 1em 0;
}
.text-author, .date {
    text-align: end;
}
.text-author:before {
    content: "\u2014";
}
table {
    border-collapse: collapse;
}
td, th {
    padding: .25em;
}
a[epub|type~="noteref"] {
    font-size: .75em;
    vertical-align: super;
}
body:not(.notesBodyType) > .title, body:not(.notesBodyType) > .epigraph {
    margin: 3em 0;
}
`
      ],
      { type: "text/css" }
    )
  );
  var template = (html) => `<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
    <head><link href="${style}" rel="stylesheet" type="text/css"/></head>
    <body>${html}</body>
</html>`;
  var dataID = "data-foliate-id";
  var makeFB2 = async (blob) => {
    const book = {};
    const doc = await parseXML(blob);
    const converter = new FB2Converter(doc);
    const $ = (x) => doc.querySelector(x);
    const $$ = (x) => [...doc.querySelectorAll(x)];
    const getPerson = (el) => {
      const nick = getElementText(el.querySelector("nickname"));
      if (nick) return nick;
      const first = getElementText(el.querySelector("first-name"));
      const middle = getElementText(el.querySelector("middle-name"));
      const last = getElementText(el.querySelector("last-name"));
      const name = [first, middle, last].filter((x) => x).join(" ");
      const sortAs = last ? [last, [first, middle].filter((x) => x).join(" ")].join(", ") : null;
      return { name, sortAs };
    };
    const getDate = (el) => el?.getAttribute("value") ?? getElementText(el);
    const annotation = $("title-info annotation");
    book.metadata = {
      title: getElementText($("title-info book-title")),
      identifier: getElementText($("document-info id")),
      language: getElementText($("title-info lang")),
      author: $$("title-info author").map(getPerson),
      translator: $$("title-info translator").map(getPerson),
      producer: $$("document-info author").map(getPerson).concat($$("document-info program-used").map(getElementText)),
      publisher: getElementText($("publish-info publisher")),
      published: getDate($("title-info date")),
      modified: getDate($("document-info date")),
      description: annotation ? converter.convert(annotation, { annotation: ["div", SECTION] }).innerHTML : null,
      subject: $$("title-info genre").map(getElementText)
    };
    book.getCover = () => fetch(getImageSrc($("coverpage image"))).then((res) => res.blob());
    const bodyData = Array.from(doc.querySelectorAll("body"), (body) => {
      const converted = converter.convert(body, { body: ["body", BODY] });
      return [
        Array.from(converted.children, (el) => {
          const ids = [el, ...el.querySelectorAll("[id]")].map((el2) => el2.id);
          return { el, ids };
        }),
        converted
      ];
    });
    const sectionData = bodyData[0][0].map(({ el, ids }) => {
      const titles = Array.from(
        el.querySelectorAll(":scope > section > .title"),
        (el2, index) => {
          el2.setAttribute(dataID, index);
          return { title: getElementText(el2), index };
        }
      );
      return { ids, titles, el };
    }).concat(
      bodyData.slice(1).map(([sections, body]) => {
        const ids = sections.map((s) => s.ids).flat();
        body.classList.add("notesBodyType");
        return { ids, el: body, linear: "no" };
      })
    ).map(({ ids, titles, el, linear }) => {
      const str = template(el.outerHTML);
      const blob2 = new Blob([str], { type: MIME2.XHTML });
      const url = URL.createObjectURL(blob2);
      const title = trim(
        el.querySelector(".title, .subtitle, p")?.textContent ?? (el.classList.contains("title") ? el.textContent : "")
      );
      return {
        ids,
        title,
        titles,
        load: () => url,
        createDocument: () => new DOMParser().parseFromString(str, MIME2.XHTML),
        // doo't count image data as it'd skew the size too much
        size: blob2.size - Array.from(
          el.querySelectorAll("[src]"),
          (el2) => el2.getAttribute("src")?.length ?? 0
        ).reduce((a, b) => a + b, 0),
        linear
      };
    });
    const idMap = /* @__PURE__ */ new Map();
    book.sections = sectionData.map((section, index) => {
      const { ids, load, createDocument, size, linear } = section;
      for (const id of ids) if (id) idMap.set(id, index);
      return { id: index, load, createDocument, size, linear };
    });
    book.toc = sectionData.map(({ title, titles }, index) => {
      const id = index.toString();
      return {
        label: title,
        href: id,
        subitems: titles?.length ? titles.map(({ title: title2, index: index2 }) => ({
          label: title2,
          href: `${id}#${index2}`
        })) : null
      };
    }).filter((item) => item);
    book.resolveHref = (href) => {
      const [a, b] = href.split("#");
      return a ? (
        // the link is from the TOC
        {
          index: Number(a),
          anchor: (doc2) => doc2.querySelector(`[${dataID}="${b}"]`)
        }
      ) : (
        // link from within the page
        { index: idMap.get(b), anchor: (doc2) => doc2.getElementById(b) }
      );
    };
    book.resolveHrefIndex = (href) => {
      const [a, b] = href.split("#");
      return a ? {
        index: Number(a)
      } : { index: idMap.get(b) };
    };
    book.splitTOCHref = (href) => href?.split("#")?.map((x) => Number(x)) ?? [];
    book.getTOCFragment = (doc2, id) => doc2.querySelector(`[${dataID}="${id}"]`);
    return book;
  };

  // ebook-adapter.js
  var engine = "kookit-foliate-95f602e";
  var extractionVersion = "ebook-kookit-utf16-1";
  async function extractEbook(buffer, format) {
    if (!(buffer instanceof ArrayBuffer) || buffer.byteLength > 8 * 1024 * 1024 || !["mobi", "azw", "azw3", "fb2"].includes(format)) throw Error("Ebook input profile");
    let book, kind;
    if (format === "fb2") {
      const str = new TextDecoder("utf-8", { fatal: true }).decode(buffer);
      if (/<!DOCTYPE|<!ENTITY|\0/i.test(str) || /encoding\s*=\s*["'](?!utf-8["'])/i.test(str)) throw Error("FB2 encoding/entities profile");
      const doc = new DOMParser().parseFromString(str, "application/xml");
      if (doc.querySelector("parsererror") || doc.documentElement.localName !== "FictionBook" || doc.documentElement.namespaceURI !== "http://www.gribuser.ru/xml/fictionbook/2.0") throw Error("Invalid FB2");
      let nodes = 0;
      const check = (n, d) => {
        if (++nodes > 1e5 || d > 48) throw Error("FB2 structure budget");
        for (const c of n.childNodes) check(c, d + 1);
      };
      check(doc, 0);
      if (doc.querySelector("binary") || doc.querySelectorAll("body > *").length > 1e3 || Array.from(doc.querySelectorAll("body")).some((b) => b.parentElement !== doc.documentElement)) throw Error("FB2 text-only/section profile");
      book = await makeFB2(new Blob([buffer]));
      kind = "fb2";
    } else {
      const file = new Blob([buffer]);
      if (!await isMOBI(file)) throw Error("Not MOBI");
      const bytes = new Uint8Array(buffer), view = new DataView(buffer), u32 = (p) => view.getUint32(p), u16 = (p) => view.getUint16(p);
      const count = u16(76);
      if (count < 2 || count > 1e3 || 78 + count * 8 + 2 > buffer.byteLength) throw Error("PDB record budget");
      const r = u32(78);
      if (r < 78 + count * 8 + 2 || r + 280 > buffer.byteLength) throw Error("MOBI header range");
      const version = u32(r + 36);
      kind = version === 8 ? "kf8" : "mobi6";
      if (![6, 8].includes(version) || format === "azw3" && version !== 8 || u16(r + 12) !== 0 || ![1, 2].includes(u16(r)) || u32(r + 240) !== 0 || u32(r + 244) !== 4294967295 || version === 8 && u32(r + 260) !== 4294967295 || u16(r + 8) >= count) throw Error("MOBI restricted profile/DRM");
      const header = u32(r + 20);
      if (header < 248 || header > 512 || r + 16 + header > buffer.byteLength) throw Error("MOBI length");
      if (u32(r + 128) & 64) {
        let p = r + 16 + header;
        const len = u32(p + 4), n = u32(p + 8);
        if (n > 1e3 || len < 12 || p + len > u32(86)) throw Error("EXTH range");
        const end = p + len;
        p += 12;
        for (let i = 0; i < n; i++) {
          const type = u32(p), l = u32(p + 4);
          if (l < 8 || p + l > end || [121, 122, 125, 126, 132].includes(type)) throw Error("Combo/fixed layout profile");
          p += l;
        }
      }
      book = await new MOBI({ unzlib: () => {
        throw Error("Embedded fonts/resources disabled");
      } }).open(file);
    }
    if (!book.sections?.length || book.sections.length > 1e3 || book.rendition?.layout === "pre-paginated") throw Error("Ebook sections profile");
    const blocks = [], warnings = ["\u6B63\u6587\u91CD\u6392\uFF1B\u56FE\u7247\u3001\u5B57\u4F53\u3001\u94FE\u63A5\u76EE\u6807\u548C\u539F\u59CB\u5206\u9875\u4E0D\u663E\u793A\u3002"];
    let start = 0, work = 0;
    const active = /* @__PURE__ */ new Set(["script", "style", "iframe", "object", "embed", "svg", "math", "form", "input", "button", "link", "meta", "base", "audio", "video", "noscript"]);
    const breaks = /* @__PURE__ */ new Set(["p", "h1", "h2", "h3", "h4", "h5", "h6", "li", "pre", "blockquote", "div", "section", "header", "td", "th", "tr"]);
    const name = (n) => (n.localName || "").toLowerCase();
    for (let section = 0; section < book.sections.length; section++) {
      let flush = function() {
        const text = runs.map((r) => r.text).join("");
        if (text.trim()) {
          if (blocks.length >= 1e4 || start + text.length > 1e6) throw Error("Ebook canonical budget");
          blocks.push({ id: blocks.length, start, section, runs, headingLevel: heading, listLevel: null, table: null, row: null, cell: null });
          start += text.length + 1;
        }
        runs = [];
        heading = null;
      }, walk = function(n, depth, bold = false, italic = false) {
        if (++work > 3e5 || depth > 48) throw Error("Ebook DOM work budget");
        if (n.nodeType === 3 || n.nodeType === 4) {
          if (n.nodeValue) runs.push({ text: n.nodeValue, bold, italic, ruby: null });
          return;
        }
        if (n.nodeType !== 1) return;
        const tag = name(n);
        if (active.has(tag) || ["rt", "rp"].includes(tag)) return;
        if (tag === "img") return;
        if (tag === "br") {
          runs.push({ text: "\n", bold, italic, ruby: null });
          return;
        }
        const block = breaks.has(tag);
        if (block) {
          flush();
          heading = /^h[1-6]$/.test(tag) ? Number(tag[1]) : n.classList.contains("title") || n.parentElement?.closest(".title") ? 1 : null;
        }
        if (tag === "ruby") {
          const rubyBase = (node, d) => {
            if (++work > 3e5 || d > 48) throw Error("Ruby structure budget");
            if (node.nodeType === 3 || node.nodeType === 4) return node.nodeValue || "";
            if (node.nodeType !== 1 || active.has(name(node)) || ["rt", "rp"].includes(name(node))) return "";
            return Array.from(node.childNodes).map((c) => rubyBase(c, d + 1)).join("");
          };
          const base = rubyBase(n, depth);
          const ruby = Array.from(n.querySelectorAll("rt")).map((c) => c.textContent).join("");
          if (ruby.length > 1024) throw Error("Ruby budget");
          runs.push({ text: base, bold, italic, ruby });
        } else for (const c of n.childNodes) walk(c, depth + 1, bold || ["strong", "b"].includes(tag), italic || ["em", "i"].includes(tag));
        if (block) flush();
      };
      if (book.sections[section].linear === "no") continue;
      const doc = await book.sections[section].createDocument();
      if (!doc || doc.querySelector("parsererror")) throw Error("Invalid ebook section XML");
      let runs = [], heading = null;
      for (const n of (doc.body || doc.documentElement).childNodes) walk(n, 0);
      flush();
    }
    book.destroy?.();
    if (!blocks.length) throw Error("Empty ebook body");
    return { engine, extractionVersion, contentKind: kind, document: { blocks, warnings } };
  }
  window.PDFnoEbookEngine = { async extract(message) {
    const binary = atob(message.data), bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
    const result = await extractEbook(bytes.buffer, message.format);
    return JSON.stringify({ ...result, v: 1, session: message.session, bookID: message.bookID, editionID: message.editionID, fileSHA256: message.fileSHA256, format: message.format });
  } };
})();
