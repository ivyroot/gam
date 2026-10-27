# P8 failure side for review: each error only under exactly its condition, in order.
<< ContractAnnot %review
  { ((artist, (target, (rating, comment))), (names, (websites, (listings, (collections, (items, (licenses, reviews))))))) | True } ->
  { _ | True } &
  { e |
      (e = Error ("NO_LICENSE" : string) && find_opt_b (sender, (artist, target)) licenses = None) ||
      (match find_opt_b (sender, (artist, target)) licenses with
       | Some (_, (_, pal)) ->
           (e = Error ("EMPTY_REVIEW" : string) && rating = None && comment = None) ||
           (match rating with
            | Some r -> e = Error ("BAD_RATING" : string) && (r < 1 || r > 10)
            | None -> False) ||
           (e = Error ("TOO_EARLY" : string) && level <= pal &&
              (match rating with
               | Some r -> r >= 1 && r <= 10
               | None -> comment <> None))
       | None -> False) } >>
