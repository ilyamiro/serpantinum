.pragma library

var FUNCTIONS = {
    "sin": "sin", "cos": "cos", "tan": "tan",
    "asin": "asin", "acos": "acos", "atan": "atan",
    "arcsin": "asin", "arccos": "acos", "arctan": "atan",
    "sinh": "sinh", "cosh": "cosh", "tanh": "tanh",
    "asinh": "asinh", "acosh": "acosh", "atanh": "atanh",
    "ln": "ln", "log": "log", "lg": "log",
    "sqrt": "sqrt", "cbrt": "cbrt", "abs": "abs", "exp": "exp"
};

var CONSTANTS = { "pi": Math.PI, "e": Math.E };

var FUNCTION_TOKEN = "(?:10\\^|e\\^|sinh⁻¹|cosh⁻¹|tanh⁻¹|sin⁻¹|cos⁻¹|tan⁻¹|sinh|cosh|tanh|sin|cos|tan|ln|log|√|∛|exp|abs)";
var TRAILING_FUNCTION = new RegExp(FUNCTION_TOKEN + "?\\($");
var TRAILING_FUNCTION_ONLY = new RegExp(FUNCTION_TOKEN + "\\($");

function fail(code) {
    throw new Error(code);
}

function tokenize(src) {
    var s = String(src);
    var tokens = [];
    var i = 0;
    while (i < s.length) {
        if (/\s/.test(s.charAt(i))) { i++; continue; }
        var rest = s.slice(i);
        var m = /^(\d+\.?\d*|\.\d+)(E[+\-−]?\d+)?/.exec(rest);
        if (m) {
            tokens.push({ t: "num", v: parseFloat(m[0].replace("−", "-")) });
            i += m[0].length;
            continue;
        }
        m = /^(sinh|cosh|tanh|sin|cos|tan)⁻¹/.exec(rest);
        if (m) {
            tokens.push({ t: "fn", v: "a" + m[1] });
            i += m[0].length;
            continue;
        }
        var c = rest.charAt(0);
        if (c === "+") { tokens.push({ t: "op", v: "+" }); i++; continue; }
        if (c === "-" || c === "−" || c === "–") { tokens.push({ t: "op", v: "-" }); i++; continue; }
        if (c === "*" || c === "×" || c === "·") { tokens.push({ t: "op", v: "*" }); i++; continue; }
        if (c === "/" || c === "÷") { tokens.push({ t: "op", v: "/" }); i++; continue; }
        if (c === "^") { tokens.push({ t: "op", v: "^" }); i++; continue; }
        if (c === "(") { tokens.push({ t: "lp" }); i++; continue; }
        if (c === ")") { tokens.push({ t: "rp" }); i++; continue; }
        if (c === "!") { tokens.push({ t: "fact" }); i++; continue; }
        if (c === "%") { tokens.push({ t: "pct" }); i++; continue; }
        if (c === "π") { tokens.push({ t: "const", v: Math.PI }); i++; continue; }
        if (c === "√") { tokens.push({ t: "fn", v: "sqrt" }); i++; continue; }
        if (c === "∛") { tokens.push({ t: "fn", v: "cbrt" }); i++; continue; }
        m = /^[A-Za-z]+/.exec(rest);
        if (m) {
            var word = m[0].toLowerCase();
            if (CONSTANTS.hasOwnProperty(word)) {
                tokens.push({ t: "const", v: CONSTANTS[word] });
            } else if (FUNCTIONS.hasOwnProperty(word)) {
                tokens.push({ t: "fn", v: FUNCTIONS[word] });
            } else {
                fail("syntax");
            }
            i += m[0].length;
            continue;
        }
        fail("syntax");
    }
    return tokens;
}

function snap(v) {
    return Math.abs(v) < 1e-15 ? 0 : v;
}

function factorial(x) {
    if (x < 0 || Math.floor(x) !== x || x > 170) fail("domain");
    var r = 1;
    for (var k = 2; k <= x; k++) r *= k;
    return r;
}

function angleFactor(mode) {
    if (mode === true || mode === "deg") return Math.PI / 180;
    if (mode === "grad") return Math.PI / 200;
    return 1;
}

