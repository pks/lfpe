This (horrid) hack reads cdec's "--show_derivations" and "--extract_rules" into
data structures  and tries to align "groups" in source and target sides
of rules in a smart, presentable way. The result resembles a phrase-based
system, given that the word alignment gives enough hints.

To run:
    ./derivation_to_json.rb < {one of the .raw files}
(first line of stdout is json data, source and target strings follow after that)

The first line of the input is the derivation as string, the following lines
are the rules used in the derivation.

