# P8 for review: the stored review is exactly the given rating and comment,
# updated_at = now, and posted_at is kept from the first review (now if none).
<< ContractAnnot %review
  { ((artist, (target, (rating, comment))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { (_, (_, (_, (_, (_, (_, (_, reviews2))))))) |
      (match find_opt_b (sender, (artist, target)) reviews with
       | Some (_, (_, (p, _))) -> find_opt_b (sender, (artist, target)) reviews2 = Some (rating, (comment, (p, now)))
       | None -> find_opt_b (sender, (artist, target)) reviews2 = Some (rating, (comment, (now, now)))) } &
  { _ | True } >>
