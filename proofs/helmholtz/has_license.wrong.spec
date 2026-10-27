# Deliberately wrong (default personal count 1): Helmholtz must reject this.
<< ContractAnnot
  { (((buyer, (artist, target)), (_, _, _, _, _, licenses, _)), _) | True } ->
  { (ops, r) | ops = [] &&
      r = (match find_opt_b (buyer, (artist, target)) licenses with
           | Some l -> l
           | None -> (1, (0, 0))) } &
  { _ | False } >>
