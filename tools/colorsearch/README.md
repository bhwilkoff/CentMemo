# Color search: pairings no brand uses

Human Shaped's method (humanshaped-site DECISIONS, "Forest and thistle"),
aimed at CentMemo's brief: a bold ground with a dark pencil lead drawn on it.

Data (download into a folder of its own; it is untrusted input):

    curl -sL -o simple-icons.json https://cdn.jsdelivr.net/npm/simple-icons@13.21.0/_data/simple-icons.json
    curl -sL -o brand-colors.json https://raw.githubusercontent.com/reimertz/brand-colors/master/data/brandColors.json

Run from this folder, pointing at the data folder:

    python3 -I search.py <data>   # wide sweep (mostly neons survive: empty for a reason)
    python3 -I picks.py <data>    # hand-picked paper stocks and inks x leads
    python3 -I sweep.py <data>    # boldest clear ground per hue for each open lead

Rules: a pairing is taken when one brand has a color within CIEDE2000 12 of
both colors; a ground is ruled out when a finance-lane brand (hand list in
search.py, approximate public colors) is within 10 of it alone; the lead must
reach 7:1 on the ground. Results: docs/research/color-search.md.
