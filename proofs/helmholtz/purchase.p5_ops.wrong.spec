# Deliberately wrong: the payment goes to the buyer, not the artist.
<< ContractAnnot %purchase
  { ((artist, (target, (tier, quantity))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (ops, _) |
      match (contract_opt sender : option (contract unit)) with
      | Some c -> ops = [TransferTokens Unit amount c; SetDelegate None]
      | None -> False } &
  { _ | True } >>
