# P6 for set_name: only the sender's names entry can change; every other
# big_map is unchanged.
<< ContractAnnot %set_name
  { (name, (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (_, (names2, (websites2, (listings2, (collections2, (items2, (licenses2, reviews2))))))) |
      names2 = update_b sender (find_opt_b sender names2) names &&
      websites2 = websites && listings2 = listings && collections2 = collections &&
      items2 = items && licenses2 = licenses && reviews2 = reviews } &
  { _ | True } >>
