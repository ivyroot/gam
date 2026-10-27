# P9: has_license returns the stored licence record, or all zeros for a key
# never written, and never fails. Storage fields in order: names, websites,
# listings, collections, collection_items, licenses, reviews.
<< ContractAnnot
  { (((buyer, (artist, target)), (_, _, _, _, _, licenses, _)), _) | True } ->
  { (ops, r) | ops = [] &&
      r = (match find_opt_b (buyer, (artist, target)) licenses with
           | Some l -> l
           | None -> (0, (0, 0))) } &
  { _ | False } >>
