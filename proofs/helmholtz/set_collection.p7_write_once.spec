# P7 for set_collection: a successful call needs the sender's website, writes
# exactly the given record, and on an existing collection keeps website_id.
<< ContractAnnot %set_collection
  { ((cid, (title, (desc, (pp, (cp, (wid, act)))))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (_, (_, (_, (_, (collections2, _))))) |
      find_opt_b (sender, wid) websites <> None &&
      find_opt_b (sender, cid) collections2 = Some (title, (desc, (pp, (cp, (wid, act))))) &&
      (match find_opt_b (sender, cid) collections with
       | Some (_, (_, (_, (_, (w, _))))) -> w = wid
       | None -> True) } &
  { _ | True } >>
