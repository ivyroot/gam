# P7 for list: a successful call needs the sender's website, writes exactly the
# given record, and on an existing listing keeps website_id and file_hash; a new
# listing needs a non-empty file_hash.
<< ContractAnnot %list
  { ((lid, (title, (itype, (desc, (pp, (cp, (wid, (act, hash)))))))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (_, (_, (_, (listings2, _)))) |
      find_opt_b (sender, wid) websites <> None &&
      find_opt_b (sender, lid) listings2 = Some (title, (itype, (desc, (pp, (cp, (wid, (act, hash))))))) &&
      (match find_opt_b (sender, lid) listings with
       | Some (_, (_, (_, (_, (_, (w, (_, h))))))) -> w = wid && h = hash
       | None -> len_bytes hash > 0) } &
  { _ | True } >>
