# Deliberately wrong: a repeat purchase resets purchased_at_level.
<< ContractAnnot %purchase
  { ((artist, (target, (tier, quantity))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (_, (_, (_, (_, (_, (_, (licenses2, _))))))) |
      find_opt_b (sender, (artist, target)) licenses2 =
        Some (match find_opt_b (sender, (artist, target)) licenses with
              | None ->
                  (match tier with
                   | Left _ -> (quantity, (0, level))
                   | Right _ -> (0, (quantity, level)))
              | Some (p, (c, lv)) ->
                  (match tier with
                   | Left _ -> (p + quantity, (c, level))
                   | Right _ -> (p, (c + quantity, level)))) } &
  { _ | True } >>
