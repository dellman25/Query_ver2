# **Product Requirements Document**

## **Product Name**

Ops Interview Assistant MVP

## **Version**

MVP v0.1

## **Purpose**

Build an AI-assisted interview workspace for business analysts (BAs) who are eliciting requirements from broker clearing and back-office operators. The MVP should help BAs capture interviews, identify missing requirement areas, shift questioning toward higher-value discovery, and produce structured post-interview outputs.

The MVP will use OpenOats as the foundation for:

* live transcription

* local session storage / knowledge base writing

* transcript persistence

* basic retrieval from local memory

The MVP will add a domain-specific requirements extraction and interview guidance layer on top.

---

## **1\. Problem Statement**

Back-office operators know how to execute operational workflows, but they often describe procedures without explaining the reasoning, controls, exceptions, or data dependencies behind them. Junior or less experienced product managers and business analysts often fail to ask the follow-up questions needed to extract usable requirements.

As a result:

* interviews over-index on procedural narration

* critical business rules and exception paths are missed

* control rationale is not captured

* requirements are incomplete or solution-biased

* post-interview synthesis is slow and inconsistent

The product must help BAs move from “what the operator does” to “what the business process requires.”

---

## **2\. Product Goal**

Enable a BA to conduct a discovery interview with an operations user and produce a structured, evidence-backed requirements draft with less missed coverage and better quality follow-up questions.

---

## **3\. MVP Outcome**

After a single interview session, the BA should be able to get:

* full timestamped transcript

* BA-authored notes and tags

* timestamped manual screenshots captured during screen share

* UI hints that adapt the BA’s questioning strategy based on current context

* extracted process steps, business rules, exceptions, controls, data needs, pain points, and open questions

* a structured post-interview summary and requirements draft

---

## **4\. Users**

### **Primary User**

* Business Analyst (BA)

### **Secondary Users**

* Junior PM

* Ops transformation lead

* Product manager reviewing requirements

### **Interview Subjects**

* Back-office operator

* Team lead

* Supervisor

* Control owner

* Reconciliation analyst

* Settlement analyst

* Operations specialist

---

## **5\. Scope**

### **In Scope for MVP**

* live transcription during interview

* local session persistence via OpenOats foundation

* BA notes during interview

* BA tagging of important moments

* manual screen capture by BA during operator screen share

* automatic timestamping of each screen capture

* interview guidance and adaptive question-shift hints

* transcript \+ note \+ screenshot timeline

* post-interview extraction into structured requirement objects

* exportable summary in markdown

### **Out of Scope for MVP**

* automatic video recording

* automatic OCR or table extraction from screenshots

* automatic regulation search and citation enrichment

* direct Jira or Confluence integration

* full workflow diagram rendering

* multi-user live collaboration

* automated desktop instrumentation

* cloud multi-tenant production architecture

---

## **6\. Product Principles**

1. Guide the BA toward business rationale, not solution design.

2. Prefer structured extraction over generic summarization.

3. Preserve evidence traceability back to transcript, note, or screenshot timestamp.

4. Keep operator burden low.

5. Support privacy-sensitive local-first workflows.

6. Do not invent requirements without grounding in source material.

---

## **7\. Core User Stories**

### **Interview Setup**

* As a BA, I want to create a session and define the process area so the assistant can guide the interview appropriately.

* As a BA, I want to select the interviewee role so prompts are better tailored.

### **During Interview**

* As a BA, I want live transcript capture so I do not need to manually record everything.

* As a BA, I want to type notes alongside the transcript so I can capture what matters.

* As a BA, I want to tag important moments as business rule, exception, control, data field, metric, pain point, or open question.

* As a BA, I want to capture screenshots while the operator is screen sharing so I can preserve visual evidence.

* As a BA, I want screenshots automatically timestamped and linked to the session timeline.

* As a BA, I want the assistant to suggest the kinds of follow-up questions I should shift toward based on what is missing.

* As a BA, I want the assistant to tell me when the operator is staying procedural and I should ask more “why,” exception, or control questions.

### **After Interview**

* As a BA, I want a structured summary of the session so I can quickly review the interview.

* As a BA, I want extracted requirement objects grouped by type so I can refine them into a requirements document.

* As a BA, I want open questions and ambiguity flags so I know what to validate next.

* As a BA, I want every extracted item to be traceable to transcript, note, or screenshot evidence.

---

## **8\. MVP Workflow**

### **Step 1: Create Session**

BA enters:

* session title

* process area

* interviewee role

* discovery objective

### **Step 2: Run Interview**

