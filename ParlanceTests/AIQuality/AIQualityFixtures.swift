// ParlanceTests/AIQuality/AIQualityFixtures.swift
import Foundation
@testable import Parlance

enum AIQualityFixtures {

    static let all: [AIQualityFixture] = [
        empty,
        greatStar,
        rambling,
        fillerHeavy,
        offTopic,
        pitchStrongHook,
        keynoteFlatOpen,
        casualClear,
    ]

    // MARK: - Interview fixtures

    static let empty = AIQualityFixture(
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
            .feedbackContainsAnyOf(["transcript", "speak", "speech", "didn't", "no speech", "insufficient"]),
        ]
    )

    static let greatStar = AIQualityFixture(
        id: "interview-great-star",
        label: "tight STAR answer, ~130 words, 0 fillers",
        mode: .interview, level: 5,
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

    static let rambling = AIQualityFixture(
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

    static let fillerHeavy = AIQualityFixture(
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
            overall: 30...50,
            metrics: [.fillerWords: 0...4]
        ),
        checks: [
            .feedbackContainsAnyOf(["filler", "um", "uh", "like", "basically"]),
        ]
    )

    static let offTopic = AIQualityFixture(
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

    // MARK: - Mode canaries

    static let pitchStrongHook = AIQualityFixture(
        id: "pitch-strong-hook",
        label: "investor pitch with clear hook + ask",
        mode: .pitch, level: 5,
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
        bands: ExpectedBands(overall: 70...90),
        checks: [
            .feedbackContainsAnyOf(["hook", "urgency", "ask", "investor", "pitch", "traction"]),
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
        bands: ExpectedBands(overall: 35...55),
        checks: [
            .feedbackContainsAnyOf(["opening", "open", "hook", "arc", "narrative"]),
        ]
    )

    static let casualClear = AIQualityFixture(
        id: "casual-clear",
        label: "natural explanation in conversational tone",
        mode: .casual, level: 3,
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
        bands: ExpectedBands(overall: 65...85),
        checks: [
            .feedbackContainsAnyOf(["clear", "natural", "conversational", "analogy"]),
        ]
    )
}
