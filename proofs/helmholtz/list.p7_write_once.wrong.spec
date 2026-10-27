# Wrong twin: claims list can only create, never update.
<< ContractAnnot %list
  { ((lid, (title, (itype, (desc, (pp, (cp, (wid, (act, hash)))))))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { _ | find_opt_b (sender, lid) listings = None } &
  { _ | True } >>
