# P6 for set_collection: only the sender's (sender, collection_id) entry can change.
<< ContractAnnot %set_collection
  { ((cid, (title, (desc, (pp, (cp, (wid, act)))))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (_, (names2, (websites2, (listings2, (collections2, (items2, (licenses2, reviews2))))))) |
      collections2 = update_b (sender, cid) (find_opt_b (sender, cid) collections2) collections &&
      names2 = names && websites2 = websites && listings2 = listings &&
      items2 = items && licenses2 = licenses && reviews2 = reviews } &
  { _ | True } >>
