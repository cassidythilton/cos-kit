# Executive style (Cassidy, Nov 20: "very good, use this style going forward")

For anything an executive reads: the weekly exec briefing, board materials, updates to Peter, Ron or Mark. It builds on
handbook/plain-language.md. Match the example below in shape, length and tone.

## The rules
1. **A headline first.** One or two sentences: the biggest thing that's working, then the biggest risk, each with its
   date. A reader who stops there knows where things stand.
2. **Three sections, always in this order:** Working, Not working, Next two weeks.
3. **Every item starts with a plain name, then the card in brackets**: "Walmart and Target enrichment (#535): ...".
   The name is what an executive would call it, not the GitHub title.
4. **One sentence per item, two at most.** What happened or where it stands, then the date it lands. No hedging
   words ("hopefully", "should", "aims to").
5. **Numbers carry their comparison**: "nearly doubled in four weeks, from 52.0K to 100.8K a week"; "about 108K of
   428K". Round to what a reader can hold. Say what the number means if it isn't obvious.
6. **Not working is stated plainly, with its cause and its fix or date**: "came back with no record, mostly from
   failed parsing. Six fixes are filed." Never soften it; never leave a problem without what's being done.
7. **Next two weeks is a dated list of outcomes**, one line each, earliest first: "Official available-foods count on
   Nov 24."
8. **Status words are exact**: "built and tested", "isn't merged yet", "due", "on track for". Never claim a step that
   hasn't happened (the checker caught "already starts by itself" when it wasn't wired up).
9. **No jargon**: no table names, lane names, file names or unexplained acronyms. Spell out once if needed.
10. **Partners and people**: cross-team work is joint ("together with the app team"); no one is named next to a miss.

## The example (approved Nov 20)

**Headline:** Walmart and Target enriched foods are on track to go live Nov 25. About a quarter of enrichment requests
come back empty, though, and the nightly rebuild still waits on production data access.

**Working**
- Walmart and Target enrichment (#535): six batches were rerun with zero audit errors, and it's on track for Live on
  Nov 25.
- Enrichment auto-start (#469): the trigger is built and tested, and cloud wiring is next. It isn't merged yet.
- 40-nutrient list (#740): one agreed list for every report, with Science sign-off due Nov 26.
- Foodgraph partnership (#630): Tolga and David joined on Nov 19, and a 1,000-product sample test is next.

**Not working**
- Data handoff to the app (#535, #650, #739): the app connector is due Nov 25, the Pantry publish Nov 30, and the
  nightly data update Dec 31.
- About 108K of 428K barcodes sent for enrichment came back with no record, mostly from failed parsing. Six fixes are
  filed.
- App scans nearly doubled in four weeks, from 52.0K to 100.8K a week, and the gap is mostly foods we don't hold yet.
- The preliminary available-foods count runs low, and the official count lands Nov 24.
- Production data access (#732, #797): until it arrives on Nov 30, the numbers refresh by hand each morning.

**Next two weeks**
- Official available-foods count on Nov 24.
- The November slice goes to Live on Nov 25.
- Science signs off on the nutrient list on Nov 26.
- Agree a scan success measure with Ron and Mark.
- Decide on the Foodgraph sample and add outside-data cost to board materials by Nov 30.
