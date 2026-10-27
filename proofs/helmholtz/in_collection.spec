# P9: in_collection is true exactly when the (artist, collection_id,
# listing_id) key exists in collection_items, and never fails.
<< ContractAnnot
  { (((artist, (cid, lid)), (_, _, _, _, items, _, _)), _) | True } ->
  { (ops, r) | ops = [] &&
      r = (match find_opt_b (artist, (cid, lid)) items with
           | Some _ -> True
           | None -> False) } &
  { _ | False } >>
