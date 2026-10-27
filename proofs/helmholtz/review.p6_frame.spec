# P6 for review: only the sender's own (sender, artist, target) review can change.
<< ContractAnnot %review
  { ((artist, (target, (rating, comment))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (_, (names2, (websites2, (listings2, (collections2, (items2, (licenses2, reviews2))))))) |
      reviews2 = update_b (sender, (artist, target)) (find_opt_b (sender, (artist, target)) reviews2) reviews &&
      names2 = names && websites2 = websites && listings2 = listings &&
      collections2 = collections && items2 = items && licenses2 = licenses } &
  { _ | True } >>
