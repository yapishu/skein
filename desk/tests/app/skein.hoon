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
::  test cell-id deterministic
::
++  test-cell-id-deterministic
  =/  id1  (sham [1 [~zod %app] [~fen %app] *@da])
  =/  id2  (sham [1 [~zod %app] [~fen %app] *@da])
  (expect-eq !>(id1) !>(id2))
::
::  test cell-id varies with input
::
++  test-cell-id-unique
  =/  id1  (sham [1 [~zod %app] [~fen %app] *@da])
  =/  id2  (sham [2 [~zod %app] [~fen %app] *@da])
  (expect-eq !>(%.n) !>(=(id1 id2)))
::
::  test derive-key produces different keys for different tags
::
++  test-derive-key-distinct
  =/  base=relay-key  0xdead.beef
  =/  cell-id=@uv  0v3
  =/  k1=@ux  (shaz (jam ['skein-hop' base cell-id]))
  =/  k2=@ux  (shaz (jam ['skein-body' base cell-id]))
  (expect-eq !>(%.n) !>(=(k1 k2)))
::
::  test seen cache pruning drops old entries
::
++  test-prune-seen
  =/  now=@da  ~2025.1.1
  =/  old=@da  (sub now ~h2)
  =/  recent=@da  (sub now ~m30)
  =/  step1=relay-step  [0v1 ~]
  =/  step2=relay-step  [0v2 ~]
  =/  seen=(map relay-step @da)
    (~(put by (~(put by *(map relay-step @da)) step1 old)) step2 recent)
  =/  cutoff=@da  (sub now ~h1)
  =/  pruned=(map relay-step @da)
    %-  ~(rep by seen)
    |=  [[step=relay-step at=@da] out=(map relay-step @da)]
    ?:  (lth at cutoff)  out
    (~(put by out) step at)
  ;:  weld
    (expect-eq !>(%.n) !>((~(has by pruned) step1)))
    (expect-eq !>(%.y) !>((~(has by pruned) step2)))
  ==
::
::  test en/de:crub:crypto round-trip
::
++  test-crub-roundtrip
  =/  key=@ux  (shaz 'test-key')
  =/  data=@  (jam 'test-data')
  =/  encrypted  (en:crub:crypto key data)
  =/  decrypted  (de:crub:crypto key encrypted)
  (expect-eq !>(`data) !>(decrypted))
::
::  test header layer encrypt/decrypt round-trip
::
++  test-header-layer-roundtrip
  =/  relay-key=@ux  (shaz 'relay-key-1')
  =/  cell-id=@uv  (sham 'test-cell')
  =/  hop-key=@ux  (shaz (jam ['skein-hop' relay-key cell-id]))
  =/  layer=header-layer
    [~[~zod] ~ `(shaz 'body-key') `~s5]
  ::  encrypt the layer
  =/  boxed=@ux  (en:crub:crypto hop-key (jam layer))
  ::  decrypt it
  =/  raw  (de:crub:crypto hop-key boxed)
  ?~  raw
    (expect-eq !>('should-decrypt') !>('failed'))
  =/  decoded  (header-layer (cue u.raw))
  (expect-eq !>(layer) !>(decoded))
::
::  test two-layer nested header (simulates 2-hop route)
::
++  test-nested-header
  =/  key1=@ux  (shaz 'relay-1-key')
  =/  key2=@ux  (shaz 'relay-2-key')
  =/  cell-id=@uv  (sham 'cell-nested')
  =/  hk1=@ux  (shaz (jam ['skein-hop' key1 cell-id]))
  =/  hk2=@ux  (shaz (jam ['skein-hop' key2 cell-id]))
  =/  body-key=@ux  (shaz 'payload-key')
  ::  inner layer (hop 2 → destination)
  =/  inner-layer=header-layer  [~ ~ `body-key ~]
  =/  inner-box=@ux  (en:crub:crypto hk2 (jam inner-layer))
  ::  outer layer (hop 1 → hop 2)
  =/  outer-layer=header-layer  [~[~zod] `inner-box ~ `~s10]
  =/  outer-box=@ux  (en:crub:crypto hk1 (jam outer-layer))
  ::  peel outer
  =/  raw1  (de:crub:crypto hk1 outer-box)
  ?~  raw1
    (expect-eq !>('outer-should-open') !>('failed'))
  =/  decoded1  (header-layer (cue u.raw1))
  ?~  inner.decoded1
    (expect-eq !>('should-have-inner') !>('failed'))
  ::  peel inner
  =/  raw2  (de:crub:crypto hk2 u.inner.decoded1)
  ?~  raw2
    (expect-eq !>('inner-should-open') !>('failed'))
  =/  decoded2  (header-layer (cue u.raw2))
  ;:  weld
    ::  outer layer has correct remaining
    (expect-eq !>(~[~zod]) !>(remaining.decoded1))
    ::  inner layer has body key
    (expect-eq !>(`body-key) !>(body-key.decoded2))
    ::  inner layer has no further inner
    (expect-eq !>(~) !>(inner.decoded2))
  ==
--
