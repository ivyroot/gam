# P1 and the success side of P2: a purchase succeeds only for an existing,
# active target whose requested tier has a non-zero price, with quantity > 0
# and exactly unit price * quantity sent.
<< ContractAnnot %purchase
  { ((artist, (target, (tier, quantity))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { _ |
      quantity > 0 &&
      (match target with
       | Left id ->
           (match find_opt_b (artist, id) listings with
            | Some (_, (_, (_, (pp, (cp, (_, (act, _))))))) ->
                act && (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) > 0 && amount = (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) * quantity
            | None -> False)
       | Right id ->
           (match find_opt_b (artist, id) collections with
            | Some (_, (_, (pp, (cp, (_, act))))) ->
                act && (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) > 0 && amount = (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) * quantity
            | None -> False)) } &
  { _ | True } >>
