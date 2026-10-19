# Czech inflection in `search_messages` (evaluation, task #13936)

Problem: `search_messages(query: "forpsi doména")` finds nothing for a subject with "domény", because every query word must be a substring of `search_text` and Czech changes word endings (doména / domény / doménu / doméně).

Measured on a 27-subject Czech sample (diacritics already folded, as in `normalize_search_text`), substring match, per query word:

| Option | Result |
| --- | --- |
| Exact (today) | "doména" matches 1 of 4 forms present; misses domény, doménu |
| Drop last 1 letter on words of 5+ | "domen" matches all 3 forms; one extra hit per noun at most (objednávka/objednávky, smlouva/smlouvy), which are the same word in another case, so they are wanted |
| Drop last 2 letters on words of 5+ | "dome" also matches the unrelated word "dome"/"domek"-type tokens (false positive seen in the sample); no recall gain over drop-1 for regular feminine nouns |
| `unaccent` + Czech stemmer | `unaccent` is already in effect (we fold in Ruby). A stemmer needs a dictionary or a new gem, a second index (tsvector) and no longer matches substrings in addresses and file names; cost far above the gain |
| Tell the model to use stems in the tool description | Free, but relies on the model; the failing case was the natural nominative |

Decision: prefix-stem matching, drop the last letter of query words with 5 or more characters (after diacritics are folded), is the winning option. It is a one-line change to `MailMessage.search` (the gin trigram index still serves the shorter `LIKE`), needs no setting, and keeps false positives to other cases of the same word. Words under 5 letters stay exact. Reject the stemmer (complexity) and drop-2 (false positives).

Follow-up: implement in `MailMessage.search` and mention in the `query` description that Czech endings are tolerated; add a fixture test "doména" finds "domény".
