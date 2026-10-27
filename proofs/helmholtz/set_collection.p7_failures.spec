# P7 failure side for set_collection.
<< ContractAnnot %set_collection
  { ((cid, (title, (desc, (pp, (cp, (wid, act)))))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { _ | True } &
  { e |
      (e = Error ("UNKNOWN_WEBSITE" : string) && find_opt_b (sender, wid) websites = None) ||
      (e = Error ("WEBSITE_ID_IMMUTABLE" : string) && find_opt_b (sender, wid) websites <> None &&
        (match find_opt_b (sender, cid) collections with
         | Some (_, (_, (_, (_, (w, _))))) -> w <> wid
         | None -> False)) } >>
