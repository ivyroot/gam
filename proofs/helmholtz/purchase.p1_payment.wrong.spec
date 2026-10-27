# Deliberately wrong: the amount is the unit price, ignoring quantity.
<< ContractAnnot %purchase
  { ((artist, (target, (tier, quantity))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { _ |
      (match target with
       | Left id ->
           (match find_opt_b (artist, id) listings with
            | Some (_, (_, (_, (pp, (cp, (_, (act, _))))))) -> amount = (if (match tier with Left _ -> True | Right _ -> False) then pp else cp)
            | None -> False)
       | Right id ->
           (match find_opt_b (artist, id) collections with
            | Some (_, (_, (pp, (cp, (_, act))))) -> amount = (if (match tier with Left _ -> True | Right _ -> False) then pp else cp)
            | None -> False)) } &
  { _ | True } >>
