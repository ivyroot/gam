# Deliberately wrong: the event comes before the payment.
<< ContractAnnot %purchase
  { ((artist, (target, (tier, quantity))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (ops, _) |
      match (contract_opt artist : option (contract unit)) with
      | Some c -> ops = [SetDelegate None; TransferTokens Unit amount c]
      | None -> False } &
  { _ | True } >>
