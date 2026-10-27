# P5: a successful purchase returns exactly two operations: the whole amount
# sent, as a unit transfer to the artist's account, then the event (which
# prove_prep.mjs turns into SET_DELEGATE None).
<< ContractAnnot %purchase
  { ((artist, (target, (tier, quantity))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (ops, _) |
      match (contract_opt artist : option (contract unit)) with
      | Some c -> ops = [TransferTokens Unit amount c; SetDelegate None]
      | None -> False } &
  { _ | True } >>
