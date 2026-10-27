# Wrong twin: claims every write resets posted_at to now.
<< ContractAnnot %review
  { ((artist, (target, (rating, comment))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (_, (_, (_, (_, (_, (_, (_, reviews2))))))) |
      find_opt_b (sender, (artist, target)) reviews2 = Some (rating, (comment, (now, now))) } &
  { _ | True } >>
