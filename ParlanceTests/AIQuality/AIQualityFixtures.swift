// ParlanceTests/AIQuality/AIQualityFixtures.swift
import Foundation
@testable import Parlance

/// Quality tiers (loose, used to organize fixtures):
/// - empty:   no transcript captured
/// - bad:     0–30, broken or shallow
/// - okay:    30–55, addresses the question with significant flaws
/// - good:    55–78, solid execution with minor issues
/// - great:   75–92, strong, well-structured
/// - perfect: 85–100, exemplary
enum AIQualityFixtures {

    static let all: [AIQualityFixture] = [
        // Interview — full tier ladder
        interviewEmpty, interviewBad, interviewRambling, interviewFillerHeavy,
        interviewOffTopic, interviewGood, interviewGreat, interviewPerfect,

        // Pitch — full tier ladder
        pitchEmpty, pitchBad, pitchOkay, pitchGood, pitchGreat, pitchPerfect,

        // Keynote — full tier ladder
        keynoteEmpty, keynoteBad, keynoteFlatOpen, keynoteGood, keynoteGreat, keynotePerfect,

        // Casual — full tier ladder
        casualEmpty, casualBad, casualOkay, casualGood, casualGreat, casualPerfect,

        // Other modes — one canary each at "good" tier
        debateGood, storytellingGood, explanationGood,
        negotiationGood, impromptuGood, networkingGood,
    ]

    // ============================================================
    // MARK: - Interview
    // ============================================================

