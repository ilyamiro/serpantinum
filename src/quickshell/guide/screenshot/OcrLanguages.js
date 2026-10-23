.pragma library

var NAMES = {
    afr: "Afrikaans", amh: "Amharic", ara: "Arabic", asm: "Assamese", aze: "Azerbaijani",
    aze_cyrl: "Azerbaijani (Cyrillic)", bel: "Belarusian", ben: "Bengali", bod: "Tibetan", bos: "Bosnian",
    bre: "Breton", bul: "Bulgarian", cat: "Catalan", ceb: "Cebuano", ces: "Czech",
    chi_sim: "Chinese (Simplified)", chi_tra: "Chinese (Traditional)", chr: "Cherokee", cos: "Corsican",
    cym: "Welsh", dan: "Danish", deu: "German", deu_latf: "German (Latin Fraktur)", div: "Dhivehi",
    dzo: "Dzongkha", ell: "Greek", eng: "English", enm: "Middle English", epo: "Esperanto", est: "Estonian",
    eus: "Basque", fao: "Faroese", fas: "Persian", fil: "Filipino", fin: "Finnish", fra: "French",
    frk: "German (Fraktur)", frm: "Middle French", fry: "Western Frisian", gla: "Scottish Gaelic",
    gle: "Irish", glg: "Galician", grc: "Ancient Greek", guj: "Gujarati", hat: "Haitian Creole",
    heb: "Hebrew", hin: "Hindi", hrv: "Croatian", hun: "Hungarian", hye: "Armenian", iku: "Inuktitut",
    ind: "Indonesian", isl: "Icelandic", ita: "Italian", ita_old: "Italian (Old)", jav: "Javanese",
    jpn: "Japanese", kan: "Kannada", kat: "Georgian", kat_old: "Georgian (Old)", kaz: "Kazakh",
    khm: "Khmer", kir: "Kyrgyz", kmr: "Kurdish (Kurmanji)", kor: "Korean", lao: "Lao", lat: "Latin",
    lav: "Latvian", lit: "Lithuanian", ltz: "Luxembourgish", mal: "Malayalam", mar: "Marathi",
    mkd: "Macedonian", mlt: "Maltese", mon: "Mongolian", mri: "Maori", msa: "Malay", mya: "Burmese",
    nep: "Nepali", nld: "Dutch", nor: "Norwegian", oci: "Occitan", ori: "Odia", pan: "Punjabi",
    pol: "Polish", por: "Portuguese", pus: "Pashto", que: "Quechua", ron: "Romanian", rus: "Russian",
    san: "Sanskrit", sin: "Sinhala", slk: "Slovak", slv: "Slovenian", snd: "Sindhi", spa: "Spanish",
    spa_old: "Spanish (Old)", sqi: "Albanian", srp: "Serbian", srp_latn: "Serbian (Latin)", sun: "Sundanese",
    swa: "Swahili", swe: "Swedish", syr: "Syriac", tam: "Tamil", tat: "Tatar", tel: "Telugu", tgk: "Tajik",
    tha: "Thai", tir: "Tigrinya", ton: "Tongan", tur: "Turkish", uig: "Uyghur", ukr: "Ukrainian",
    urd: "Urdu", uzb: "Uzbek", uzb_cyrl: "Uzbek (Cyrillic)", vie: "Vietnamese", yid: "Yiddish", yor: "Yoruba"
};

function name(code) {
    return NAMES[code] || code;
}