System provides:

* live transcript pane

* BA notes pane

* tagging controls

* screenshot capture control

* dynamic guidance panel

### **Step 3: Capture Screen During Screen Share**

BA clicks “Capture Screen”

System:

* stores image locally

* attaches timestamp

* links to current transcript point

* allows optional BA label for screenshot

### **Step 4: Adaptive Question Guidance**

System continuously analyzes transcript \+ notes and shows UI hints for what questioning mode the BA should shift toward.

### **Step 5: Post-Interview Synthesis**

System generates:

* session summary

* process understanding summary

* extracted facts

* requirements draft

* open questions

* evidence links

---

## **9\. Functional Requirements**

## **9.1 Session Setup**

The system must allow the BA to create a new interview session.

Fields required:

* session title

* process area

* interviewee role

Fields optional:

* discovery objective

* tags

Acceptance criteria:

* BA can start a session in under 60 seconds.

* session metadata is persisted locally.

## **9.2 Live Transcription**

The system must use OpenOats transcription capability as the base live transcript engine.

Acceptance criteria:

* transcript appears in near real time

* transcript segments are timestamped

* transcript is persisted locally

* transcript is viewable as a chronological timeline

## **9.3 Notes Pane**

The system must allow the BA to enter freeform notes during the interview.

Acceptance criteria:

* notes autosave locally

* each note receives timestamp metadata

* notes can be linked to transcript context if entered while transcript is active

## **9.4 Tagging**

The system must allow the BA to tag notes or transcript moments with structured categories.

Initial tag types:

* business rule

* exception

* control

* data field

* metric

* pain point

* open question

Acceptance criteria:

* BA can add a tag with one click

* tags appear in session timeline

* tags are included in post-interview extraction

## **9.5 Manual Screen Capture**

The system must allow the BA to manually capture screenshots during a screen-share walkthrough.

Required behavior:

* capture current screen or active shared window

* timestamp capture automatically

* store image locally in session folder

* create timeline event for screenshot

* allow optional user label, e.g. “daily fails dashboard”

Acceptance criteria:

* screenshot capture takes no more than 2 clicks

* screenshot appears in timeline within 2 seconds

* timestamp is associated automatically

* screenshots persist with session data

## **9.6 Adaptive Question-Shift Guidance**

The system must analyze live transcript and notes to provide UI hints on how the BA should change questioning approach.

The system must detect when the conversation is dominated by procedural narration and suggest a shift toward one or more of the following modes:

* why / rationale

* decision logic

* exceptions

* controls / risk

* data dependencies

* outputs / reports

* upstream/downstream handoffs

The system should not force exact questions only; it should give directional hints and example prompts.

Example hint text:

* “The operator is describing steps. Shift toward why this step exists.”

* “You have the main flow but not the exception path. Ask what usually goes wrong.”

* “A report is being shown on screen. Shift toward what decisions are made from these columns.”

* “You captured an action but not the rule behind it. Ask what condition causes path A vs B.”

Acceptance criteria:

* hints update at least every 30 seconds or after meaningful transcript change

* hints are based on current transcript \+ note state

* hints identify at least one missing requirement dimension

* hints include at least one example phrasing the BA can use

## **9.7 Screenshot-Aware Guidance**

When a screenshot is captured, the system must bias hints toward screen-based discovery prompts.

Preferred hint themes when screenshot is recent:

* identify what screen/report this is

* identify what decision is made from the screen

* identify which fields matter

* identify thresholds or filters being used

* identify what is missing from the screen that causes additional work

Acceptance criteria:

* at least one screenshot-aware hint appears after capture if no newer hint supersedes it

## **9.8 Timeline View**

The system must display a unified chronological timeline of:

* transcript segments

* BA notes

* tags

* screenshots

Acceptance criteria:

* timeline items show timestamps

* screenshot items are clickable and viewable

* tagged items are visually distinct

## **9.9 Post-Interview Extraction**

The system must create structured objects from transcript, notes, tags, and screenshot labels.

Object types for MVP:

* process step

* business rule

* exception

* control

* data element

* pain point

* metric

* open question

* requirement draft

Acceptance criteria:

* output contains separate sections by object type

* each object references one or more source timestamps or evidence pointers

* ambiguous items can be flagged as inferred or unresolved

## **9.10 Post-Interview Summary**

The system must generate a markdown summary including:

* session metadata

* high-level process summary

* key findings

* extracted objects by type

* draft requirements

* unanswered questions

* evidence references

Acceptance criteria:

* BA can export summary as markdown file

