(* Non-vacuity for purchase_p5: a concrete chain context, environment,
   storage and purchase under which GAM's purchase entrypoint succeeds, so
   purchase_p5's hypothesis can actually hold. Coq evaluates the whole
   prover copy on these values. *)
Require Import Michocoq.macros.
Import syntax. Import comparable.
Require Import NArith ZArith Bool Uint63 String.
Require Import Michocoq.semantics Michocoq.entrypoints.
Import error.
Require List.
Open Scope string_scope.
Require Import Gam.gam_source Gam.purchase_p5.

(* An entrypoint of a passable parameter tree has a passable type. Needed to
   build the environment's SELF contract for every entrypoint annotation. *)
Lemma get_entrypoint_passable e ep an t :
  get_entrypoint e ep an = Some t ->
  Is_true (is_passable (entrypoint_tree_to_type ep)) -> Is_true (is_passable t).
Proof.
  revert an; induction ep as [a|a IHa ana b IHb anb]; intros an Ht Hp; simpl in Ht;
    unfold get_entrypoint_root in Ht.
  - destruct an as [an|]; simpl in Ht; [destruct (eqb_annot e an); simpl in Ht|];
      try discriminate; injection Ht as <-; exact Hp.
  - simpl in Hp; apply andb_prop_elim in Hp; destruct Hp as (Hpa, Hpb).
    destruct an as [an|]; simpl in Ht; [destruct (eqb_annot e an); simpl in Ht|].
    + injection Ht; intros; subst; simpl; apply andb_prop_intro; auto.
    + destruct (get_entrypoint e a ana) eqn:Ha; simpl in Ht.
      * injection Ht; intros; subst; eauto.
      * eauto.
    + destruct (get_entrypoint e a ana) eqn:Ha; simpl in Ht.
      * injection Ht; intros; subst; eauto.
      * eauto.
Qed.

Lemma get_entrypoint_opt_passable e ep an t :
  get_entrypoint_opt e ep an = Some t ->
  Is_true (is_passable (entrypoint_tree_to_type ep)) -> Is_true (is_passable t).
Proof.
  intros Ht Hp.
  assert (Hd : get_default_entrypoint ep an = Some t -> Is_true (is_passable t)).
  { unfold get_default_entrypoint.
    destruct (get_entrypoint _ ep an) eqn:H; simpl.
    - intro E; injection E; intros; subst; eauto using get_entrypoint_passable.
    - intro E; injection E; intros; subst; exact Hp. }
  destruct e as [e|]; simpl in Ht; [destruct (eqb_annot e _)|]; eauto using get_entrypoint_passable.
Qed.

Lemma get_opt_some {A : Set} (o : Datatypes.option A) H : o = Some (get_opt o H).
Proof. destruct o; destruct H; reflexivity. Qed.

(* GAM is the only originated contract; every originated address has GAM's
   parameter type. Implicit (tz1) addresses are contract unit regardless. *)
Definition gam_address := Mk_smart_contract_address "KT1Gam".

Module Context <: ContractContext.
  Definition get_contract_type (_ : smart_contract_address_constant) :
    Datatypes.option entrypoint_tree := Some parameter_ty.
End Context.

Module G := gam Context.
Import G.semantics.

Definition one_mutez : tez.mutez := 1%uint63.

Definition self_contract annot_opt H :
  data (contract (get_opt (get_entrypoint_opt annot_opt parameter_ty None) H)).
Proof.
  refine (build_contract _ (Originated gam_address, annot_opt) _ _).
  - apply (get_entrypoint_opt_passable annot_opt parameter_ty None).
    + apply get_opt_some.
    + exact I.
  - simpl. apply get_opt_some.
Defined.

Definition artist : data address := Implicit (Mk_key_hash "tz1Artist").
Definition buyer : data address := Implicit (Mk_key_hash "tz1Buyer").

Definition env : @proto_env (Some (parameter_ty, None)) :=
  @mk_proto_env (Some (parameter_ty, None))
    (fun _ => Originated gam_address)  (* generate_new_address *)
    (0%uint63)  (* balance *)
    (buyer)  (* source *)
    (buyer)  (* sender *)
    (self_contract)  (* self *)
    (one_mutez)  (* amount *)
    (0%Z)  (* now *)
    (7%N)  (* level *)
    (fun _ => Mk_key_hash "")  (* hash_key *)
    (fun _ _ _ => ""%string)  (* pack *)
    (fun _ _ _ => None)  (* unpack *)
    (fun b => b)  (* blake2b *)
    (fun b => b)  (* sha256 *)
    (fun b => b)  (* sha512 *)
    (fun b => b)  (* keccak *)
    (fun b => b)  (* sha3 *)
    (fun _ _ _ => false)  (* check_signature *)
    (Mk_chain_id "")  (* chain_id_ *)
    (fun _ => 0%N)  (* voting_power *)
    (0%N)  (* total_voting_power *)
    (fun ms => Sapling_state_repr ms "")  (* sapling_empty_state *)
    (fun ms => fun _ _ => None)  (* sapling_verify_update *).

(* One active listing (artist, 0) at 1 mutez personal, not for sale
   commercially; everything else empty. *)
Definition listing0 :=
  ("Title"%string, ("photograph"%string, (""%string, (one_mutez, (0%uint63, (0%N, (true, "hash"%string))))))).

Definition storage : data storage_ty :=
  (map.empty,
   (map.empty,
    (map.insert (comparable.compare_eq_iff (Cpair address nat)) (comparable.gt_trans (Cpair address nat))
       (artist, 0%N) listing0 (map.empty),
     (map.empty,
      (map.empty,
       (map.empty,
        map.empty)))))).

(* purchase(artist, Listing 0, Personal, 1) with AMOUNT = 1 mutez *)
Definition input : data (entrypoint_tree_to_type parameter_ty) :=
  inr (inl (artist, (inl 0%N, (inl tt, 1%N)))).

Theorem purchase_succeeds :
  exists ops s',
    eval_seq env G.gam 60 ((input, storage), tt) = Return ((ops, s'), tt).
Proof. do 2 eexists. vm_compute. reflexivity. Qed.

(* And the premise of purchase_p5 really holds: *)
Corollary purchase_p5_not_vacuous :
  exists ops s',
    eval_seq env G.gam 60 ((input, storage), tt) = Return ((ops, s'), tt) /\
    exists c : data (contract unit),
      contract_ None unit I artist = Some c /\
      ops = (transfer_tokens unit I tt (amount env) c :: set_delegate None :: nil)%list.
Proof.
  destruct purchase_succeeds as (ops & s' & H).
  exists ops, s'; split; [exact H|].
  eapply G.purchase_p5; [|exact H]. repeat constructor.
Qed.
