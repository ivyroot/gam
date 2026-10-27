# P2 and the failure side of P1: purchase fails only with one of these
# errors, each under exactly its condition, checked in this order.
<< ContractAnnot %purchase
  { ((artist, (target, (tier, quantity))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { _ | True } &
  { e |
      (e = Error ("ZERO_QUANTITY" : string) && quantity = 0) ||
      (e = Error ("UNKNOWN_LISTING" : string) && quantity > 0 &&
         (match target with
          | Left id -> find_opt_b (artist, id) listings = None
          | Right _ -> False)) ||
      (e = Error ("UNKNOWN_COLLECTION" : string) && quantity > 0 &&
         (match target with
          | Left _ -> False
          | Right id -> find_opt_b (artist, id) collections = None)) ||
      (e = Error ("NOT_ACTIVE" : string) && quantity > 0 &&
         (match target with
          | Left id ->
              (match find_opt_b (artist, id) listings with
               | Some (_, (_, (_, (pp, (cp, (_, (act, _))))))) -> !act
               | None -> False)
          | Right id ->
              (match find_opt_b (artist, id) collections with
               | Some (_, (_, (pp, (cp, (_, act))))) -> !act
               | None -> False))) ||
      (e = Error ("NOT_FOR_SALE" : string) && quantity > 0 &&
         (match target with
          | Left id ->
              (match find_opt_b (artist, id) listings with
               | Some (_, (_, (_, (pp, (cp, (_, (act, _))))))) -> act && (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) = 0
               | None -> False)
          | Right id ->
              (match find_opt_b (artist, id) collections with
               | Some (_, (_, (pp, (cp, (_, act))))) -> act && (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) = 0
               | None -> False))) ||
      (e = Overflow && quantity > 0 &&
         (match target with
          | Left id ->
              (match find_opt_b (artist, id) listings with
               | Some (_, (_, (_, (pp, (cp, (_, (act, _))))))) -> act && (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) > 0
               | None -> False)
          | Right id ->
              (match find_opt_b (artist, id) collections with
               | Some (_, (_, (pp, (cp, (_, act))))) -> act && (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) > 0
               | None -> False))) ||
      (e = Error ("WRONG_AMOUNT" : string) && quantity > 0 &&
         (match target with
          | Left id ->
              (match find_opt_b (artist, id) listings with
               | Some (_, (_, (_, (pp, (cp, (_, (act, _))))))) -> act && (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) > 0 && amount <> (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) * quantity
               | None -> False)
          | Right id ->
              (match find_opt_b (artist, id) collections with
               | Some (_, (_, (pp, (cp, (_, act))))) -> act && (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) > 0 && amount <> (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) * quantity
               | None -> False))) ||
      (e = Error ("ARTIST_CANNOT_RECEIVE" : string) && quantity > 0 &&
         (match target with
          | Left id ->
              (match find_opt_b (artist, id) listings with
               | Some (_, (_, (_, (pp, (cp, (_, (act, _))))))) -> act && (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) > 0 && amount = (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) * quantity
               | None -> False)
          | Right id ->
              (match find_opt_b (artist, id) collections with
               | Some (_, (_, (pp, (cp, (_, act))))) -> act && (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) > 0 && amount = (if (match tier with Left _ -> True | Right _ -> False) then pp else cp) * quantity
               | None -> False)) &&
         (match (contract_opt artist : option (contract unit)) with
          | Some _ -> False
          | None -> True)) } >>
