# Replay UI refinement and full-step timeline

Status: UI implemented; new CI pending. Full-step timing is a separate implementation milestone.

## Design

Blue #2563eb, slate neutrals and white. Preserve the existing layout, spacing and typography except for compact summary and control alignment. Do not recolor the application under test.

- Vendor Lucide 0.456.0 SVG geometry and include its license in the exported offline HTML. No CDN, no runtime icon package or remote request.
- Action mapping: fill = TextCursorInput; select = ListFilter; click = MousePointerClick; submit = Send; navigation = ExternalLink; assertion = CircleCheck; setup = Package; action = Play; multiple recorded field actions = FilePenLine; transition = Hourglass. Use the same action icon for all text fields.
- Gherkin cards remain one per step. Chips represent recorded actions; their active state tracks the media interval.
- Default subtle diagonal hatching only on steps with neither a video cue nor a DOM recording. The Shade unreplayed checkbox changes styling only and never filters or hides steps. No hatch on active cards.
- Distinguish No video cue (case has video, step lacks a link), DOM replay and Results only. Do not claim a step was not executed because replay is missing.
- Compact six summary pills with neutral zero counts, semantic nonzero success/failure, and normal-weight text. Uniform native select height, caret, padding and keyboard behavior.

## Independent timeline layers (next milestone)

1. Step interval: runtime step identity, recording identity, actual media start/end, provenance and timing quality; independent of focus geometry. A step may have no UI actions.
2. Action interval: existing observed focus segment, optional geometry and action label. A step can contain multiple actions.
3. Presentation annotation: navigation/hourglass overlay, explicitly editorial, never used as measured network latency.

Record step boundaries with an explicit media-clock mapping (for example captured frames with identifiable landmarks or a calibrated producer timestamp). Never use summed test durations, pre-recording setup times, callback receive timestamps or interpolated guesses as exact media positions. Steps completed before capture are visibly marked outside recording and remain non-seekable unless separately recorded. Unmapped gaps remain inactive. Existing old point-cue and DOM replay semantics remain supported.

## Acceptance

UI: genuine Lucide shapes, uniform field chips, default hatch and reversible toggle, six summary pills, consistent native selects, no network requests. Core and legacy Chromium smoke pass. Next milestone: actual recording maps navigation, form, submit and assertions to their own verified intervals; playback highlights the step independently of action chips; seeking works both directions; no invented timings for setup or unrecorded tests. Fast/Execution capture unchanged by presentation styling.

## Header and shape preferences

Default Rounded controls (7 px) and tags (5 px), optional Pill (999 px) via a live Shape selector. Only small controls and badges change; step cards, panels and video stay unchanged. In suite header, actual selected-case metadata renders as compact labeled tags near summary pills. Search comes first and filters the adjacent native test dropdown; status stays separate. Keep native selects for keyboard/accessibility and regression compatibility rather than introducing a custom combobox in this iteration. Remove duplicated producer metadata from case labels. Hide the DOM recording selector if no DOM recording exists; retain the video recording selector and legacy DOM navigation. Preference is per open report, no persistence or second exported HTML. Add Chromium regression checks. CI pending.