function applyFunction(name, x, deg) {
    var k = angleFactor(deg);
    switch (name) {
    case "sin": return snap(Math.sin(x * k));
    case "cos": return snap(Math.cos(x * k));
    case "tan":
        var c = snap(Math.cos(x * k));
        if (c === 0) fail("domain");
        return snap(Math.sin(x * k)) / c;
    case "asin":
        if (x < -1 || x > 1) fail("domain");
        return Math.asin(x) / k;
    case "acos":
        if (x < -1 || x > 1) fail("domain");
        return Math.acos(x) / k;
    case "atan": return Math.atan(x) / k;
    case "sinh": return Math.sinh(x);
    case "cosh": return Math.cosh(x);
    case "tanh": return Math.tanh(x);
    case "asinh": return Math.asinh(x);
    case "acosh":
        if (x < 1) fail("domain");
        return Math.acosh(x);
    case "atanh":
        if (x <= -1 || x >= 1) fail("domain");
        return Math.atanh(x);
    case "ln":
        if (x <= 0) fail("domain");
        return Math.log(x);
    case "log":
        if (x <= 0) fail("domain");
        return snap(Math.log10(x));
    case "sqrt":
        if (x < 0) fail("domain");
        return Math.sqrt(x);
    case "cbrt": return Math.cbrt(x);
    case "abs": return Math.abs(x);
    case "exp": return Math.exp(x);
    }
    fail("syntax");
}

function parse(tokens, deg) {
    var pos = 0;

    function peek() { return tokens[pos]; }
    function isOp(tk, v) { return tk !== undefined && tk.t === "op" && tk.v === v; }
    function startsOperand(tk) {
        return tk !== undefined && (tk.t === "num" || tk.t === "const" || tk.t === "fn" || tk.t === "lp");
    }
    function check(v) {
        if (!isFinite(v)) fail("domain");
        return v;
    }

    function parseExpr() {
        var first = parseTerm();
        var acc = first.v;
        while (isOp(peek(), "+") || isOp(peek(), "-")) {
            var op = tokens[pos++].v;
            var r = parseTerm();
            var rv = r.base !== undefined ? acc * r.base / 100 : r.v;
            acc = check(op === "+" ? acc + rv : acc - rv);
        }
        return acc;
    }

    function parseTerm() {
        var first = parseUnary();
        var acc = first.v;
        var base = first.base;
        while (true) {
            var tk = peek();
            if (isOp(tk, "*")) {
                pos++;
                acc = check(acc * parseUnary().v);
            } else if (isOp(tk, "/")) {
                pos++;
                var d = parseUnary().v;
                if (d === 0) fail("div0");
                acc = check(acc / d);
            } else if (startsOperand(tk)) {
                if (tk.t === "num" && tokens[pos - 1].t === "num") fail("syntax");
                acc = check(acc * parseUnary().v);
            } else {
                break;
            }
            base = undefined;
        }
        return { v: acc, base: base };
    }

    function parseUnary() {
        if (isOp(peek(), "-")) {
            pos++;
            var r = parseUnary();
            return { v: -r.v, base: r.base !== undefined ? -r.base : undefined };
        }
        if (isOp(peek(), "+")) {
            pos++;
            return parseUnary();
        }
        return parsePower();
    }

    function parsePower() {
        var b = parsePostfix();
        if (isOp(peek(), "^")) {
            pos++;
            var e = parseUnary();
            if (b.v === 0 && e.v < 0) fail("div0");
            var v = Math.pow(b.v, e.v);
            if (isNaN(v)) fail("domain");
            return { v: check(v) };
        }
        return b;
    }

    function parsePostfix() {
        var p = parsePrimary();
        var v = p;
        var base;
        while (peek() !== undefined && (peek().t === "fact" || peek().t === "pct")) {
            var tk = tokens[pos++];
            if (tk.t === "fact") {
                v = factorial(v);
                base = undefined;
            } else {
                base = v;
                v = v / 100;
            }
        }
        return { v: v, base: base };
    }

    function parseFunctionArgument() {
        if (isOp(peek(), "-")) {
            pos++;
            return -parseFunctionArgument();
        }
        if (isOp(peek(), "+")) {
            pos++;
            return parseFunctionArgument();
        }
        return parsePostfix().v;
    }

    function closeParen() {
        var tk = peek();
        if (tk === undefined) return;
        if (tk.t !== "rp") fail("syntax");
        pos++;
    }

    function parsePrimary() {
        var tk = tokens[pos++];
        if (tk === undefined) fail("syntax");
        if (tk.t === "num" || tk.t === "const") return tk.v;
        if (tk.t === "lp") {
            var inner = parseExpr();
            closeParen();
            return inner;
        }
        if (tk.t === "fn") {
            var arg;
            if (peek() !== undefined && peek().t === "lp") {
                pos++;
                arg = parseExpr();
                closeParen();
            } else {
                arg = parseFunctionArgument();
            }
            return check(applyFunction(tk.v, arg, deg));
        }
        fail("syntax");
    }

    if (tokens.length === 0) fail("empty");
    var result = parseExpr();
    if (pos < tokens.length) fail("syntax");
    return result;
}

