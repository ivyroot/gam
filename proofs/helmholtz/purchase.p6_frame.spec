# P6 for purchase: every big_map other than licenses is unchanged.
<< ContractAnnot %purchase
  { ((artist, (target, (tier, quantity))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (_, (names2, (websites2, (listings2, (collections2, (items2, (_, reviews2))))))) |
      names2 = names && websites2 = websites && listings2 = listings &&
      collections2 = collections && items2 = items && reviews2 = reviews } &
  { _ | True } >>
