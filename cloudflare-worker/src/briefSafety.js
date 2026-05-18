// Layered output safety pipeline for the weekly coach brief.
//
// Each check returns { ok: true } or { ok: false, reason }. The top-level
// runSafetyPipeline runs them in cheap-to-expensive order and short-circuits
// on the first failure. Telemetry should log only the `reason` code — NEVER
// the brief content itself, to avoid persisting potentially-bad output.

// Profanity wordlist. Starter set covering common English profanity, slurs,
// and vulgar terms. Source-controlled deliberately (not hot-loaded from any
// third party) so it can be reviewed in code review. Keep entries lowercase,
// word-boundary matched. Extend as observed; do not remove without review.
//
// The list intentionally includes substitution-resistant forms (e.g., both
// "shit" and "shitty") rather than relying on stemming.
export const PROFANITY = new Set([
    // generic profanity
    "fuck", "fucked", "fucker", "fuckers", "fucking", "motherfucker",
    "shit", "shits", "shitty", "shitting", "bullshit",
    "ass", "asses", "asshole", "assholes",
    "bitch", "bitches", "bitchy", "bitching",
    "bastard", "bastards",
    "damn", "damned", "goddamn", "goddamned",
    "crap", "crappy",
    "piss", "pissed", "pissing",
    "dick", "dicks", "dickhead", "dickheads",
    "cock", "cocks", "cocky",
    "pussy", "pussies",
    "cunt", "cunts",
    "twat", "twats",
    "wanker", "wankers", "tosser", "tossers",
    "bollocks",
    "douche", "douchebag", "douchebags",
    "prick", "pricks",
    "slut", "sluts", "slutty",
    "whore", "whores",
    "skank", "skanks", "skanky",
    "jerk", "jerks", "jerkoff",
    "screw", "screwed", // borderline; included for child-safety bias
    // slurs / hate terms
    "faggot", "faggots", "fag", "fags",
    "dyke", "dykes",
    "tranny", "trannies",
    "retard", "retarded", "retards",
    "spaz", "spazz",
    "nigger", "nigga", "niggas", "niggers",
    "chink", "chinks",
    "gook", "gooks",
    "spic", "spics",
    "kike", "kikes",
    "wetback", "wetbacks",
    "raghead", "ragheads",
    "towelhead", "towelheads",
    // sexual content
    "sex", "sexy", "porn", "porno", "boobs", "tits", "titty",
    "horny", "orgasm", "masturbate", "masturbating",
    "ejaculate", "ejaculation",
    // violence
    "kill", "killed", "killing", "murder", "murdered",
    "rape", "raped", "rapist",
    "suicide",
]);

const HEDGE_PHRASES = [
    "maybe",
    "perhaps",
    "kind of",
    "kinda",
    "sort of",
    "sorta",
    "i think",
    "i guess",
    "might want",
    "could possibly",
    "you might",
    "you could maybe",
    "it seems like",
    "appears to be somewhat",
    "in my opinion",
    "if you ask me",
];

const PII_PATTERNS = [
    // email
    /\b[\w.+-]+@[\w-]+\.[\w.-]+\b/i,
    // phone — 10–15 digits w/ common separators
    /\b(?:\+?\d[\s.-]?){9,14}\d\b/,
    // US SSN shape
    /\b\d{3}-\d{2}-\d{4}\b/,
    // street address (number + word + suffix)
    /\b\d{1,5}\s+\w+(?:\s+\w+)?\s+(?:street|st|avenue|ave|road|rd|blvd|drive|dr|lane|ln|way|court|ct)\b/i,
];

// --- individual checks ----------------------------------------------------

export function checkLength(text) {
    const words = (text.trim().match(/\S+/g) || []).length;
    if (words < 25 || words > 80) return { ok: false, reason: `length:${words}` };
    return { ok: true };
}

export function checkProfanity(text) {
    const tokens = text.toLowerCase().match(/\b[\w'-]+\b/g) || [];
    for (const t of tokens) {
        if (PROFANITY.has(t)) return { ok: false, reason: `profanity:${t}` };
    }
    return { ok: true };
}

export function checkHedging(text) {
    const lower = text.toLowerCase();
    for (const phrase of HEDGE_PHRASES) {
        // word-boundary on the left so "kindling" doesn't match "kind"
        const pattern = new RegExp(`(?:^|[^a-z])${phrase.replace(/ /g, "\\s+")}(?:[^a-z]|$)`);
        if (pattern.test(lower)) return { ok: false, reason: `hedge:${phrase}` };
    }
    return { ok: true };
}

export function checkPII(text) {
    for (const pat of PII_PATTERNS) {
        if (pat.test(text)) return { ok: false, reason: "pii_match" };
    }
    return { ok: true };
}

export function checkHighlights({ brief, highlights }) {
    if (!Array.isArray(highlights)) return { ok: false, reason: "highlights_missing" };
    if (highlights.length > 3)       return { ok: false, reason: "highlights_too_many" };
    for (const h of highlights) {
        if (!h || typeof h.phrase !== "string") return { ok: false, reason: "highlight_shape" };
        if (!brief.includes(h.phrase))           return { ok: false, reason: `highlight_not_in_brief:${h.phrase}` };
        if (!["positive", "negative"].includes(h.kind)) {
            return { ok: false, reason: "highlight_kind" };
        }
    }
    return { ok: true };
}

// --- top-level pipeline ---------------------------------------------------

/**
 * Run all safety checks in cheap-to-expensive order. Returns the first
 * failure verdict, or { ok: true } if every check passes.
 */
export function runSafetyPipeline({ brief, highlights }) {
    for (const check of [
        () => checkLength(brief),
        () => checkProfanity(brief),
        () => checkHedging(brief),
        () => checkPII(brief),
        () => checkHighlights({ brief, highlights }),
    ]) {
        const r = check();
        if (!r.ok) return r;
    }
    return { ok: true };
}