function evaluate(expr, deg) {
    return parse(tokenize(expr), deg);
}

function format(x) {
    if (x === 0) return "0";
    if (Math.floor(x) === x && Math.abs(x) < 1e15) return String(x).replace(/^-/, "−");
    var s = String(Number(x.toPrecision(12)));
    s = s.replace("e+", "E").replace("e", "E");
    return s.replace(/^-/, "−");
}

function trimTrailing(expr) {
    var e = expr;
    var prev;
    do {
        prev = e;
        e = e.replace(/\s+$/, "");
        e = e.replace(/[+\-−×÷*\/^]$/, "");
        e = e.replace(TRAILING_FUNCTION, "");
    } while (e !== prev);
    return e;
}

function openParens(expr) {
    var open = 0;
    for (var i = 0; i < expr.length; i++) {
        var c = expr.charAt(i);
        if (c === "(") open++;
        else if (c === ")" && open > 0) open--;
    }
    return open;
}

function closeParens(expr) {
    var n = openParens(expr);
    var out = expr;
    for (var i = 0; i < n; i++) out += ")";
    return out;
}

function removeLastToken(expr) {
    if (/\^\(−1\)$/.test(expr)) return expr.replace(/\^\(−1\)$/, "");
    var m = TRAILING_FUNCTION_ONLY.exec(expr);
    if (m) return expr.slice(0, m.index);
    return expr.slice(0, -1);
}

function hasOperation(expr) {
    var tokens;
    try {
        tokens = tokenize(expr);
    } catch (err) {
        return false;
    }
    if (tokens.length === 0) return false;
    if (tokens.length === 1 && tokens[0].t === "num") return false;
    return true;
}

function normalizeClipboard(text) {
    var s = String(text).split("=")[0].replace(/\u00a0/g, " ").trim();
    s = s.replace(/,/g, ".");
    s = s.replace(/\*/g, "×").replace(/\//g, "÷").replace(/[-–]/g, "−");
    s = s.replace(/sqrt/gi, "√").replace(/cbrt/gi, "∛").replace(/pi/gi, "π");
    s = s.replace(/(?:arc|a)(sinh|cosh|tanh|sin|cos|tan)/gi, function (m, fn) { return fn.toLowerCase() + "⁻¹"; });
    s = s.replace(/\b(SIN|COS|TAN|LN|LOG|EXP|ABS)\b/g, function (m) { return m.toLowerCase(); });
    return s;
}

function sanitizeTyped(text) {
    return String(text)
        .replace(/[*·]/g, "×").replace(/[\/:]/g, "÷").replace(/[-–]/g, "−").replace(/,/g, ".")
        .replace(/[\[{]/g, "(").replace(/[\]}]/g, ")")
        .replace(/[^0-9A-Za-z+−×÷^%!().πE√∛⁻¹ ]/g, "");
}

function toPlain(text) {
    return String(text).replace(/−/g, "-").replace(/×/g, "*").replace(/÷/g, "/")
        .replace(/π/g, "pi").replace(/√/g, "sqrt").replace(/∛/g, "cbrt")
        .replace(/(sinh|cosh|tanh|sin|cos|tan)⁻¹/g, "a$1");
}

function isValid(expr) {
    if (expr === "") return false;
    try {
        tokenize(expr);
        return true;
    } catch (err) {
        return false;
    }
}
