module DY.Core.Attacker.Knowledge

open DY.Core.Bytes.Type
open DY.Core.Bytes
open DY.Core.Trace.Type
open DY.Core.Trace.Invariant
open DY.Core.Label.Type
open DY.Core.Label

#set-options "--fuel 1 --ifuel 0"

val attacker_knows_aux: nat -> trace -> bytes -> prop
let rec attacker_knows_aux step tr msg =
  if step = 0 then (
    (
      msg_sent_on_network tr msg
    ) \/ (
      exists prin sess_id.
        is_corrupt tr (principal_state_label prin sess_id) /\
        state_was_set tr prin sess_id msg
    ) \/ (
      exists lit.
        msg == literal_to_bytes lit
    )
  ) else (
    // Use less steps (not super useful, but why not)
    attacker_knows_aux (step-1) tr msg \/
    // Concatenation
    (
      exists b1 b2.
        msg == concat b1 b2 /\
        attacker_knows_aux (step-1) tr b1 /\
        attacker_knows_aux (step-1) tr b2
    ) \/ (
      exists i b2 buf.
        Some (msg, b2) == split buf i /\
        attacker_knows_aux (step-1) tr buf
    ) \/ (
      exists i b1 buf.
        Some (b1, msg) == split buf i /\
        attacker_knows_aux (step-1) tr buf
    ) \/
    // AEAD
    (
      exists key nonce buf ad.
        msg == aead_enc key nonce buf ad /\
        attacker_knows_aux (step-1) tr key /\
        attacker_knows_aux (step-1) tr nonce /\
        attacker_knows_aux (step-1) tr buf /\
        attacker_knows_aux (step-1) tr ad
    ) \/ (
      exists key nonce buf ad.
        Some msg == aead_dec key nonce buf ad /\
        attacker_knows_aux (step-1) tr key /\
        attacker_knows_aux (step-1) tr nonce /\
        attacker_knows_aux (step-1) tr buf /\
        attacker_knows_aux (step-1) tr ad
    ) \/
    // Public-key encryption
    (
      exists sk.
        msg == pk sk /\
        attacker_knows_aux (step-1) tr sk
    ) \/ (
      exists pk nonce buf.
        msg == pk_enc pk nonce buf /\
        attacker_knows_aux (step-1) tr pk /\
        attacker_knows_aux (step-1) tr nonce /\
        attacker_knows_aux (step-1) tr buf
    ) \/ (
      exists sk buf.
        Some msg == pk_dec sk buf /\
        attacker_knows_aux (step-1) tr sk /\
        attacker_knows_aux (step-1) tr buf
    ) \/
    // Signature
    (
      exists sk.
        msg == vk sk /\
        attacker_knows_aux (step-1) tr sk
    ) \/ (
      exists sk nonce buf.
        msg == sign sk nonce buf /\
        attacker_knows_aux (step-1) tr sk /\
        attacker_knows_aux (step-1) tr nonce /\
        attacker_knows_aux (step-1) tr buf
    ) \/
    // Hash
    (
      exists buf.
        msg == hash buf /\
        attacker_knows_aux (step-1) tr buf
    )
  )

[@@ "opaque_to_smt"]
val attacker_knows: trace -> bytes -> prop
let attacker_knows tr msg =
  exists step. attacker_knows_aux step tr msg

val move_requires_4
      (#a #b #c #d: Type)
      (#p #q: (a -> b -> c -> d -> Type))
      ($_: (x: a -> y: b -> z: c -> w: d -> Lemma (requires (p x y z w)) (ensures (q x y z w))))
      (x: a)
      (y: b)
      (z: c)
      (w: d)
    : Lemma (p x y z w ==> q x y z w)
let move_requires_4 #a #b #c #d #p #q pf x y z w =
  introduce p x y z w ==> q x y z w with _. pf x y z w

val corrupted_state_is_publishable:
  {|protocol_invariants|} ->
  tr:trace -> prin:principal -> sess_id:nat -> content:bytes ->
  Lemma
  (requires
    is_corrupt tr (principal_state_label prin sess_id) /\
    state_was_set tr prin sess_id content /\
    trace_invariant tr
  )
  (ensures is_publishable tr content)
let corrupted_state_is_publishable #invs tr prin sess_id content =
  state_is_knowable_by tr prin sess_id content

#push-options "--z3rlimit 25"
val attacker_only_knows_publishable_values_aux:
  {|protocol_invariants|} ->
  step:nat -> tr:trace -> msg:bytes ->
  Lemma
  (requires
    trace_invariant tr /\
    attacker_knows_aux step tr msg
  )
  (ensures is_publishable tr msg)
let rec attacker_only_knows_publishable_values_aux #invs step tr msg =
  if step = 0 then (
    FStar.Classical.forall_intro   (FStar.Classical.move_requires   (msg_sent_on_network_are_publishable tr));
    FStar.Classical.forall_intro   (FStar.Classical.move_requires   (msg_sent_on_network_are_publishable tr));
    FStar.Classical.forall_intro_3 (FStar.Classical.move_requires_3 (corrupted_state_is_publishable tr));
    FStar.Classical.forall_intro   (FStar.Classical.move_requires   (literal_to_bytes_is_publishable tr))
  ) else (
    FStar.Classical.forall_intro   (FStar.Classical.move_requires   (attacker_only_knows_publishable_values_aux (step-1) tr));
    FStar.Classical.forall_intro_2 (FStar.Classical.move_requires_2 (concat_preserves_publishability tr));
    FStar.Classical.forall_intro_2 (FStar.Classical.move_requires_2 (split_preserves_publishability tr));
    FStar.Classical.forall_intro_4 (                move_requires_4 (aead_enc_preserves_publishability tr));
    FStar.Classical.forall_intro_4 (                move_requires_4 (aead_dec_preserves_publishability tr));
    FStar.Classical.forall_intro   (FStar.Classical.move_requires   (pk_preserves_publishability tr));
    FStar.Classical.forall_intro_3 (FStar.Classical.move_requires_3 (pk_enc_preserves_publishability tr));
    FStar.Classical.forall_intro_2 (FStar.Classical.move_requires_2 (pk_dec_preserves_publishability tr));
    FStar.Classical.forall_intro   (FStar.Classical.move_requires   (vk_preserves_publishability tr));
    FStar.Classical.forall_intro_3 (FStar.Classical.move_requires_3 (sign_preserves_publishability tr));
    FStar.Classical.forall_intro   (FStar.Classical.move_requires   (hash_preserves_publishability tr));
    ()
  )
#pop-options

val attacker_only_knows_publishable_values:
  {|protocol_invariants|} ->
  tr:trace -> msg:bytes ->
  Lemma
  (requires
    trace_invariant tr /\
    attacker_knows tr msg
  )
  (ensures is_publishable tr msg)
let attacker_only_knows_publishable_values #invs tr msg =
  reveal_opaque (`%attacker_knows) (attacker_knows);
  eliminate exists step. attacker_knows_aux step tr msg
  returns is_publishable tr msg
  with _. (
    attacker_only_knows_publishable_values_aux step tr msg
  )
