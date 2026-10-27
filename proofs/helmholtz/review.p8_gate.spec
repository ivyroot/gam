# P8 for review: success only with a licence for (sender, artist, target) bought
# in an earlier block, a rating (1-10) or a comment, and a rating in range.
<< ContractAnnot %review
  { ((artist, (target, (rating, comment))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { _ |
      (match find_opt_b (sender, (artist, target)) licenses with
       | Some (_, (_, pal)) -> level > pal
       | None -> False) &&
      (match rating with
       | Some r -> r >= 1 && r <= 10
       | None -> comment <> None) } &
  { _ | True } >>
