//
//  ItalianLookup.swift
//  Patente-Learning
//
//  Translates individual Italian tokens used in TappableSentenceView.
//
//  Two sources, merged at startup:
//    1. All chapter word lists (ChapterList + JSONLoader) — takes priority
//    2. Hardcoded grammar dictionary: articles, prepositions, common verbs,
//       adverbs, conjunctions, pronouns, and common driving-context words
//
//  Usage:
//    ItalianLookup.shared.translate("vietata") // → "forbidden"
//    ItalianLookup.shared.translate("______")  // → nil (blank tokens)
//

import Foundation

final class ItalianLookup {

    static let shared = ItalianLookup()

    private var table: [String: String] = [:]

    private init() {
        // Source 1 — all chapter vocabulary
        for chapter in ChapterList.allCases {
            for word in loadChapter(chapter.filename).words {
                table[word.italian.lowercased()] = word.english
            }
        }
        // Source 2 — grammar dictionary (only fills gaps not covered by vocab)
        for (key, value) in Self.grammar where table[key] == nil {
            table[key] = value
        }
    }

    /// Returns an English gloss for a raw Italian token, or nil if unknown.
    /// Strips leading/trailing punctuation before lookup.
    func translate(_ raw: String) -> String? {
        let clean = raw
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?\"'()[]–—-«»"))
        guard !clean.isEmpty, !clean.allSatisfy({ $0 == "_" }) else { return nil }
        return table[clean]
    }

    // MARK: - Grammar Dictionary

    // ~120 entries covering the connective tissue of Italian driving-theory prose.
    // Keys are lowercase; values are concise English glosses.
    private static let grammar: [String: String] = [

        // ── Definite articles ────────────────────────────────────────────────
        "il": "the",    "lo": "the",    "la": "the",
        "i":  "the",    "gli": "the",   "le": "the",    "l'": "the",

        // ── Indefinite articles ──────────────────────────────────────────────
        "un": "a",  "uno": "a",  "una": "a",  "un'": "a",

        // ── Simple prepositions ──────────────────────────────────────────────
        "di": "of",         "a": "to / at",     "da": "from / by",
        "in": "in",         "con": "with",      "su": "on",
        "per": "for",       "tra": "between",   "fra": "between",

        // ── Articulated prepositions (di) ────────────────────────────────────
        "del": "of the",    "dello": "of the",  "della": "of the",
        "dei": "of the",    "degli": "of the",  "delle": "of the",

        // ── Articulated prepositions (a) ─────────────────────────────────────
        "al": "to the",     "allo": "to the",   "alla": "to the",
        "ai": "to the",     "agli": "to the",   "alle": "to the",

        // ── Articulated prepositions (da) ────────────────────────────────────
        "dal": "from the",  "dallo": "from the", "dalla": "from the",
        "dai": "from the",  "dagli": "from the", "dalle": "from the",

        // ── Articulated prepositions (in) ────────────────────────────────────
        "nel": "in the",    "nello": "in the",  "nella": "in the",
        "nei": "in the",    "negli": "in the",  "nelle": "in the",

        // ── Articulated prepositions (su) ────────────────────────────────────
        "sul": "on the",    "sullo": "on the",  "sulla": "on the",
        "sui": "on the",    "sugli": "on the",  "sulle": "on the",

        // ── Articulated prepositions (con) ───────────────────────────────────
        "col": "with the",  "coi": "with the",

        // ── Essere (to be) ───────────────────────────────────────────────────
        "essere": "to be",
        "sono": "am / are", "sei": "you are",   "è": "is",
        "siamo": "we are",  "siete": "you are", "era": "was",
        "erano": "were",    "fu": "was",         "stato": "been",

        // ── Avere (to have) ──────────────────────────────────────────────────
        "avere": "to have",
        "ho": "I have",     "hai": "you have",  "ha": "has",
        "abbiamo": "we have", "avete": "you have", "hanno": "have",

        // ── Modal verbs ──────────────────────────────────────────────────────
        "dovere": "must / to have to",
        "deve": "must",     "devono": "must",   "dovuto": "had to",
        "potere": "to be able to",
        "può": "can",       "possono": "can",   "potuto": "been able",
        "volere": "to want",
        "vuole": "wants",   "vogliono": "want", "voluto": "wanted",
        "sapere": "to know",
        "sa": "knows",      "sanno": "know",

        // ── Common verbs ─────────────────────────────────────────────────────
        "fare": "to do / make",     "fa": "does",       "fanno": "do",
        "andare": "to go",          "va": "goes",       "vanno": "go",
        "venire": "to come",        "viene": "comes",   "vengono": "come",
        "dare": "to give",          "dà": "gives",
        "stare": "to stay / be",    "sta": "is / stays",
        "uscire": "to exit",        "esce": "exits",
        "salire": "to get on",      "sale": "gets on",
        "scendere": "to get off",   "scende": "gets off",
        "fermare": "to stop",       "ferma": "stops",
        "fermarsi": "to stop",
        "tenere": "to hold",        "tiene": "holds",
        "mettere": "to put",        "mette": "puts",
        "usare": "to use",          "usa": "uses",
        "indicare": "to indicate",  "indica": "indicates",
        "segnalare": "to signal",   "segnala": "signals",
        "rispettare": "to obey",    "rispetta": "obeys",
        "superare": "to exceed",    "supera": "exceeds",
        "mantenere": "to maintain", "mantiene": "maintains",
        "ridurre": "to reduce",     "riduce": "reduces",
        "aumentare": "to increase", "aumenta": "increases",
        "controllare": "to check",  "controlla": "checks",
        "evitare": "to avoid",      "evita": "avoids",
        "causare": "to cause",      "causa": "causes",
        "permettere": "to allow",   "permette": "allows",
        "vietare": "to forbid",     "vieta": "forbids",
        "obbligare": "to oblige",   "obbliga": "obliges",

        // ── Clitic / reflexive pronouns ──────────────────────────────────────
        "si": "oneself / one",  "ci": "us / there",
        "vi": "you / there",    "mi": "me / myself",
        "ti": "you / yourself", "ne": "of it / some",

        // ── Subject pronouns ─────────────────────────────────────────────────
        "io": "I",      "tu": "you",    "lui": "he",
        "lei": "she",   "noi": "we",    "voi": "you (pl.)",
        "loro": "they",

        // ── Demonstratives ───────────────────────────────────────────────────
        "questo": "this",   "questa": "this",
        "questi": "these",  "queste": "these",
        "quello": "that",   "quella": "that",
        "quelli": "those",  "quelle": "those",

        // ── Indefinites ──────────────────────────────────────────────────────
        "ogni": "every",        "qualsiasi": "any",
        "qualche": "some",      "nessuno": "nobody / none",
        "nessuna": "none",      "tutto": "all / whole",
        "tutti": "all / everyone", "tutte": "all",
        "tutta": "entire",      "altro": "other",
        "altra": "other",       "altri": "others",
        "altre": "others",      "stesso": "same",
        "stessa": "same",       "entrambi": "both",
        "entrambe": "both",

        // ── Common adverbs ───────────────────────────────────────────────────
        "non": "not",           "già": "already",
        "sempre": "always",     "mai": "never",
        "anche": "also / too",  "solo": "only",
        "ancora": "still / again", "subito": "immediately",
        "bene": "well",         "male": "badly",
        "molto": "very / a lot", "poco": "little",
        "troppo": "too much",   "abbastanza": "enough",
        "più": "more",          "meno": "less",
        "prima": "before",      "dopo": "after",
        "allora": "then / so",  "ora": "now",
        "qui": "here",          "qua": "here",
        "lì": "there",          "là": "there",
        "sopra": "above",       "sotto": "below",
        "dentro": "inside",     "fuori": "outside",
        "avanti": "forward",    "indietro": "backward",
        "insieme": "together",  "comunque": "anyway",
        "invece": "instead",    "almeno": "at least",
        "circa": "about / around", "spesso": "often",

        // ── Conjunctions ─────────────────────────────────────────────────────
        "e": "and",     "ed": "and",    "o": "or",
        "ma": "but",    "però": "but",  "eppure": "yet",
        "quindi": "so", "oppure": "or", "né": "nor",
        "mentre": "while", "quando": "when", "perché": "because",
        "poiché": "since", "affinché": "so that", "sebbene": "although",
        "se": "if",     "come": "as / how", "dove": "where",
        "che": "that / which", "chi": "who", "quanto": "how much",

        // ── Common road-context adjectives ───────────────────────────────────
        "obbligatorio": "mandatory", "obbligatoria": "mandatory",
        "vietato": "forbidden",      "vietata": "forbidden",
        "pericoloso": "dangerous",   "pericolosa": "dangerous",
        "sicuro": "safe",            "sicura": "safe",
        "libero": "free / clear",    "libera": "free / clear",
        "consentito": "allowed",     "consentita": "allowed",
        "necessario": "necessary",   "necessaria": "necessary",
        "corretto": "correct",       "corretta": "correct",
        "sbagliato": "wrong",        "sbagliata": "wrong",
        "immediato": "immediate",    "immediata": "immediate",
        "apposito": "appropriate",   "apposita": "appropriate",
        "visibile": "visible",       "udibile": "audible",
        "adeguato": "adequate",      "adeguata": "adequate",

        // ── Common road-context nouns (outside chapter vocab) ────────────────
        "via": "road / way",         "tratto": "stretch of road",
        "senso": "direction",        "lato": "side",
        "bordo": "edge",             "zona": "zone",
        "area": "area",              "centro": "centre",
        "distanza": "distance",      "spazio": "space",
        "tempo": "time",             "ora": "hour",
        "caso": "case",              "modo": "way",
        "tipo": "type",              "parte": "part",
        "uso": "use",                "presenza": "presence",
        "condizione": "condition",   "condizioni": "conditions",
        "norma": "rule",             "norme": "rules",
        "legge": "law",              "codice": "code",
        "regola": "rule",            "regole": "rules",
        "diritto": "right",          "avviso": "warning",
        "attenzione": "caution",     "cura": "care",
        "rispetto": "respect",       "rischio": "risk",
        "effetto": "effect",         "motivo": "reason",
        "pericolo": "danger",        "danni": "damage",
        "danno": "damage",

        // ── Numbers as words ─────────────────────────────────────────────────
        "due": "two",   "tre": "three",
        "quattro": "four", "cinque": "five",
        "sette": "seven", "otto": "eight", "nove": "nine",
        "dieci": "ten", "cento": "hundred", "mille": "thousand",
        "primo": "first", "seconda": "second", "secondo": "second",
        "terzo": "third", "ultimo": "last",
    ]
}
