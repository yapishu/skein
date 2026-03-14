/-  *skein
/+  *test
|%
::  sanity check
::
++  test-sanity
  (expect-eq !>(2) !>((add 1 1)))
::
::  test jam/cue payload round-trip
::
++  test-payload-roundtrip
  =/  original  'hello-skein'
  =/  boxed  (jam original)
  =/  opened  (cue boxed)
  (expect-eq !>(original) !>(opened))
::
::  test en/de:crub:crypto symmetric round-trip
::
++  test-crub-symmetric-roundtrip
  =/  key=@ux  (shaz 'test-key')
  =/  data=@  (jam 'test-data')
  =/  encrypted  (en:crub:crypto key data)
  =/  decrypted  (de:crub:crypto key encrypted)
  (expect-eq !>(`data) !>(decrypted))
::
::  test X25519 DH shared secret commutativity
::
++  test-x25519-dh-roundtrip
  =/  seed-a=@ux  (end [3 32] (shaz 'alice-seed'))
  =/  seed-b=@ux  (end [3 32] (shaz 'bob-seed'))
  =/  pub-a=@ux   `@ux`(puck:ed:crypto seed-a)
  =/  pub-b=@ux   `@ux`(puck:ed:crypto seed-b)
  ::  shared secrets must match (DH commutativity)
  =/  shared-ab=@ux  (shar:ed:crypto pub-b seed-a)
  =/  shared-ba=@ux  (shar:ed:crypto pub-a seed-b)
  (expect-eq !>(shared-ab) !>(shared-ba))
::
::  test ephemeral DH seal/open round-trip
::
++  test-seal-open-roundtrip
  =/  relay-seed=@ux  (end [3 32] (shaz 'relay-seed'))
  =/  relay-pub=@ux   `@ux`(puck:ed:crypto relay-seed)
  =/  data=@  (jam 'hello-skein-crypto')
  =/  eny=@  (shaz 'test-entropy')
  ::  seal
  =/  eph-seed=@ux  (end [3 32] (shaz (jam [%skein-eph-seal eny data])))
  =/  eph-pub=@ux   `@ux`(puck:ed:crypto eph-seed)
  =/  shared=@ux    (shar:ed:crypto relay-pub eph-seed)
  =/  sym-key=@ux   (shaz shared)
  =/  sealed=@ux    (en:crub:crypto sym-key data)
  =/  box=@ux       `@ux`(jam [eph-pub sealed])
  ::  open
  =/  raw  (cue box)
  ?>  ?=(^ raw)
  ?>  ?=(@ -.raw)
  ?>  ?=(@ +.raw)
  =/  r-shared=@ux  (shar:ed:crypto -.raw relay-seed)
  =/  r-sym=@ux     (shaz r-shared)
  =/  opened        (de:crub:crypto r-sym +.raw)
  (expect-eq !>(`data) !>(opened))
::
::  test body onion wrap/peel round-trip
::
++  test-onion-body-roundtrip
  =/  body=@ux  `@ux`(jam 'test-payload-data')
  =/  rng1=@ux  (shaz 'rng-1')
  =/  rng2=@ux  (shaz 'rng-2')
  =/  rng3=@ux  (shaz 'rng-3')
  ::  wrap: apply in order [rng3 rng2 rng1] (innermost first)
  =/  w1=@ux  (en:crub:crypto rng3 body)
  =/  w2=@ux  (en:crub:crypto rng2 w1)
  =/  wrapped=@ux  (en:crub:crypto rng1 w2)
  ::  peel: each hop peels its own layer
  =/  p1  (de:crub:crypto rng1 wrapped)
  ?~  p1  (expect-eq !>('peel-1-should-work') !>('failed'))
  =/  p2  (de:crub:crypto rng2 u.p1)
  ?~  p2  (expect-eq !>('peel-2-should-work') !>('failed'))
  =/  p3  (de:crub:crypto rng3 u.p2)
  ?~  p3  (expect-eq !>('peel-3-should-work') !>('failed'))
  (expect-eq !>(body) !>(u.p3))
::
::  test seen cache pruning drops old entries
::
++  test-prune-seen
  =/  now=@da  ~2025.1.1
  =/  old=@da  (sub now ~h2)
  =/  recent=@da  (sub now ~m30)
  =/  cid1=@uv  0v1
  =/  cid2=@uv  0v2
  =/  seen=(map @uv @da)
    (~(put by (~(put by *(map @uv @da)) cid1 old)) cid2 recent)
  =/  cutoff=@da  (sub now ~h1)
  =/  pruned=(map @uv @da)
    %-  ~(rep by seen)
    |=  [[cid=@uv at=@da] out=(map @uv @da)]
    ?:  (lth at cutoff)  out
    (~(put by out) cid at)
  ;:  weld
    (expect-eq !>(%.n) !>((~(has by pruned) cid1)))
    (expect-eq !>(%.y) !>((~(has by pruned) cid2)))
  ==
--