* summary is generated from local session data

---

## **10\. UI Requirements**

## **10.1 Main Layout**

Three-panel layout preferred:

### **Left Panel**

* live transcript timeline

### **Center Panel**

* BA notes editor

* tagging controls

* screenshot capture control

### **Right Panel**

* guidance panel

* questioning mode hints

* missing coverage indicators

## **10.2 Guidance Panel UX**

The guidance panel must show:

* current interview mode detected

* recommended shift in questioning style

* 1–3 example prompts

* missing coverage areas

Possible detected modes:

* procedural narration

* decision explanation

* exception discussion

* control discussion

* screen walkthrough

Possible shift labels:

* Shift to Why

* Shift to Exceptions

* Shift to Decision Rules

* Shift to Controls

* Shift to Data Needs

* Shift to Reporting / Outputs

## **10.3 Missing Coverage Indicators**

The system should show lightweight indicators for whether the BA has captured:

* purpose

* trigger

* decision logic

* exceptions

* controls

* data fields

* outputs

* metrics

These should be hints, not hard blockers.

---

## **11\. Domain Logic Requirements**

The MVP must include a simple domain extraction schema that attempts to fill the following slots:

* process purpose

* trigger

* actor

* system mentioned

* step/action

* decision rule

* exception path

* control/risk rationale

* data needed

* output/report

* pain point

* metric/SLA

The assistant should use unfilled slots to drive guidance.

---

## **12\. Prompting / Intelligence Logic**

### **12.1 Guidance Engine Inputs**

* process area

* interviewee role

* transcript window

* recent notes

* recent tags

* screenshot capture events and labels

* filled vs unfilled schema slots

### **12.2 Guidance Engine Outputs**

* recommended questioning shift

* reason for shift

* example prompts

* missing coverage target

### **12.3 Example Rules**

If transcript is step-heavy and low on reasoning language:

* recommend Shift to Why or Shift to Decision Rules

If transcript includes many normal steps but few exception markers:

* recommend Shift to Exceptions

If tags show actions but no controls:

* recommend Shift to Controls

If screenshot was captured recently:

* recommend screen-based follow-up prompts

If operator mentions dashboard, report, queue, column, filter, or sort:

* recommend Shift to Reporting / Outputs or Data Needs

---

## **13\. Data Model**

### **Session**

* id

* title

* process\_area

* interviewee\_role

* objective

* created\_at

* updated\_at

### **TranscriptSegment**

* id

* session\_id

* speaker

* text

* timestamp\_start

* timestamp\_end

* confidence

### **Note**

* id

* session\_id

* text

* created\_at

* linked\_transcript\_id optional

### **Tag**

* id

* session\_id

* type

* source\_type (note or transcript)

* source\_id

* created\_at

### **ScreenshotCapture**

* id

* session\_id

* file\_path

* label optional

* captured\_at

* linked\_transcript\_id optional

### **ExtractedFact**

* id

* session\_id

* type

* text

* evidence\_refs\[\]

* confidence

* status (explicit, inferred, unresolved)

### **SummaryArtifact**

* id

* session\_id

* markdown\_path

* generated\_at

---

## **14\. Technical Constraints**

* leverage OpenOats where feasible for live transcription and local storage flow

* local-first storage for MVP

* no mandatory cloud dependency for core session functionality

* architecture should permit later replacement of local-only components

---

## **15\. Non-Functional Requirements**

### **Performance**

* transcript updates should feel near real time

* screenshot capture should complete quickly enough to not disrupt interview flow

* guidance refresh should not lag the UI noticeably

### **Reliability**

* autosave session state continuously

* recover session after crash where possible

### **Privacy**

* all session artifacts stored locally in MVP

* screenshots and transcripts must not leave device unless explicitly exported later

### **Usability**

* BA should be able to learn the core workflow in one session

* screenshot capture and tagging must be low-friction

---

## **16\. Success Metrics**

### **Primary MVP Success Metrics**

* BA completes an interview session with transcript, notes, and screenshots in one tool

* BA reports guidance was useful in shifting questions during interview

* post-interview summary reduces manual write-up time

### **Product Quality Metrics**

* percent of sessions with at least one extracted business rule

* percent of sessions with at least one extracted exception

* percent of sessions with at least one open question

* BA-rated usefulness of guidance hints

* BA-rated usefulness of screenshot timestamps and timeline linking

---

## **17\. Open Questions / Future Enhancements**

* should we add OCR to screenshots in v1.1?

* should screenshots support region capture or full screen only?

