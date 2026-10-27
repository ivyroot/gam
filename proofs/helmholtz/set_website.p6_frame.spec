# P6 for set_website: only the sender's (sender, website_id) entry can change.
<< ContractAnnot %set_website
  { ((wid, url), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (_, (names2, (websites2, (listings2, (collections2, (items2, (licenses2, reviews2))))))) |
      websites2 = update_b (sender, wid) (find_opt_b (sender, wid) websites2) websites &&
      names2 = names && listings2 = listings && collections2 = collections &&
      items2 = items && licenses2 = licenses && reviews2 = reviews } &
  { _ | True } >>
