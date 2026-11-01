.pragma library

function formatInlineMarkdown(text) {
    if (!text) return "";
    var s = text;
    s = s.replace(/`([^`]+)`/g, "<font color=\"#fab387\" face=\"monospace\"><b>$1</b></font>");
    s = s.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");
    s = s.replace(/__([^_]+)__/g, "<b>$1</b>");
    s = s.replace(/\*([^*]+)\*/g, "<i>$1</i>");
    s = s.replace(/_([^_]+)_/g, "<i>$1</i>");
    s = s.replace(/~~([^~]+)~~/g, "<s>$1</s>");
    return s;
}

function markdownToHtml(md) {
    if (!md) return "";
    var lines = md.split("\n");
    var out = [];
    var inCode = false;
    var codeLines = [];
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (line.trim().indexOf("```") === 0) {
            if (inCode) {
                out.push("<pre style=\"background-color:#181825;color:#cdd6f4;\"><code>" + codeLines.join("<br/>") + "</code></pre>");
                codeLines = [];
                inCode = false;
            } else {
                inCode = true;
                codeLines = [];
            }
            continue;
        }
        var esc = line.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        if (inCode) {
            codeLines.push(esc);
            continue;
        }
        if (esc.indexOf("### ") === 0) {
            out.push("<b><font size=\"+1\">" + formatInlineMarkdown(esc.substring(4)) + "</font></b>");
        } else if (esc.indexOf("## ") === 0) {
            out.push("<b><font size=\"+2\">" + formatInlineMarkdown(esc.substring(3)) + "</font></b>");
        } else if (esc.indexOf("# ") === 0) {
            out.push("<b><font size=\"+3\">" + formatInlineMarkdown(esc.substring(2)) + "</font></b>");
        } else if (/^\s*[-*+]\s+/.test(esc)) {
            var item = esc.replace(/^\s*[-*+]\s+/, "");
            out.push("&nbsp;&nbsp;• " + formatInlineMarkdown(item));
        } else if (/^\s*\d+\.\s+/.test(esc)) {
            var m = esc.match(/^(\s*\d+\.)\s+(.*)$/);
            out.push("&nbsp;&nbsp;" + (m ? m[1] + " " + formatInlineMarkdown(m[2]) : esc));
        } else if (esc.indexOf("> ") === 0) {
            out.push("<i><font color=\"#a6adc8\">│ " + formatInlineMarkdown(esc.substring(2)) + "</font></i>");
        } else {
            out.push(formatInlineMarkdown(esc));
        }
    }
    if (inCode && codeLines.length > 0) {
        out.push("<pre style=\"background-color:#181825;color:#cdd6f4;\"><code>" + codeLines.join("<br/>") + "</code></pre>");
    }
    return out.join("<br/>");
}

function formatRelativeTime(timestamp, i18n, timeFormat) {
    if (!timestamp) return "";
    var now = new Date();
    var noteDate = new Date(timestamp);
    var diffSec = Math.floor((now.getTime() - noteDate.getTime()) / 1000);

    var timePart = (timeFormat || "HH:mm").indexOf("hh:") !== -1
        ? Qt.formatDateTime(noteDate, "hh:mm AP")
        : Qt.formatDateTime(noteDate, "HH:mm");

    if (diffSec < 60) return i18n.t("datetime.just_now");

    var diffMin = Math.floor(diffSec / 60);
    if (diffMin < 60) return i18n.t("datetime.minutes_ago", { mins: diffMin });

    var isSameDay = now.getFullYear() === noteDate.getFullYear() &&
                    now.getMonth() === noteDate.getMonth() &&
                    now.getDate() === noteDate.getDate();

    var yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    var isYesterday = yesterday.getFullYear() === noteDate.getFullYear() &&
                      yesterday.getMonth() === noteDate.getMonth() &&
                      yesterday.getDate() === noteDate.getDate();

    var diffDays = Math.floor(diffSec / 86400);

    if (isSameDay) return timePart;
    if (isYesterday) return i18n.t("datetime.yesterday", { time: timePart });
    if (diffDays < 7) return Qt.formatDateTime(noteDate, "dddd") + " " + timePart;
    return Qt.formatDateTime(noteDate, "yyyy-MM-dd ") + timePart;
}

function formatPreciseTime(timestamp) {
    if (!timestamp) return "";
    return Qt.formatDateTime(new Date(timestamp), "yyyy-MM-dd HH:mm:ss");
}
