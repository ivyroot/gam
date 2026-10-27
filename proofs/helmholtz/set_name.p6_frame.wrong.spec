# Wrong twin: claims set_name leaves names unchanged.
<< ContractAnnot %set_name
  { (name, (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (_, (names2, _)) | names2 = names } &
  { _ | True } >>
