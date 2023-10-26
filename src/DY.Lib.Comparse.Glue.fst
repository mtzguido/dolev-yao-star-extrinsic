module DY.Lib.Comparse.Glue

open Comparse
open DY.Core

instance bytes_like_bytes: bytes_like bytes = {
  length = length;

  empty = literal_to_bytes FStar.Seq.empty;
  empty_length = (fun () -> length_literal_to_bytes FStar.Seq.empty);
  recognize_empty = (fun b ->
  literal_to_bytes_to_literal FStar.Seq.empty;
    match bytes_to_literal b with
    | None -> false
    | Some lit ->
      if Seq.length lit = 0 then (
        assert(lit `FStar.Seq.eq` FStar.Seq.empty);
        bytes_to_literal_to_bytes b;
        true
      ) else (
        length_literal_to_bytes FStar.Seq.empty;
        false
      )
  );

  concat = concat;
  concat_length = (fun b1 b2 -> concat_length b1 b2);

  split = split;
  split_length = (fun b i -> split_length b i);

  split_concat = (fun b1 b2 -> split_concat b1 b2);

  concat_split = (fun b i -> concat_split b i);

  to_nat = (fun b ->
    bytes_to_literal_to_bytes b;
    match bytes_to_literal b with
    | None -> None
    | Some lit ->  (
      FStar.Endianness.lemma_be_to_n_is_bounded lit;
      Some (FStar.Endianness.be_to_n lit)
    )
  );
  from_nat = (fun sz n ->
    literal_to_bytes (FStar.Endianness.n_to_be sz n)
  );

  from_to_nat = (fun sz n ->
    literal_to_bytes_to_literal (FStar.Endianness.n_to_be sz n)
  );

  to_from_nat = (fun b ->
    bytes_to_literal_to_bytes b
  );
}

val bytes_invariant_is_pre_compatible:
  cinvs:crypto_invariants -> tr:trace ->
  Lemma
  (bytes_pre_is_compatible (bytes_invariant cinvs tr))
  [SMTPat (bytes_pre_is_compatible (bytes_invariant cinvs tr))]
let bytes_invariant_is_pre_compatible cinvs tr =
  bytes_pre_is_compatible_intro #bytes (bytes_invariant cinvs tr)
    ()
    (fun b1 b2 -> ())
    (fun b i -> ())
    (fun sz n -> ())

val is_publishable_is_pre_compatible:
  cinvs:crypto_invariants -> tr:trace ->
  Lemma
  (bytes_pre_is_compatible (is_publishable cinvs tr))
  [SMTPat (bytes_pre_is_compatible (is_publishable cinvs tr))]
let is_publishable_is_pre_compatible cinvs tr =
  bytes_pre_is_compatible_intro #bytes (is_publishable cinvs tr)
    (literal_to_bytes_is_publishable cinvs tr FStar.Seq.empty)
    (fun b1 b2 -> concat_preserves_publishability cinvs tr b1 b2)
    (fun b i -> split_preserves_publishability cinvs tr b i)
    (fun sz n -> literal_to_bytes_is_publishable cinvs tr (FStar.Endianness.n_to_be sz n))

val is_knowable_by_is_pre_compatible:
  cinvs:crypto_invariants -> lab:label -> tr:trace ->
  Lemma
  (bytes_pre_is_compatible (is_knowable_by cinvs lab tr))
  [SMTPat (bytes_pre_is_compatible (is_knowable_by cinvs lab tr))]
let is_knowable_by_is_pre_compatible cinvs lab tr =
  bytes_pre_is_compatible_intro #bytes (is_knowable_by cinvs lab tr)
    (literal_to_bytes_is_publishable cinvs tr Seq.empty)
    (fun b1 b2 -> concat_preserves_knowability cinvs lab tr b1 b2)
    (fun b i -> split_preserves_knowability cinvs lab tr b i)
    (fun sz n -> (literal_to_bytes_is_publishable cinvs tr (FStar.Endianness.n_to_be sz n)))

val parse_serialize_inv_lemma_smtpat:
  #bytes:Type0 -> {|bl:bytes_like bytes|} ->
  a:Type -> {|ps_a:parseable_serializeable bytes a|} ->
  x:a ->
  Lemma
  (ensures parse a (serialize #bytes a x) == Some x)
  [SMTPat (parse #bytes #bl a #ps_a (serialize #bytes a #ps_a x))]
let parse_serialize_inv_lemma_smtpat #bytes #bl a #ps_a x =
  parse_serialize_inv_lemma #bytes a #ps_a x
