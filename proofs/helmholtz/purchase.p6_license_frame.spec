# P6 for licenses: the only licence entry purchase can change is the buyer's
# own (sender, artist, target) key; every other key is untouched.
<< ContractAnnot %purchase
  { ((artist, (target, (tier, quantity))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (_, (_, (_, (_, (_, (_, (licenses2, _))))))) |
      licenses2 =
        update_b (sender, (artist, target)) (find_opt_b (sender, (artist, target)) licenses2) licenses } &
  { _ | True } >>
