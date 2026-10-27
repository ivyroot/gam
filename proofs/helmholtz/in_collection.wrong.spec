# Deliberately wrong (negated): Helmholtz must reject this.
<< ContractAnnot
  { (((artist, (cid, lid)), (_, _, _, _, items, _, _)), _) | True } ->
  { (ops, r) | ops = [] &&
      r = (match find_opt_b (artist, (cid, lid)) items with
           | Some _ -> False
           | None -> True) } &
  { _ | False } >>
