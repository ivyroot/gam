# P3 and P4: the buyer's licence for (sender, artist, target) is the old one
# with the requested tier's count raised by exactly quantity, the other count
# unchanged, and purchased_at_level set to the current level on the first
# purchase and unchanged after that.
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
                   | Left _ -> (p + quantity, (c, lv))
                   | Right _ -> (p, (c + quantity, lv)))) } &
  { _ | True } >>
