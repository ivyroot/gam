# P6 for list: only the sender's (sender, listing_id) entry can change.
<< ContractAnnot %list
  { ((lid, (title, (itype, (desc, (pp, (cp, (wid, (act, hash)))))))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (_, (names2, (websites2, (listings2, (collections2, (items2, (licenses2, reviews2))))))) |
      listings2 = update_b (sender, lid) (find_opt_b (sender, lid) listings2) listings &&
      names2 = names && websites2 = websites && collections2 = collections &&
      items2 = items && licenses2 = licenses && reviews2 = reviews } &
  { _ | True } >>
