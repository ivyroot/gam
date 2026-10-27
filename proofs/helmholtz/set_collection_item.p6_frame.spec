# P6 for set_collection_item: only the sender's (sender, collection_id,
# listing_id) membership key can change.
<< ContractAnnot %set_collection_item
  { ((cid, (lid, inc)), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (_, (names2, (websites2, (listings2, (collections2, (items2, (licenses2, reviews2))))))) |
      items2 = update_b (sender, (cid, lid)) (find_opt_b (sender, (cid, lid)) items2) items &&
      names2 = names && websites2 = websites && listings2 = listings &&
      collections2 = collections && licenses2 = licenses && reviews2 = reviews } &
  { _ | True } >>