* should screenshot capture attempt to detect active shared app/window?

* should we let BAs manually mark an excerpt of transcript as especially important?

* should the local knowledge base include prior sessions as retrieval context by default?

* when should we add regulation enrichment and citation support?

* should requirement draft outputs map directly to user stories in a future version?

---

## **18\. Proposed MVP Milestones**

### **Milestone 1: Session Foundation**

* session creation

* OpenOats transcript integration

* local persistence

* notes pane

### **Milestone 2: Capture and Timeline**

* tagging

* screenshot capture

* timestamped timeline

### **Milestone 3: Guidance Layer**

* slot tracking

* questioning shift hints

* screenshot-aware hints

### **Milestone 4: Synthesis**

* extracted facts

* markdown summary generation

* requirements draft

---

## **19\. Implementation Notes for Codex**

Build this as a thin product layer on top of OpenOats rather than rewriting transcription from scratch.

Prioritize:

1. stable session model

2. clean timeline UI

3. screenshot capture workflow

4. deterministic slot tracking

5. LLM-powered guidance and synthesis behind structured prompts

Avoid over-building:

* no complex orchestration framework required for MVP

* no automated screenshot understanding required initially

* no external search dependency required for core MVP

---

## **20\. Additional Product Thoughts**

1. Add a visible “questioning mode” chip in the UI so the BA can quickly see the assistant’s current recommendation.

2. Add keyboard shortcuts for tags and screenshot capture to preserve interview flow.

3. Keep an explicit distinction between “what was said” and “what the system inferred.”

4. Treat screenshots as evidence objects, not just attachments.

5. Start with one or two operations process templates rather than trying to generalize across all back-office workflows.

6. Make summary output brutally practical: concise, structured, exportable, and source-linked.

---

## **21\. Example Guidance Hints**

### **Case: Procedural narration only**

Detected pattern: operator is describing steps in sequence.

Hint:

* Shift to Why

* Ask: “What is the reason this step is necessary?”

* Ask: “What risk or issue are you trying to catch here?”

### **Case: Main flow captured, no exception path**

Hint:

* Shift to Exceptions

* Ask: “What usually goes wrong in this process?”

* Ask: “Which cases cannot follow the normal path?”

### **Case: Report visible on screen**

Hint:

* Shift to Reporting / Data Needs

* Ask: “What decision are you making from this report?”

* Ask: “Which columns matter most and why?”

* Ask: “What is missing from this view that makes you open another tool?”

### **Case: Action described, no business rule captured**

Hint:

* Shift to Decision Rules

* Ask: “What condition makes you choose this action?”

* Ask: “Is there a threshold, date, amount, or status that determines this?”

### **Case: Manual check mentioned**

Hint:

* Shift to Controls

* Ask: “Why does this check exist?”

* Ask: “What happens if this is skipped or delayed?”

---

## **22\. Definition of Done for MVP**

The MVP is done when a BA can:

* create a session

* capture a live transcript

* type notes and apply tags

* manually capture timestamped screenshots during screen share

* receive live questioning-shift hints

* review a unified timeline

* generate a structured markdown summary with extracted requirement objects and evidence references

A few extra thoughts that will make the MVP much stronger:

First, add a **“question mode” state machine** rather than only freeform hints. In practice, the UI should show one current recommendation like:

* Shift to Why

* Shift to Exceptions

* Shift to Controls

* Shift to Data Needs

* Shift to Reporting

That will be easier for BAs to follow than a wall of suggestions.

Second, keep **evidence traceability** strict from day one. Every extracted rule, exception, or requirement should carry:

* source type

* timestamp

* transcript/snippet reference

* screenshot reference if applicable

* explicit vs inferred status

That will matter a lot once people start trusting the outputs.

Third, since you’re using OpenOats as the base, I’d be careful not to let the “knowledge base / memory” become a messy dump. For MVP, separate storage into:

* raw transcript

* BA notes

* screenshot metadata

* extracted facts

* generated summaries

That separation will save you pain later.

Fourth, for screen capture, add two tiny but high-value UX details:

* optional label immediately after capture

* “link this screenshot to current topic” shortcut

Without that, screenshots will become hard to interpret later.

Fifth, I would strongly recommend **keyboard shortcuts** in MVP:

* tag as rule

* tag as exception

* tag as control

* capture screenshot

This is one of those details that will dramatically improve real interview usability.

Sixth, don’t overreach on “AI asks the next best question” in v1. The safer and better MVP is:

* detect missing dimension

* recommend questioning shift

* offer 2–3 example phrasings