    static let interviewEmpty = AIQualityFixture(
        id: "interview-empty",
        label: "empty transcript — user didn't speak",
        mode: .interview, level: 1,
        question: "Tell me about yourself.",
        transcript: "",
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 0...15),
        checks: [
            .allMetricsAtMost(2),
            .feedbackContainsAnyOf([
                "transcript", "speak", "speech", "audio", "recording", "captured",
                "didn't", "no speech", "insufficient", "no response",
            ]),
        ]
    )

    static let interviewBad = AIQualityFixture(
        id: "interview-bad",
        label: "dismissive, no specifics, near-zero engagement",
        mode: .interview, level: 1,
        question: "Why do you want this role?",
        transcript: """
        Honestly I just need a job. I applied to a bunch of places and you're one of them. The pay seems okay. \
        I think I could probably do the work, I've done similar stuff before. So yeah, that's why.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 5...30),
        checks: [
            .feedbackContainsAnyOf(["specific", "engage", "passion", "research", "shallow", "dismissive", "generic"]),
        ]
    )

    static let interviewRambling = AIQualityFixture(
        id: "interview-rambling",
        label: "long, unstructured, no clear close",
        mode: .interview, level: 5,
        question: "What's your biggest weakness?",
        transcript: """
        So I think my biggest weakness is sort of related to how I think about feedback, like, \
        when I get feedback I sometimes take a while to process it, not because I'm being defensive \
        or anything but more because I want to think about whether I agree with it before I act on it. \
        And I've been told this before, that I should be quicker to respond, but I'm not sure that's right \
        because if you respond too quickly you don't really process the feedback, you just sort of agree \
        in the moment and then forget about it. So I've been working on this but I'm also not totally \
        sure it's a problem in the way that other people think it is. There's also another thing which is \
        I'm sometimes too detail-oriented, like I'll spend a long time on something that doesn't necessarily \
        need it, but I think that's also kind of a strength because the details matter, especially in our \
        line of work. So yeah, that's how I think about it.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(
            overall: 30...55,
            metrics: [.structure: 0...5]
        ),
        checks: []
    )

    static let interviewFillerHeavy = AIQualityFixture(
        id: "interview-filler-heavy",
        label: "decent answer with ~20 filler words",
        mode: .interview, level: 3,
        question: "Why do you want this role?",
        transcript: """
        Um, so basically I want this role because, like, I've been following the company for, you know, \
        about two years and, um, the work on inference optimization is, like, exactly what I want to \
        be doing. Like, I spent, you know, the last three years basically working on, um, training \
        infrastructure, and I think the next, you know, frontier is really inference. Um, and honestly \
        I think this team is, like, one of the few places where, you know, that work is actually shipping \
        to users. So, basically, that's why.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(
            overall: 25...55,
            metrics: [.fillerWords: 0...4]
        ),
        checks: [
            .feedbackContainsAnyOf(["filler", "um", "uh", "like", "basically"]),
        ]
    )

    static let interviewOffTopic = AIQualityFixture(
        id: "interview-off-topic",
        label: "coherent but answers a different question",
        mode: .interview, level: 5,
        question: "Tell me about a time you disagreed with your manager.",
        transcript: """
        I would describe my management style as fairly hands-off. I prefer to set clear goals and \
        let my team figure out the path. I check in weekly, but I try not to micromanage. I think the \
        best engineers do their best work when they have ownership and trust. I also believe in radical \
        transparency about company priorities, so I share what I learn from leadership meetings as quickly \
        as possible. My team has consistently shipped on time and reported high engagement scores.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 25...50),
        checks: [
            .feedbackContainsAnyOf(["question", "asked", "address", "answer", "disagree"]),
            .metricInRange(.relevance, 0...4),
        ]
    )

    static let interviewGood = AIQualityFixture(
        id: "interview-good",
        label: "solid answer with structure but missing strong close",
        mode: .interview, level: 5,
        question: "What's a project you're proud of?",
        transcript: """
        I led the redesign of our notifications system last year. The team had been getting complaints \
        that notifications were too noisy, so I gathered the data on which alert types users were dismissing \
        and proposed three categories: critical, important, and informational. We rolled out the new \
        categorization behind a feature flag and tracked dismissal rates over four weeks. Dismissal rates \
        on important and critical alerts dropped meaningfully, and we got fewer complaints. The team adopted \
        the categorization as the default. Looking back, I wish I'd run a structured user survey at the end \
        to capture qualitative feedback alongside the dismissal numbers, but the project was a clear win.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(
            overall: 55...80,
            metrics: [.structure: 6...10]
        ),
        checks: [
            .bestMomentQuoteInTranscript,
        ]
    )

    static let interviewGreat = AIQualityFixture(
        id: "interview-great",
        label: "tight STAR answer with quantified outcome",
        mode: .interview, level: 7,
        question: "Tell me about a time you led a team through a difficult challenge.",
        transcript: """
        Last quarter I led the migration of our billing system from a legacy provider to Stripe. \
        The team was skeptical because the old system had a year of accumulated edge cases. \
        I started by mapping every supported flow into a test matrix, then split the migration \
        into three phases: read-only mirroring, dual-writes, and finally a cutover behind a feature flag. \
        We hit one snag with proration on annual upgrades, which I resolved by adding a reconciliation job \
        that ran nightly for the first two weeks. The cutover finished on schedule with zero customer-visible \
        incidents and reduced our payment processing costs by twelve percent. The team now uses that test matrix \
        as the template for any payments work.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(
            overall: 75...95,
            metrics: [.structure: 7...10, .fillerWords: 8...10]
        ),
        checks: [
            .bestMomentQuoteInTranscript,
        ]
    )

    static let interviewPerfect = AIQualityFixture(
        id: "interview-perfect",
        label: "exemplary answer — quantified, structured, demonstrates judgment",
        mode: .interview, level: 9,
        question: "Walk me through a complex technical decision you made.",
        transcript: """
        In Q2 I led the call to rewrite our event ingestion pipeline from Kafka to a custom queue we built \
        on top of Postgres. The decision was contested — Kafka was working — so I framed it around three \
        questions: what does it cost us to keep, what does it cost to leave, and what's the risk of either path. \
        The keep cost was forty thousand dollars a year for a managed cluster we used at five percent of capacity. \
        The leave cost was four engineer-weeks. The risk on leaving was that Postgres would buckle past two thousand \
        events per second, so I built a load-test rig and proved we held up cleanly to ten thousand. We shipped \
        the migration over six weeks behind a per-tenant flag, with zero customer-visible incidents and ninety \
        percent infrastructure cost reduction. The lesson, which I've used twice since, is that the cheapest \
        time to revisit infrastructure is right before it stops being cheap.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(
            overall: 85...100,
            metrics: [.structure: 8...10, .relevance: 8...10, .vocabulary: 8...10]
        ),
        checks: [
            .bestMomentQuoteInTranscript,
        ]
    )

    // ============================================================
    // MARK: - Pitch
    // ============================================================

    static let pitchEmpty = AIQualityFixture(
        id: "pitch-empty",
        label: "empty transcript — pitch silent",
        mode: .pitch, level: 1,
        question: "Pitch your startup in 60 seconds.",
        transcript: "",
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 0...15),
        checks: [.allMetricsAtMost(2)]
    )

    static let pitchBad = AIQualityFixture(
        id: "pitch-bad",
        label: "vague AI pitch with no traction, hook, or ask",
        mode: .pitch, level: 1,
        question: "Pitch your startup in 60 seconds.",
        transcript: """
        Yeah so we have this app idea. It does stuff with AI. We think people will want it. We don't \
        have customers yet but we'll figure that out. We're looking for some funding to keep going.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 5...30),
        checks: [
            .feedbackContainsAnyOf(["hook", "specific", "traction", "ask", "vague", "shallow"]),
        ]
    )

    static let pitchOkay = AIQualityFixture(
        id: "pitch-okay",
        label: "structured pitch but weak hook and no compelling traction",
        mode: .pitch, level: 3,
        question: "Pitch your startup in 60 seconds.",
        transcript: """
        We're building a tool that helps small businesses track their expenses better. Right now they \
        mostly use spreadsheets which are a pain. We've talked to about twenty people who said they'd \
        consider using it. We're charging twenty dollars a month and have a working prototype. We need \
        help getting in front of more customers, and we think this could be a good business over time. \
        We're looking to raise about a million dollars to grow the team.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 30...58),
        checks: [
            .feedbackContainsAnyOf(["hook", "differentiat", "specific", "urgency", "traction"]),
        ]
    )

    static let pitchGood = AIQualityFixture(
        id: "pitch-good",
        label: "decent pitch with traction but weak differentiation",
        mode: .pitch, level: 5,
        question: "Pitch your startup in 60 seconds.",
        transcript: """
        Small businesses lose roughly four hours a week reconciling invoices manually. We built a tool \
        called Reconcile that connects to their accounting software and matches invoices against bank \
        transactions automatically. We've onboarded ninety customers in three months at fifty dollars \
        per seat per month, and our top cohort is renewing at ninety percent. The pitch is simple: \
        we take a four-hour weekly chore and make it five minutes. We're raising a one-and-a-half \
        million dollar pre-seed to expand the integrations team and start outbound sales.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 55...82),
        checks: [
            .feedbackContainsAnyOf(["traction", "hook", "specific", "ask"]),
        ]
    )

    static let pitchGreat = AIQualityFixture(
        id: "pitch-great",
        label: "investor pitch with strong hook + traction + ask",
        mode: .pitch, level: 7,
        question: "Pitch your startup in 60 seconds.",
        transcript: """
        Eighty-three percent of small businesses still send invoices as PDF attachments. They wait an \
        average of forty-two days to get paid, and twenty percent of those invoices never get paid at all. \
        We built Ledgerline. It's a single API that turns any PDF invoice into a tracked, paid-on-time \
        receivable in under three days, using underwriting we built on top of bank transaction data. \
        We've onboarded twelve hundred businesses in five months and we're processing eight million dollars \
        a month in invoices. We're raising a four million dollar seed to grow the underwriting team and \
        expand into the UK by Q3.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 70...92),
        checks: [
            .feedbackContainsAnyOf(["hook", "urgency", "ask", "investor", "pitch", "traction"]),
        ]
    )

    static let pitchPerfect = AIQualityFixture(
        id: "pitch-perfect",
        label: "exemplary pitch — sharp hook, traction, social proof, ask, defensibility",
        mode: .pitch, level: 9,
        question: "Pitch your startup in 60 seconds.",
        transcript: """
        Every year, freight brokers waste two billion dollars on phone calls confirming truck locations \
        that GPS already knows. We're Pulse. We sit between the broker's TMS and the carrier's ELD and \
        replace those calls with real-time location, ETA, and exception alerts — no integration work for \
        the carrier. In nine months we've signed twenty-three of the top hundred US brokers, including \
        Coyote and Echo. Net revenue retention is one hundred sixty percent because every broker we add \
        pulls in the carriers they already work with, which compounds the network. We're raising fifteen \
        million Series A from a partner who's done the network-effect playbook before, to lock in the \
        next thirty brokers before our largest competitor closes their pivot.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(
            overall: 85...100,
            metrics: [.persuasiveness: 8...10, .vocabulary: 8...10]
        ),
        checks: [
            .feedbackContainsAnyOf(["hook", "traction", "ask", "specific", "investor"]),
            .bestMomentQuoteInTranscript,
        ]
    )

    // ============================================================
    // MARK: - Keynote
    // ============================================================

    static let keynoteEmpty = AIQualityFixture(
        id: "keynote-empty",
        label: "empty transcript — speaker silent",
        mode: .keynote, level: 1,
        question: "Open a keynote on AI ethics.",
        transcript: "",
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 0...15),
        checks: [.allMetricsAtMost(2)]
    )

    static let keynoteBad = AIQualityFixture(
        id: "keynote-bad",
        label: "shallow keynote intro, no engagement",
        mode: .keynote, level: 1,
        question: "Open a keynote on AI ethics.",
        transcript: """
        Hi everyone. AI is a really important topic. There are good things and bad things about it. \
        We need to think about it carefully. Let me tell you what I think. AI can be helpful but also \
        dangerous. Anyway, here's my talk.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 5...30),
        checks: [
            .feedbackContainsAnyOf(["hook", "shallow", "generic", "specific", "open"]),
        ]
    )

    static let keynoteFlatOpen = AIQualityFixture(
        id: "keynote-flat-open",
        label: "generic keynote intro, no narrative arc",
        mode: .keynote, level: 5,
        question: "Open a keynote on the future of remote work.",
        transcript: """
        Hello everyone. Thank you for being here today. I'd like to talk about remote work and \
        what I think it will look like in the future. Remote work has changed a lot recently. \
        There are many factors that affect remote work. Some companies have gone fully remote \
        and others have not. Today I will share some thoughts on this topic. I hope you find it \
        useful. Let's get started.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 30...58),
        checks: [
            .feedbackContainsAnyOf(["opening", "open", "hook", "arc", "narrative"]),
        ]
    )

    static let keynoteGood = AIQualityFixture(
        id: "keynote-good",
        label: "decent keynote opening with a hook attempt",
        mode: .keynote, level: 5,
        question: "Open a keynote about climate tech.",
        transcript: """
        Last March I stood on a glacier that, according to the geologist next to me, had retreated \
        three football fields in the past two summers. That image is what I want you to hold onto \
        for the next thirty minutes, because the talk we're about to have is not really about \
        carbon capture or solar arrays — it's about how fast we can move once we decide to. The \
        good news, and the reason I'm cautiously optimistic, is that we have most of the technology \
        we need. The bad news is that deploying it at scale requires the boring work of permits, \
        capital, and grids. Today I'll walk you through three companies that are doing that boring \
        work well, and one specific lesson from each.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 55...82),
        checks: [
            .feedbackContainsAnyOf(["hook", "arc", "open", "imagery", "story"]),
        ]
    )

    static let keynoteGreat = AIQualityFixture(
        id: "keynote-great",
        label: "strong keynote opening with hook, frame, and clear stakes",
        mode: .keynote, level: 7,
        question: "Open a keynote on the future of education.",
        transcript: """
        In nineteen eighty-four, a researcher named Benjamin Bloom showed that a kid taught one-on-one \
        outperforms a kid in a classroom by two standard deviations. Two standard deviations. That's \
        the gap between an average student and the top two percent of a class. He called it the \
        two-sigma problem, and he spent the rest of his career trying to find a way to scale tutoring \
        to every kid. He never found it. He died in nineteen ninety-nine. I'm here today because, \
        for the first time in forty years, we have a real shot at solving Bloom's problem — and \
        if we do, it will be the largest single uplift in human capability in our lifetimes. The \
        question is not whether the technology can do it. The question is whether we'll let it.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 75...95),
        checks: [
            .feedbackContainsAnyOf(["hook", "arc", "stakes", "open", "story"]),
        ]
    )

    static let keynotePerfect = AIQualityFixture(
        id: "keynote-perfect",
        label: "exemplary keynote opening — story, frame, surprise, stakes",
        mode: .keynote, level: 9,
        question: "Open a keynote about the future of work.",
        transcript: """
        On the morning of October twenty-ninth, nineteen twenty-nine, a junior trader at the \
        New York Stock Exchange named Edward Bennett walked through the front doors with the \
        same lunch his wife had packed every weekday for eleven years: a ham sandwich, an apple, \
        and a thermos of black coffee. By the end of that day the world he had been preparing \
        for his entire adult life was gone, and the world that replaced it would not be \
        recognizable for another generation. I think we are standing in October of nineteen \
        twenty-nine right now. Not because we are headed for a crash — we may or may not be — \
        but because the assumption that the work we have spent decades preparing for will \
        still exist in a decade is the most expensive bet most of us are making, and almost \
        none of us are pricing it correctly. This morning I want to give you a way to think \
        about that bet, three signals to watch for, and one decision you can make this week.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(
            overall: 85...100,
            metrics: [.engagement: 8...10, .vocabulary: 8...10]
        ),
        checks: [
            .feedbackContainsAnyOf(["hook", "open", "story", "arc", "stakes"]),
            .bestMomentQuoteInTranscript,
        ]
    )

    // ============================================================
    // MARK: - Casual
    // ============================================================

    static let casualEmpty = AIQualityFixture(
        id: "casual-empty",
        label: "empty transcript — silent",
        mode: .casual, level: 1,
        question: "Explain how DNS works to a friend.",
        transcript: "",
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 0...15),
        checks: [.allMetricsAtMost(2)]
    )

    static let casualBad = AIQualityFixture(
        id: "casual-bad",
        label: "shallow, hand-wavy, jargon without explanation",
        mode: .casual, level: 1,
        question: "Explain how TCP works to a friend.",
        transcript: """
        Yeah TCP is a thing computers use to talk to each other. There's also UDP. They're different. \
        TCP is like the more careful one I think? I don't really remember the details. It uses packets. \
        Yeah.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 5...30),
        checks: [
            .feedbackContainsAnyOf(["specific", "shallow", "vague", "explain", "jargon", "clarity"]),
        ]
    )

    static let casualOkay = AIQualityFixture(
        id: "casual-okay",
        label: "answers question but unclear, uses jargon",
        mode: .casual, level: 3,
        question: "Explain how an SSL certificate works.",
        transcript: """
        So an SSL certificate is what makes a website secure. It's like a digital signature that proves \
        the site is who it claims to be. There's a thing called a certificate authority that signs them. \
        When your browser connects to a site, it checks the certificate against a list of trusted \
        authorities, and if it matches, the connection is encrypted. The encryption uses something called \
        public-key cryptography, where there's a public key and a private key. That's basically how it works.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 35...62),
        checks: [
            .feedbackContainsAnyOf(["analogy", "specific", "jargon", "explain", "clarity"]),
        ]
    )

    static let casualGood = AIQualityFixture(
        id: "casual-good",
        label: "clear answer with one good analogy",
        mode: .casual, level: 5,
        question: "Explain what an API is to a non-technical friend.",
        transcript: """
        An API is like a waiter at a restaurant. You don't go into the kitchen to grab the food yourself \
        — you tell the waiter what you want, and they bring it back. The kitchen has its own way of \
        doing things, and it might change how it cooks something, but as long as the waiter still \
        delivers what you ordered, you don't need to care. APIs work the same way: one program asks \
        another program for something, and as long as both sides agree on the menu — what you can \
        ask for, what you'll get back — the underlying details don't matter to the caller.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 60...85),
        checks: [
            .feedbackContainsAnyOf(["analogy", "clear", "natural", "explain"]),
        ]
    )

    static let casualGreat = AIQualityFixture(
        id: "casual-great",
        label: "natural explanation in conversational tone",
        mode: .casual, level: 5,
        question: "Explain how DNS works to a friend.",
        transcript: """
        Okay so when you type a website name into your browser, your computer doesn't actually know \
        where that website lives. It needs to look it up, kind of like looking up a phone number in a \
        phone book. That's what DNS does. Your computer asks a DNS server, hey, what's the address \
        for example.com, and the server gives back a number — that's the IP address. Then your computer \
        uses that number to actually connect. The clever part is that DNS is layered: there are root \
        servers, then servers for each top-level domain like com or net, then servers for the specific \
        domain. So one lookup might bounce through a few servers, but it usually happens in milliseconds.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 60...95),
        checks: [
            .feedbackContainsAnyOf(["clear", "natural", "conversational", "analogy"]),
        ]
    )

    static let casualPerfect = AIQualityFixture(
        id: "casual-perfect",
        label: "exemplary natural explanation with layered analogies",
        mode: .casual, level: 7,
        question: "Explain what a database transaction is to a friend.",
        transcript: """
        Imagine you're transferring twenty dollars to a friend. Two things have to happen: your account \
        goes down by twenty, and theirs goes up by twenty. Now imagine the power flickers right between \
        those two steps. If only one of them happened, money has either vanished or appeared from nowhere \
        — both bad. A database transaction is the bank's way of saying: these two things either both \
        happen, or neither happens, and from the outside they look like one indivisible event. That's \
        the whole idea. The clever part is that databases give you four guarantees with this — they \
        call it ACID — and the most interesting one is isolation, which means even if a thousand \
        transfers happen at once, each one sees a consistent snapshot of the world, like everyone is \
        in their own little time bubble for the duration of their transfer.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(
            overall: 80...100,
            metrics: [.clarity: 8...10, .engagement: 7...10]
        ),
        checks: [
            .feedbackContainsAnyOf(["analogy", "clear", "natural", "engagement"]),
            .bestMomentQuoteInTranscript,
        ]
    )

    // ============================================================
    // MARK: - Other modes (good-tier canaries)
    // ============================================================

    static let debateGood = AIQualityFixture(
        id: "debate-good",
        label: "takes a position, defends with evidence, anticipates counter",
        mode: .debate, level: 5,
        question: "Should remote work be the default for software companies?",
        transcript: """
        Yes, with one caveat. Remote should be the default because it expands the talent pool — you \
        stop being limited to whoever lives within commute distance of an office, and the data backs \
        this up. GitLab and Automattic have been remote-first for over a decade and ship at the same \
        rate as in-office competitors. The caveat is the first six months of a new hire. New engineers \
        ramp faster with co-located mentorship, so I'd say remote-default with quarterly weeks where \
        teams overlap in person. The trade-off is real, but the upside on hiring outweighs it for most \
        software companies, and the few that genuinely need in-person work usually know who they are.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 60...85),
        checks: [
            .feedbackContainsAnyOf(["position", "argument", "counter", "evidence", "clear"]),
        ]
    )

    static let storytellingGood = AIQualityFixture(
        id: "storytelling-good",
        label: "personal story with specific detail and clear lesson",
        mode: .storytelling, level: 5,
        question: "Tell a personal story about a setback that taught you something.",
        transcript: """
        When I was twenty-two I started my first company with two friends. We raised a small seed \
        round, built a product nobody wanted, and shut down eighteen months later. The setback wasn't \
        the failure itself — it was realizing on day three after we shut down that I'd been ignoring \
        the same signal for nine months. Customer interviews kept saying the same thing: I'd use this \
        if it cost half what it does. Instead of cutting the price, we kept building features. The \
        lesson wasn't listen to customers — everyone says that. It was: listen to the boring feedback, \
        not just the exciting feedback. Boring feedback is uncomfortable because it usually means you \
        have to undo work, not add to it.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 60...85),
        checks: [
            .feedbackContainsAnyOf(["story", "specific", "lesson", "detail", "engagement"]),
            .bestMomentQuoteInTranscript,
        ]
    )

    static let explanationGood = AIQualityFixture(
        id: "explanation-good",
        label: "technical explanation with analogy and clear trade-off",
        mode: .explanation, level: 5,
        question: "Explain how a database index works.",
        transcript: """
        An index is the database equivalent of the index at the back of a textbook. Without it, \
        finding a specific row means scanning every page. With it, you have a sorted list pointing \
        to the right page directly. The trade-off is that every time you add or change a row, you \
        also have to update the index — so writes become slower in exchange for faster reads. That's \
        why you don't index every column: you index the ones you query frequently. Most databases use \
        a B-tree structure for indexes, which keeps them balanced as data grows so a lookup stays \
        fast even when the table has millions of rows.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 60...85),
        checks: [
            .feedbackContainsAnyOf(["analogy", "clear", "trade", "explain", "specific"]),
        ]
    )

    static let negotiationGood = AIQualityFixture(
        id: "negotiation-good",
        label: "anchored, principled, concrete justification",
        mode: .negotiation, level: 5,
        question: "Walk through how you'd negotiate a higher salary on an offer.",
        transcript: """
        First, anchor on a number that's both ambitious and defensible. I look at three data points: \
        the company's leveling guide, the upper quartile of the market for the role from levels.fyi, \
        and the gap between my current and the new total compensation. I'll typically come in ten to \
        fifteen percent above the offer with a specific rationale: here's the impact I expect to have \
        in the first six months, here's what comparable roles pay at peer companies, and here's the \
        delta from my current compensation. Then I stop talking. The hardest part of a salary \
        negotiation is the silence after you make your ask, because the temptation to soften it is \
        enormous. Don't.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 60...85),
        checks: [
            .feedbackContainsAnyOf(["specific", "concrete", "anchor", "structure", "clear"]),
        ]
    )

    static let impromptuGood = AIQualityFixture(
        id: "impromptu-good",
        label: "hot take with rationale, doesn't ramble",
        mode: .impromptu, level: 5,
        question: "If you could change one thing about software development culture, what would it be?",
        transcript: """
        I'd kill the assumption that more meetings equals more alignment. Most teams I've worked with \
        treat meetings as the default coordination tool, and the result is a calendar full of status \
        updates that should have been a paragraph in a doc. The tax is huge: every meeting is the \
        time-cost times the number of attendees, and most of those attendees aren't speaking. The \
        change I'd make is a defaults flip. The default for any update should be a written summary, \
        and the meeting only happens if there's a specific decision someone needs help making. That \
        single flip would give back fifteen percent of every engineer's week.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 55...82),
        checks: [
            .feedbackContainsAnyOf(["position", "specific", "concrete", "clear", "argument"]),
        ]
    )

    static let networkingGood = AIQualityFixture(
        id: "networking-good",
        label: "concise self-introduction with an open thread",
        mode: .networking, level: 5,
        question: "Introduce yourself at a tech conference networking event.",
        transcript: """
        I'm Maya. I lead engineering at a small Series A called Streamline — we build infrastructure \
        for high-volume IoT data, mostly for industrial customers. I've been there about two years, \
        before that I spent six years on the data platform team at Uber, which is where I learned \
        that ninety percent of distributed systems problems are actually communication problems. \
        Right now I'm trying to figure out how to scale our deploy pipeline without slowing down our \
        weekly release cadence — happy to swap notes if anyone here has done a similar transition.
        """,
        timingStats: .empty,
        audioFeatures: .empty,
        bands: ExpectedBands(overall: 55...82),
        checks: [
            .feedbackContainsAnyOf(["concise", "specific", "intro", "engagement", "open"]),
        ]
    )
}
