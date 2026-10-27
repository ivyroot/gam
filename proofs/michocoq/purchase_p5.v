(* P5 for purchase, kernel-checked: a successful purchase returns exactly
   [transfer of AMOUNT to the artist's contract unit; the event], where the
   event is the SET_DELEGATE None that prove_prep.mjs puts in place of EMIT.
   Cross-checks proofs/helmholtz/purchase.p5_ops.spec. *)
Require Import Michocoq.macros.
Import syntax. Import comparable.
Require Import NArith ZArith.
Require Import Michocoq.semantics Michocoq.entrypoints.
Import error.
Require List.
Require Import Gam.gam_source.

Definition parameter_ty := Eval cbv in contract_file_parameter contract_file.
Definition storage_ty := Eval cbv in contract_file_storage contract_file.

(* The WRONG_AMOUNT check is `AMOUNT; COMPARE; NEQ; IF { FAILWITH } {}`. *)
Lemma neq_false_eq (c : comparison) :
  negb (Z.eqb (comparison_to_int c) Z0) = false -> c = Eq.
Proof. destruct c; simpl; congruence. Qed.

Module gam(C:ContractContext).
Module semantics := Semantics C. Import semantics.

Definition gam : full_contract _ parameter_ty None storage_ty :=
  Eval cbv in contract_file_code contract_file.

Theorem purchase_p5
  (env : @proto_env (Some (parameter_ty, None)))
  artist target tier quantity (s : data storage_ty) ops s' fuel :
  60 <= fuel ->
  eval_seq env gam fuel ((inr (inl (artist, (target, (tier, quantity)))), s), tt)
    = Return ((ops, s'), tt) ->
  exists c : data (contract unit),
    contract_ None unit I artist = Some c /\
    ops = (transfer_tokens unit I tt (amount env) c :: set_delegate None :: nil)%list.
Proof.
  intros Hfuel H.
  rewrite return_precond, eval_seq_precond_correct in H.
  unfold eval_seq_precond in H.
  do 30 (more_fuel; simpl in H).
  destruct s as (names, (websites, (listings, (collections, (items, (licenses, reviews)))))).
  simpl in H.
  destruct H as (_, H).
  destruct target as [id|id]; simpl in H;
    destruct H as (record & _ & _ & H);
    destruct tier as [[]|[]]; destruct H as (_ & H);
    match type of H with precond ?m _ => destruct m as [|z]; simpl in H; [contradiction|] end;
    destruct H as (Hamount & H);
    apply neq_false_eq, tez.compare_eq_iff in Hamount; subst z;
    match type of H with match ?lic with _ => _ end => destruct lic as [(p, (cm, lvl))|] end; simpl in H;
    destruct H as (c & Hc & Heq);
    injection Heq; intros; subst; exists c; exact (conj Hc eq_refl).
Qed.

End gam.
