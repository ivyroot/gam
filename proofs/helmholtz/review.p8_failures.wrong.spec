# Wrong twin: claims a review in the purchase block itself (level = pal) is allowed.
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
           (e = Error ("TOO_EARLY" : string) && level < pal)
       | None -> False) } >>
