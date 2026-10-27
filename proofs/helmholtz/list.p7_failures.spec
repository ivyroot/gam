# P7 failure side for list: each error only under exactly its condition, in order.
<< ContractAnnot %list
  { ((lid, (title, (itype, (desc, (pp, (cp, (wid, (act, hash)))))))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { _ | True } &
  { e |
      (e = Error ("UNKNOWN_WEBSITE" : string) && find_opt_b (sender, wid) websites = None) ||
      (find_opt_b (sender, wid) websites <> None &&
        (match find_opt_b (sender, lid) listings with
         | Some (_, (_, (_, (_, (_, (w, (_, h))))))) ->
             (e = Error ("WEBSITE_ID_IMMUTABLE" : string) && w <> wid) ||
             (e = Error ("FILE_HASH_IMMUTABLE" : string) && w = wid && h <> hash)
         | None -> e = Error ("EMPTY_FILE_HASH" : string) && len_bytes hash = 0)) } >>
